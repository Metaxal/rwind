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
         x11-racket/x11
         racket/list
         racket/contract
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

(define*/contract current-workspace-number 
  (or/c #f number?)
  "Current workspace number"
  #f)

;====================;
;=== Constructors ===;
;====================;

(struct workspace (id window)
  #:transparent
  #:mutable)
(provide (struct-out workspace))

(define*/contract (make-workspace [id #f]
                                  #:background-color [bk-color black-pixel])
  (() ((or/c string? #f) #:background-color exact-nonnegative-integer?) . ->* . workspace?)
  "Returns a newly created workspace, which contains a new unmapped window of the size of the display.
  The new workspace is inserted into the workspace list."
  ;; Sets the new window attributes so that it will report any events
  (define attrs (make-XSetWindowAttributes 
                 #:event-mask '(SubstructureRedirectMask)
                 #:background-pixel bk-color
                 ))
  (define window
    (XCreateWindow (current-display) (true-root-window)
                   0 0
                   (display-width) (display-height)
                   0
                   CopyFromParent/int
                   'InputOutput
                   #f
                   '(EventMask BackPixel) attrs))
  ;; Create the window, but don't map it yet.
  ;; Make sure we will see the keymap events
  (virtual-root-apply-keymaps window)
  (define wk (workspace id window))
  (insert-workspace wk)
  wk)

;==================;
;=== Predicates ===;
;==================;

(define*/contract (workspace-subwindow? wk window)
  (workspace? window? . -> . any/c)
  "Returns #f if window is a mapped window of the specified workspace, or non-#f otherwise."
  (member window (workspace-subwindows window)))

(define* (valid-workspace-number? wkn)
  (and (number? wkn) (>= wkn 0) (< wkn (count-workspaces))))

(define* workspace-ref?
  (or/c workspace? number? string?))

;=================;
;=== Selectors ===;
;=================;

(define*/contract (find-root-window-workspace window)
  (window? . -> . any/c)
  "Returns the workspace for which window is the (virtual) root, or #f if none is found."
  (findf (λ(wk)(window=? window (workspace-window wk))) 
         workspaces))

(define*/contract (workspace-subwindows wk)
  (workspace? . -> . list?)
  "Returns the list of windows that are mapped in the specified workspace."
  (window-list (workspace-window wk)))

(define* (count-workspaces)
  (length workspaces))

(define*/contract (number->workspace wkn)
  (valid-workspace-number? . -> . workspace?)
  "Returns the workspace of the associated number."
  (list-ref workspaces wkn))

(define*/contract (workspace->number wk)
  (workspace? . -> . number?)
  "Returns the workspace-number of the given workpsace."
  (for/or ([w workspaces] [i (in-naturals)])
    (and (eq? w wk) i)))

(define* (current-workspace)
  (list-ref workspaces current-workspace-number))

(define*/contract (find-workspace wk/i/n)
  (workspace-ref? . -> . (or/c #f workspace?))
  "Returns the workspace of the given workspace-id/workspace-number/workspace, or #f if none is found."
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
  (findf (λ(wk)(member window (workspace-subwindows wk)))
         workspaces))

;==================;
;=== Operations ===;
;==================;

(define*/contract (insert-workspace wk [n (length workspaces)])
  (workspace? . -> . void?)
  "Inserts workspace wk at position n."
  (cond [(or (valid-workspace-number? n) (= n (length workspaces)))
         (define-values (left right) (split-at workspaces n))
         (set! workspaces (append left (list wk) right))]
        [else 
         (error "Cannot insert workspace: Invalid number:" n)]))

;; TODO: what to do about the windows contained in the current workspace?
(define*/contract (remove-workspace wkn)
  (valid-workspace-number? . -> . void?)
  (define-values (left right) (split-at workspaces wkn))
  (set! workspaces (append left (rest right))))

(define*/contract (activate-workspace wk/i/n)
  (valid-workspace-number? . -> . any)
  "Switches to workspace number wkn."
  (dprintf "Activating workspace ~a\n" wk/i/n)
  (define wk-new (find-workspace wk/i/n))
  ; Hide the old workspace:
  (when (current-root-window)
    ; otherwise no workspace is active, we are at the root window
    (unmap-window (current-root-window)))
  ; change the current root:
  (current-root-window (workspace-window wk-new))
  (set! current-workspace-number (workspace->number wk-new))
  ; show the new workspace with all its windows:
  (map-window (current-root-window))
  ; The following may fail because the window may not yet be visible:
  ;(set-input-focus (current-root-window))
  (set-input-focus (true-root-window))
  )

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
  
(define*/contract (next-workspace! [inc 1] [warp? (workspace-warp?)])
  (() (number? any/c) . ->* . void?)
  "Switches to the next workspace by offset 'inc' in linear order and returns the new workspace number.
  If 'wrap?' is true, then the list is circular, otherwise it is bounded."
  (activate-workspace (workspace-addn current-workspace-number inc warp?)))

(define*/contract (previous-workspace! [dec 1] [warp? (workspace-warp?)])
  (() (number? any/c) . ->* . void?)
  "Switches to the previous workspace by offest 'dec' in linear order and returns the new workspace number.
  If 'wrap?' is true, then the list is circular, otherwise it is bounded."
  (activate-workspace (workspace-subn current-workspace-number dec warp?)))

(define*/contract (remove-window-from-workspace window wk)
  (window? workspace? . -> . any/c)
  #f)

(define*/contract (add-window-to-workspace window wk)
  (window? workspace? . -> . any)
  (dprintf "Adding window ~a to workspace ~a\n" window wk)
  (define old-wk (find-window-workspace window))
  (when old-wk
    (remove-window-from-workspace window wk))
  (reparent-window window (workspace-window wk)))

(define*/contract (move-window-to-workspace window wk/i/n)
  (window? workspace-ref? . -> . any)
  (add-window-to-workspace window (find-workspace wk/i/n)))

(define*/contract (move-window-to-workspace/activate window wk/i/n)
  (window? workspace-ref? . -> . any)
  (define wk (find-workspace wk/i/n))
  (add-window-to-workspace window wk)
  (activate-workspace (workspace->number wk)))


#;(module+ test
  (require rackunit)
  (init-workspaces)
  (check = (next-workspace!) 0)
  (check-pred workspace? (insert-workspace))
  (check = (next-workspace!) 1)
  (check = (next-workspace!) 1)
  (check = (next-workspace! 1 #t) 0)
  )

;============;
;=== Init ===;
;============;

(define* (init-workspaces)
  ; Wait for sync to be sure that all pending windows (not currently managed by us) are mapped:
  (XSync (current-display) #f)
  
  (define existing-windows (window-list (true-root-window)))
  ;; Create a two initial workspaces
  ;; This sets the current-root-window, and applies the keymap to it
  (make-workspace "First"  #:background-color (find-named-color "DarkSlateGray"))
  (make-workspace "Second" #:background-color (find-named-color "DarkSlateBlue"))
  (make-workspace "Third"  #:background-color (find-named-color "Sienna"))

  (activate-workspace 0)

  ;; Put all mapped windows in the activated worskpace
  (for-each (λ(w)(add-window-to-workspace w (current-workspace)))
            existing-windows)
  )

