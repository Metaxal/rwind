#lang racket/base

(require rwind/doc-string
         rwind/util
         rwind/gui/base
         racket/gui/base
         racket/class
         racket/dict
         )

(define* (make-menu parent dic)
  (for ([(k v) (in-dict dic)])
    (cond [(and k (dict? v))
           (make-menu (new menu% [label k] [parent parent]) v)]
          [(and (string? k) (procedure? v))
           (new menu-item% [parent parent]
                [label k]
                [callback v])]
          [(not k)
           (new separator-menu-item% [parent parent])]
          [else
           ; or raise an error?
           (error "Wrong format in menu ~a\n" (cons k v))])))

(define* (make-popup-menu dic)
  #;(define fr (new frame% [label ""]
                 [style '(no-resize-border no-caption no-system-menu hide-menu-bar float)]
                 [x 0] [y 0] [width 0 #;40] [height 0 #;20]))
  (define pm (new popup-menu%
                  [title "Some popup menu"]
                  [popdown-callback (L* (printf "menu popped down\n")
                                        #;(send fr show #f))]))
  #;(define bt (new button% [label "Menu"] [parent fr]
                  [callback (λ _ (send fr popup-menu pm 0 0))]))
  (make-menu pm dic)
  pm #;(list fr pm))

(define* (show-popup-menu menu x y)
  (define fr main-gui-frame #;(car menu))
  (define pm menu #;(cadr menu))
  (dprint-wait "Showing frame")
  #;(send fr move x y) ; so that it will be masked by the popup-menu
  #;(send fr show #t)
  (dprint-ok)
  (dprint-wait "Showing menu")
  (send fr popup-menu pm 0 0)
  (dprint-ok))

;;; For Testing:
#|
(define* (make-item str)
  (cons str (λ _ (printf "~a called.\n" str))))

(define* test-popup
  (make-popup-menu 
   `(
     ,(make-item "Item 1")
     (#f)
     ,(make-item "Item 2")
     ("Submenu 1" 
      ,(make-item "Subitem 1")
      ,(make-item "Subitem 2")
      ))))

(module+ test
  
  (define pm (make-popup-menu 
              `(
                ,(make-item "Item 1")
                (#f)
                ,(make-item "Item 2")
                ("Submenu 1" 
                 ,(make-item "Subitem 1")
                 ,(make-item "Subitem 2")
                 ))))
   (show-popup-menu pm 0 0)
  )
|#