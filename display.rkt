#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/doc-string
         rwind/util
         rwind/policy/base
         x11/x11
         racket/date
         racket/match
         )

;; TODO: update when xrandr is invoked (ConfigureNotify)
;; But should better use the (head-infos)
(define* (display-size [screen 0])
  "Returns the values of width and height of the given screen.
  Warning: These values may not reflect the current screen widths if they have changed?!"
  (values (XDisplayWidth (current-display) screen)
          (XDisplayHeight (current-display) screen)))

(define* (display-width [screen 0])
  (XDisplayWidth (current-display) screen))

(define* (display-height [screen 0])
  (XDisplayHeight (current-display) screen))

(define* (screen-count)
  (XScreenCount (current-display)))


(define* (init-debug)
  (when (rwind-debug)
    ;:::::::::::;
    ;:: Debug ::;
    ;:::::::::::;

    (set-Xdebug! #t) ; for POSIX compliant systems

    (x11-debug-prefix "  X: ")

    ; For debugging purposes only, because very slow!
    #;(XSynchronize (current-display) #t)

    #;(XSetAfterFunction (current-display)
                         (λ(display) ; -> int
                           ; This function is called after each X function
                           ))
    )

  ;; Errors and error-handlers:
  ;; http://tronche.com/gui/x/xlib/event-handling/protocol-errors/default-handlers.html
  ;; https://github.com/SawfishWM/sawfish/blob/47e09a56bffb17e1deda7adff175ae67c9a48daa/src/display.c
  (XSetErrorHandler
   (λ(display err-ev)
     ;(printf "Error received: ~a\n" (XErrorEvent->list* err-ev))
     (match-define
       (XErrorEvent _ disp resourceid _ err-code request-code minor-code)
       err-ev)
     (printf "*** Error: ~a\n" (XGetErrorText disp err-code 500)) ; Sufficient bytes?
     
     (when (eq? err-code 'BadWindow)
       (unless (and (eq? request-code 'X_ConfigureWindow)
                    (eq? minor-code 0))
         (policy. on-bad-window resourceid)))
     
     1)) ; must return an _int
  )

(define* (init-display)
  (define d (getenv "DISPLAY"))
  (dprintf "\n *** New session on ~a on display ~a ***\n"
           (date->string (current-date) #t)
           d)

  (current-display (XOpenDisplay #f))
  (unless (current-display)
    (error (format "Cannot open display ~a" d))
    (exit))
  )

(define* (exit-display)
  (XCloseDisplay (current-display))
  )

(define* (grab-server)
  (XGrabServer (current-display)))

(define* (ungrab-server)
  (XUngrabServer (current-display)))
