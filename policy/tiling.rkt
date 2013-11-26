#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/policy/simple
         rwind/doc-string
         rwind/window
         rwind/workspace
         racket/list
         racket/dict
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
    
    (inherit current-window current-workspace activate-window)
    
    (define/public (get-layouts)
      (dict-keys layouts))
    
    (define/public (set-layout new-layout)
      (define proc (dict-ref layouts new-layout #f))
      (cond [proc
             (set! layout new-layout)
             (relayout)]
            [else
             (printf "Warning: Unknown layout: ~a.\n" layout)
             (define l (get-layouts))
             (printf "Existing layouts: ~a\n" l)
             (define fallback (first l))
             (printf "Falling back to ~a layout.\n" fallback)
             (set-layout fallback)]))
    
    (define/public (give-focus [wk (current-workspace)])
      (when wk
        (workspace-give-focus wk)))
    
    ;; Needs to be redefined over policy-simple% to keep the 
    ;; order consistent with the layout (which is based on the workspace list)
    (define/override (activate-next-window)
      (define wf (focus-window))
      (when wf
        (define wk (find-window-workspace wf))
        (when wk
          (define wins (filter window-viewable? (workspace-windows wk)))
          (define rst (member wf wins window=?))
          (when rst
            (if (<= (length rst) 1)
                (activate-window (first wins))
                (activate-window (second rst)))))))
    
    (define/override (activate-previous-window)
      (define wf (focus-window))
      (when wf
        (define wk (find-window-workspace wf))
        (when wk
          (define wins (reverse (filter window-viewable? (workspace-windows wk))))
          (define rst (member wf wins window=?))
          (when rst
            (if (<= (length rst) 1)
                (activate-window (first wins))
                (activate-window (second rst)))))))    

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
    
    ;; `dir' is either 'up or 'down
    (define/public (move-window dir [w (current-window)])
      (when w
        (define wk (find-window-workspace w))
        (when wk
          (workspace-move-window wk w dir)
          (relayout))))
    #|
    (define/public (circulate-windows-up [wk (current-workspace)])
      (when wk
        (workspace-circulate-windows-up wk))
      (relayout))
    
    (define/public (circulate-windows-down [wk (current-workspace)])
      (when wk
        (workspace-circulate-windows-down wk))
      (relayout))|#
    
    ;; This can be overriden, e.g. see ../private/try-layout.rkt
    (define/public (place-window window x y w h)
      (move-resize-window window x y w h))
        
    (define/override (relayout [wk (current-workspace)])
      ; Keep only mapped windows
      (define wl (filter window-viewable? (workspace-windows wk)))
      (define-values (x y w h) (workspace-bounds wk))
      (do-layout wl 0 0 w h)) ; relative to workspace root window
    
    (define/public (do-layout wl x y w h)
      (define proc (dict-ref layouts layout))
      (proc wl x y w h))
    
    (define (uniform-layout)
      (define (loop wl x y w h)
        (cond [(empty? wl) (void)]
              [(empty? (rest wl))
               (place-window (first wl) x y w h)]
              [else
               (define n (floor (/ (length wl) 2)))
               (define-values (wl1 wl2) (split-at wl n))
               (define ratio (/ n (length wl)))
               (define-values (dx dy) 
                 (if (> w h)
                     (values (floor (* w ratio)) #f)
                     (values #f (floor (* h ratio)))))
               (loop wl1 x y (or dx w) (or dy h))
               (loop wl2
                     (+ x (or dx 0)) (+ y (or dy 0))
                     (if dx (- w dx) w) (if dy (- h dy) h))]))
      loop)
    
    ; http://dwm.suckless.org/patches/fibonacci
    (define (dwindle-layout ratio)
      (define (loop wl x y w h)
        (cond [(empty? wl) (void)]
              [(empty? (rest wl))
               (place-window (first wl) x y w h)]
              [else
               (define-values (dx dy) 
                 (if (> w h)
                     (values (floor (* w ratio)) #f)
                     (values #f (floor (* h ratio)))))
               (place-window (first wl) x y (or dx w) (or dy h))
               (loop (rest wl)
                     (+ x (or dx 0)) (+ y (or dy 0))
                     (if dx (- w dx) w) (if dy (- h dy) h))]))
      loop)
    
    (define/override (on-init-workspaces)
      (super on-init-workspaces)
      (for ([wk workspaces])
        (relayout wk)))
    
    #;(define/override (on-configure-request window value-mask
                                           x y width height border-width above stack-mode)
      ; Do not honor configure requests
      (void))
    
    #;(define/override (on-activate-workspace wk)
      (void))
    
    #;(define/override (on-change-workspace-mode mode)
      (void))

    (super-new)

    ; Must be defined after the procedures.
    ; The first layout is the fallback one.
    (define layouts
      `((uniform    . ,(uniform-layout))
        (dwindle    . ,(dwindle-layout 1/2))
        (dwindle2/5 . ,(dwindle-layout 2/5))
        ))
    
    (init-field [layout 'uniform])
    
    ))
