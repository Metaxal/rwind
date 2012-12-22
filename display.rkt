#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base 
         rwind/doc-string
         rwind/util
         x11-racket/x11
         racket/date
         )

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


(define* (init-debug)
  (when (rwind-debug)
    ;:::::::::::;
    ;:: Debug ::;
    ;:::::::::::;
    
    (set-Xdebug! #t) ; for POSIX compliant systems
    
    (x11-debug-prefix "  X: ")
    
    ; For debugging purposes only, because very slow!
    (XSynchronize (current-display) #t)
    
    ; TODO: set _XDebug to #t !
    #;(XSetAfterFunction (current-display)
                         (λ(display) ; -> int
                           ; This function is called after each X function
                           ))
    )
  
  ;; Errors and error-handlers:
  ;; http://tronche.com/gui/x/xlib/event-handling/protocol-errors/default-handlers.html
  (XSetErrorHandler 
   (λ(display err-ev)
     ;(printf "Error received: ~a\n" (XErrorEvent->list* err-ev))
     (printf "*** Error: ~a\n" (XGetErrorText 
                                (XErrorEvent-display err-ev)
                                (XErrorEvent-error-code err-ev)
                                500)) ; Sufficient bytes?
     1)) ; must return an _int
  )

(define* (init-display)
  (dprintf "\n *** New session on ~a on display ~a ***\n" 
           (date->string (current-date) #t)
           (getenv "DISPLAY"))
  
  (current-display (XOpenDisplay #f))
  (unless (current-display)
    (error "Cannot open display.")
    (exit))
  )
      
(define* (exit-display)
  (XCloseDisplay (current-display))
  )

(define* (grab-server)
  (XGrabServer (current-display)))

(define* (ungrab-server)
  (XUngrabServer (current-display)))
