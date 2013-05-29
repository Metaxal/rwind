#!/usr/bin/racket
#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL
;;; Note that the standalone client.rkt is in GPL, because it uses readline, but rwind does not depend on it.

#| TODO:
PRIORITIES:
- *** make the basis so that extending and debugging is easy! ***
- make sure Racket's GUI works... (problems with the event-spaces)

Other:
- security of the server: make sure the user at the other end of the tcp connection
  is the same as the one running the server!
  Use Unix uid's? ask for password?

- (select-window)
  plus look at all the window utilities in Sawfish (lisp/sawfish/wm/windows.jl)
- shutdown more gracefully?
- time-stamps are quite probably not handled properly

- viewports?

- GUI. Started, but problem, conflict with Racket's gui?

- grab the server here and there to speed up things
  Warning: Beware of deadlocks, especially with the gui thread

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
X11_RACKET_DEBUG=1 raco setup x11 rwind && xinit .xinit-rwind -- :1 &

- In rwind's directory: raco link rwind
to be able to use (require rwind/keymap) for example
(optional: raco setup rwind)

- After trying hard to use threads (and failing) with Xlib, it seems anyway that it's better to not use them at all.
  It's of no use of the user's script, and the client may be better off in a separate application.
  Sawfish does not seem to use XInitThreads() either.
|#

(require ;"base.rkt" "window-util.rkt" "keymap.rkt" "util.rkt"
         ;; WARNING! Requiring the files via a raco link or via relative file does not require it in the same "namespace" (or something)!!
         ;; Further requirement for the bug to appear: it must be started with xinit
         ;; see https://groups.google.com/forum/?fromgroups=#!topic/racket-users/jEXWq_24cOU
         ;; (is this still true today?)
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
         x11/x11 ; needs raco pkg install x11
         ; WARNING: the x11.rkt lib still needs some work. Every function that one uses should be checked with the official documentation.

         racket/match
         )

(provide main)

(debug-prefix "RW: ")
;; Backup the current ports handlers
(define-values (out0 in0 err0)
  (values (current-output-port) (current-input-port) (current-error-port)))

;===========;
;=== Run ===;
;===========;
(define (run)
  (with-output-to-file rwind-log-file
    #:exists 'replace
    ; For logging purposes, also see racket's logging facility (search for "logging")
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

        ; This adds all mapped windows to the first workspace:
        (init-workspaces)

        (init-server)

        ;==================;
        ;=== Event loop ===;
        ;==================;
        (run-event-loop)

        (dprintf "Terminating... ")

        ; Need to unlock to avoid deadlock with the server-thread break
        (XUnlockDisplay (current-display))

        (exit-server)

        (exit-workspaces)

        (exit-display)

        ))); log to file

  (dprintf "RWind terminated.\n")
  ; Make sure to exit the process, e.g., in case somethings hangs, like gui frames
  (restart-rwind?))

;============;
;=== Main ===;
;============;
(define (main)

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
  (run))
