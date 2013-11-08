#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/doc-string)

;; like a box, but with a function (and it's easy to switch to a parameter)
;; Their values are shared between all threads
(define* (make-fun-box val)
  "Like a box, but the identifier is used like for parameters.
  On the contrary to parameters, the value of a fun-box is shared by all threads."
  (let ([var val])
    (case-lambda
      [() var]
      [(new-val) (set! var new-val)])))

(define* current-display  (make-fun-box #f))
(define* rwind-debug      (make-fun-box #f))
(define* exit-rwind?      (make-fun-box #f))
(define* restart-rwind?   (make-fun-box #f))

(define* rwind-app-name               "RWind")
(define* rwind-version                '(0 1))
(define* rwind-app-description        "Window manager in the Racket programming language")
(define* rwind-dir-name               "rwind")
(define* rwind-user-config-file-name  "config.rkt")
(define* rwind-env-config-var         "RWIND_CONFIG_FILE")
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

