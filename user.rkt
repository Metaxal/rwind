#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/util
         rwind/doc-string
         racket/file
         )

(define* cmd-line-config-file (make-fun-box #f))

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

(define* (init-user)
  ;; Read user configuration file
  ;; There must be a 'raco link' to the rwind directory (no real need to raco setup for now),
  ;; so that it can be easily used with (require rwind/keymap) for example.
  ;; (a language might even be better, e.g., to redefine define (or just give a new 'define/doc'?)
  ;; It would be useless to thread it, as one would still need to call XLockDisplay
  (let ([user-f (rwind-user-config-file)])
    (with-handlers ([exn:fail? (λ(e)(printf "Error while loading user config file ~a:\n~a\n"
                                            user-f
                                            (exn-message e)))])
      (when (file-exists? user-f)
        (dynamic-require user-f #f))))
  )


