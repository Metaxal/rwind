#lang racket/base

(require rwind/base
         rwind/doc-string
         rwind/window
         rwind/display
         rwind/gui/base
         rwind/gui/gtk
         racket/gui
         racket/runtime-path
         )

(define bitmap-dict (make-weak-hash))

; Should probably use define-runtime-path?
(define-runtime-path themes-path (build-path 'up "themes"))
(define (theme-file theme file)
  (build-path themes-path theme file))

(define* (get-theme-bitmap theme file)
  "Returns the path for the file of the given theme."
  (define file-path (theme-file theme file))
  (hash-ref! bitmap-dict file-path
             (λ()(read-bitmap file-path))))

(define* current-theme (make-fun-box "Simple")) ; parameter instead?

(define framed-windows-dict 
  #;"Dictionary of the window => frame% associations.
The window is the x11 window of the application, not the x11 window of the frame%.
To get the x11 window of the frame%, use (send a-frame x11-window) for the 'outside' window
or (send a-frame x11-client-window) for the 'inside' window (in the sense of `get-client-handle')."
  (make-weak-hash))

(define (add-framed-window window frame)
  #;"Adds a window => frame% association. 
Also adds the frame's client window => frame% association."
  (hash-set! framed-windows-dict window frame)
  (hash-set! framed-windows-dict (send frame get-frame-window) frame))

(define (remove-framed-window window frame-window)
  (hash-remove! framed-windows-dict window)
  (hash-remove! framed-windows-dict frame-window)
  )

;===============;
;=== Exports ===;
;===============;

(define* (find-window-frame window)
  "Returns the frame% that contains the specified application window, 
or #f if window is not framed.
Window can be either the window of the application, or the 'outside' window of the frame%."
  (hash-ref framed-windows-dict window #f))

(define* (framed-windows)
  "Returns the list of the windows that have a frame%."
  (map (λ(f)(send f get-window)) (framed-windows-frames)))

(define* (framed-windows-frames)
  (remove-duplicates (hash-values framed-windows-dict)))


(define* (enframe-window window)
  "Creates a frame% for the window, and return it, or #f if the window is already framed."
  (and
   (not (find-window-frame window))
   (new client-frame% [window window])))

(define* (unframe-window window)
  "Removes the frame for the specified window."
  (define client-frame (find-window-frame window))
  (and client-frame
       (send client-frame unframe)))

;==========================;
;=== Client frame class ===;
;==========================;

(define client-frame%
  (class frame%
    (init [(win window)])
    
    (define window #f)
    (define vert-margin 3)
    (define horiz-margin 3)
    (define title-height #f)
    (define title-width #f)
    
    (define (init window)
      (define-values (x y) (window-position window))
      (define-values (w h) (window-dimensions window))
      (define name (window-name window))
      (define close-bmp (get-theme-bitmap (current-theme) "close.png"))
      (super-new [label name] 
                 [x x] [y y]
                 [width w] [height h]
                 [alignment '(center top)])
      (define vp (new vertical-panel% [parent this]
                      [stretchable-width #t]
                      [stretchable-height #f]
                      [alignment '(center top)]))
      (define hp (new horizontal-panel% [parent vp]
                      [stretchable-width #t]))
            
      ;; Title
      (define bt-close (new button% [parent hp]
                            [label close-bmp]
                            [vert-margin 0] [horiz-margin 0]
                            [callback (thunk* (send this on-exit))]))
      (new pane% [parent hp])
      (define title-msg (new message% [parent hp] [label name]
                             [auto-resize #t]
                             [vert-margin 0] [horiz-margin 0]))
      (new pane% [parent hp])
      (define bt-max (new button% [parent hp]
                          [label (get-theme-bitmap (current-theme) "maximize.png")]
                          [vert-margin 0] [horiz-margin 0]
                          [callback (thunk* (displayln "Maximize?"))]))
      (set! title-width (send hp get-width))
      (set! title-height (send bt-close get-height))
      (send this resize (+ horiz-margin w horiz-margin) (+ title-height vert-margin h vert-margin))
      (send this show #t)
      
      ; Register the window and the frame-window
      (add-framed-window window this)
      
      ; TODO:
      ; Here, we should need to make sure that the frame is shown.
      ; But since it is processed in a different thread, we should need to wait.
      ; Use events and sync between threads?
      (sleep 1)
      
      (define f-window (widget-x11-window this #t))
      ;(define vp-client-window (widget-x11-window p-client)) ; needs a panel% to have a window
      
      (grab-server) ; to avoid drawing to the screen
      ; or reparent it to the panel below?
      (move-window window horiz-margin (+ title-height vert-margin))
      (reparent-window window f-window)
      (ungrab-server)
      )
    
    (init win)
    ; set the window only at the end, so that it is not troubled 
    ; by the size changes above.
    (set! window win)
    
    (define/public (get-window) window)
    
    (define/public (get-frame-window)
      #;"Returns the frame's x11 'outside' window."
      (widget-x11-window this #f))
    
    (define/public (get-frame-inside-window)
      #;"Returns the frame's x11 'inside' window."
      (widget-x11-window this #t))
    
    (define/override (on-focus)
      ; doesn't work
      (set-input-focus window))
    
    (define/override (on-size w h)
      (when window
        (define ww (- w horiz-margin horiz-margin))
        (define wh (- h title-height vert-margin vert-margin))
        (resize-window window ww wh)))
    
    (define/public (unframe)
      (reparent-window window (current-root-window))
      (remove-framed-window window (send this window-frame))
      ; We should also destroy the window. How do we do this nicely?
      (send this on-exit))
    
    ))

