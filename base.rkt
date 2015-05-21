#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/doc-string)

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
(define* rwind-website                "http://github.com/Metaxal/rwind")
(define* rwind-tcp-port               54321)
(define* rwind-log-file
  (build-path (find-system-path 'home-dir) "rwind.log"))

; ~/bin
(define bin-dir
  (build-path (find-system-path 'home-dir) "bin"))

; ~/bin/launcher.rkt
(define* rwind-launcher
  (build-path bin-dir "rwind-launcher.rkt"))

(define* user-files-dir "user-files")

; Defines if a window is protected.
; Used (at least) in workspace.rkt to avoid circular dependencies with window.rkt
; (it's not pretty but that seems the most reasonnable thing to do for now.)
(define* window-user-killable? #f)
(define* (set-window-user-killable? proc)
  (set! window-user-killable? proc))

