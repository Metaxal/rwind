#lang racket

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/doc-string)

;; like a box, but with a function (and it's easy to switch to a parameter)
;; Their values are shared between all threads
(define* (make-fun-box val)
  "Like a box, but the identifier is used like for parameters.
Similar to make-parameter, but without all the thread safety and the parameterization (and, thus, faster)."
  (let ([var val])
    (case-lambda
      [() var]
      [(new-val) (set! var new-val)])))

(define* current-display  (make-fun-box #f))
(define* rwind-debug      (make-fun-box #f))
(define* exit-rwind?      (make-fun-box #f))
(define* restart-rwind?   (make-fun-box #f))

(define* rwind-app-name               "RWind")
(define* rwind-version                '(1 0))
(define* rwind-app-description        "Window manager in the Racket programming language")
(define* rwind-dir-name               "rwind")
(define* rwind-user-config-file-name  "config.rkt")
(define* rwind-website                "http://github/...")
(define* rwind-tcp-port               54321)
