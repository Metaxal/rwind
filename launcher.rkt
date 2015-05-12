#!/usr/bin/env racket
#lang racket/gui
; launcher.rkt

(define launcher-frame
  (new frame%
       [label "Rwind Launcher"]
       [min-width 400]))

(define launcher-tfield
  (new text-field%
       [parent launcher-frame]
       [label "Please enter a command:"]
       [style '(single vertical-label)]
       [callback (λ (l e)
                   (when (eq? (send e get-event-type) 'text-field-enter)
                     (let ([plst (process (send l get-value))])
                       ; close the launcher window
                       (send l set-value "")
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

(send launcher-frame show #t)
(send launcher-tfield focus)
