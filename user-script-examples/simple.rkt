#lang racket/base

;;; User configuration file

(require rwind/keymap
         rwind/window
         rwind/util
         rwind/user
         rwind/workspace
         racket/function)

;;; Some key/mouse bindings

(add-bindings 
 global-keymap
 ;; Open xterm
 "A-C-t" (L* (rwind-system "xterm"))
 ;; Open xclock
 "M-C-c" (L* (rwind-system "xclock -digital -update 1"))
 ;; Open gmrun (requires it to be installed)
 "M-F2" (L* (rwind-system "gmrun"))
 ;; Opens the client of rwind for console interaction
 "M-F12" (L* (rwind-system "xterm -g 80x24+400+0 -T 'RWind Client' -e 'racket -e \"(require rwind/client)\"'"))
 ;; Open the config file for editing, with "open" on mac or "xdg-open" or "mimeopen" on Linux
 "M-F10" (L* (open-user-config-file))
 )

(for ([i 3])
  (add-bindings
   global-keymap
   ;; Switch to the first workspace
   (format "Super-F~a" (add1 i)) (L* (activate-workspace i))
   ;; Move window to workspace and activate
   (format "S-Super-F~a" (add1 i)) (L* (move-window-to-workspace/activate (input-focus) i))
   ))

(add-bindings
 window-keymap
 ;; Moving window with Ctrl-Button1
 "C-Move1" (motion-move-window)
 ;; Resizing window with Ctrl-Button3
 "C-Move3" (motion-resize-window))

(add-binding
 window-keymap
 ;; Left-click to focus and raise window.
 ;; We need to use the grab sync mode in order to be able to replay the event to the window
 ;; after we have processsed it, using allow-events.
 ;; (see http://tronche.com/gui/x/xlib/input/XGrabPointer.html)
 ;; (see metacity/src/core/display.c around line 1728)
 "Press1" (λ(ev)
            (define w (keymap-event-window ev))
            (raise-window w)
            (set-input-focus w)
            (allow-events 'ReplayPointer)
            )
 #:grab-mode 'GrabModeSync)