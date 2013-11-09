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

    ;; Called when a key is pressed.
    ;; Keybindings have already been called.
    (define/public (on-keypress keyboard-ev)
      (void))
    
    ;; Called when a mouse button is pressed.
    ;; Mouse button bindings have already been called.
    (define/public (on-mouse-button mouse-ev)
      (void))
    
    ;; Called when the mouse moves.
    ;; Mouse and keybindings have already been called.
    (define/public (on-motion-notify mouse-ev)
      (void))
    
    ;; Called when a window has requested to be mapped
    (define/public (on-map-request window new?)
      (void))
    
    ;; Called after a window has been unmapped
    (define/public (on-unmap-notify window)
      (void))
    
    ;; Called after a window has been destroyed
    (define/public (on-destroy-notify window)
      (void))
    
    ;; Called on an inner call to create-simple-window,
    ;; i.e., not on an X event
    (define/public (on-create-window window)
      (void))
    
    ;; Called after a window has been created
    (define/public (on-create-notify window)
      (void))
    
    ;; Called after a window has been requested for configuration.
    ;; It is up to the policy to choose whether this request should be honored.
    (define/public (on-configure-request window value-mask
                                         x y width height border-width above stack-mode)
      (void))
    
    ;; Called after the true root window has been configured,
    ;; for example after a resolution change, a newly plugged screen, etc.
    (define/public (on-configure-notify-true-root)
      (void))
    
    ;; Called from click-to-activate and other places
    (define/public (activate-window window)
      (void))
    
    ;; Gives the keyboard focus to the next window in the list of windows
    (define/public (activate-next-window)
      (void))

    ;; Gives the keyboard focus to the previous window in the list of windows
    (define/public (activate-previous-window)
      (void))

    ;; Called after a window has been added to the workspace wk
    (define/public (on-add-window-to-workspace window wk)
      (void))
    
    ;; Called after a window has been removed from the workspace wk
    (define/public (on-remove-window-from-workspace window wk)
      (void))
    
    ;; Called after workspaces have been initialized
    (define/public (on-init-workspaces)
      (void))
    
    ;; Called after a workspace has been activated
    (define/public (on-activate-workspace wk)
      (void))
    
    ;; Called after the workspace mode (single, multi) has been changed
    (define/public (on-change-workspace-mode mode)
      (void))
    
    (super-new)))

; Use a fun box instead of a parameter so that 
; it is really a single global variable,
; that can be change for example via the client.
; (The client runs from a different thread, 
; and parameters are thread-dependent.)
(define* current-policy (make-fun-box (new policy%)))

