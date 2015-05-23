#lang racket/gui
; launcher-base.rkt
(require rwind/base
         rwind/util
         rwind/doc-string)
(provide open-launcher)

(define* rwind-launcher-history-file
  (find-user-config-file rwind-dir-name "rwind-launcher-history.txt"))

(define* (launcher-history)
  "History of launched commands from the Rwind launcher."
  (if (file-exists? rwind-launcher-history-file)
      (reverse (file->lines rwind-launcher-history-file))
      null))

(define* (add-launcher-history! command)
  "Add to the history of launched commands."
  (with-output-to-file rwind-launcher-history-file
    (λ ()
      (printf "~a~n" command))
    #:mode 'text
    #:exists 'append))

(define* (open-launcher)
  "Show the program launcher."
  (rwind-system "racket -l rwind/launcher"))
