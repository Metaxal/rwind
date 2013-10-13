#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/util
         rwind/base
         rwind/doc-string
         rwind/keymap
         rwind/window
         rwind/workspace
         rwind/policy/base
         x11/x11
         x11/fd
         racket/match
         )

;;; See https://github.com/SawfishWM/sawfish/blob/master/src/events.c

(define (handle-event event)
  #;"Main function to handle events received from the X server."

  (define event-type (XAnyEvent-type event))
  (dprintf "Event type: ~a\n" event-type)

  (case event-type

    [(MappingNotify)
     ; When the keyboard mapping changes.
     (XRefreshKeyboardMapping event)]

    [(KeyPress)
     (match-define
       (XKeyEvent type serial send-event display window root subwindow time
                  x y x-root y-root modifiers key-code same-screen)
       event)
     (define key-string (XKeysymToString (XKeycodeToKeysym (current-display) key-code 0)))
     (dprintf "KeyPress: key-code: ~a (~a) modifiers: ~a\n" key-code key-string modifiers)

     ; Give the subwindow as argument if the root window is selected.
     ; This is useful for the global-keymap.
     (define keyboard-ev (keyboard-event subwindow key-code 'KeyPress modifiers))
     (call-keymaps-binding keyboard-ev)
     (policy. on-keypress keyboard-ev)]

    #;[(KeyRelease)
       useful?]

    [(ButtonPress ButtonRelease)
     (match-define
       (XButtonEvent type serial send-event display window root subwindow
                     time x y x-root y-root modifiers button same-screen)
       event)
     (dprintf "~a x: ~a y: ~a x-root: ~a y-root: ~a button: ~a modifiers: ~a window: ~a (~a) subwindow: ~a (~a)\n"
              event-type
              x y x-root y-root button modifiers
              (window-name window) window (window-name subwindow) subwindow)
     (define mouse-ev (mouse-event (or subwindow window) button event-type modifiers x-root y-root))
     (call-keymaps-binding mouse-ev)
     (policy. on-mouse-button mouse-ev)]

    [(MotionNotify)
     ; When the mouse pointer moves.
     ; Consume all pending 'MotionNotify events, and keep the last one
     (while (XCheckTypedEvent (current-display) 'MotionNotify event))
     (match-define
       (XMotionEvent type serial send-event display window root subwindow time
                     x y x-root y-root modifiers is-hint same-screen)
       event)
     (define button (find-modifiers-button modifiers)) ; for 'Move events
     (dprintf "Move x: ~a y: ~a x-root: ~a y-root: ~a button: ~a modifiers: ~a window: ~a subwindow: ~a\n"
              x y x-root y-root button modifiers
              (window-name window) (window-name subwindow))
     (define mouse-ev (mouse-event subwindow button 'ButtonMove modifiers x-root y-root))
     (call-keymaps-binding mouse-ev)
     (policy. on-motion-notify mouse-ev)]

    [(ConfigureRequest)
     ; When a window asks for changing its configuration (geometry)
     ; https://github.com/SawfishWM/sawfish/blob/master/src/events.c#L1109
     ; https://github.com/SawfishWM/sawfish/search?q=XConfigureWindow&ref=cmdform
     (match-define
       (XConfigureRequestEvent type serial send-event _display parent window
                               x y width height border-width above stack-mode value-mask)
       event)
     ; This should probably depend on the window type,
     ; e.g., splash windows should be centered
     ; fullscreen windows, etc.
     ; See the EWMH.
     ; This behavior specification belongs to the policy.
     (XConfigureWindow (current-display) window value-mask
                       (make-XWindowChanges x y (bound-value width 1 10000) (bound-value height 1 10000)
                                            border-width above stack-mode))
     #;(policy. on-configure-request ...)]

    [(ConfigureNotify)
     ; When the configuration of a window changes.
     (match-define
       (XConfigureEvent type serial send-event _display event-window window
                               x y width height border-width above override-redirect)
       event)
     (unless override-redirect
       ;; TODO: Seems to be called twice. -> Call only if there are changes?
       (cond [(true-root-window? window)
              (dprintf "Configuring root window\n")
              (dprintf "Updating workspaces\n")
              (xinerama-update-infos)
              (update-workspaces)
              #;(policy. on-configure-notify-true-root)]))]

    #;[(Expose)
       ; When the X server asks for the window to be (partly) redrawn
       ; (because it was previously somehow hidden, possibly partially only)
     (define window (XExposeEvent-window event))
     ; give the input focus to the window that appears?
     (policy. on-expose window)]

    [(MapRequest)
     ; When a window asks to be mapped on the screen.
     (define window (XMapRequestEvent-window event))
     ; if override-redirect is true it is a top-level window
     (cond [(find-root-window-workspace window)
            ; This is a virtual root window, find the corresponding workspace
            => (λ(wk)
                 (dprintf "Mapping workspace root ~a\n" wk)
                 (show-window window)
                 #f)]
           [(find-window-workspace window)
            ; This is an already managed window, just raise it normally.
            => (λ(wk)
                 (dprintf "Mapping existing window in ~a\n" wk)
                 (show-window window)
                 (policy. on-map-request window #f)
                 #f)]
           [else
            (dprintf "Mapping new window\n")
            ; This is a new window
            ; Apply the keymap to it
            ;(window-apply-keymap window window-keymap) ; no, only (virtual) root windows have keymaps?
            ; add it to the current workspace
            (add-window-to-workspace window (pointer-workspace))
            (show-window window)
            (policy. on-map-request window #t)
            ])]
    
    #;[(MapNotify)
     ; When a window is mapped on the screen 
     ; A window with override-redirect should be ignored.
     ]

    [(UnmapNotify)
     ; When a window has been unmapped.
     (define window (XUnmapEvent-window event))
     (dprintf "Unmapping ~a\n" window)
     ;(remove-window-from-workspace window)
     (policy. on-unmap-notify window)]
    
    [(DestroyNotify)
     ; When a window has been destroyed.
     (define window (XDestroyWindowEvent-window event))
     (remove-window-from-workspace window)
     (policy. on-destroy-notify window)]

    [(CreateNotify)
     ; When a window has been created with Create(Simple)Window
     (define window (XCreateWindowEvent-window event))
     (define override? (XCreateWindowEvent-override-redirect event))
     (policy. on-create-notify window)
     (dprintf "Create-notify ~a\n" window)
    ]

    #;[(EnterNotify LeaveNotify)
       ; When the pointer enters or leaves a window
       ; for enternotify, compress the event queue with XCheckTypedEvent, as for MotionNotify:
       ; http://incise.org/tinywm.html
       #f]

    #;[(FocusIn FocusOut) 
       ; When the window receives/loses the keyboard focus
       #f]

    #;[(ReparentNotify)
     ; When a window is reparented to another window
       ; TODO: We should monitor this event to remove windows from workspaces?
     ]
    
    #;[(GravityNotify)
     ; When ...
     ]
    
    [(ClientMessage)
     ; When a window communicates with the root window (i.e. with the window manager)
     (dprintf "Client message: window: ~a message-type: ~a format: ~a\n"
              (XClientMessageEvent-window event)
              (atom->string (XClientMessageEvent-message-type event))
              (XClientMessageEvent-format event))
     ]

    [else
     (dprintf "Unhandled event ~a\n" (XEvent->list* event))]))

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
  ; Kevin Tew's version (unfortunately, it does not seem that it can be used
  ; to avoid using other threads, although I think it should)
  (define x11-port (open-fd-input-port (XConnectionNumber (current-display))
                                       #;'x11-connection))
  (let loop ()
    (with-handlers ([exn:fail? (λ(e)(dprintf (exn-message e))
                                 #;(thread (λ()(error-message-box e))))])
      (sync/enable-break
       (handle-evt x11-port
                   (lambda (_in)
                     (until (zero? (XPending (current-display)))
                            (handle-event (XNextEvent* (current-display))))
                     ))
       ; This could be used by the server instead of creating a thread?
       #;(handle-evt (current-input-port)
                     (lambda (e)
                       (printf "INPUT ~a ~a\n" e (read-line e))))))
    (unless (exit-rwind?)
      (loop))))
