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
    
    (define/public (current-workspace)
      (or (focus-workspace)
          (pointer-workspace)))
    
    (define/public (give-focus [wk (current-workspace)])
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
    
    ;; TODO: Should circulate only between mapped windows!
    ;; Plus maybe we should move only the focus window and leave the rest untouched?
    (define/public (circulate-windows-up [wk (current-workspace)])
      (when wk
        (workspace-circulate-windows-up wk))
      (relayout))
    
    (define/public (circulate-windows-down [wk (current-workspace)])
      (when wk
        (workspace-circulate-windows-down wk))
      (relayout))
    
    ;; This can be overriden, e.g. see ../private/try-layout.rkt
    (define/public (place-window window x y w h)
      (move-resize-window window x y w h))
        
    (define/public (relayout [wk (current-workspace)])
      ; Keep only mapped windows
      (define wl (filter window-viewable? (workspace-windows wk)))
      (define-values (x y w h) (workspace-bounds wk))
      (do-layout wl x y w h))
    
    (define/public (do-layout wl x y w h)
      (case layout
        [(uniform) (uniform-layout wl x y w h)]
        [(dwindle) (dwindle-layout wl x y w h)]
        [else (printf "Unknown layout: ~a")]))
    
    (define/public (uniform-layout wl x y w h)
      (let loop ([wl wl] [x x] [y y] [w w] [h h])
        (cond [(empty? wl) (void)]
              [(empty? (rest wl))
               (place-window (first wl) x y w h)]
              [else
               (define n (floor (/ (length wl) 2)))
               (define-values (wl1 wl2) (split-at wl n))
               ;  we could put a stronger ratio if we want to have more room for the highest windows
               (define ratio (/ n (length wl)))
               (define-values (dx dy) 
                 (if (> w h)
                     (values (floor (* w ratio)) #f)
                     (values #f (floor (* h ratio)))))
               (loop wl1 x y (or dx w) (or dy h))
               (loop wl2
                     (+ x (or dx 0)) (+ y (or dy 0))
                     (if dx (- w dx) w) (if dy (- h dy) h))])))
    
    ; http://dwm.suckless.org/patches/fibonacci
    (define (dwindle-layout wl x y w h #:ratio [ratio 1/2])
      (let loop ([wl wl] [x x] [y y] [w w] [h h])
        (cond [(empty? wl) (void)]
              [(empty? (rest wl))
               (place-window (first wl) x y w h)]
              [else
               (define-values (dx dy) 
                 (if (> w h)
                     (values (* w ratio) #f)
                     (values #f (* h ratio))))
               (place-window (first wl) x y (or dx w) (or dy h))
               (loop (rest wl)
                     (+ x (or dx 0)) (+ y (or dy 0))
                     (if dx (- w dx) w) (if dy (- h dy) h))])))
    
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
