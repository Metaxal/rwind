#lang racket/base

(require "base.rkt"
         "util.rkt"
         racket/file
         racket/path
         racket/runtime-path
         (for-syntax "base.rkt"))

;;; Warning: This file must be run *without* sudo to install the config.rkt and xinit files
;;;   but it must be run with sudo for the session manager files.

(define-runtime-path src-dir user-files-dir)
(define-runtime-path configure.rkt "configure.rkt")

(define (copy-file/print src dst)
  (printf "Copying: ~a\n     To: ~a\n" src dst)
  (define do-copy 
    (cond [(file-exists? dst)
           (printf "The file '~a' already exists. Do you want to overwrite it? [y/N] " dst)
           (member (read-line) '("Y" "y"))]
          [else #t]))
  (when do-copy
    (with-handlers ([exn:fail:filesystem:errno? 
                     (λ(e)
                       (define errno (exn:fail:filesystem:errno-errno e))
                       (cond [(equal? errno '(13 . posix))
                              (printf "Error: Permission denied.
You probably need to run this command with 'sudo'
")
                              (exit -1)]
                             [else (raise e)]))])
      (make-parent-directory* dst)
      (copy-file src dst #t))))

;; Displays a list of numbered choices and asks the user for a choice.
;; Returns the index chosen by the user.
;; Indices start at 1.
;; default is the index of the default choice.
;; text is the text line preceding the choice list.
(define (text-choice l #:text [text ""] #:default [default #f])
  (displayln text)
  (for ([e l] 
        [i (in-naturals 1)])
    (printf "  ~a.\t~a\n" i e))
  (for/or ([i (in-naturals)])
    (display (string-append "Enter a number"
                            (if default 
                                (format " (default: ~a)" default)
                                "")
                            ": "))
    (define str (read-line))
    (define n
      (if (and default (string=? "" str))
          default
          (string->number str)))
    (and n
         (<= 1 n (length l))
         n)))

;; Creates the configuration file
(define (config-config)
  (copy-file/print
   (build-path src-dir "config-simple.rkt")
   (find-user-config-file rwind-dir-name rwind-user-config-file-name)))

;; Installs file for lightdm/gdm style login screens
(define (session-config)
  (copy-file/print
   (build-path src-dir "applications-rwind.desktop")
   "/usr/share/applications/rwind.desktop")
  
  (copy-file/print
   (build-path src-dir "xsessions-rwind.desktop")
   "/usr/share/xsessions/rwind.desktop")
  
  (define start-files
    (filter (λ(f) (and (file-exists? (build-path src-dir f))
                       (equal? (filename-extension f) #"start")))
            (directory-list src-dir)))
  
  (define start-index
    (text-choice start-files #:text "Which start file do you want to use?"))
  
  (copy-file/print
   (build-path src-dir (list-ref start-files (sub1 start-index)))
   "/usr/local/bin/rwind.start"))

;; Install files for use with xinit/startx
(define (xinit-config)
  (copy-file/print
   (build-path src-dir ".xinitrc-rwind")
   (build-path (getenv "HOME") ".xinitrc-rwind")))

(module+ main
  (cond
    [(equal? (current-command-line-arguments)
             #("session"))
     (session-config)]
    [else
     (config-config)
     
     (define kind
       (text-choice 
        #:text "What kind of configuration do you want?"
        '("Session manager (lightdm, gdm, etc.)"
          "xinit/startx")
        #:default 1))
     
     (case kind
       [(1)
        (printf "Need sudo rights to continue. Please type the following:\n")
        (printf "  sudo ~s ~s session\n"
                (path->string (find-system-path 'exec-file))
                (path->string configure.rkt))
        (exit 0)]
       [(2) (xinit-config)])]))
