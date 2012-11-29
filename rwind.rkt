#!/usr/bin/racket
#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL
;;; Note that client.rkt is in GPL, because it uses readline, but rwind does not depend on it.

#| TODO: 
- security of the server: make sure the user at the other end of the tcp connection 
  is the same as the one running the server!
  Use Unix uid's? ask for password?

- (select-window)
  plus look at all the window utilities in Sawfish (lisp/sawfish/wm/windows.jl)
- shutdown more gracefully?
- contracts? types?
- time-stamps are quite probably not handled properly

- viewports?
- monitors / heads

- GUI. Started, but problem, conflict with Racket's gui?

- grab the server here and there to speed up things

- Planet 2 packaging
|#

#| Helpful resources:
- tinywm: http://incise.org/tinywm.html
- evilwm: http://www.6809.org.uk/evilwm/
- simplewm: http://sqizit.bartletts.id.au/2011/03/28/how-to-write-a-window-manager-in-python/
- sawfish: http://sawfish.wikia.com/wiki/Main_Page
  make the doc:
    in sawfish/man: makeinfo --html -I . sawfish.texi
    then: firefox sawfish/index.html
- xlambda: https://github.com/kazzmir/x11-racket/blob/master/xlambda/xlambda.rkt
- awesome: http://awesome.naquadah.org/download/
- http://tronche.com/gui/x/xlib
- for window managers:
  http://tronche.com/gui/x/xlib/window-and-session-manager/
  http://tronche.com/gui/x/xlib/ICC/client-to-window-manager/
- http://menehune.opt.wfu.edu/Kokua/Irix_6.5.21_doc_cd/usr/share/Insight/library/SGI_bookshelves/SGI_Developer/books/XLib_PG/sgi_html/
- ICCCM: http://tronche.com/gui/x/icccm/
- non-ICCCM features: http://standards.freedesktop.org/wm-spec/1.4/ar01s02.html
- Extended Window Manager Hints: http://standards.freedesktop.org/wm-spec/latest/
- Window Managers: http://www.csl.mtu.edu/cs4760/www/Lectures/OlderLectures/HCIExamplesLectures/XWin/xWM.htm
- wmctrl: a small software with which RWind should be made compliant
  http://en.wikipedia.org/wiki/Wmctrl
- X Window Managers: http://en.wikipedia.org/wiki/X_window_manager
- X11: http://www.freebsd.org/cgi/man.cgi?query=X&sektion=7&manpath=XFree86+4.7.0
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
         rwind/base
         rwind/color
         rwind/display
         rwind/events
         rwind/keymap
         rwind/server 
         rwind/user
         rwind/util
         rwind/window
         rwind/workspace
         rwind/gui/base
         x11-racket/x11 ; needs raco link x11-racket
         ; WARNING: the x11.rkt lib still needs some work. Every function that one uses should be checked with the official documentation.
         )

; for testing the popup-menu bug:
;(require racket/gui/base rwind/test/popup-menu)


(debug-prefix "RW: ")

#;(define restart? #f)

(define (run)
  (with-output-to-file (build-path (find-system-path 'home-dir) "rwind.log")
    #:exists 'replace
    ; For logging purposes, also see racket's logging facility search for "logging")
    (λ()
      (parameterize ([current-error-port (current-output-port)]
                     ;; Set the current directory to the user's dir
                     [current-directory (find-user-config-dir rwind-dir-name)])
        
        ;; Initialize thread support
        ;; This must be the first X procedure to call
        (XInitThreads)
        
        (init-display)
        (init-debug)
        
        (XLockDisplay (current-display))
        
        (init-root-window)
        
        (init-colors)
        
        ;; Find which ModMask are the *-Lock modifiers
        (find-modifiers)
        
        (intern-atoms)
        
        (init-gui)
        
        (init-user)
        
        (init-keymap)

        #| For testing
        (define f (new frame% [label "auie"]))
        (define cb (new button% [parent f] [label "Menu"] 
                        [callback (λ(cb ev)
                                    (printf "*** button callback in gui-eventspace? ~a\n" (in-gui-eventspace?))
                                    (send f popup-menu menu2 100 150))]))
        ;(define cb2 (new button% [parent f] [label "Hide Me"] [callback (λ _ (send f show #f))]))
        ;(send f show #t)
        ; TEST
        (add-bindings 
         global-keymap
         "C-F1"
         (L* (queue-callback (λ();(printf "*** C-F1 callback in gui-eventspace? ~a\n" (in-gui-eventspace?))
                                (thread (λ()(send f popup-menu menu2 100 400))))))
         ;(L* (thread (λ()(match (query-pointer) [(list w x y m) (show-popup-menu menu2 x y)]))))
         "C-F2"
         ; needs a thread, otherwise it freezes the main thread, since it's a dialog box that
         ; requires to be mapped by the main thread
         (L* (thread (λ()(message-box "Title" "Message"))))
         "C-F3" 
         (L* (send f show #t))
         )
|#
        
        ; This adds all mapped windows to the first workspace:
        (init-workspaces)
        
        (init-server)
        
        ;==================;
        ;=== Event loop ===;
        ;==================;
        (with-handlers ([exn:fail? (λ(e)(thread (λ()(error-message-box e))))])
          (run-event-loop))

        (dprintf "Terminating... ")
        
        ; Need to unlock to avoid deadlock with the server-thread break
        (XUnlockDisplay (current-display))
        
        (exit-server)
        
        ; Not sure I should call that if the user wants to replace the current wm by some other
        ; without logging out.
        ;(XDestroySubwindows (current-display) (current-root-window)) ; useful?
        
        (exit-display)
        ))); log to file
  
  
  
  ; Broken
  #;(when restart?
      (dprintf "Restarting... ")
      ; Run another process without killing this one, 
      ; otherwise the Xserver may terminate
      (define l (cons  (path->string (find-system-path 'run-file))
                       (vector->list (current-command-line-arguments))))
      (dprintf "Command-line:~a\n" l)
      (apply system* l))
  
  (dprintf "Finished.\n"))

(module+ main
  (require racket/match)
  
  ;; take the config file from the environment
  (let ([config-file (getenv "RWIND_CONFIG_FILE")])
    (when (and config-file (file-exists? config-file))
      (cmd-line-config-file (path->complete-path config-file))))

  (let arg-loop ([args (vector->list (current-command-line-arguments))])
    (unless (null? args)
      (match args
        [(list (or "--help" "-h"))
         (displayln "Usage:
rwind [arguments] ...
racket -t rwind.rkt [arguments] ...

Arguments:
-h, --help
    This help message
-c, --config config-file
    Uses config-file in place of the default user configuration file
--debug
    Prints RWind debugging information
")]
        [(list (or "--config" "-c") config-file arg-rest ...)
         (if (file-exists? config-file)
             (cmd-line-config-file (path->complete-path config-file))
             (error "Configuration file does not exist:" config-file))
         (arg-loop arg-rest)]
        [(list "--debug" arg-rest ...)
         (rwind-debug #t)
         (arg-loop arg-rest)]
        [else
         (printf "Warning: Unused arguments ~a\n" args)])))
  (run)
  )
