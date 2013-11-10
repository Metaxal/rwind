#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/policy/base
         rwind/doc-string
         rwind/window
         rwind/workspace
         racket/class
         racket/list
         )

;;; Simple policy
;;; This class defines a simple stacking policy for managing windows.

(define* policy-simple%
  (class policy%
    
    (define/public (current-workspace)
      (or (focus-workspace)
          (pointer-workspace)))
    
    (define/public (current-window)
      (or (focus-window)
          (pointer-window)))    

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
    ;; In (viewable-windows), the highest window is the last one (see XQueryTree).
    ;; xmonad uses a zipper for that (but requires to keep a window list in sync 
    ;; with the actual windows of the workspace)
    (define/override (activate-next-window)
      (define wf (focus-window))
      (when wf
        (lower-window (focus-window)))
      (define wl (viewable-windows))
      (unless (empty? wl)
        (activate-window (last wl))))
    
    (define/override (activate-previous-window)
      (define wl (viewable-windows))
      (unless (empty? wl)
        (activate-window (first wl))))
    
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
