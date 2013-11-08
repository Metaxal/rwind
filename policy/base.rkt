#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/doc-string
         racket/class)
; Do not include window, workspace, etc., because it would lead to cycles.
; Instead, all code that requires these modules should be written in the 
; derived classes (which other files should not depend on).

#| Policies

A policy defines most of the behavior of the window manager,
like the layout policy (where to place windows, what size, what order, etc.)
and the focus policy (to what window do we give the focus when a window is destroyed
or added, etc.).
Key/mouse-bindings are not handled by policies.

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
    
    (define/public (on-configure-request window value-mask
                                         x y width height border-width above stack-mode)
      (void))
    
    (define/public (on-configure-notify-true-root)
      (void))
    
    ;; Called from click-to-activate and other places
    (define/public (activate-window window)
      (void))
    
    ;; Gives the keyboard focus to the next window in the list of windows.
    (define/public (activate-next-window)
      (void))

    (define/public (on-add-window-to-workspace window wk)
      (void))
    
    (define/public (on-remove-window-from-workspace window wk)
      (void))
    
    (define/public (on-init-workspaces)
      (void))
    
    (define/public (on-activate-workspace wk)
      (void))
    
    (define/public (on-change-workspace-mode mode)
      (void))
    
    (super-new)))

; Use a fun box instead of a parameter so that 
; it is really a single global variable,
; that can be change for example via the client.
; (The client runs from a different thread, 
; and parameters are thread-dependent.)
(define* current-policy (make-fun-box (new policy%)))

