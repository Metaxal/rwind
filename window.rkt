#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/doc-string
         rwind/util
         x11-racket/x11
         racket/list
         racket/contract
         )

#| TODO
- contracts
|#

(define* window? exact-nonnegative-integer?)

(define*/contract (window=? w1 w2)
  (window? window? . -> . boolean?)
  (eq? w1 w2))

;; TEST: for testing
(define* (create-test-window [x 100] [y 100])
  "Creates a simple window under the root and maps it."
  (define window (XCreateSimpleWindow (current-display) (current-root-window)
                                      x y 100 100 2 0 0))
  (when window (map-window window))
  window)

;========================;
;=== Window Accessors ===;
;========================;

#;(define* (window-name/class window)
  (define-values (status hint) (XGetClassHint (current-display) window))
  (and status
       (list (XClassHint-res-name) (XClassHint-res-class))))

(define* (window-text-property window atom)
  "Returns a list of strings for the property named atom for the given window."
  (and window
       (let ([txt (XGetTextProperty (current-display) window atom)])
         ; should use the Xmb variant instead?
         (and txt (XTextPropertyToStringList txt)))))

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
  WM_TAKE_FOCUS
  WM_DELETE_WINDOW
  )


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
       (list 'XA_WM_NAME 'XA_WM_ICON_NAME))
  #;(map (λ(v)(window-text-property window v))
       (list _NET_WM_NAME
             _NET_WM_VISIBLE_NAME
             _NET_WM_ICON_NAME
             _NET_WM_VISIBLE_ICON_NAME)))
   

