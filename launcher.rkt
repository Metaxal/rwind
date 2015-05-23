#!/usr/bin/env racket
#lang racket/base
; launcher.rkt
; Lehi Toskin

(require rwind/launcher-base
         racket/gui/base
         racket/class
         racket/system
         racket/list
         racket/string)

;==========================;
;=== Command completion ===;
;==========================;

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
(define (reset-command-cycle!)
  (set! command-cycle '()))

(define (completion-cycle!)
  (when (empty? command-cycle)
    (set! command-cycle
          (find-prefix (send launcher-tfield get-value))))
  (unless (empty? command-cycle)
    (define cmd (first command-cycle))
    (send launcher-tfield set-value cmd)
    ; Place the first command in last position
    (set! command-cycle
          (append (rest command-cycle) (list cmd)))))

;=======================;
;=== History cycling ===;
;=======================;

;; Zipper for history cycling
(define hist-init (launcher-history))
(define up-hist #f)
(define down-hist #f)
(define (reset-zipper!)
  (set! up-hist hist-init)
  (set! down-hist '()))
(reset-zipper!)

(define (hist-up!)
  (unless (empty? up-hist)
    (define cmd (first up-hist))
    (set! up-hist (rest up-hist))
    (set! down-hist (cons cmd down-hist))
    (send launcher-tfield set-value cmd)))

(define (hist-down!)
  (if (empty? down-hist)
      (send launcher-tfield set-value "")
      (let ([cmd (first down-hist)])
        (set! down-hist (rest down-hist))
        (set! up-hist (cons cmd up-hist))
        (send launcher-tfield set-value cmd))))

;===========;
;=== Gui ===;
;===========;

(define (enter-callback tf e)
  (define type (send e get-event-type))
  (when (eq? type 'text-field)
    ; New character typed, reset the matching commands and history cycle
    (reset-zipper!)
    (reset-command-cycle!))
  (when (eq? type 'text-field-enter)
    (define str (send tf get-value))
    (define plst (process str))
    ; close the launcher window
    (send launcher-frame show #f)
    (send tf set-value "")
    ; add to history
    (add-launcher-history! str)
    ; explicitly close input/output ports
    (close-input-port (first plst))
    (close-output-port (second plst))
    (close-input-port (fourth plst))))

(define my-dialog%
  (class dialog%
    ;; Catch the Tab character before the text-field to perform command completion
    ;; and cycle through matching commands
    (define/override (on-traverse-char ev)
      (define ret (super on-traverse-char ev))
      (define key-code (send ev get-key-code))
      (case key-code
        [(up) (hist-up!)]
        [(down) (hist-down!)]
        [(#\tab) (completion-cycle!)
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
       [callback enter-callback]))

(send launcher-tfield focus) ; needs to be before, as `show` is blocking in a dialog%
(send launcher-frame show #t)
