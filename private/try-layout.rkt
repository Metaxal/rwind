#lang slideshow
(require "../policy/tiling.rkt")

(define (at x y p)
  (ht-append
    (blank x 0)
    (vl-append
     (blank 0 y)
     p)))

(define try-layout%
  (class policy-tiling%
    (super-new)
    
    (init-field x0 y0 w0 h0 windows)
    
    (inherit do-layout)
    
    (define root-window #f)
    
    (define/public (get-root-window)
      root-window)
    
    (define/public (clear-root-window)
      (set! root-window  (blank w0 h0)))
    
    (define/override (place-window window x y w h)
      (set! root-window
            (lt-superimpose
             root-window
             (at (- x x0) (- y y0)
                 (colorize
                  (cc-superimpose (rectangle w h) (text (~a window)))
                  (shuffle (list (random 128) (+ 128 (random 128)) (+ 64 (random 128)))))))))
    
    (define/override (relayout [wk #f])
      (do-layout windows x0 y0 w0 h0))
    
    (clear-root-window)
    ))

(module+ main
  (define lay1 (new try-layout% [x0 10] [y0 20] [w0 1024/2] [h0 768/2]
                    [windows (range 10)]))

  (send* lay1
    (relayout)
    (get-root-window))
  
  (send* lay1
    (clear-root-window)
    (set-layout 'dwindle)
    (relayout)
    (get-root-window))

  
  )
