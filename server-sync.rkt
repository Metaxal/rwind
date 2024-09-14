#lang racket

;; Trying to make the server not use threads
;; (not currently used)

(require rwind/base
         rwind/util
         rwind/window
         rwind/keymap
         racket/tcp
         )

(define-namespace-anchor server-namespace-anchor)
(define server-namespace (namespace-anchor->namespace server-namespace-anchor))

(define (make-server-listener)
  (dprint-wait "Opening listener")
  (define listener (tcp-listen rwind-tcp-port))
  (dprint-ok)
  listener)

(define (handle-server-accept listener)
  (dprint-wait "Accepting client")
  (define-values (in out) (tcp-accept/enable-break listener))
  (dprint-ok)
  (list in out))

;; Returns #t if the client wants to continue handling events,
;; or #f if the client is shut down
(define (handle-server-input in out)
  (define e (read in))
  (cond [(equal? e '(exit))
         #f]
        [(eof-object? e)
         #f]
        [else
         (dprintf "Received ~a\n" e)
         ; if it fails, simply return the message
         (with-handlers ([exn:fail? (λ(e)
                                      (define res (exn-message e))
                                      (dprintf "Sending exception: ~a" res)
                                      (write (~v res) out)
                                      (flush-output out))])
           (define res (eval e server-namespace))
           (dprint-wait "Sending value: ~v" res)
           (write (~v res) out)
           (flush-output out)
           )
         (dprint-ok)
         #t]))

#;(module+ main
  (rwind-debug #t)
  (define listener (make-server-listener))
  (define clients '())
  (dynamic-wind
   void
   (let loop ()
     (dprintf "#Clients: ~a\n" (length clients))
     (define (make-client-handle-evts in-out)
       (define-values (in out) (apply values in-out))
       (and (not (port-closed? in))
            (choice-evt
             (handle-evt (port-closed-evt in)
                         (λ(e)
                           (dprintf "Port closed, removing client.\n")
                           (set! clients (remove in-out clients))))
             (handle-evt in
                         (λ(in)
                           (unless (handle-server-input in out)
                             (dprintf "Client exited, removing client.\n")
                             (set! clients (remove in-out clients)))
                           (loop))))))
     (apply
      sync/enable-break
      #;(handle-evt (system-idle-evt)
                  (λ(e)(dprintf "Idle\n")
                    (loop)))
      (handle-evt listener
                  (λ(listener)
                    (define client-ports (handle-server-accept listener))
                    (set! clients (cons client-ports clients))
                    (loop)))
      (filter values (map make-client-handle-evts clients))))
   (λ()
     (dprintf "Terminating")
     (tcp-close listener)
     (dprint-ok)
     )))

;; With threads
(module+ main
  (rwind-debug #t)
  (define listener (make-server-listener))
  (define (make-client-thread in out)
    (thread
     (λ()
       (let loop ()
         (sync/enable-break
          (handle-evt (port-closed-evt in)
                      (λ(e)
                        (dprintf "Port closed.\n")))
          (handle-evt in
                      (λ(in)
                        (if (handle-server-input in out)
                            (loop)
                            (dprintf "Client exited.\n"))
                        )))))))

  (dynamic-wind
   void
   (let loop ()

     (sync/enable-break
      #;(handle-evt (system-idle-evt)
                    (λ(e)(dprintf "Idle\n")
                      (loop)))
      (handle-evt listener
                  (λ(listener)
                    (define in-out (handle-server-accept listener))
                    (apply make-client-thread in-out)
                    (loop)))
      ))
   (λ()
     (dprintf "Terminating")
     (tcp-close listener)
     (dprint-ok)
     )))
