#lang racket/gui
; launcher-base.rkt
(require rwind/base
         rwind/util
         rwind/doc-string)

(define history-max-length 50)

(define rwind-launcher-history-file
  (find-user-config-file rwind-dir-name "rwind-launcher-history.txt"))

(define* (launcher-history)
  "History of launched commands from the Rwind launcher."
  (define hist
    (if (file-exists? rwind-launcher-history-file)
        (reverse (file->lines rwind-launcher-history-file))
        null))
  ;; If history is too long, truncate it and rewrite the file
  ;; (we don't want the history to grow indefinitely)
  (when (> (length hist) (* 2 history-max-length))
    (display-lines-to-file
     (reverse (take hist history-max-length))
     rwind-launcher-history-file
     #:mode 'text
     #:exists 'replace))
  hist)

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
