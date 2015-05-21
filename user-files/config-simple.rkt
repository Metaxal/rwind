#lang racket/base

;;; User configuration file

(require rwind/base
         rwind/keymap
         rwind/window
         rwind/util
         rwind/user
         rwind/workspace
         rwind/policy/base
         rwind/policy/simple
         rwind/policy/tiling
         racket/class)

; Set the number of workspaces
(num-workspaces 4)

; Use a stacking policy
(current-policy (new policy-simple%))
; Uncomment this instead if you want a tiling policy
#;(current-policy (new policy-tiling%))

;;; Some key/mouse bindings

(add-bindings 
 global-keymap
 ; Open xterm with Alt/Meta-Control-t
 "M-C-t" (L* (rwind-system "xterm"))
 ; Open xclock
 "M-C-c" (L* (rwind-system "xclock -digital -update 1"))
 ; Open gmrun (requires it to be installed). See also 'dmenu'.
 ;"M-F2"  (L* (rwind-system "gmrun"))
 "M-F2"  (L* (open-launcher))
 ; Open the config file for editing, with "open" on mac or "xdg-open" or "mimeopen" on Linux
 "M-F11" (L* (open-user-config-file))
 ; Open the client of rwind for console interaction
 "M-F12" (L* (rwind-system "xterm -g 80x24+400+0 -T 'RWind Client' -e 'racket -l rwind/client'"))
 ; Close window gracefully if possible, otherwise kill the client
 "M-F4"  (L* (delete-window (input-focus)))
 ; Give keyboard focus to the next/previous window
 "M-Tab"   (L* (policy. activate-next-window))
 "M-S-Tab" (L* (policy. activate-previous-window))
 ; Place one workspace over all heads (monitors)
 "M-Super-F5" (L* (change-workspace-mode 'single))
 ; Place one workspace per head
 "M-Super-F6" (L* (change-workspace-mode 'multi))
 ; Tiling: Move the window up or down in the hierarchy
 "Super-Page_Up"   (L* (policy. move-window 'up))
 "Super-Page_Down" (L* (policy. move-window 'down))
 )

(for ([i (num-workspaces)])
  (add-bindings
   global-keymap
   ; Switch to the i-th workspace with Super-F1, Super-F2, etc.
   (format "Super-F~a" (add1 i)) (L* (activate-workspace i))
   ; Move window to workspace and switch to workspace
   (format "S-Super-F~a" (add1 i)) (L* (move-window-to-workspace/activate (input-focus) i))
   ))

(add-bindings
 window-keymap
 ; Move window with Meta-Button1
 "M-Move1" (motion-move-window)
 ; Resize window with Meta-Button3
 "M-Move3" (motion-resize-window)
 )

(bind-click-to-activate "Press1")

(add-bindings 
 root-keymap 
 ; Quit RWind
 "Super-S-Escape" (L* (dprintf "Now exiting.\n")
                      (exit-rwind? #t))
 ; Restart RWind
 ; (e.g., if the config file has changed)
 "Super-C-Escape" (L* (dprintf "Now exiting and restarting.\n")
                      (restart-rwind? #t)
                      (exit-rwind? #t))
 ; Recompile and Restart RWind
 ; (e.g., if rwind's code has changed)
 "Super-C-S-Escape" (L* (when (recompile-rwind)
                          (dprintf "Restarting...\n")
                          (restart-rwind? #t)
                          (exit-rwind? #t)))
 )
 