(define* (window-class window)
  "Returns the list of classes of the window."
  (window-text-property window 'XA_WM_CLASS))


(define* (window-protocols window)
  ; Use XGetAtomNames instead of XGetAtomName ?
  (map (λ(v)(if (symbol? v)
                v
                (XGetAtomName (current-display) v)))
       (XGetWMProtocols (current-display) window)))

(define* (window-attributes window)
  (XGetWindowAttributes (current-display) window))

(define* (window-dimensions window)
  (define attr (window-attributes window))
  (values (XWindowAttributes-width attr)
          (XWindowAttributes-height attr)))

(define* (window-position window)
  (define attr (window-attributes window))
  (values (XWindowAttributes-x attr)
          (XWindowAttributes-y attr)))

(define* (window-border-width window)
  (define attr (window-attributes window))
  (XWindowAttributes-border-width attr))


(define* (window-map-state window)
  "Returns 'IsUnmapped, 'IsUnviewable or 'IsViewable.
 IsUnviewable is used if the window is mapped but some ancestor is unmapped."
  (define attrs (and window (XGetWindowAttributes (current-display) window)))
  (and attrs (XWindowAttributes-map-state attrs)))

(define* (window-viewable? window)
  (eq? 'IsViewable (window-map-state window)))

;========================;
;=== Window Modifiers ===;
;========================;

(define* (move-window window x y)
  (XMoveWindow (current-display) window x y))

(define* (resize-window window w h)
  (XResizeWindow (current-display) window w h))

(define* (move-resize-window window x y w h)
  (XMoveResizeWindow (current-display) window x y w h))

(define* (show-window window)
  (XMapWindow (current-display) window))

(define* (show/raise-window window)
  (XMapRaised (current-display) window))

(define* (hide-window window)
  (XUnmapWindow (current-display) window))

(define* (raise-window window)
  (XRaiseWindow (current-display) window))

(define* (map-window window)
  (XMapWindow (current-display) window))

(define* (unmap-window window)
  (XUnmapWindow (current-display) window))

(define* (lower-window window)
  (XLowerWindow (current-display) window))

(define* (iconify-window window)
  (XIconifyWindow (current-display) window))

;(define (uniconify-window window)(void))

(define* (reparent-window window new-parent)
  "Changes the parent of window to new-parent."
  (define-values (x y) (window-position window))
  (XReparentWindow (current-display) window new-parent
                   x y))

(define* (send-event window event-mask event [propagate #t])
  (XSendEvent (current-display) window propagate event-mask event))

(define* (send-client-message window msg-type msg-value)
  (error "Not implemented.")
  ;(define event (make-XClientMessageEvent 
  )

(define* (destroy-window window)
  (XDestroyWindow (current-display) window))

(define* (kill-client window)
  (XKillClient (current-display) window))

(define* (delete-window window)
  "Tries to gently close the window and client if possible, otherwise kills it."
  (if (memq 'WM_DELETE_WINDOW (window-protocols window))
      (send-client-message window 'WM_PROTOCOLS 'WM_DELETE_WINDOW)
      (kill-client window)))

(define* (set-window-border-width window width)
  (XSetWindowBorderWidth (current-display) window width))

(define* (set-window-background-color window color)
  "Color must be a color found with find-named-color or similar (i.e., it is a color-pixel)."
  (XSetWindowBackground (current-display) window color)
  ; refresh:
  (clear-window window))

(define* (clear-window window)
  (XClearWindow (current-display) window))

;=====================;
;=== Focus/Pointer ===;
;=====================;

(define* (input-focus)
  (car (XGetInputFocus (current-display))))

(define* (set-input-focus window)
  "Gives the keyboard focus to the window if it is viewable."
  ; TODO: focus should not be given to windows that don't want it
  (when (and window (window-viewable? window))
    (XSetInputFocus (current-display) window 'RevertToParent CurrentTime)))

(define* (set-input-focus/raise window)
  (when window
    (set-input-focus window)
    (raise-window window)))

(define* (query-pointer)
"Returns values:
  win: the targeted window
  x: the x coordinate in the root window
  y: the y coordinate in the root window
  mask: the modifier mask"
  (define-values (rc root win x y win-x win-y mask)
    (XQueryPointer (current-display) (current-root-window)))
  (list win x y mask))

(define* (pointer-focus)
  "Returns the window that is below the mouse pointer."
  (car (query-pointer)))

;; Replace the global keymap by an empty one
;; with only one binding: Button1Press
;; Use grabPointer, and ungrab it in the callback
#;(define* (select-window)
  void)

(define* (focus-next!)
  "Gives the keyboard focus to the next window in the list of windows" 
  ; TODO: cycle only among windows that want focus
  (define wl (viewable-windows))
  (unless (empty? wl)
    (let* ([wl (cons (last wl) wl)]
           [w (input-focus)]
           ; if no window has the focus (maybe the root has it)
           [m (member w wl)])
      (if m
          ; the cadr should not be a problem because of the last that ensures 
          ; that the list has at least 2 elements if w is found
          (set-input-focus/raise (cadr m))
          ; not found, give the focus to the firt window
          (set-input-focus/raise (first wl))))))

;===============================;
;=== Window Lists Operations ===;
;===============================;

(define* (window-list [parent (current-root-window)])
  "Returns the list of windows."
  (filter values (XQueryTree (current-display) parent)))

(define* (filter-windows proc [parent (current-root-window)])
  "Maps proc to the list of windows."
  (filter (λ(w)(and w (proc w))) (window-list parent)))

(define* (find-windows rx [parent (current-root-window)])
  "Returns the list of windows that matches the regexp rx."
  (filter-windows (λ(w)(regexp-match rx (window-name w))) parent))

(define* (find-windows-by-class rx [parent (current-root-window)])
  "Returns the list of windows for which one of the window's classes matches the regexp rx."
  (filter-windows (λ(w)(ormap (λ(c)(regexp-match rx c)) (window-class w))) parent))

(define* (mapped-windows [parent (current-root-window)])
  "Returns the list of windows that are mapped but not necessarily viewable
(i.e., the window is mapped but one ancester is unmapped)."
  (filter-windows (λ(w)(let ([s (window-map-state w)])
                         (and s (not (eq? 'IsUnmapped s)))))
                  parent))

(define* (viewable-windows [parent (current-root-window)])
  (filter-windows (λ(w)(eq? 'IsViewable (window-map-state w))) parent))


;; todo: send window to left/right/up/down, etc.

;================;
;=== Monitors ===;
;================;

#| Ideas
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
|#

#;(define* (monitor-dimensions m)
  #f)

#;(define* (monitor-offset m)
  #f)


;===================;
;=== Root Window ===;
;===================;

(define* (init-root-window)
  (true-root-window (XDefaultRootWindow (current-display)))
  ;; Ask the root window to send us any event
  ;; (Q: is it useful if we use virtual roots?)
  (define attrs (make-XSetWindowAttributes #:event-mask '(SubstructureRedirectMask)))
  (XChangeWindowAttributes (current-display) (true-root-window) '(EventMask) attrs)
  )

(define* (with-root-window/proc new-root proc)
  (let ([old-root (current-root-window)])
    (dynamic-wind
     (λ()(current-root-window new-root))
     proc
     (λ()(current-root-window old-root)))))



