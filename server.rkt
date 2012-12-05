#lang racket ; to load all useful procedures for evaling the client commands

;;; Author: Laurent Orseau
;;; License: LGPL

#| TODO
- security: 
  - verify that the user is the same as the owner of the root window
- module->namespace with a separate module instead of an anchor?

|#

(require x11-racket/x11
         rwind/base
         rwind/util
         rwind/window
         rwind/keymap
         rwind/doc-string
         rwind/workspace
         racket/tcp
         )

(provide start-rwind-server)

(define-namespace-anchor server-namespace-anchor)
(define server-namespace (namespace-anchor->namespace server-namespace-anchor))

(define (start-rwind-server [continuous? #t])
  (dprint-wait "Opening listener")
  (define listener (tcp-listen rwind-tcp-port 4 #t "127.0.0.1"))
  (dprint-ok)
  
  (dynamic-wind
   void
   (λ()
     (let accept-loop ()
       (dprint-wait "Waiting for client")
       (define-values (in out) (tcp-accept/enable-break listener))
       (printf "Client is connected.\n")
       
       (dynamic-wind
        void
        (λ()
          (dprint-wait "Waiting for data")
          (for ([e (in-port read in)]
                #:break (equal? e '(exit))
                )
            (printf "Received ~a\n" e)
              ; if it fails, simply return the message
              (with-handlers ([exn:fail? (λ(e)
                                           (define res (exn-message e))
                                           (dprintf "Sending exception: ~a" res)
                                           (write-data/flush res out))])
                (define res 
                  (let ([d (current-display)])
                    (dynamic-wind
                     (λ() (XLockDisplay d))
                     (λ() 
                       ;(printf "BEFORE EVAL")(flush-output)
                       (with-output-to-string
                        (λ()
                          (define r (eval e server-namespace))
                          (unless (void? r)
                            (write r)))))
                     (λ() 
                       ;(printf "BETWEEN EVAL AND FLUSH")(flush-output)
                       (XFlush (current-display))
                       ;(printf "AFTER FLUSH")(flush-output)
                       (XUnlockDisplay d)))))
                (dprint-wait "Sending value: ~a" res)
                ; Printed in a string, to send a string, 
                ; because the reader cannot read things like #<some-object>
                (write-data/flush res out)
                )
            (dprint-ok)
            (dprint-wait "Waiting for data")
            
            ))
        (λ()
          (dprintf "Closing connection.\n")
          (close-input-port in)
          (close-output-port out)
          (when continuous?
            (accept-loop))
          ))))
   ; out
   (λ()
     (dprint-wait "Closing listener")
     (tcp-close listener)
     (dprint-ok))))

(define server-thread #f)

(define* (init-server)
  ;; Start the server
  (set! server-thread
    (parameterize ([debug-prefix "Srv: "])
      (thread start-rwind-server)))
  )

(define* (exit-server)
  ; Call a break so that dynamic-wind can close the ports and the listener
  (break-thread server-thread)
  ; Wait for the thread to be closed before closing everything
  ;(thread-wait server-thread) ; deadlock?
  )

(module+ main
  (rwind-debug #t)
  (current-display (XOpenDisplay #f))
  (dynamic-wind
   void
   (λ()(start-rwind-server #f))
   (λ()
     (dprint-wait "Closing display")
     (XCloseDisplay (current-display))
     (dprint-ok)))
  )
