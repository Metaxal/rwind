#lang racket/base

;;; Author: Laurent Orseau <laurent orseau gmail com> -- 2012-11-09
;;; License: GPL (see gpl-3.0.txt)
;;; (in GPL because the readline lib is itself in GPL.
;;; But since the rest of RWind does not depend on this client, it's no big deal.)

#| TODO
- does not seem to detect that the server could not start?
|#

(require racket/tcp
         rwind/base
         rwind/util
         readline ; for more usable client. WARNING: requires the license to be GPL?
         ; or invoke it with 'racket -l readline client.rkt'
         ; Or I can release the client only under GPL?
         )

(define client-prompt "rwind-client> ")
(define client-result-format "-> [~a]\n")

(print-wait "Trying to connect to server")
(define-values (in out) (tcp-connect/enable-break "localhost" rwind-tcp-port))
(print-ok)

(dynamic-wind
 void
 (λ()
   (printf client-prompt)(flush-output)
   (define exit? #f)
   (for ([e (in-port read)]
         #:break (or exit? (equal? e '(exit)))
         )
     (print-wait "Sending: ~a" e)
     ; Wrap the output in a list, otherwise it may not be sent/flushed (bug?)
     (write-data/flush e out)
     (print-ok)
     ; receiving from server, unwrap
     (define res (read in))
     (if (eof-object? res)
         (set! exit? #t)
         (begin
           (printf client-result-format res)
           (printf client-prompt)(flush-output)))
     ))
 (λ()
   (print-wait "Closing connection")
   (close-input-port in)
   (close-output-port out)
   (print-ok)))

(module+ main
  (rwind-debug #t)
  )