#lang racket/base

(require "base.rkt"
         ;rwind/base
         "test-inc.rkt";(file "/home/laurent/.config/rwind/config.rkt")
         )

(current-display "plop")
(printf "current display in rwind-test: ~a\n" (current-display))
(print-display)
