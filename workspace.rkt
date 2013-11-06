#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/display
         rwind/doc-string
         rwind/util
         rwind/keymap
         rwind/window
         rwind/color
         rwind/policy/base
         x11/x11
         racket/list
         racket/contract
         rackunit
         )

#| *** Workspace **** (aka desktops)

The children of the root window are the workspace's virtual roots (one per workspace).
The virtual root contains all the "top-level" windows of the clients.
To switch between workspaces, it suffices to unmap the current workspace and map the new one
(This is done by activate-workspace).

|#

#|
- See sawfish/lisp/sawfish/wm/workspaces.jl
- evilwm, make-new-client
- Workspaces are organized into a list (no need for a vector since we don't expect more
  than a dozen of them).
  The layout (grid, sphere, etc.) will be implemented on top of that.
- Convention: wk: workspace; wkn: workspace-number; w: window

http://en.wikipedia.org/wiki/Root_window
http://stackoverflow.com/questions/2431535/top-level-window-on-x-window-system
|#

#| TODO
- do not provide unnecessary procedures
|#

;=================;
;=== Variables ===;
;=================;

(define* workspaces '())

(define* workspace-warp?
  "Fun-box that holds whether moving after the last (first) workpsace returns to the first (last)."
  (make-fun-box #f))

#;(define*/contract current-workspace-number
  (or/c #f number?)
  "Current workspace number"
  #f)

(define workspace-mode
  #;"Controls the modes in which the workspaces are displayed.
'single: One workspace over all heads (monitors). The workspace is of the size of the heads bounding box.
'multi: One workspace per head. The workspace size is adapted to the head."
  (make-fun-box 'single))

;====================;
;=== Constructors ===;
;====================;

;; window is the virtual root window of the workspace
(struct workspace (id root-window windows)
  #:transparent
  #:mutable)
(provide (struct-out workspace))

(define*/contract (make-workspace [id #f]
                                  #:background-color [bk-color black-pixel])
  ([] [(or/c string? #f) #:background-color exact-nonnegative-integer?] . ->* . workspace?)
  "Returns a newly created workspace, which contains a new unmapped window of the size of the display.
  The new workspace is inserted into the workspace list."
  ;; Sets the new window attributes so that it will report any events
  (define attrs (make-XSetWindowAttributes
                 #:event-mask '(SubstructureRedirectMask
                                SubstructureNotifyMask)
                 #:background-pixel bk-color
                 ))
  ;; Create the window, but don't map it yet.
  (define root-window
    (XCreateWindow (current-display) (true-root-window)
                   0 0
                   (display-width) (display-height)
                   0
                   CopyFromParent/int
                   'InputOutput
                   #f
                   '(EventMask BackPixel) attrs))

  ;; Add the window to the list of supported virtual roots
  ;; Does this work?? Not sure it really appends...
  (change-window-property (true-root-window) _NET_VIRTUAL_ROOTS 'XA_WINDOW 'PropModeAppend (list root-window))

  ;; Make sure we will see the keymap events
  (virtual-root-apply-keymaps root-window)
  (define wk (workspace id root-window '()))
  (insert-workspace wk)
  wk)

;==================;
;=== Predicates ===;
;==================;

(define*/contract (workspace-subwindow? wk window)
  (workspace? window? . -> . any/c)
  "Returns non-#f if window is a mapped window of the specified workspace, or #f otherwise."
  (member window (workspace-subwindows window)))

(define* (valid-workspace-number? wkn)
  (and (number? wkn) (>= wkn 0) (< wkn (count-workspaces))))

(define* workspace-ref?
  (or/c workspace? number? string?))

(define*/contract (some-root-window? window)
  (window? . -> . any/c)
  "Returns #f if window is not a (virtual) root window, non-#f otherwise."
  (or (find-root-window-workspace window)
      (window=? window (true-root-window))))

;=================;
;=== Selectors ===;
;=================;

(define*/contract (workspace-bounds wk)
  (workspace? . -> . (values number? number? number? number?))
  "Returns the position and dimension of the virtual root window of the specified workspace."
  (window-bounds (workspace-root-window wk)))

(define*/contract (workspace-dimensions wk)
  (workspace? . -> . (values number? number?))
  "Returns the dimension of the virtual root window of the specified workspace."
  (window-dimensions (workspace-root-window wk)))

(define*/contract (workspace-position wk)
  (workspace? . -> . (values number? number?))
  "Returns the position of the virtual root window of the specified workspace."
  (window-position (workspace-root-window wk)))

(define*/contract (find-root-window-workspace window)
  (window? . -> . any/c)
  "Returns the workspace for which window is the (virtual) root, or #f if none is found."
  (findf (λ(wk)(window=? window (workspace-root-window wk)))
         workspaces))

(define*/contract (find-head-workspace hd)
  (number? . -> . (or/c #f workspace?))
  "Returns the (current) root-window of the given head."
  (and=> (head-root-window hd)
         find-root-window-workspace))

(define*/contract (workspace-subwindows wk)
  (workspace? . -> . list?)
  "Returns the list of windows that are managed by the specified workspace,
in the sense of `window-list'."
  ; Should be simply `workspace-windows', but not yet entirely functional.
  (window-list (workspace-root-window wk)))

(define* (count-workspaces)
  (length workspaces))

(define*/contract (number->workspace wkn)
  (valid-workspace-number? . -> . workspace?)
  "Returns the workspace of the associated number."
  (list-ref workspaces wkn))

(define*/contract (workspace->number wk)
  (workspace? . -> . number?)
  "Returns the workspace-number of the given workspace."
  (for/or ([w workspaces] [i (in-naturals)])
    (and (eq? w wk) i)))

(define*/contract (find-workspace wk/i/n)
  (workspace-ref? . -> . (or/c #f workspace?))
  "Returns the workspace of the given workspace/workspace-id/workspace-number, or #f if none is found."
  (cond [(workspace? wk/i/n) wk/i/n]
        [(string? wk/i/n)
         (findf (λ(wk)(string=? wk/i/n (workspace-id wk)))
                workspaces)]
        [(valid-workspace-number? wk/i/n)
         (number->workspace wk/i/n)]
        [else #f])
  )

(define*/contract (find-window-workspace window)
  (window? . -> . (or/c #f workspace?))
  "Returns the workspace that contains window, or #f if none is found."
  (findf (λ(wk)(member window (workspace-subwindows wk)))
         workspaces))

(define*/contract (guess-window-workspace window)
  (window? . -> . (or/c #f workspace?))
  "Returns the workspace that /should/ contain the window based on the window position,
but that does not currently contain it.
This is mainly meant to be used to restore windows to their proper workspaces."
  (and=> (find-window-head window)
         find-head-workspace))

(define* (pointer-workspace)
  "Returns the workspace that contains the pointer or #f if none is found."
  (find-head-workspace (pointer-head)))

(define* (focus-workspace)
  "Returns the workspace that contains the window having the focus or #f if none is found."
  (find-head-workspace (focus-head)))

(define/contract (workspace-addn n0 inc warp?)
  (valid-workspace-number? number? any/c . -> . valid-workspace-number?)
  (define nmax (count-workspaces))
  (define wkn (+ n0 inc))
  (if warp?
      (modulo wkn nmax)
      (min wkn (sub1 nmax))))

(define/contract (workspace-subn n0 dec warp?)
  (valid-workspace-number? number? any/c . -> . valid-workspace-number?)
  (define nmax (count-workspaces))
  (define wkn (- n0 dec))
  (if warp?
      (modulo wkn nmax)
      (max wkn 0)))

;==================;
;=== Operations ===;
;==================;

(define*/contract (change-workspace-mode mode)
  ((one-of/c 'multi 'single) . -> . any)
  "Controls the modes in which the workspaces are displayed.
  'single: One workspace over all heads (monitors). The workspace is of the size of the heads bounding box.
  'multi: One workspace per head. The workspace size is adapted to the head."

  ; (Warning) TODO: The multi mode should not be activated if some heads are superimposed!

  (when (not (eq? mode (workspace-mode)))
    (workspace-mode mode)
    (policy. on-change-workspace-mode mode)
    (update-workspaces)
    ))

(define/contract (unmap-workspace wk)
  (workspace? . -> . any)
  ;; Removes the workspace from the screen
  (unmap-window (workspace-root-window wk))
  )

(define*/contract (insert-workspace wk [n (length workspaces)])
  (workspace? . -> . any)
  "Inserts workspace wk at position n."
  (cond [(or (valid-workspace-number? n) (= n (length workspaces)))
         (define-values (left right) (split-at workspaces n))
         (set! workspaces (append left (list wk) right))]
        [else
         (error "Cannot insert workspace: Invalid number:" n)]))

;; TODO: what to do about the windows contained in the current workspace?
;; (currently they are plain lost!)
(define*/contract (remove-workspace wkn)
  (valid-workspace-number? . -> . void?)
  (define-values (left right) (split-at workspaces wkn))
  (set! workspaces (append left (rest right))))

(define*/contract (remove-window-from-workspace window [wk (find-window-workspace window)])
  ([window?] [(or/c workspace? #f)] . ->* . any/c)
  "Removes the window from the workspace (by default the workspace of the window)
if it is not #f."
  ;; TODO: Remove the workspace-window from the list of _NET_VIRTUAL_ROOTS
  ;(change-window-property (true-root-window) _NET_VIRTUAL_ROOTS 'XA_WINDOW 'PropModeAppend (list root-window) 32)
  (when wk
    (set-workspace-windows! wk (remove window (workspace-windows wk)))
    (policy. on-remove-window-from-workspace window wk)))

(define*/contract (add-window-to-workspace window wk)
  (window? workspace? . -> . any)
  "Adds the window to the workspace. 
If the window was in another workspace, it is removed from the latter."
  (dprintf "Adding window ~a to workspace ~a\n" window wk)
  (define wk-src (find-window-workspace window))
  (cond [(some-root-window? window)
         (dprintf "Warning: not a valid window (~a) to add to workspace\n" window)]
        [(not (eq? wk wk-src))
         ; The found workspace (or #f) is not the target workspace
         (remove-window-from-workspace window wk-src)
         (reparent-window window (workspace-root-window wk))
         (define wk-ws (workspace-windows wk))
         (unless (memq window wk-ws)
           ; This can happen if closed windows get reused for new ones, like xterm
           (set-workspace-windows! wk (cons window wk-ws)))
         (policy. on-add-window-to-workspace window wk)]))


(define*/contract (move-window-to-workspace window wk/i/n)
  (window? workspace-ref? . -> . any)
  (add-window-to-workspace window (find-workspace wk/i/n)))

(define*/contract (move-window-to-workspace/activate window wk/i/n)
  (window? workspace-ref? . -> . any)
  (define wk (find-workspace wk/i/n))
  (add-window-to-workspace window wk)
  (activate-workspace wk))

(define/contract (activate-workspace/single wk)
  (workspace? . -> . any)
  ;; Places the specified workspace over all heads

  #;(define old-root (head-info-root-window hd-info))

  ; Make sure all workspace windows are unmapped:
  ; (could be optimized, but is safer)
  (for ([wk workspaces])
    (unmap-window (workspace-root-window wk)))
  ; Hide the old workspace:
  #;(when old-root
    (unmap-window old-root))

  ;; Make the new workspace root window fit to the bounding box of all heads
  (workspace-fit-to-heads wk)

  ;; Make the new root window the root of all heads
  (define new-root (workspace-root-window wk))
  (for ([hd-info (head-infos)])
    (set-head-info-root-window! hd-info new-root))

  ; show the new workspace with all its windows:
  (map-window new-root)
  )

(define/contract (activate-workspace/multi new-wk head)
  (workspace? number? . -> . any)
  ;; Activates the specified workspace when in 'multi mode

  (define hd-info (get-head-info head))
  (check-not-false hd-info)

  (define old-root (head-info-root-window hd-info))
  (define new-root (workspace-root-window new-wk))
  (define other-head (find-root-window-head new-root))

  (cond [(window=? new-root old-root)
         ; We are trying to activate the current-workspace -> no change
         (dprintf "Trying to activate the current workspace.\n")
         ; in case it is not already mapped:
         (map-window new-root)
         ]
        [other-head
         ; The new workspace is already mapped in another head, so we swap the workspaces instead
         (dprintf "New workspace already mapped in head ~a.\n" other-head)
         (define old-wk (find-root-window-workspace old-root))
         (define other-head-info (get-head-info other-head))

         (set-head-info-root-window! other-head-info old-root)
         (set-head-info-root-window! hd-info new-root)

         ; Reconfigure the workspace to the dimensions of the head/monitor on which it is displayed
         ; TODO: use find-root-window-heads ?
         (workspace-fit-to-heads old-wk (list other-head))
         (workspace-fit-to-heads new-wk (list head))

         ; just in case they are not mapped:
         (map-window old-root)
         (map-window new-root)
         ]
        [else
         ; We replace the current workspace by the new one in the specified head
         (dprintf "Normal replacement of current workspace.\n")

         ; Hide the old workspace:
         (when old-root
           (unmap-window old-root))

         ; List of heads that contain the old-root
         (define heads (if old-root
                           (find-root-window-heads old-root)
                           (list head)))

         ; Reconfigure the workspace to span over all the heads the old workspace was in
         (workspace-fit-to-heads new-wk heads)

         ; show the new workspace with all its windows:
         (map-window new-root)

         ; The following may fail because the window may not yet be visible:
         ;(set-input-focus new-root)
         ; TODO: Add a callback for when the window is visible?
         (set-input-focus (true-root-window))]))

(define*/contract (activate-workspace wk/i/n [head (pointer-head)])
  ([workspace-ref?] [number?] . ->* . any)
  "Switches to workspace wk/i/n (either a `workspace?', a `number?' or a workspace identifier)."
  (dprintf "Activating workspace ~a\n" wk/i/n)

  (define new-wk (find-workspace wk/i/n))
  (check-not-false new-wk)

  (case (workspace-mode)
    [(single) (activate-workspace/single new-wk)]
    [(multi)  (activate-workspace/multi new-wk head)])
  (policy. on-activate-workspace new-wk))

(define* (workspace-fit-to wk hx hy hw hh [move? #t] [resize? move?])
  "Moves and resizes the workspace to the given dimensions.
  If move? is not #f, all top-level windows of the workspace are moved proportionally to the resizing ratio.
  If resize? is not #f, they are resized proportionally."
  (define window (workspace-root-window wk))
  (define-values (w-old h-old) (window-dimensions window))
  (move-resize-window window hx hy hw hh)
  (define (scale-w wi)
    (round (/ (* wi hw) w-old)))
  (define (scale-h hi)
    (round (/ (* hi hh) h-old)))
  (when (or move? resize?)
    (for ([win (workspace-subwindows wk)])
      (define-values (x y w h) (window-bounds win))
      (move-resize-window win
                          (if move? (scale-w x) x)
                          (if move? (scale-h y) y)
                          (if resize? (scale-w w) w)
                          (if resize? (scale-h h) h)
                          ))))

(define*/contract (workspace-fit-to-heads wk [heads #f] [move? #t] [resize? move?])
  ([workspace?] [(or/c #f (listof number?)) any/c any/c] . ->* . any)
  "Like `workspace-fit-to', but fits to a given list of heads (numbers), i.e.,
the workspace window will then span over all the given heads.
If heads is #f, then all heads are considered.
Furthermore, it also changes the root-windows of the heads."
  (unless heads (set! heads (head-count)))
  (define-values (gx gy gw gh) (head-list-bounds heads))
  ; make the virtual root fit to the head
  (workspace-fit-to wk gx gy gw gh move? resize?)
  (define wk-root (workspace-root-window wk))
  ; Change the current root of all the containing heads:
  (for ([hd heads])
    (set-head-info-root-window! (get-head-info hd) wk-root)))

(define* (update-workspaces)
  "Updates the information about the screens and maps one workspace in each screen.
See `change-workspace-mode' for more information on the different modes."

  ; First make sure that all root windows are unmapped
  (for-each unmap-workspace workspaces)

  (case (workspace-mode)
    [(single)
     (activate-workspace/single (first workspaces))]
    [(multi)
     ; WARNING: We should check that no root-window are overlapping,
     ; otherwise we should fall back to 'single mode!
     (for ([hd (head-count)])
       (define wk (or (find-workspace hd)
                      (make-workspace (number->string hd))))
       (workspace-fit-to-heads wk (list hd))
       (activate-workspace/multi wk hd))])
  )

(define*/contract (split-workspace [style 'horiz])
  ([] [(one-of/c 'horiz 'vert)] . ->* . any)
  "Splits the current workspace horizontally or vertically.
This allows for multiple workspaces on a single monitor.
See also `split-head'."
  (if (eq? (workspace-mode) 'multi)
      (begin
        (split-head #:style style)
        (update-workspaces))
      (dprintf "split-workspace: Must be in 'multi mode (use `change-workspace-mode')")))

(define*/contract (exit-workspace wk)
  (workspace? . -> . any)
  "Reparents all sub-windows of the specified workspace to the true root."
  ; This is necessary to avoid killing the windows when RWind quits.
  (define root (true-root-window))
  (for ([w (workspace-subwindows wk)])
    (reparent-window w root)))

(define* (reset-workspaces)
  (xinerama-update-infos)
  (update-workspaces))

;============;
;=== Init ===;
;============;

(define* (init-workspaces)
  ; Wait for sync to be sure that all pending windows (not currently managed by us) are mapped:
  (XSync (current-display) #f)

  (change-window-property (true-root-window) _NET_SUPPORTED 'XA_WINDOW 'PropModeAppend (list _NET_VIRTUAL_ROOTS))


  ; Get the window list *before* creating the workspace windows...
  (define existing-windows (window-list (true-root-window)))

  (define color-list
    '("DarkSlateGray" "DarkSlateBlue" "Sienna" "DarkRed"))

  ; Create at least one workspace per head
  ; (This should move to the user's config file?)
  (for ([i (max (head-count) 4)]
        [color (in-cycle color-list)])
    ; Create a workspace and apply the keymap to it
    (make-workspace (number->string i)  #:background-color (find-named-color color)))

  ; Place the workspaces for a given mode
  (change-workspace-mode 'single)
  
  (dprintf "Workspaces:\n")
  (for ([wk workspaces])
    (dprintf "wk:~a\n" wk)
    (dprintf "bounds: ~a\n" (cvl workspace-bounds wk)))
  
  (dprintf "Heads:~a\n" (head-infos))

  (dprintf "Trying to add windows:\n")
  ; Put all mapped windows in the workspace it belongs to,
  ; depending on its position
  (for ([w existing-windows])
    (define wk (guess-window-workspace w))
    (dprintf "~a\n" (cvl window-bounds w))
    (if wk
        (add-window-to-workspace w wk)
        (dprintf "Warning: Could not guess workspace for window ~a\n" w)))
  )

(define* (exit-workspaces)
  "Reparents all sub-windows to the true root-window."
  ; TODO: unmap all workspace virtual-root-windows?
  (for-each exit-workspace workspaces)
  )
