#lang racket/base

(require "base.rkt"
         "util.rkt")

(provide installer)

(define user-files-dir "user-files")


;; Ask to create the configuration files only if they are not already present.
(define (installer dir-path collect-dir)
  
  (displayln "\n*** RWind Configuration ***\n")
  
  (define (create-default name src dst)
    (unless (file-exists? dst)
      (printf "Would you like to create a default ~a file?\n" name)
      (printf "Source: ~a\nTarget: ~a\n" src dst)
      (printf "[Y/n] ")
      (define create (read-line))
      (when (member create '("Y" "y" ""))
        (copy-file src dst))
      (newline)))
  
  (create-default 
   "user configuration"
   (build-path collect-dir user-files-dir "config-simple.rkt")
   (find-user-config-file rwind-dir-name rwind-user-config-file-name))

  (create-default
   ".xinit-rwind"
   (build-path collect-dir user-files-dir ".xinitrc-rwind")
   (build-path (getenv "HOME") ".xinitrc-rwind")))