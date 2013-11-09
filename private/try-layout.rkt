#lang slideshow

(define root-window #f)
(define (set-root-window rw)
  (set! root-window rw))

(define (at x y p)
  (ht-append
    (blank x 0)
    (vl-append
     (blank 0 y)
     p)))

(define (move-resize-window win x2 y2 w2 h2)
  (set! root-window
        (lt-superimpose
         root-window
         (at x2 y2
             (colorize
              (cc-superimpose (rectangle w2 h2) (text (~a win)))
              (shuffle (list (random 128) (+ 128 (random 128)) (+ 64 (random 128)))))))))

(define (uniform-layout wl x y w h)
  (let loop ([x x] [y y] [w w] [h h] [wl wl])
    (cond [(empty? wl) (void)]
          [(empty? (rest wl))
           (move-resize-window (first wl) x y w h)]
          [else
           (define n (floor (/ (length wl) 2)))
           (define-values (wl1 wl2) (split-at wl n))
           ;  we can also put a stronger ratio if we want to have more room for the highest windows
           (define ratio (/ n (length wl)))
           (define-values (dx dy) 
             (if (> w h)
                 (values (* w ratio) #f)
                 (values #f (* h ratio))))
           (loop x y (or dx w) (or dy h) wl1)
           (loop (+ x (or dx 0)) (+ y (or dy 0))
                 (if dx (- w dx) w) (if dy (- h dy) h)
                 wl2)]
          )))

; http://dwm.suckless.org/patches/fibonacci
(define (dwindle-layout wl x y w h #:ratio [ratio 1/2])
  (let loop ([x x] [y y] [w w] [h h] [wl wl])
    (cond [(empty? wl) (void)]
          [(empty? (rest wl))
           (move-resize-window (first wl) x y w h)]
          [else
           (define-values (dx dy) 
             (if (> w h)
                 (values (* w ratio) #f)
                 (values #f (* h ratio))))
           (move-resize-window (first wl) x y (or dx w) (or dy h))
           (loop (+ x (or dx 0)) (+ y (or dy 0))
                 (if dx (- w dx) w) (if dy (- h dy) h)
                 (rest wl))]
          )))

(module+ main
  (define-values (x y w h) (values 10 20 620 410))
  (define wl (range 10))
  
  (set-root-window (blank w h))
  (uniform-layout wl x y w h)
  root-window
  
  (set-root-window (blank w h))
  (dwindle-layout (range 10) x y w h #:ratio 1/2)
  root-window

  (set-root-window (blank w h))
  (dwindle-layout (range 10) x y w h #:ratio 1/3)
  root-window
  
  )
