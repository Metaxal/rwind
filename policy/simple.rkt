#lang racket/base

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
    
    (define/override (on-create-window window)
      (let ([wk (guess-window-workspace window)])
        (if wk
            (add-window-to-workspace window wk)
            (dprintf "Warning: Could not guess workspace for window ~a\n" window))))
    
    (define/override (activate-window window)
      (set-input-focus/raise window))
    
    (super-new)))

; To be sure to have at least one working policy
(current-policy (new policy-simple%))

