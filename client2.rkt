#lang racket ; to load all useful procedures for evaling the client commands

(require x11-racket/x11
         rwind/base
         rwind/util
         rwind/window
         rwind/keymap
         rwind/doc-string
         ;racket/tcp
         readline
         )

;(provide start-rwind-server)

(define-namespace-anchor server-namespace-anchor)
(define server-namespace (namespace-anchor->namespace server-namespace-anchor))
; or use module->namespace with a different module that is empty except for the requires?
; would be safer no?

(define (start-rwind-client [continuous? #t])
  (define rwind-prompt "rwind-client> ")
  (define rwind-out-prompt "")
  
  (current-display (XOpenDisplay #f))
  (unless (current-display)
    (error "Cannot open display.")
    (exit))
    
  (define (client-loop)
    (display rwind-prompt) (flush-output)
    (XSync (current-display) #f) ; sync and wait for sync'ed state
    (for ([e (in-port read)]
          #:break (equal? e '(exit))
          )
      ; if it fails, simply return the message
      (with-handlers ([exn:fail? (λ(e)
                                   (define res (exn-message e))
                                   (displayln res))])
        (define res (eval e server-namespace))
        (printf "~a~v\n" rwind-out-prompt res)
        (display rwind-prompt) (flush-output)
        
        ;; This seems necessary to force the server to handle our request immediately
        ;; otherwise, I sometimes see it hand until some other request is given        
        (XFlush (current-display))
        )))
  
  (dynamic-wind
   void
   client-loop
   (λ() (XCloseDisplay (current-display)))))

(module+ main
  (rwind-debug #t)
  (start-rwind-client #f))
