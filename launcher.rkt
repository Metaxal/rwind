#!/usr/bin/env racket
#lang racket/base
; launcher.rkt
; Lehi Toskin

(require racket/gui/base
         racket/class
         racket/system
         racket/list
         racket/string)

;; Create the list of executable commands found in the directories of the
;; PATH environment variable
(define commands
  (filter values
          (for*/list ([l (string-split(getenv "PATH") ":")]
                      [f (directory-list l)])
            (define p (build-path l f))
            (and (file-exists? p)
                 (memq 'execute (file-or-directory-permissions p))
                 (path->string f) #;(list (path->string f) p)))))

;; Returns the list of commands for which str is a prefix
(define (find-prefix str)
  (define len (string-length str))
  (filter
   (λ(c)(and (>= (string-length c) len)
             (string=? str (substring c 0 len))))
   commands))

;; (mutable) List of commands matching the current string in the text-field
(define command-cycle '())

(define my-dialog%
  (class dialog%
    ;; Catch the Tab character before the text-field to perform command completion
    ;; and cycle through matching commands
    (define/override (on-traverse-char ev)
      (define ret (super on-traverse-char ev))
      (cond [(equal? (send ev get-key-code) #\tab)
             (when (empty? command-cycle)
               (set! command-cycle
                     (find-prefix (send launcher-tfield get-value))))
             (unless (empty? command-cycle)
               (define cmd (first command-cycle))
               (send launcher-tfield set-value cmd)
               ; Place the first command in last position
               (set! command-cycle
                     (append (rest command-cycle) (list cmd))))
             #t] ; don't propagate the Tab
            [else ret]))
    (super-new)))

(define launcher-frame
  (new my-dialog%
       [label "RWind Launcher"]
       [min-width 400]))

(define launcher-tfield
  (new text-field%
       [parent launcher-frame]
       [label "Enter a command:"]
       [style '(single vertical-label)]
       [callback (λ (tf e)
                   (define type (send e get-event-type))
                   (when (eq? type 'text-field)
                     ; New character typed, reset the matching commands
                     (set! command-cycle '()))
                   (when (eq? type 'text-field-enter)
                     (let ([plst (process (send tf get-value))])
                       ; close the launcher window
                       (send tf set-value "")
                       (send launcher-frame show #f)
                       ; explicitly close input/output ports
                       (close-input-port (first plst))
                       (close-output-port (second plst))
                       (close-input-port (fourth plst)))))]))

#;(define* (show-launcher)
  "Show the program launcher."
  (send launcher-frame show #t)
  (send launcher-frame enable #t)
  (send launcher-tfield enable #t))

(send launcher-tfield focus) ; needs to be before, as `show` is blocking in a dialog%
(send launcher-frame show #t)
