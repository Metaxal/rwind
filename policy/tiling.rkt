#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/util
         rwind/policy/base
         rwind/doc-string
         rwind/window
         rwind/workspace
         racket/list
         racket/class
         )

(provide policy-tiling%)

;;; Tiling policy
;;; See other tiling policies from xmonad:
;;; http://xmonad.org/xmonad-docs/xmonad-contrib/

;;; To try a layout, use the ../private/test-layout.rkt

(define* policy-tiling%
  (class policy%
    
    (init-field [layout 'matrix])
    
    (define/public (set-layout new-layout)
      (set! layout new-layout)
      (relayout))
    
    ;; Gives the focus back to a window of the current workspace.
    ;; It's safer to use the pointer to identify the workspace than
    ;; the input-focus (because the focus might not be owned by any 
    ;; top-level window).
    (define/public (give-focus [wk (pointer-workspace)])
      (when wk
        (workspace-give-focus wk)))

    (define/override (on-map-request window new?)
      ; give the window the input focus (if viewable)
      (relayout)
      (activate-window window))
    
    (define/override (on-unmap-notify window)
      (relayout))
    
    (define/override (on-destroy-notify window)
      (relayout))
    
    (define/override (on-configure-notify-true-root)
      (relayout))
    
    (define/override (on-create-window window)
      (let ([wk (guess-window-workspace window)])
        (if wk
            (add-window-to-workspace window wk)
            (dprintf "Warning: Could not guess workspace for window ~a\n" window))))
    
    (define/override (activate-window window)
      ; remember the window that has the focus
      ; so that switching between workspaces will restore the correct focus
      (workspace-focus-in window)
      (set-input-focus/raise window))
    
    ;; Gives the keyboard focus to the next window in the list of windows.
    (define/override (activate-next-window)
      ; TODO: cycle only among windows that want focus
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
    
    (define/public (relayout [wk (focus-workspace)])
      ; Keep only mapped windows
      (define wl (filter window-viewable? (workspace-windows wk)))
      (define-values (x y w h) (workspace-bounds wk))
      (case layout
        [(matrix) (relayout-matrix wl x y w h)]))
    
    (define/public (relayout-matrix wl x y w h)
      (let loop ([x x] [y y] [w w] [h h] [wl wl])
        (cond [(empty? wl) (void)]
              [(empty? (rest wl))
               (move-resize-window (first wl) x y w h)]
              [else
               (define n (floor (/ (length wl) 2)))
               (define-values (wl1 wl2) (split-at wl n))
               ;  we could put a stronger ratio if we want to have more room for the highest windows
               (define ratio (/ n (length wl)))
               (define-values (dx dy) 
                 (if (> w h)
                     (values (floor (* w ratio)) #f)
                     (values #f (floor (* h ratio)))))
               (loop x y (or dx w) (or dy h) wl1)
               (loop (+ x (or dx 0)) (+ y (or dy 0))
                     (if dx (- w dx) w) (if dy (- h dy) h)
                     wl2)])))
    
    (define/override (on-init-workspaces)
      (for ([wk workspaces])
        (relayout wk)))
    
    #;(define/override (on-activate-workspace wk)
      (void))
    
    #;(define/override (on-change-workspace-mode mode)
      (void))

    (super-new)))
