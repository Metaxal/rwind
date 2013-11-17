#lang racket/base
(require "base.rkt"
         racket/runtime-path
         (for-syntax "base.rkt"
                     racket/runtime-path))

(define-runtime-path src-dir user-files-dir)

(define (copy-file/print src dst)
  (printf "Copying: ~a\n     To: ~a\n" src dst)
  (define do-copy 
    (cond [(file-exists? dst)
           (printf "The file '~a' already exists. Do you want to overwrite it? [y/N] " dst)
           (member (read-line) '("Y" "y"))]
          [else #t]))
  (when do-copy
    (with-handlers ([exn:fail:filesystem:errno? 
                     (λ(e)(define errno (exn:fail:filesystem:errno-errno e))
                       (cond [(equal? errno '(13 . posix))
                              (printf "Error: Permission denied.
You probably have to run this command with 'sudo'.
Try 'sudo racket -l rwind/install-session'.
")
                              (exit -1)]
                             [else (raise e)]))])
      (copy-file src dst #t))))

(copy-file/print 
 (build-path src-dir "applications-rwind.desktop")
 "/usr/share/applications/rwind.desktop")

(copy-file/print
 (build-path src-dir "xsessions-rwind.desktop")
 "/usr/share/xsessions/rwind.desktop")

(printf "Would you like to start some Gnome daemons with your session? [y/N] ")
(define gnome? (member (read-line) '("y" "Y")))

(copy-file/print
 (build-path src-dir (if gnome? "rwind-gnome.start" "rwind.start"))
 "/usr/local/bin/rwind.start")
