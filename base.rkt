#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/doc-string)

;; like a box, but with a function (and it's easy to switch to a parameter)
;; Their values are shared between all threads
(define* (make-fun-box val)
  "Like a box, but the identifier is used like for parameters.
Similar to make-parameter, but without all the thread safety and the 
parameterization (and, thus, faster)."
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
(define* rwind-website                "http://github/Metaxal/rwind")
(define* rwind-tcp-port               54321)
(define* rwind-log-file
  (build-path (find-system-path 'home-dir) "rwind.log"))

; Defines if a window is proteced.
; Used (at least) in workspace.rkt to avoid circular dependencies with window.rkt
; (it's not pretty but that seems the most reasonnable thing to do for now.)
(define* window-user-killable? #f)
(define* (set-window-user-killable? proc)
  (set! window-user-killable? proc))

