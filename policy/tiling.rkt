#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/policy/simple
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

;;; To try a layout, use the ../private/try-layout.rkt

(define* policy-tiling%
  (class policy-simple%
    ; Inherits from simple% to have the same focus behavior
    
    (init-field [layout 'uniform])
    
    (inherit activate-window activate-next-window)
    
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
        
    (define/public (relayout [wk (focus-workspace)])
      ; Keep only mapped windows
      (define wl (filter window-viewable? (workspace-windows wk)))
      (define-values (x y w h) (workspace-bounds wk))
      (case layout
        [(uniform) (relayout-uniform wl x y w h)]))
    
    (define/public (relayout-uniform wl x y w h)
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
        (relayout wk))
      (activate-next-window))
    
    #;(define/override (on-configure-request window value-mask
                                           x y width height border-width above stack-mode)
      ; Do not honor configure requests
      (void))
    
    #;(define/override (on-activate-workspace wk)
      (void))
    
    #;(define/override (on-change-workspace-mode mode)
      (void))

    (super-new)))
