#lang racket/base

;;; User configuration file

(require rwind/base
         rwind/keymap
         rwind/window
         rwind/util
         rwind/user
         rwind/workspace
         racket/function)

;;; Some key/mouse bindings

(add-bindings 
 global-keymap
 ; Open xterm with Alt/Meta-Control-t
 "M-C-t" (L* (rwind-system "xterm"))
 ; Open xclock
 "M-C-c" (L* (rwind-system "xclock -digital -update 1"))
 ; Open gmrun (requires it to be installed)
 "M-F2"  (L* (rwind-system "gmrun"))
 ; Opens the client of rwind for console interaction
 "M-F12" (L* (rwind-system "xterm -g 80x24+400+0 -T 'RWind Client' -e 'racket -e \"(require rwind/client)\"'"))
 ; Open the config file for editing, with "open" on mac or "xdg-open" or "mimeopen" on Linux
 "M-F10" (L* (open-user-config-file))
 ; Close window gracefully if possible, otherwise kill the client
 "M-F4"  (L* (delete-window (input-focus)))
 ; Give keyboard focus to the next window
 "M-Tab" (L* (activate-next-window))
 ; Place one workspace over all heads (monitors)
 "M-Super-F5" (L* (change-workspace-mode 'single))
 ; Place one workspace per head
 "M-Super-F6" (L* (change-workspace-mode 'multi))
 )

(for ([i 4])
  (add-bindings
   global-keymap
   ; Switch to the i-th workspace with Super-F1, Super-F2, etc.
   (format "Super-F~a" (add1 i)) (L* (activate-workspace i))
   ; Move window to workspace and switch to workspace
   (format "S-Super-F~a" (add1 i)) (L* (move-window-to-workspace/activate (input-focus) i))
   ))

(add-bindings
 window-keymap
 ; Moving window with Meta-Button1
 "M-Move1" (motion-move-window)
 ; Resizing window with Meta-Button3
 "M-Move3" (motion-resize-window)
 )

(bind-click-to-activate "Press1")

(add-bindings 
 root-keymap 
 ; Quit RWind
 "M-Escape" (L* (dprintf "Now exiting.\n")
                (exit-rwind? #t))
 "C-Escape" (L* (dprintf "Now exiting and restarting.\n")
                (restart-rwind? #t)
                (exit-rwind? #t))
 ; Recompile RWind, quit and restart
 "M-C-Escape" (L* (when (recompile-rwind)
                    (dprintf "Restarting...\n")
                    (restart-rwind? #t)
                    (exit-rwind? #t)))
 )
 
