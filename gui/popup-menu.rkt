#lang racket/base

(require rwind/doc-string
         rwind/util
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
  (define fr (new frame% [label ""]
                 ;[style '(no-resize-border no-caption no-system-menu hide-menu-bar float)]
                 [x 0] [y 0] [width 40] [height 20]))
  (define pm (new popup-menu%
                 [popdown-callback (λ _ (printf "menu popped down\n")
                                     (send fr show #f))]))
  (make-menu pm dic)
  (list fr pm))

(define* (show-popup-menu menu x y)
  (define fr (car menu))
  (define pm (cadr menu))
  (dprint-wait "Showing frame")
  (send fr show #t)
  (dprint-ok)
  (dprint-wait "Showing menu")
  (send fr popup-menu pm x y)
  (dprint-ok))

;;; For Testing:

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