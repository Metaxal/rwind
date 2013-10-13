#lang racket/base

(require rwind/doc-string
         racket/class)
; Do not include window, workspace, etc., because it would lead to cycles.
; Instead, all code that requires these modules should be written in the 
; derived classes (which other files should not depend on).

#| Policies

A policy defines most of the behavior of the window manager,
except (at least) for keybindings.
It can be easily extended and modified by using Racket's OO tools,
like inheritence, augment, mixins, etc.

The policy% class is virtual in the sense that no method does anything,
and it must necessarily be  implemented to have a working WM.

|#

;; For the lazy guy (me)
(provide policy.)
(define-syntax-rule (policy. args ...)
  (send (current-policy) args ...))

(define* policy%
  (class object%
    
    (define/public (on-keypress keyboard-ev)
      (void))
    
    (define/public (on-mouse-button mouse-ev)
      (void))
    
    (define/public (on-motion-notify mouse-ev)
      (void))
    
    (define/public (on-map-request window new?)
      (void))
    
    (define/public (on-unmap-notify window)
      (void))
    
    (define/public (on-destroy-notify window)
      (void))
    
    ;; Called on an inner call to create-simple-window,
    ;; i.e., not on an X event.
    (define/public (on-create-window window)
      (void))
    
    (define/public (on-create-notify window)
      (void))
    
    ;; Called from click-to-activate and other places(?)
    (define/public (activate-window window)
      (void))
    
    (super-new)))

(define* current-policy (make-parameter (new policy%)))

