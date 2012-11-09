#!/usr/bin/racket
#lang racket/base

#| TODO: 
- (select-window)
  plus look at all the window utilities in Sawfish (lisp/sawfish/wm/windows.jl)
- shutdown more gracefully?
- contracts? types?
- time-stamps are probably not handled properly

- workspaces (desktops) + viewports?
- monitors
|#

;;; Author: Laurent Orseau
;;; License: LGPL, except for the client.rkt which is in GPL (because of readline)

#| Helpful resources:
- tinywm: http://incise.org/tinywm.html
- evilwm: http://www.6809.org.uk/evilwm/
- simplewm: http://sqizit.bartletts.id.au/2011/03/28/how-to-write-a-window-manager-in-python/
- sawfish: http://sawfish.wikia.com/wiki/Main_Page
- xlambda: https://github.com/kazzmir/x11-racket/blob/master/xlambda/xlambda.rkt
- http://tronche.com/gui/x/xlib
- for window managers:
  http://tronche.com/gui/x/xlib/window-and-session-manager/
  http://tronche.com/gui/x/xlib/ICC/client-to-window-manager/
- http://menehune.opt.wfu.edu/Kokua/Irix_6.5.21_doc_cd/usr/share/Insight/library/SGI_bookshelves/SGI_Developer/books/XLib_PG/sgi_html/
- ICCCM: http://tronche.com/gui/x/icccm/
- non-ICCCM features: http://standards.freedesktop.org/wm-spec/1.4/ar01s02.html
- Extended Window Manager Hints: http://standards.freedesktop.org/wm-spec/latest/
|#

#|
- compilation and launch:
X11_RACKET_DEBUG=1 raco setup x11-racket rwind && xinit .xinit-rwind -- :1 &

- In rwind's directory: raco link rwind
to be able to use (require rwind/keymap) for example
(optional: raco setup rwind)

- After trying hard to use threads (and failing) with Xlib, it seems anyway that it's better to not use them at all.
  It's of no use of the user's script, and the client may be better off in a separate application.
  Sawfish does not seem to use XInitThreads() either.
|#

(require ;"base.rkt" "window-util.rkt" "keymap.rkt" "util.rkt"
         ;; WARNING! Requiring the files via a raco link or via relative file does not require it in the same "namespace" (or something)!!
         ;; Further requirement for the bug to appear: it must started with xinit
         ;; see https://groups.google.com/forum/?fromgroups=#!topic/racket-users/jEXWq_24cOU
         rwind/base rwind/window rwind/keymap rwind/util rwind/events rwind/server 
         x11-racket/x11 ; needs raco link x11-racket
         ; WARNING: the x11.rkt lib still needs some work. Every function that one uses should be checked with the official documentation.
         racket/date
         racket/function
         racket/pretty
         )

(rwind-debug #t)
(debug-prefix "RW: ")

(define restart? #f)

(with-output-to-file (build-path (find-system-path 'home-dir) "rwind.log")
  #:exists 'replace
  (λ()
    (parameterize ([current-error-port (current-output-port)]
                   ;; Set the current directory to the user's dir
                   [current-directory (find-user-config-dir rwind-dir-name)])
      
      (dprintf "\n *** New session on ~a on display ~a ***\n" 
               (date->string (current-date) #t)
               (getenv "DISPLAY"))
      
      ;; Initialize thread support
      ;; This must be the first X procedure to call
      (XInitThreads)
      
      (current-display (XOpenDisplay #f))
      (unless (current-display)
        (error "Cannot open display.")
        (exit))
      
      (XLockDisplay (current-display))
      
      (current-root-window (XDefaultRootWindow (current-display)))
      
      (when (rwind-debug)
        ;:::::::::::;
        ;:: Debug ::;
        ;:::::::::::;
        
        (set-Xdebug! #t) ; for POSIX compliant systems
        
        (x11-debug-prefix "  X: ")
        
        ; For debugging purposes only, because very slow!
        (XSynchronize (current-display) #t)
        
        ; TODO: set _XDebug to #t !
        #;(XSetAfterFunction (current-display)
                           (λ(display) ; -> int
                             ; This function is called after each X function
                             ))
        ; Errors and error-handlers:
        ; http://tronche.com/gui/x/xlib/event-handling/protocol-errors/default-handlers.html
        (XSetErrorHandler 
         (λ(display err-ev)
           ;(printf "Error received: ~a\n" (XErrorEvent->list* err-ev))
           (printf "*** Error: ~a\n" (XGetErrorText 
                                      (XErrorEvent-display err-ev)
                                      (XErrorEvent-error-code err-ev)
                                      200)) ; Sufficient bytes?
           1)) ; must return an _int
        ) ; debug
      
      ;; Find which ModMask are the *-Lock modifiers
      (find-lock-modifiers)
      
      (intern-atoms)
      
      ;; Ask the root window to send us any event
      (define attrs (make-XSetWindowAttributes #:event-mask '(SubstructureRedirectMask)))
      (XChangeWindowAttributes (current-display) (current-root-window) '(EventMask) attrs)
      
      ;(XSync (current-display) #f)
      ;(XFlush (current-display))
      
      ;; Start the server
      (define server-thread
        (parameterize ([debug-prefix "Srv: "])
          (thread start-rwind-server)))
      
      ;; Read user configuration file
      ;; There must be a 'raco link' to the rwind directory (no need to raco setup for now),
      ;; so that it can be easily used with (require rwind/keymap) for example.
      ;; (a language might even be better, to redefine define (or just give a new 'define/doc'?)
      ;; It would be useless to thread it, as one would still need to call XLockDisplay
      (let ([user-f (rwind-user-config-file)])
        (with-handlers ([exn:fail? (λ(e)(printf "Error while loading user config file ~a:\n~a\n"
                                                user-f
                                                (exn-message e)))])
          (when (file-exists? user-f)
            (dynamic-require user-f #f))))
      
      ;; TODO: Make a "root" keymap, that remains on top of the global one, 
      ;; and that cannot be modified by the user?
      (bind-key global-keymap "Escape" '(Mod1Mask) 
                (thunk*
                 (dprintf "Now exiting.\n")
                 (exit-rwind? #t)))
      #;(bind-key global-keymap "Escape" '(ControlMask Mod1Mask) 
                (thunk*
                 (printf "Restarting...\n")
                 (set! exit? #t)
                 (set! restart? #t)))

      (dprintf "global keymap:\n")
      (pretty-print global-keymap)
      (dprintf "window keymap:\n")
      (pretty-print window-keymap)
      
      (window-apply-keymap (current-root-window) global-keymap)
      
      
      ;==================;
      ;=== Event loop ===;
      ;==================;
      (run-event-loop)
            
      
      (dprintf "Terminating... ")
      ;(XUnlockDisplay (current-display)) ; don't unlock?
      ; Call a break so that dynamic-wind can close the ports and the listener
      (break-thread server-thread)
      ; Not sure I should call that if the user wants to replace the current wm by some other
      ; without logging out.
      ;(XDestroySubwindows (current-display) (current-root-window)) ; useful?
      (XCloseDisplay (current-display))
      ))) ; log to file


; Broken
#;(when restart?
  (dprintf "Restarting... ")
  ; Run another process without killing this one, 
  ; otherwise the Xserver may terminate
  (define l (cons  (path->string (find-system-path 'run-file))
                   (vector->list (current-command-line-arguments))))
  (dprintf "Command-line:~a\n" l)
  (apply system* l))

(dprintf "Finished.\n")