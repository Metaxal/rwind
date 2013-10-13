#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

;;; Derived from: https://gist.github.com/tonyg/4548874

;;; Allows to run another racket program and restart it without having
;;; to restart the whole racket process.
;;; The procedure `recompile' is exported to allow recompilation before
;;; restarting the "process".

(require compiler/compiler)

(provide recompile)

(define the-collection-str  "rwind")
(define the-file-str        "rwind")
(define the-procedure-sym   'main)

(define the-collection-file-sym
  (string->symbol (string-append the-collection-str "/" the-file-str)))

;; -> bool
;; Returns #t if the compilation was a success,
;; Otherwise displays the error message and returns #f.
;; Call this procedure from the-procedure-sym to recompile the collection.
(define (recompile [error-handler
                    (λ(e)(displayln "Error: Something went wrong during compilation:")
                      (displayln (exn-message e))
                      (displayln "Aborting procedure."))])
  (displayln "Recompiling...")
  (with-handlers ([exn:fail? (λ(e)(error-handler e)
                               #f)])
    (compile-collection-zos the-collection-str
                            #:skip-doc-sources? #t)
    (displayln "Compilation done.")
    #t))

(module+ main

  ;; -> bool
  ;; Dynamic-requires the specified file,
  ;; runs the specified procedure and returns its (single) return value.
  ;; If this value is not #f, the process is restarted.
  ;; It is up to the user procedure to call the recompile procedure when needed.
  ;; (It doesn't do it automatically in case compilation goes wrong, in which case
  ;; it may be unsuitable to even stop the running user procedure.)
  (define (run)
    (define sub-custodian (make-custodian))
    (printf "Starting delegate main...\n")
    (define restart?
      (parameterize ([current-custodian sub-custodian]
                     [current-namespace (make-base-namespace)])
        (define run (dynamic-require the-collection-file-sym
                                     the-procedure-sym))
        (run)))
    (printf "Terminating delegate main...\n")
    (custodian-shutdown-all sub-custodian)
    restart?)

  (let loop ()
    (when (run)
      (loop)))

  (displayln "Terminating program.")
  ; In case something is hanging, preventing the process from terminating:
  (exit))
