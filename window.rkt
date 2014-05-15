#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/doc-string
         rwind/util
         rwind/display
         rwind/policy/base
         rwind/color
         x11/x11
         x11/xinerama
         racket/contract
         racket/list
         racket/match
         )

(module+ test (require rackunit))

(define* window? 0+-integer?)

(define*/contract (window=? w1 w2)
  ((or/c #f window?) (or/c #f window?) . -> . boolean?)
  "Returns #t if w1 and w2 are the same non-#f windows, #f otherwise."
  (and w1 w2 (eq? w1 w2)))

(provide (struct-out rect)
         (struct-out pos)
         (struct-out size))
(struct rect (x y w h) ; rectangle
  #:transparent)
(struct pos (x y) ; position
  #:transparent)
(struct size (w h)
  #:transparent)

;=======================;
;=== Window creators ===;
;=======================;

(define* (create-simple-window x y w h [border-width 0])
  (define window (XCreateSimpleWindow (current-display) (true-root-window)
                                      x y w h border-width 0 0))
  (when window (policy. on-create-window window))
  window)

;; For testing
(define* (create-test-window [x 100] [y 100])
  "Creates a simple window under the root and maps it."
  (define window (create-simple-window x y 100 100 2))
  (when window (map-window window))
  window)

;=============;
;=== Atoms ===;
;=============;

; put in a separate file?

(define* (intern-atom atom)
  (XInternAtom (current-display) atom #f))

(define-syntax-rule (define-atoms set-atoms atom ...)
  (begin (begin (define atom #f)
                (provide atom))
         ...
         (define (set-atoms)
           (begin
             (set! atom (intern-atom (symbol->string 'atom)))
             (unless atom
               (dprintf "Warning: atom ~a not set!\n" 'atom)))
           ...)
         ))

(provide intern-atoms)
;; (intern-atoms) must be called on init.
(define-atoms intern-atoms
  WM_DELETE_WINDOW
  WM_PROTOCOLS
  WM_STATE
  WM_TAKE_FOCUS
  WM_TRANSIENT_FOR
  
  __SWM_VROOT

  ; http://standards.freedesktop.org/wm-spec/latest/
  _NET_WM_NAME
  _NET_WM_VISIBLE_NAME
  _NET_WM_ICON_NAME
  _NET_WM_VISIBLE_ICON_NAME
  _NET_WM_DESKTOP

   ; http://developer.gnome.org/wm-spec/#id2551694
  _NET_WM_STATE
  _NET_WM_STATE_MODAL
  _NET_WM_STATE_STICKY
  _NET_WM_STATE_MAXIMIZED_VERT
  _NET_WM_STATE_MAXIMIZED_HORZ
  _NET_WM_STATE_SHADED
  _NET_WM_STATE_SKIP_TASKBAR
  _NET_WM_STATE_SKIP_PAGER
  _NET_WM_STATE_HIDDEN
  _NET_WM_STATE_FULLSCREEN
  _NET_WM_STATE_ABOVE
  _NET_WM_STATE_BELOW
  _NET_WM_STATE_DEMANDS_ATTENTION
  
  ; http://developer.gnome.org/wm-spec/#id2551529
  _NET_WM_WINDOW_TYPE
  _NET_WM_WINDOW_TYPE_NORMAL
  _NET_WM_WINDOW_TYPE_DIALOG
  _NET_WM_WINDOW_TYPE_DESKTOP
  _NET_WM_WINDOW_TYPE_DOCK

  ; http://developer.gnome.org/wm-spec/#id2551927
  _NET_WM_ALLOWED_ACTIONS

  _NET_SUPPORTED
  _NET_VIRTUAL_ROOTS
  )

(define* _NET_WM_STATE_REMOVE  0) ; remove/unset property
(define* _NET_WM_STATE_ADD     1) ; add/set property
(define* _NET_WM_STATE_TOGGLE  2) ; toggle property

(define* (atom->string atom)
  (if (symbol? atom)
      atom
      (XGetAtomName (current-display) atom)))

;; That's a bit too loose though. It would be bette to check if the symbol is known.
(define* atom? (or/c symbol? number?))

(define* (atom=? a1 a2)
  (= (atom->number a1) (atom->number a2)))

;=================;
;=== Selectors ===;
;=================;

(define* (query-tree window)
  "Returns the parent and the children of the specified window."
  (XQueryTree (current-display) window))

(define* (window-text-property window atom)
  "Returns a list of strings for the property named atom for the given window."
  (and window
       (let ([txt (XGetTextProperty (current-display) window atom)])
         ; should use the Xmb variant instead?
         (and txt (XTextPropertyToStringList txt)))))

(define* (window-name window)
  ;(printf "net wm name: ~a\n" _NET_WM_NAME)
  (define names
    (or
     (window-text-property window _NET_WM_NAME)
     (window-text-property window 'XA_WM_NAME)))
  (and names (not (null? names)) (car names)))

(define* (window-names window)
  "Returns the list of list of strings for the name,
  the visible name, the icon name and the visible icon name in order."
  (map (λ(v)(window-text-property window v))
       (list 'XA_WM_NAME 'XA_WM_ICON_NAME)))

(define* (window-class window)
  "Returns the list of classes of the window."
  (window-text-property window 'XA_WM_CLASS))

(define* (window-protocols window)
  "Returns the list of protocols as atoms that the window supports."
  (or (XGetWMProtocols (current-display) window)
      '()))

(define* (window-attributes window)
  (XGetWindowAttributes (current-display) window))

(define* (window-bounds window)
  "Returns the rectangle (x y w h) of the attributes of window."
  (define attr (window-attributes window))
  (and attr
       (rect (XWindowAttributes-x attr)
             (XWindowAttributes-y attr)
             (XWindowAttributes-width attr)
             (XWindowAttributes-height attr))))

(define* (window-size window)
  (define attr (window-attributes window))
  (and attr
       (size (XWindowAttributes-width attr)
             (XWindowAttributes-height attr))))

(define* (window-position window)
  "Returns the position of the window relatively to its parent."
  (define attr (window-attributes window))
  (and attr
       (pos (XWindowAttributes-x attr)
            (XWindowAttributes-y attr))))

(define* (window-absolute-position window)
  "Returns the position of the window relative to the root window."
  (let loop ([window window] [x 0] [y 0])
    (if window
        (match (window-position window)
          [(pos xw yw)
           (let-values ([(parent children) (query-tree window)])
             (loop parent (+ x xw) (+ y yw)))])
        (pos x y))))

(define* (window-border-width window)
  (define attr (window-attributes window))
  (and attr (XWindowAttributes-border-width attr)))

(define*/contract (window-map-state window)
  ((or/c #f window?) . -> . (or/c 'IsUnmapped 'IsUnviewable 'IsViewable #f))
  "Returns 'IsUnmapped, 'IsUnviewable, 'IsViewable, or #f if the window is does not exist.
  IsUnviewable is returned if the window is mapped but some ancestor is unmapped."
  (define attrs (and window (XGetWindowAttributes (current-display) window)))
  (and attrs (XWindowAttributes-map-state attrs)))

(define* (window-viewable? window)
  (eq? 'IsViewable (window-map-state window)))

(define* (window-unmapped? window)
  (eq? 'IsUnmapped (window-map-state window)))

(define* (window-mapped? window)
  (memq (window-map-state window) '(IsViewable IsUnviewable)))

(define* (window-has-type? window type)
  "Returns non-#f if the window has the specified type, #f otherwise."
  (define types (net-window-types window))
  (and types (memq type types)))

(define* (window-dialog? window)
  (window-has-type? window _NET_WM_WINDOW_TYPE_DIALOG))

(define* (net-window-desktop? window)
  (window-has-type? window _NET_WM_WINDOW_TYPE_DESKTOP))

(define* (window-user-movable? window)
  (define types (or (net-window-types window) '()))
  (not (or (ormap (λ(t)(memq t types))
              (list _NET_WM_WINDOW_TYPE_DESKTOP
                    _NET_WM_WINDOW_TYPE_DOCK))
           (find-root-window-head window))))

(define* (window-user-resizable? window)
  (window-user-movable? window))

;=============================;
;=== Window List Selectors ===;
;=============================;

(define*/contract (window-children parent)
  (window? . -> . (listof window?))
  "Returns the list of child windows of the specified parent window.
   The windows are in stacking order, bottom (first) to top (last)."
  (define-values (_parent children) (query-tree parent))
  (filter values children))

;=========================;
;=== Window operations ===;
;=========================;

(define* (move-window window x y)
  (XMoveWindow (current-display) window x y))

(define* (resize-window window w h)
  (XResizeWindow (current-display) window w h))

(define* (move-resize-window window x y w h)
  (XMoveResizeWindow (current-display) window x y w h))

(define* (show-window window)
  (XMapWindow (current-display) window)
  (change-window-state window 'normal))

(define* (show/raise-window window)
  (XMapRaised (current-display) window)
  (change-window-state window 'normal))

(define* (hide-window window)
  (XUnmapWindow (current-display) window))

(define* (raise-window window)
  "Raises window to top, unless it has type _NET_WM_WINDOW_TYPE_DESKTOP."
  ; TODO: This test probably belongs to the policy!
  (unless (window-has-type? window _NET_WM_WINDOW_TYPE_DESKTOP)
    (XRaiseWindow (current-display) window)))

(define* (lower-window window)
  (XLowerWindow (current-display) window))

(define* (map-window window)
  (XMapWindow (current-display) window)
  (change-window-state window 'normal))

;; Should probably not change the window state here?
(define* (unmap-window window)
  (XUnmapWindow (current-display) window))

(define* (iconify-window window)
  (XIconifyWindow (current-display) window)
  (change-window-state window 'iconic))

;(define (uniconify-window window)(void))

(define* (reparent-window window new-parent)
  "Changes the parent of window to new-parent."
  (match (window-position window)
    [(pos x y)
     (XReparentWindow (current-display) window new-parent
                      x y)]))

(define* (send-event window event-mask event [propagate #f])
  (XSendEvent (current-display) window propagate event-mask event))

(define* (send-client-message window msg-type msg-values [format 32])
  "Sends an XClientMessage event to window.
  msg-type must be an atom.
  format must be either 8, 16 or 32, and is the size in bits of each sent value.
  msg-values must be a list of at most 20 8bits or 10 16bits or 5 32bits values.
  If msg-values is longer than this, only the first elements are considered."
  (define event (make-ClientMessageEvent (current-display) window msg-type msg-values format))
  (dprintf "Client-message: ~a\n" (XClientMessageEvent->list* event))
  (send-event window '() event)
  )

;; Doesn't really belong here... -> keymap.rkt?
(define* (allow-events event-mode)
  (XAllowEvents (current-display) event-mode CurrentTime))

(define*/contract (destroy-window window)
  (window? . -> . any)
  (XDestroyWindow (current-display) window)
  (change-window-state window 'withdrawn))

(define*/contract (kill-client window)
  (window? . -> . any)
  "Attempts to kill the window without warning. 
  May kill the window manager if window is one of the virtual roots."
  (XKillClient (current-display) window))

;; Does not seem to work properly... 
;; TODO: Look at other window managers to see how they do it.
;; - does not delete all windows that could be destroyed
;; - when calling it on a window created with `create-simple-window', RWind crashes (or just halts?).
(define*/contract (delete-window window)
  (window? . -> . any)
  "Tries to gently close the window and client if possible, otherwise kills it."
  (if (window-user-killable? window)
      (if (member WM_DELETE_WINDOW (window-protocols window))
          (send-client-message window WM_PROTOCOLS (list WM_DELETE_WINDOW CurrentTime))
          (kill-client window))
      (dprintf "Warning: Cannot delete window ~a" window)))

(define* (set-window-border-width window width)
  (XSetWindowBorderWidth (current-display) window width))

(define*/contract (set-window-border-color window color)
  (window? (or/c string? 1+-integer?) . -> . any)
  (define attrs (make-XSetWindowAttributes #:border-pixel (if (string? color)
                                                              (find-named-color color)
                                                              color)))
  (define mask (XSetWindowAttributes->mask attrs))
  (XChangeWindowAttributes (current-display) window mask attrs))

(define* (set-window-background-color window color)
  "Color is either a color-pixel or a string suitable for `find-named-color'."
  (XSetWindowBackground (current-display) window 
                        (if (string? color)
                            (find-named-color color)
                            color))
  ; refresh:
  (clear-window window))

(define* (clear-window window)
  (XClearWindow (current-display) window))

(define*/contract (delete-window-property window property)
  (window? atom? . -> . any)
  (XDeleteProperty (current-display) window property))

(define*/contract (change-window-property window property type mode data-list [format 32])
  ([window? atom? atom? PropMode? list?] [(one-of/c 8 16 32)] . ->* . any)
  (ChangeProperty (current-display) window property type mode data-list format))

(define*/contract (change-window-state window state)
  (window? (one-of/c 'withdrawn 'normal 'iconic) . -> . any)
  (define s (case state 
              [(withdrawn) 0]
              [(normal)    1]
              [(iconic)    3]))
  (change-window-property window WM_STATE 'XA_ATOM 'PropModeReplace (list s))
  )

(define* (add-window-to-save-set window)
  (dprintf "Adding ~a to save set\n" window)
  (XAddToSaveSet (current-display) window))

(define* (window-properties window)
  (XListProperties (current-display) window))

(define*/contract (get-window-property window property)
  (window? atom? . -> . (or/c list? #f))
  "Returns a list of elements corresponding to `property', or #f if the property is not found or in case of error."
  (GetWindowProperty (current-display) window property))

(define*/contract (get-window-property-atoms window property)
  (window? atom? . -> . list?)
  "Returns a list of Atoms for the given property and window."
  (or (get-window-property window property) '()))

(define*/contract (window-transient-for window)
  (window? . -> . (or/c #f window?))
  "Returns the window for which `window` is transient, or #f if `window` is not a transient window."
  (and=> (get-window-property window WM_TRANSIENT_FOR) first))

; For information on all the window types, see http://developer.gnome.org/wm-spec/#id2551529
; (use it with (map atom->string ...) for better reading)
(define*/contract (net-window-types window)
  (window? . -> . list?)
  "Returns a list of types as atoms for the specified window."
  (get-window-property-atoms window _NET_WM_WINDOW_TYPE))

(define* (net-window-allowed-actions window)
  (get-window-property-atoms window _NET_WM_ALLOWED_ACTIONS))

(define* (configure-window window value-mask x y width height border-width above stack-mode)
  (XConfigureWindow
      (current-display) window value-mask
      (make-XWindowChanges x y (bound-value width 1 10000) (bound-value height 1 10000)
                           border-width above stack-mode)))

(define*/contract (net-window-state window)
  (window? . -> . list?)
  (get-window-property-atoms window _NET_WM_STATE))

(define* (net-window-fullscreen? window)
  (memq _NET_WM_STATE_FULLSCREEN (net-window-state window)))

(define*/contract (change-net-window-state-properties window updater)
  (window? [(listof atom?) . -> . (listof atom?)] . -> . any)
  (change-window-property window _NET_WM_STATE 'XA_ATOM 'PropModeReplace 
                          (updater (net-window-state window))))

(define*/contract (delete-net-wm-state-property window prop)
  (window? atom? . -> . any)
  (change-net-window-state-properties window (λ(l)(remove prop l atom=?))))

(define*/contract (add-net-wm-state-property window prop)
  (window? atom? . -> . any)
  (change-net-window-state-properties window (λ(l)(if (member prop l atom=?)
                                                  l
                                                  (cons prop l)))))

(define*/contract (set-net-window-desktop window num)
  (window? 0+-integer? . -> . any)
  (change-window-property window _NET_WM_DESKTOP 'XA_CARDINAL 'PropModeReplace (list num)))

(define*/contract (net-window-desktop window)
  (window? . -> . (or/c #f 0+-integer? -1))
  "Returns the _NET_WM_DESKTOP number of window, or #f if none is found.
  A value of -1 indicates that the window should appear on all desktops."
  (define n (get-window-property window _NET_WM_DESKTOP))
  (and n (first n)))


;==============================;
;=== More window operations ===;
;==============================;

;; TODO: save the current state of the window before maximizing
;; so as to restore it on unmaximize

(define* (h-maximize-window window)
  "Maximizes window horizontally in the window's head."
  (match/values (window+head-bounds window)
    [((rect x y w h) (size wmax hmax))
     (move-resize-window window 0 y wmax h)]))

(define* (v-maximize-window window)
  "Maximizes window vertically in the window's head."
  (match/values (window+head-bounds window)
    [((rect x y w h) (size wmax hmax))
     (move-resize-window window x 0 w hmax)]))

(define* (maximize-window window)
  "Maximizes window horizontally and vertically in the window's head."
  (match (head-size (find-window-head window))
    [(size wmax hmax)
     (move-resize-window window 0 0 wmax hmax)]))

(define* (center-window window)
  "Centers the window in the current head."
  (move-window-frac window 1/2 1/2))

(define*/contract (move-window-frac window frac-x frac-y)
  (window? (real-in 0 1) (real-in 0 1) . -> . any/c)
  "Places the window at a fraction of its head.
  Ex: (move-window (pointer-head) 1/4 3/4)"
  (match/values (window+head-bounds window)
    [((rect x y w h) (size wmax hmax))
     (move-window window
                  (truncate (* frac-x (- wmax w)))
                  (truncate (* frac-y (- hmax h))))]))

(define*/contract (move-resize-window-frac window frac-x frac-y frac-w [frac-h frac-w])
  ([window? (real-in 0 1) (real-in 0 1) (real-in 0 1)] [(real-in 0 1)] . ->* . any/c)
  "Places the window at a fraction of its head.
  Ex: (move-resize-window (pointer-head) 1/2 3/4 1/4 1/4)"
  (match/values (window+head-bounds window)
    [((rect x y w h) (size wmax hmax))
     (define new-w (truncate (* frac-w wmax)))
     (define new-h (truncate (* frac-h hmax)))
     (move-resize-window window
                         (truncate (* frac-x (- wmax new-w)))
                         (truncate (* frac-y (- hmax new-h)))
                         new-w new-h)]))

(define*/contract (move-resize-window-grid window cols win-col win-row col-span [row-span col-span]
                                           #:rows [rows cols])
  ([window? (integer-in 1 100) (integer-in 0 99) (integer-in 0 99) (integer-in 0 99)]
   [(integer-in 1 100) #:rows (integer-in 0 99)]
   . ->* . any/c)
  "Places window in the grid of size (rows, cols) at the cell (row, col) 
  spanning over col-span and row-span cells.
  Row and col range from 0 to rows-1 and cols-1."
  (match/values (window+head-bounds window)
    [((rect x y w h) (size wmax hmax))
     (define cell-w (truncate (/ wmax cols)))
     (define cell-h (truncate (/ hmax rows)))
     (move-resize-window window
                         (* win-col cell-w) (* win-row cell-h)
                         (* col-span cell-w) (* row-span cell-h))]))

(define*/contract (move-resize-window-grid-auto window cols [rows cols])
  ([window? (integer-in 1 100)] [(integer-in 1 100)] . ->* . any/c)
  "Places window in the grid in the row and column of its gravity center."
  (match/values (window+head-bounds window)
    [((rect x y w h) (size wmax hmax))
     (define xc (max 0 (min (sub1 wmax) (+ x (quotient w 2)))))
     (define yc (max 0 (min (sub1 hmax) (+ y (quotient h 2)))))
     (define win-col (truncate (/ (* cols xc) wmax)))
     (define win-row (truncate (/ (* rows yc) hmax)))
     (move-resize-window-grid window cols #:rows rows win-col win-row 1)]))

;=====================;
;=== Focus/Pointer ===;
;=====================;

(define* (query-pointer [root (pointer-root-window)])
  "Returns a list of the following values:
    win: the targeted window
    x: the x coordinate in the root window
    y: the y coordinate in the root window
    mask: the modifier mask
  root is the window relative to which the query is made, and the child window win is returned.
  By default it is the virtual-root under the pointer."
  (define-values (rc _root win x y win-x win-y mask)
    (XQueryPointer (current-display)
                   ;(true-root-window)
                   root
                   ))
  (values win x y mask))

(define* (pointer-head)
  "Returns the head number that contains the mouse pointer."
  (define-values (win x y mask) (query-pointer (true-root-window)))
  (find-head x y))

(define* (focus-head)
  "Returns the head number that contains the input focus window,
  in the sense of `find-window-head'."
  (and=> (focus-window) find-window-head))

(define* (pointer-root-window)
  "Returns the virtual root-window that contains the pointer."
  (and=> (pointer-head) head-root-window))

(define* (focus-root-window)
  "Returns the virtual root window that has the keyboard focus."
  #;(XWindowAttributes-root (window-attributes (focus-window))) ; nope, gives the true root
  #;(workspace-root-window (find-window-workspace (focus-window)))
  (and=> (focus-head) head-root-window))

(define* (pointer-focus)
  "Returns the window that is below the mouse pointer."
  (define-values (win x y mask) (query-pointer))
  win)

(define* pointer-window
  "Synonym for `pointer-focus'."
  pointer-focus)

(define* (input-focus)
  "Returns the window that currently has the keyboard focus."
  (car (XGetInputFocus (current-display))))

(define* focus-window
  "Synonym for `input-focus'."
  input-focus)

(define* (set-input-focus window)
  "Gives the keyboard focus to the window if it is viewable."
  ; TODO: focus should not be given to windows that don't want it?
  ; But may still be useful to select a window, e.g. to close it.
  (when (and window (window-viewable? window))
    (XSetInputFocus (current-display) window 'RevertToParent CurrentTime)))

(define* (set-input-focus/raise window)
  (when window
    (set-input-focus window)
    (raise-window window)))

;; Replace the global keymap by an empty one
;; with only one binding: Button1Press
;; Use grabPointer, and ungrab it in the callback.
;; ** Other option: Create an InputOnly window above the entire root window
;; and select input on it.
#;(define* (select-window)
  void)

(define* (circulate-subwindows-up window)
  (XCirculateSubwindowsUp (current-display) window))

(define* (circulate-subwindows-down window)
  (XCirculateSubwindowsDown (current-display) window))

;===========================================;
;=== Heads / Monitors / Physical Screens ===;
;===========================================;


#| Ideas
- sawfish/src/functions.c
- The best and simplest way may be to consider one desktop per monitor.
  (this however requires to resize the windows and positions according to each monitor?)
- to test monitors on a single screen, I could set up "virtual" monitors,
  i.e., split the screen in different monitors.
  This could even be a usefull feature (to develop further and expand?)
- each monitor may display a different workspace (like xmonad)
- These should be done as extensions to RWind, not in the core
- use xinerama?
- Resources:
  http://awesome.naquadah.org/wiki/Using_Multiple_Screens
  (fr) http://doc.ubuntu-fr.org/multi-ecran
- see (get-display-count)
|#

(define* head-infos (make-fun-box #f))
(define* (head-count)
  "Returns the number of (virtual) heads."
  (max 1 (vector-length (head-infos))))

(struct head-info
  (screen root-window x y w h)
  #:transparent
  #:mutable)
(provide (struct-out head-info))
(doc head-info
     "Structure holding information about heads (monitors, screens).
  screen is the physical head on which the (possibly virtual) head is mapped.
  It may be different from the position of the head in the xinerama-screen-infos 
  vector in the case a screen has been split.
  root-window be shared among several heads and thus may not have the same 
  size as the head.")
  
(define (heads-intersect? hd1 hd2)
  (with-head-info
   hd1 (s1 win1 x1 y1 w1 h1)
   (with-head-info
    hd2 (s2 win2 x2 y2 w2 h2)
    ; rectangle empty intersection:
    (not (or (> x1 (+ x2 w2))
             (> x2 (+ x1 w1))
             (> y1 (+ y2 h2))
             (> y2 (+ y1 w1)))))))

(define* (xinerama-update-infos)
  (define infos (XineramaQueryScreens (current-display)))
  (head-infos
   (if infos
       (for/vector ([inf infos])
         (match inf
           [(XineramaScreenInfo screen x y w h)
            (head-info screen #f x y w h)]))
       ; otherwise create a single head with the display size
       (vector (head-info 0 #f 0 0 (display-width) (display-height))))))

(define* (get-head-info hd)
  (and (head-infos)
       (>= hd 0)
       (< hd (head-count))
       (vector-ref (head-infos) hd)))

(provide with-head-info)
(define-syntax-rule (with-head-info hd (screen win x y w h) body ...)
  ; input: hd
  ; output: screen win x y w h
  (let ([info (get-head-info hd)])
    (and info
         (match info
           [(head-info screen win x y w h)
            body ...]))))

(define* (head-size hd)
  "Returns the size of the given head number."
  (with-head-info
   hd (s win x y w h)
   (size w h)))

(define* (head-position hd)
  "Returns the x and y offset of the given head number."
  (with-head-info
   hd (s win x y w h)
   (pos x y)))

(define* (head-bounds hd)
  "Returns the (x y w h) values of the specified head number."
  (with-head-info
   hd (s win x y w h)
  (rect x y w h)))

(define* (head-root-window hd)
  "Returns the (current) root window of the specified head number."
  (with-head-info
   hd (s win x y w h)
   win))

(define* (find-root-window-head win)
  "Returns the head number that has win as its root window, or #f if none is found."
  (for/or ([hd-info (head-infos)]
           [i (in-naturals)])
    (and (window=? win (head-info-root-window hd-info)) i)))

(define* (find-root-window-heads win)
  "Returns the list of heads that has win as its root window."
  (filter
   values
   (for/list ([hd-info (head-infos)]
              [i (in-naturals)])
     (and (window=? win (head-info-root-window hd-info)) i))))

(define* (find-head px py)
  "Returns the number of the first head that contains the point (px, py), or #f if not found."
  (for/or ([info (head-infos)] [i (in-naturals)])
    (match info
      [(head-info s win x y w h)
       (and (>= px x) (< px (+ x w))
            (>= py y) (< py (+ y h))
            i)])))

(define* (head-list-bounds [heads #f])
  "Returns the values (x y w h) of the enclosing rectangle (bounding box) of the given list of heads.
  If heads is #f, all heads are considered."
  (define f inexact->exact) ; needed because inf.0 only has an inexact representation
  (let ([heads (or heads (head-count))]) ; if #f, make the for loop iterate through all numbers
    (define-values (x1 y1 x2 y2)
      (for/fold ([x1 +inf.0] [y1 +inf.0] [x2 -inf.0] [y2 -inf.0])
        ([hd heads])
        (with-head-info 
         hd (s win x y w h)
         (values (min x1 x) (min y1 y)
                 (max x2 (+ x w)) (max y2 (+ y h))))))
    (rect (f x1) (f y1) (f (- x2 x1)) (f (- y2 y1)))))

(define* (find-window-head win)
  "Returns the head number that contains one of the corners or the center
  of the window that has the input focus.
  Returns #f if no corner and center is contained in any head
  (which should be rare if the window is visible)."
  (and win
       (match/values (values (window-size win)
                             (window-absolute-position win))
         [((size w h) (pos x y))
          (or (find-head x                     y)
              (find-head (+ x w)               y)
              (find-head x                     (+ y h))
              (find-head (+ x w)               (+ y h))
              (find-head (+ x (quotient w 2))  (+ y (quotient h 2))))])))



#;(module+ main
  (require racket/vector)
  (init-display)
  (split-head)
  (head-infos)
  (head-size 0)
  (find-head 0 0)
  (find-head 1000 1000)
  (exit-display))

(define* (window+head-bounds window)
  "Returns the bounds of the window and the size of its enclosing head."
  (values (window-bounds window) (head-size (find-window-head window))))

(define* (window+vroot-bounds window)
  "Returns the bounds of the window and its enclosing virtual root."
  (values (window-bounds window)
          (window-bounds (head-root-window (find-window-head window)))))

(define*/contract (split-head [fraction 1/2] [hd (pointer-head)] #:style [style 'horiz])
  ([] [(real-in 0 1) natural-number/c #:style (one-of/c 'horiz 'vert)] . ->* . any)
  "Splits the specified head in two new heads, vertically or horizontally
  depending on the specified style.
  This can be used to simulate several heads on a single monitor."
  (with-head-info
   hd (s win x y w h)
   (define w1 (* w fraction))
   (define h1 (* h fraction))
   (define l (vector->list (head-infos)))
   (define-values (left right) (split-at l hd))
   (head-infos
    (list->vector
     (append left
             (if (eq? style 'horiz)
                 (list (head-info s #f x         y         w1        h)
                       (head-info s #f (+ x w1)  y         (- w w1)  h))
                 (list (head-info s #f x         y         w         h1)
                       (head-info s #f x         (+ y h1)  w         (- h h1))))
             (rest right))))))

(module+ test
  (define hds (vector (head-info 0 #f 100 200 800 400)))
  (head-infos hds)
  (split-head 1/4 0 #:style 'horiz)
  (check-equal? (head-infos) (vector (head-info 0 #f 100 200 200 400)
                                     (head-info 0 #f 300 200 600 400)))
  (head-infos hds)
  (split-head 1/4 0 #:style 'vert)
  (check-equal? (head-infos) (vector (head-info 0 #f 100 200 800 100)
                                     (head-info 0 #f 100 300 800 300)))
  )


;===================;
;=== Root Window ===;
;===================;

(define* true-root-window (make-fun-box #f))

(define* (true-root-window? win)
  (window=? win (true-root-window)))

(define* (init-root-window)
  (true-root-window (XDefaultRootWindow (current-display)))
  ;; Ask the root window to send us any event
  ;; (is it useful if we use virtual roots?)
  (XChangeWindowAttributes (current-display) (true-root-window) '(EventMask)
                           (make-XSetWindowAttributes
                            #:event-mask '(SubstructureRedirectMask
                                           SubstructureNotifyMask
                                           StructureNotifyMask)))
  (unless (XineramaIsActive (current-display))
    (dprintf "Warning: Xinerama not yet active\n"))

  (xinerama-update-infos)
  )
