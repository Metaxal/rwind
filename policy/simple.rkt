#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require ;rwind/base
         ;rwind/util
         rwind/policy/base
         rwind/doc-string
         rwind/window
         rwind/workspace
         racket/class
         racket/list
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
      ; Gives the focus to window.
      ; Remembers the window that has the focus
      ; so that switching between workspaces will restore the correct focus.
      ; Removes the old focus window border and adds a border around the new focus.
      (when window
        (define old-focus (focus-window))
        (unless (window=? old-focus window)
          (when old-focus
            (set-window-border-width old-focus 0))
          (set-window-border-width window 3)
          (set-input-focus/raise window)
          (workspace-focus-in window))))
    
    ;; Gives the keyboard focus to the next window in the list of windows.
    (define/override (activate-next-window)
      (define wl (viewable-windows))
      (unless (empty? wl)
        (let* ([wl (cons (last wl) wl)]
               [w (focus-window)]
               ; if no window has the focus (maybe the root has it)
               [m (member w wl)])
          (activate-window
           (if m
               ; the `second' should not be a problem because of the last that ensures
               ; that the list has at least 2 elements if w is found
               (second m)
               ; not found, give the focus to the first window
               (first wl))))))
    
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
