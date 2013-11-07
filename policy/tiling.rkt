#lang racket/base

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

;;; To try a layout, use the ../test/test-layout.rkt

(define* policy-tiling%
  (class policy%
    
    (init-field [layout 'matrix])
    
    (define/public (set-layout new-layout)
      (set! layout new-layout)
      (relayout))

    (define/override (on-map-request window new?)
      ; give the window the input focus (if viewable)
      (activate-window window)
      (relayout))
    
    (define/override (on-unmap-notify window)
      ; todo: give focus to first window?
      (relayout))
    
    (define/override (on-destroy-notify window)
      ; todo: give focus to first window?
      (relayout))
    
    (define/override (on-create-window window)
      (let ([wk (guess-window-workspace window)])
        (if wk
            (add-window-to-workspace window wk)
            (dprintf "Warning: Could not guess workspace for window ~a\n" window))))
    
    (define/override (activate-window window)
      (set-input-focus/raise window))
    
    (define/public (relayout)
      (define wk (focus-workspace))
      (define wl (workspace-windows wk))
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
                     wl2)]
              )))
    
    (super-new)))
