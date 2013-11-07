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
         racket/list
         racket/contract
         )

#| TODO
- contracts and tests...
- Xlib Vol I, p. 47, Performance Optimizing
  "functions with Fetch, Get or Query should be avoided in the event loop" (for applications)
  This is because the X server can be running on a different machine, 
  and network latencies should be avoided.
  This is why window managers store window properties locally
  (but this requires carefully keeping such values up to date).
|#

(module+ test (require rackunit))

(define* window? exact-nonnegative-integer?)

(define*/contract (window=? w1 w2)
  ((or/c #f window?) (or/c #f window?) . -> . boolean?)
  "Returns #t if w1 and w2 are the same non-#f windows, #f otherwise."
  (and w1 w2 (eq? w1 w2)))

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
  ; http://standards.freedesktop.org/wm-spec/latest/
  _NET_WM_NAME
  _NET_WM_VISIBLE_NAME
  _NET_WM_ICON_NAME
  _NET_WM_VISIBLE_ICON_NAME
  _NET_WM_STATE ; http://developer.gnome.org/wm-spec/#id2551694

  _NET_WM_WINDOW_TYPE ; http://developer.gnome.org/wm-spec/#id2551529
  _NET_WM_WINDOW_TYPE_NORMAL
  _NET_WM_WINDOW_TYPE_DESKTOP
  _NET_WM_WINDOW_TYPE_DOCK

  _NET_WM_ALLOWED_ACTIONS ; http://developer.gnome.org/wm-spec/#id2551927
  _NET_SUPPORTED
  _NET_VIRTUAL_ROOTS
  WM_TAKE_FOCUS
  WM_DELETE_WINDOW
  WM_PROTOCOLS
  WM_STATE
  __SWM_VROOT
  )

(define* (atom->string atom)
  (if (symbol? atom)
      atom
      (XGetAtomName (current-display) atom)))

;; That's a bit too loose though. It would be bette to check if the symbol is known.
(define* atom? (or/c symbol? number?))

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
  "Returns the values (x y w h) of the attributes of window."
  (define attr (window-attributes window))
  (values (XWindowAttributes-x attr)
          (XWindowAttributes-y attr)
          (XWindowAttributes-width attr)
          (XWindowAttributes-height attr)))

(define* (window-dimensions window)
  (define attr (window-attributes window))
  (values (XWindowAttributes-width attr)
          (XWindowAttributes-height attr)))

(define* (window-position window)
  "Returns the position of the window relatively to its parent."
  (define attr (window-attributes window))
  (values (XWindowAttributes-x attr)
          (XWindowAttributes-y attr)))

(define* (window-absolute-position window)
  "Returns the position of the window relative to the root window."
  (let loop ([window window] [x 0] [y 0])
    (if window
        (let*-values ([(xw yw) (window-position window)]
                      [(parent children) (query-tree window)])
          (loop parent (+ x xw) (+ y yw)))
        (values x y))))

(define* (window-border-width window)
  (define attr (window-attributes window))
  (XWindowAttributes-border-width attr))

(define* (window-map-state window)
  "Returns 'IsUnmapped, 'IsUnviewable or 'IsViewable.
 IsUnviewable is used if the window is mapped but some ancestor is unmapped."
  (define attrs (and window (XGetWindowAttributes (current-display) window)))
  (and attrs (XWindowAttributes-map-state attrs)))

(define* (window-has-type? window type)
  "Returns non-#f if the window has the specified type, #f otherwise."
  (define types (get-window-type window))
  (and types (memq type types)))

