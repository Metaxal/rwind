#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/util
         rwind/policy/base
         rwind/doc-string
         rwind/window
         rwind/workspace
         racket/class
         )

#| Simple policy

This class defines a simple policy for managing windows.

|#


(define* policy-simple%
  (class policy%

    (define/override (on-map-request window new?)
      ; give the window the input focus (if viewable)
      (activate-window window))
        
    (define/override (activate-window window)
      (set-input-focus/raise window))
    
    (define/override (on-configure-request window value-mask
                                           x y width height border-width above stack-mode)
      ; honor configure request
      ; This should probably depend on the window type,
      ; e.g., splash windows should be centered
      ; fullscreen windows, etc.
      ; See the EWMH.
      ; This behavior specification belongs to the policy.
      (configure-window window value-mask x y width height border-width above stack-mode))
    
    (super-new)))
