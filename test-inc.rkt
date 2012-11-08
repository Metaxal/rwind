#lang racket/base
(require rwind/base)

(printf "Using user configuration file\n")

(provide print-display)
(define (print-display)
  (printf "* current-display: ~a\n" (current-display))
  )