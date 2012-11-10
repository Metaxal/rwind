#lang racket/base

(require rwind/util
         rwind/base
         rwind/doc-string
         rwind/keymap
         rwind/window
         x11-racket/x11
         x11-racket/fd
         racket/match
         )

(define* (handle-event event)
  "Main function to handle events received from the X server."
  
  (define event-type (XAnyEvent-type event))
  (dprintf "Event type: ~a\n" event-type)
  
  (case event-type
    
    [(KeyPress)
     (match-define 
       (XKeyEvent type serial send-event display window root subwindow time 
                  x y x-root y-root modifiers key-code same-screen)
       event)
     (define key-string (XKeysymToString (XKeycodeToKeysym (current-display) key-code 0)))
     (dprintf "KeyPress: key-code: ~a (~a) modifiers: ~a\n" key-code key-string modifiers)
     
     ; Give the subwindow as argument if the root window is selected.
     ; This is useful for the global-keymap.
     (define keyboard-ev (keyboard-event (least-root-window window subwindow) key-code 'KeyPress modifiers))
     (call-keymaps-binding keyboard-ev)]
    
    #;[(KeyRelease)
       useful?]
    
    [(ButtonPress ButtonRelease)
     (match-define 
       (XButtonEvent type serial send-event display window root subwindow
                     time x y x-root y-root modifiers button same-screen)
       event)
     (dprintf "~a x: ~a y: ~a x-root: ~a y-root: ~a button: ~a modifiers: ~a window: ~a subwindow: ~a\n"
              event-type
              x y x-root y-root button modifiers
              (window-name window) (window-name subwindow))
     (define mouse-ev (mouse-event (least-root-window window subwindow) button event-type modifiers x-root y-root))
     (call-keymaps-binding mouse-ev)]
    
    [(MotionNotify)
     ; Consume all pending 'MotionNotify events
     (for/and () (XCheckTypedEvent (current-display) 'MotionNotify event))
     (match-define 
       (XMotionEvent type serial send-event display window root subwindow time x y x-root y-root modifiers is-hint same-screen)
       event)
     (define button (find-modifiers-button modifiers)) ; for 'Move events
     (dprintf "Move x: ~a y: ~a x-root: ~a y-root: ~a button: ~a modifiers: ~a window: ~a subwindow: ~a\n"
              x y x-root y-root button modifiers
              (window-name window) (window-name subwindow))
     (define mouse-ev (mouse-event (least-root-window window subwindow) button 'ButtonMove modifiers x-root y-root))
     (call-keymaps-binding mouse-ev)]
    
    [(ConfigureRequest)
     (configure-window event)]
    
    [(MapRequest)
     (define window (XMapRequestEvent-window event))
     (XMapRaised (current-display) window)
     (window-apply-keymap window window-keymap)
     (set-input-focus window)
     ;(add-mapped-window window)
     ]
    
    [(MappingNotify)
     ; see the warning about override-redirect in Tronche's doc
     (XRefreshKeyboardMapping event)]
    
    #;[(UnmapNotify)
     (define window (XUnmapEvent-window event))
     ;(remove-mapped-window window)
     ]
    
    [else
     (dprintf "Unhandled event ~a\n" (XEvent->list* event))
     ]) ; case
  )

(provide run-event-loop)
#;(define (run-event-loop)
  ; Jon Rafkind's version
  (define events (make-channel))
  (start-x11-event-thread (current-display) events)
  
  (XFlush (current-display))
  (let server-loop ()
    
    ;(XSync (current-display) #f)
    ;(XFlush (current-display)) ; normally XNextEvent flushes itself
    (flush-output) ; to write to file
    
    ;(define event (XNextEvent* (current-display))) ; waits for the next event
    (sync/enable-break
     (handle-evt events 
                 (lambda (event)
                   (dynamic-wind
                    (λ()(XLockDisplay (current-display)))
                    (λ()(handle-event event))
                    (λ()(XUnlockDisplay (current-display))))
                   (unless (exit-rwind?) 
                     (server-loop))))))
  )

(define (run-event-loop)
  (XFlush (current-display))
  ; Kevin Tew's version
  (define x11-port (open-fd-input-port (XConnectionNumber (current-display)) #;'x11-connection))
  (let loop ()
    (sync/enable-break
     (handle-evt x11-port 
                 (lambda (e)
                   (let loop2 ()
                     ; don't we miss handling event e?
                     (unless (zero? (XPending (current-display)))
                       (handle-event (XNextEvent* (current-display)))
                       (loop2)))
                   ))
     ; This could be used by the server instead of creating a thread?
     #;(handle-evt (current-input-port)
                   (lambda (e)
                     (printf "INPUT ~a ~a\n" e (read-line e)))))
    (unless (exit-rwind?)
      (loop))))