(define* (window-viewable? window)
  (eq? 'IsViewable (window-map-state window)))

(define* (window-user-movable? window)
  (define types (or (get-window-type window) '()))
  (not (or (ormap (λ(t)(memq t types))
              (list _NET_WM_WINDOW_TYPE_DESKTOP
                    _NET_WM_WINDOW_TYPE_DOCK))
           (find-root-window-head window))))

(define* (window-user-resizable? window)
  (window-user-movable? window))

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
  (define-values (x y) (window-position window))
  (XReparentWindow (current-display) window new-parent
                   x y))

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

(define* (allow-events event-mode)
  (XAllowEvents (current-display) event-mode CurrentTime))

(define*/contract (destroy-window window)
  (window? . -> . any)
  (XDestroyWindow (current-display) window)
  (change-window-state window 'withdrawn))

(define*/contract (kill-client window)
  (window? . -> . any)
  (XKillClient (current-display) window))

;; Does not seem to work properly... 
;; TODO: Look at other window managers to see how they do it.
;; - does not delete all windows that could be destroyed
;; - when calling it on a window created with `create-simple-window', RWind crashes (or just halts?).
(define* (delete-window window)
  "Tries to gently close the window and client if possible, otherwise kills it."
  (if (member WM_DELETE_WINDOW (window-protocols window))
      (send-client-message window WM_PROTOCOLS (list WM_DELETE_WINDOW CurrentTime))
      (kill-client window)))

(define* (set-window-border-width window width)
  (XSetWindowBorderWidth (current-display) window width))

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

(define*/contract (change-window-property window property type mode data-list [format 32])
  ([window? atom? atom? PropMode? list?] [(one-of/c 8 16 32)] . ->* . any)
  (ChangeProperty (current-display) window property type mode data-list format))

(define*/contract (change-window-state window state)
  (window? (one-of/c 'withdrawn 'normal 'iconic) . -> . any)
  (define s (case state 
              [(withdrawn) 0]
              [(normal) 1]
              [(iconic) 3]))
  (change-window-property window WM_STATE 'XA_ATOM 'PropModeReplace (list s))
  ; TODO: udpdate _NET_WM_STATE too?
  )

(define* (add-window-to-save-set window)
  (dprintf "Adding ~a to save set\n" window)
  (XAddToSaveSet (current-display) window))

(define* (window-properties window)
  (XListProperties (current-display) window))

(define* (get-window-property window property type data-type)
  "Returns a list of elements corresponding to property, or #f.
  property: Atom
  type: Atom
  data-type: any; Type of the elements of the data list to be returned."
  (GetWindowProperty (current-display) window property type data-type))

(define* (get-window-property-atoms window property)
  "Returns a list of Atoms for the given property and window."
  (or (get-window-property window property 'XA_ATOM Atom) #f))

; For information on all the window types, see http://developer.gnome.org/wm-spec/#id2551529
; (use it with (map atom->string ...) for better reading)
(define* (get-window-type window)
  "Returns a list of types as atoms for the specified window."
  (get-window-property-atoms window _NET_WM_WINDOW_TYPE))

(define* (get-window-state window)
  (get-window-property-atoms window _NET_WM_STATE))

(define* (get-window-allowed-actions window)
  (get-window-property-atoms window _NET_WM_ALLOWED_ACTIONS))

;==============================;
;=== More window operations ===;
;==============================;

;; TODO? Parameterize the following procedurs by either the head or the workspace?

(define* (h-maximize-window window)
  "Maximizes window horizontally."
  (define-values (x y w h wmax hmax) (window+head-bounds window))
  (move-resize-window window 0 y wmax h))

(define* (v-maximize-window window)
  "Maximizes window vertically."
  (define-values (x y w h wmax hmax) (window+head-bounds window))
  (move-resize-window window x 0 w hmax))

(define* (maximize-window window)
  "Maximizes window horizontally and vertically."
  (define-values (wmax hmax) (head-dimensions (find-window-head window)))
  (move-resize-window window 0 0 wmax hmax))

(define* (center-window window)
  "Centers the window in the current head."
  (move-window-frac window 1/2 1/2))

(define*/contract (move-window-frac window frac-x frac-y)
  (window? (real-in 0 1) (real-in 0 1) . -> . any/c)
  "Places the window at a fraction of its head.
Ex: (move-window (pointer-head) 1/4 3/4)"
  (define-values (x y w h wmax hmax) (window+head-bounds window))
  (move-window window (truncate (* frac-x (- wmax w))) (truncate (* frac-y (- hmax h)))))

(define*/contract (move-resize-window-frac window frac-x frac-y frac-w [frac-h frac-w])
  ([window? (real-in 0 1) (real-in 0 1) (real-in 0 1)] [(real-in 0 1)] . ->* . any/c)
  "Places the window at a fraction of its head.
Ex: (move-resize-window (pointer-head) 1/2 3/4 1/4 1/4)"
  (define-values (x y w h wmax hmax) (window+head-bounds window))
  (define new-w (truncate (* frac-w wmax)))
  (define new-h (truncate (* frac-h hmax)))
  (move-resize-window window
                      (truncate (* frac-x (- wmax new-w))) (truncate (* frac-y (- hmax new-h)))
                      new-w new-h))

(define*/contract (move-resize-window-grid window cols win-col win-row col-span [row-span col-span]
                                           #:rows [rows cols])
  ([window? (integer-in 1 100) (integer-in 0 99) (integer-in 0 99) (integer-in 0 99)]
   [(integer-in 1 100) #:rows (integer-in 0 99)]
   . ->* . any/c)
  "Places window in the grid of size (rows, cols) at the cell (row, col) 
spanning over col-span and row-span cells.
Row and col range from 0 to rows-1 and cols-1."
  (define-values (x y w h wmax hmax) (window+head-bounds window))
  (define cell-w (truncate (/ wmax cols)))
  (define cell-h (truncate (/ hmax rows)))
  (move-resize-window window
                      (* win-col cell-w) (* win-row cell-h)
                      (* col-span cell-w) (* row-span cell-h)))

(define*/contract (move-resize-window-grid-auto window cols [rows cols])
  ([window? (integer-in 1 100)] [(integer-in 1 100)] . ->* . any/c)
  "Places window in the grid in the row and column of its gravity center."
  (define-values (x y w h wmax hmax) (window+head-bounds window))
  (define xc (max 0 (min (sub1 wmax) (+ x (quotient w 2)))))
  (define yc (max 0 (min (sub1 hmax) (+ y (quotient h 2)))))
  (define win-col (truncate (/ (* cols xc) wmax)))
  (define win-row (truncate (/ (* rows yc) hmax)))
  (move-resize-window-grid window cols #:rows rows win-col win-row 1))

;==============================;
;=== Window List Operations ===;
;==============================;

(define* (window-children window)
  (define-values (parent children) (query-tree window))
  children)

(define* (window-list [parent (focus-root-window)])
  "Returns the list of windows."
  (filter values (window-children parent)))

(define* (filter-windows proc [parent (focus-root-window)])
  "Maps proc to the list of windows."
  (filter (λ(w)(and w (proc w))) (window-list parent)))

(define* (find-windows rx [parent (focus-root-window)])
  "Returns the list of windows that matches the regexp rx."
  (filter-windows (λ(w)(let ([n (window-name w)])
                         (and n (regexp-match rx n))))
                  parent))

(define* (find-windows-by-class rx [parent (focus-root-window)])
  "Returns the list of windows for which one of the window's classes matches the regexp rx."
  (filter-windows (λ(w)(ormap (λ(c)(regexp-match rx c)) (window-class w))) parent))

(define* (mapped-windows [parent (focus-root-window)])
  "Returns the list of windows that are mapped but not necessarily viewable
(i.e., the window is mapped but one ancestor is unmapped)."
  (filter-windows (λ(w)(let ([s (window-map-state w)])
                         (and s (not (eq? 'IsUnmapped s)))))
                  parent))

(define* (viewable-windows [parent (focus-root-window)])
  (filter-windows (λ(w)(eq? 'IsViewable (window-map-state w))) parent))


;; todo: send window to left/right/up/down, etc.
;; Put all these procs in a separate window-utils.rkt file?

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
  (find-window-head (focus-window)))

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

(define* input-window
  "Synonym for `input-focus'."
  input-focus)

(define* focus-window
  "Synonym for `input-focus'."
  input-focus)

(define* (set-input-focus window)
  "Gives the keyboard focus to the window if it is viewable."
  ; TODO: focus should not be given to windows that don't want it
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

(require x11/xinerama racket/match)

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
dimensions as the head.")

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
       ; otherwise create a single head with the display dimensions
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

(define* (head-dimensions hd)
  "Returns the dimensions of the given head number."
  (with-head-info
   hd (s win x y w h)
   (values w h)))

(define* (head-position hd)
  "Returns the x and y offset of the given head number."
  (with-head-info
   hd (s win x y w h)
   (values x y)))

(define* (head-bounds hd)
  "Returns the (x y w h) values of the specified head number."
  (with-head-info
   hd (s win x y w h)
  (values x y w h)))

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
  (define (app1 op a b)
    (if a (op a b) b))
  (let ([heads (or heads (head-count))]) ; if #f, make the for loop iterate through all numbers
    (define-values (x1 y1 x2 y2)
      (for/fold ([x1 #f] [y1 #f] [x2 #f] [y2 #f])
        ([hd heads])
        (match (get-head-info hd)
          [(head-info s win x y w h)
           (values (app1 min x1 x) (app1 min y1 y)
                   (app1 max x2 (+ x w)) (app1 max y2 (+ y h)))])))
    (values x1 y1 (- x2 x1) (- y2 y1))))

(define* (find-window-head win)
  "Returns the head number that contains one of the corners or the center
of the window that has the input focus.
Returns #f if no corner and center is contained in any head
(which should be rare if the window is visible)."
  (and win
       (let*-values ([(x y w h) (window-bounds win)]
                     [(x y) (window-absolute-position win)])
         (or (find-head x                     y)
             (find-head (+ x w)               y)
             (find-head x                     (+ y h))
             (find-head (+ x w)               (+ y h))
             (find-head (+ x (quotient w 2))  (+ y (quotient h 2)))))))



#;(module+ main
  (require racket/vector)
  (init-display)
  (split-head)
  (head-infos)
  (head-dimensions 0)
  (find-head 0 0)
  (find-head 1000 1000)
  (exit-display))

(define* (window+head-bounds window)
  "Returns the bounds of the window and the dimensions of its enclosing head."
  (define-values (x y w h) (window-bounds window))
  (define-values (xroot yroot wroot hroot) (head-bounds (find-window-head window)))
  (values x y w h wroot hroot))

(define* (window+vroot-bounds window)
  "Returns the bounds of the window and its enclosing virtual root."
  (define-values (x y w h) (window-bounds window))
  (define-values (xroot yroot wroot hroot) 
    (window-bounds (head-root-window (find-window-head window))))
  (values x y w h xroot yroot wroot hroot))


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

(define* (activate-next-window)
  "Gives the keyboard focus to the next window in the list of windows."
  ; TODO: cycle only among windows that want focus
  (define wl (viewable-windows))
  (unless (empty? wl)
    (let* ([wl (cons (last wl) wl)]
           [w (focus-window)]
           ; if no window has the focus (maybe the root has it)
           [m (member w wl)])
      (policy. activate-window
               (if m
                   ; the `second' should not be a problem because of the last that ensures
                   ; that the list has at least 2 elements if w is found
                   (second m)
                   ; not found, give the focus to the first window
                   (first wl))))))

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

  (xinerama-update-infos)
  )
