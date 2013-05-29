#lang racket/base

(require rwind/doc-string
         rwind/window
         racket/class)

(define* current-policy (make-parameter #f))

;; For the lazy guy
(provide policy.)
(define-syntax-rule (policy. args ...)
  (send (current-policy) args ...))

(define* policy-base%
  (class object%
    
    (define/public (on-keypress keyboard-ev)
      (void))
    
    (define/public (on-mouse-button mouse-ev)
      (void))
    
    (define/public (on-motion-notify mouse-ev)
      (void))
    
    (define/public (on-map-request window new?)
      ; give the window the input focus (if viewable)
      (raise-window window)
      (set-input-focus window))
    
    (define/public (on-unmap-notify window)
      (void))
    
    (define/public (on-destroy-notify window)
      (void))
    
    (super-new)))

(current-policy (new policy-base%))
