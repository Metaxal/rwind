#lang racket

(require rwind/doc-string)

;; like a box, but with a function (and it's easy to switch with a parameter)
;; Their values are shared between all threads
(define* (make-fun-box val)
  "Similar to make-parameter, but without all the thread safety and the parameterization."
  (let ([var val])
    (case-lambda
      [() var]
      [(new-val) (set! var new-val)])))

(define* true-root-window     (make-fun-box #f))
(define* current-display      (make-fun-box #f))
(define* current-root-window  (make-fun-box #f))
(define* rwind-debug          (make-fun-box #f))
;(define current-display (make-parameter #f))
;(define current-root-window (make-parameter #f))
;(define rwind-debug (make-parameter #f))
(define* exit-rwind?          (make-fun-box #f))

(define* rwind-app-name "RWind")
(define* rwind-version '(1 0))
(define* rwind-app-description "Window manager in the Racket programming language")
(define* rwind-dir-name "rwind")
(define* rwind-user-config-file-name "config.rkt")
(define* rwind-website "http://github/...")

(define* rwind-tcp-port 54321)

#;(define mapped-windows '())
#;(define (get-mapped-windows)
  mapped-windows)
#;(provide (rename-out [get-mapped-windows mapped-windows]))
#;(doc mapped-windows "Returns the list of mapped windows.")
#;(define* (add-mapped-window w)
  (set! mapped-windows (cons w mapped-windows)))
#;(define* (remove-mapped-window w)
  (set! mapped-windows (remv w mapped-windows)))
