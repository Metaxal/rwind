#lang racket/base

(require rwind/base
         rwind/util
         rwind/doc-string
         racket/file
         )

(define* cmd-line-config-file (make-fun-box #f))
(define* rwind-uds-socket (make-fun-box (find-user-config-file rwind-dir-name "rwind-socket")))

(define* (rwind-user-config-file)
  "Returns the configuration-file path for rwind (and may create the directory)."
  (or (cmd-line-config-file)
      (find-user-config-file rwind-dir-name rwind-user-config-file-name)))

(define* (open-user-config-file)
  "Tries to open the user configuration file for edition, using the system default editor."
  (define f (rwind-user-config-file))
  (unless (file-exists? f)
    (display-to-file
     "#lang racket/base
;;; User configuration file

(require rwind/keymap rwind/base rwind/util rwind/window)

"
     f #:mode 'text))
  (open-file f))

;; TODO:
;; - If loading the user file fails, fall back to a default configuration (file)?
;; - replace the `printf' by `log-error'
(define* (init-user)
  ;; Read user configuration file
  ;; It would be useless to thread it, as one would still need to call XLockDisplay
  (let ([user-f (rwind-user-config-file)])
    (when (file-exists? user-f)
      (with-handlers ([exn:fail? #;error-message-box
                                 (λ(e)(printf "Error while loading user config file ~a:\n~a\n"
                                              user-f
                                              (exn-message e)))])
        (dynamic-require user-f #f)))))
