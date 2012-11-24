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
 ;; Switch to the first workspace
 "Super-F1" (L* (activate-workspace 0))
 ;; Switch to the second workspace
 "Super-F2" (L* (activate-workspace 1)))

(add-bindings
 window-keymap
 ;; Left-click to focus and raise window
 "Press1" (λ(ev)
            (define w (keymap-event-window ev))
            (raise-window w)
            (set-input-focus w)
            )
 ;; Moving window with Ctrl-Button1
 "C-Move1" (motion-move-window)
 ;; Resizing window with Ctrl-Button3
 "C-Move3" (motion-resize-window))

