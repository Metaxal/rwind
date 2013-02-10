#lang racket/base

(require rwind/doc-string
         racket/gui/base
         racket/class
         )

(define* gui-eventspace (make-eventspace))

(current-eventspace gui-eventspace)

(define* (in-gui-eventspace?)
  (eq? (current-thread) (eventspace-handler-thread gui-eventspace)))
;  (eq? (current-eventspace) gui-eventspace))


#|
(provide with-gui)
(define-syntax-rule (with-gui body ...)
  (parameterize ([current-eventspace gui-eventspace])
    body ...))

(doc with-gui
     "Use this form to surround any code that deals with racket/gui code inside RWind. 
It paramaterizes the current event space to a dedicated one so that Racket GUI calls
do not get frozen.

See Racket documentation: doc/gui/windowing-overview.html")
|#

#;(define* main-gui-frame
  (new frame% [label "Main Gui Frame"]
       [x 10] [y 10] [width 0] [height 0]))

(define* (error-message-box e)
  (message-box "Error from RWind"
               (exn-message e)
               #f '(stop ok)))

(define* (init-gui)
  ;; Warning: When running a dialog box, it is mandatory to run it in a separate thread
  ;; otherwise the main thread will be blocked, and the dialog will not show up, 
  ;; since the main loop is what would show it, freezing everything.
  ;; (And it's useless to run the main loop in a separate thread, since keybindings 
  ;; are run from that loop)
  #;(send main-gui-frame show #t)
  #t
  )