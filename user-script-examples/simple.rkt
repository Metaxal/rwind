#lang racket/base

;;; User configuration file

(require rwind/keymap
         rwind/window
         rwind/util
         rwind/user
         rwind/workspace
         racket/function)

;;; Some key/mouse bindings
;;; Mod1Mask is Alt/Meta
;;; Mod4Mask is the Super key (Windows key on PCs)

;; Open xterm
(add-binding global-keymap "A-C-t"
             (L* (rwind-system "xterm")))

;; Open xclock
(add-binding global-keymap "M-C-c"
          (L* (rwind-system "xclock -digital -update 1")))

;; Open gmrun (requires it to be installed)
(add-binding global-keymap "M-F2"
          (L* (rwind-system "gmrun")))

;; Opens the client of rwind for console interaction
(add-binding global-keymap "M-F12"
          (L* (rwind-system "xterm -g 80x24+400+0 -T 'RWind Client' -e 'racket -e \"(require rwind/client)\"'")))

;; Open the config file for editing, with "open" on mac or "xdg-open" on Linux
(add-binding global-keymap "M-F10"
          (L* (open-user-config-file)))

;; Switch to the first workspace
(add-binding global-keymap "Super-F1"
          (L* (activate-workspace 0)))

;; Switch to the second workspace
(add-binding global-keymap "Super-F2"
          (L* (activate-workspace 1)))

;; Left-click to focus and raise window
(add-binding window-keymap "Press1"
             (λ(ev)
               (define w (keymap-event-window ev))
               (raise-window w)
               (set-input-focus w)
               ))

;; Moving window with Ctrl-Button1
(add-binding window-keymap "C-Move1"
             (motion-move-window))

;; Resizing window with Ctrl-Button3
(add-binding window-keymap "C-Move3"
             (motion-resize-window))

