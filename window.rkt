#lang racket/base

(require ;"base.rkt"
         rwind/base
         rwind/doc-string
         rwind/util
         x11-racket/x11
         ;"../x11-racket/x11.rkt"
         racket/match
         racket/list
         )

;(provide (all-defined-out))

#| TODO
- error checking!
  use contracts and verify that windows exist, etc.
- Documentation
  Docstrings?
  Scribblings?
|#

(define* (root-window? window)
  ; windows are _ulong or #f
  (and window
       (= (current-root-window) window)))

(define* (subwindow? window)
  (and window (not (root-window? window))))

(define* (least-root-window w1 w2)
  "Returns w1 or w2 if one of them is a non-root window, 
otherwise returns the root window if either w1 or w2 is the root window,
otherwise returns #f."
  (if (subwindow? w1)
      w1
      (if (subwindow? w2)
          w2
          (or w1 w2))))

(define* (move-window window x y)
  (XMoveWindow (current-display) window x y))

(define* (resize-window window w h)
  (XResizeWindow (current-display) window w h))

(define* (move-resize-window window x y w h)
  (XMoveResizeWindow (current-display) window x y w h))

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
  )


(define* (window-name window)
  ;(printf "net wm name: ~a\n" _NET_WM_NAME)
  (define names
    (or
     (window-text-property window _NET_WM_NAME)
     (window-text-property window 'XA_WM_NAME)))
  (and names (car names)))
   
(define* (window-names window)
  "Returns the list of list of strings for the name, 
the visible name, the icon name and the visible icon name in order."
  (map (λ(v)(window-text-property window v))
       (list _NET_WM_NAME
             _NET_WM_VISIBLE_NAME
             _NET_WM_ICON_NAME
             _NET_WM_VISIBLE_ICON_NAME)))
   

(define* (window-class window)
  "Returns the list of classes of the window."
  (window-text-property window 'XA_WM_CLASS))

(define* (input-focus)
  (car (XGetInputFocus (current-display))))

(define* (set-input-focus window)
  (XSetInputFocus (current-display) window 0 CurrentTime))

(define* (raise-window window)
  (XRaiseWindow (current-display) window))

(define* (set-input-focus/raise w)
  (when w
    (set-input-focus w)
    (raise-window w)))

(define* (lower-window window)
  (XLowerWindow (current-display) window))

(define* (iconify-window window)
  (XIconifyWindow (current-display) window))

;(define (uniconify-window window)(void))

(define* (destroy-window window)
  (XDestroyWindow (current-display) window))

(define* (configure-window configure-request-event)
  (match-define 
    (XConfigureRequestEvent type serial send-event _display parent window
                            x y width height border-width above stack-mode value-mask)
    configure-request-event)
  (XConfigureWindow (current-display) window value-mask 
                    (make-XWindowChanges x y width height border-width above stack-mode)))

(define* (set-window-border-width window width)
  (XSetWindowBorderWidth (current-display) window width))

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
  
;;; This should be in x-util.rkt?

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

(define* (window-list)
  "Returns the list of windows."
  (filter values (XQueryTree (current-display) (current-root-window))))

(define* (filter-windows proc)
  "Maps proc to the list of windows."
  (filter (λ(w)(and w (proc w))) (window-list)))

(define* (find-windows rx)
  "Returns the list of windows that matches the regexp rx."
  (filter-windows (λ(w)(regexp-match rx (window-name w)))))

(define* (find-windows-by-class rx)
  "Returns the list of windows for which one of the window's classes matches the regexp rx."
  (filter-windows (λ(w)(ormap (λ(c)(regexp-match rx c)) (window-class w)))))

(define* (window-map-state w)
  (define attrs (and w (XGetWindowAttributes (current-display) w)))
  (and attrs (XWindowAttributes-map-state attrs)))

(define* (mapped-windows)
  "Returns the list of windows that are mapped but not necessarily viewable (i.e., the window is mapped but one ancester is unmapped)."
  (filter-windows (λ(w)(let ([s (window-map-state w)])
                         (and s (not (eq? 'IsUnmapped s)))))))

(define* (viewable-windows)
  (filter-windows (λ(w)(eq? 'IsViewable (window-map-state w)))))

(define* (display-dimensions [screen 0])
  "Returns the values of width and height of the given screen."
  (values (XDisplayWidth (current-display) screen)
          (XDisplayHeight (current-display) screen)))

(define* (display-width [screen 0])
  (XDisplayWidth (current-display) screen))

(define* (display-height [screen 0])
  (XDisplayHeight (current-display) screen))

(define* (screen-count)
  (XScreenCount (current-display)))




;================;
;=== Monitors ===;
;================;

#| Ideas
- to test monitors on a single screen, I could set up "virtual" monitors, 
  i.e., split the screen in different monitors.
  This could even be a usefull feature (to develop further and expand?)
- each monitor may display a different workspace (like xmonad)
- These should be done as extensions to RWind, not in the core
- use xinerama?
|#

#;(define* (monitor-dimensions m)
  #f)

#;(define* (monitor-offset m)
  #f)
