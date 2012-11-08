#lang racket/base

(require rwind/util
         rwind/base
         rwind/doc-string
         rwind/keymap
         rwind/window
         x11-racket/x11
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
     (XMapWindow (current-display) window)
     (window-apply-keymap window window-keymap)
     (set-input-focus window)]
    
    [(MappingNotify)
     (XRefreshKeyboardMapping event)]
    
    [else
     (dprintf "Unhandled event ~a\n" (XEvent->list* event))
     ]) ; case
  )