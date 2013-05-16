#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/base
         rwind/doc-string
         x11/x11
         racket/dict
         )

#|
- (in French) http://pficheux.free.fr/articles/lmf/xlib-images/
- List of existing colors:
  $ tail /etc/X11/rgb.txt -n +2 | sed -e 's/^\s*//' -e 's/\s\s*/ /g'| cut -d' ' -f4,5
  (colors are case insensitive)
  - see also color-database<%> in Racket's help, but not all colors may be supported by default 
|#

(define* black-pixel #f)
(define* white-pixel #f)

;; Cache the colors in a dictionary.
;; Maybe it would be a better idea to use Racket's own database... 
;; (but not sure how to deal with that)
(define color-database (make-hash))

(define* (find-named-color color-str [default-color black-pixel])
  (dict-ref! color-database color-str
             (λ()
               (define disp (current-display))
               (define screen (DefaultScreen disp))
               (AllocNamedColor disp screen color-str default-color))))

(define* (init-colors)
  (define disp (current-display))
  (define screen (DefaultScreen disp))

  (set! black-pixel (BlackPixel disp screen))
  (set! white-pixel (WhitePixel disp screen))  
  )
  

;; Not yet conform to XAllocColor...
#;(define* (random-dark-color)
  (define disp (current-display))
  (define screen (DefaultScreen disp))
  (define cmap (DefaultColorMap disp screen))
  (XAllocColor disp cmap
               (shuffle (list (random 64)
                              (+ 64 (random 64))
                              (+ 64 (random 64))))))
