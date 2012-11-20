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
(bind-key global-keymap "t" '(Mod1Mask ControlMask)
          (L* (rwind-system "xterm")))

;; Open xclock
(bind-key global-keymap "c" '(Mod1Mask ControlMask)
          (L* (rwind-system "xclock -digital -update 1")))

;; Open gmrun (requires it to be installed)
(bind-key global-keymap "F2" '(Mod1Mask)
          (L* (rwind-system "gmrun")))

;; Opens the client of rwind for console interaction
(bind-key global-keymap "F12" '(Mod1Mask)
          (L* (rwind-system "xterm -g 80x24+400+0 -T 'RWind Client' -e 'racket -e \"(require rwind/client)\"'")))

;; Open the config file for editing, with "open" on mac or "xdg-open" on Linux
(bind-key global-keymap "F10" '(Mod1Mask)
          (L* (open-user-config-file)))

;; Switch to the first workspace
(bind-key global-keymap "F1" '(Mod4Mask)
          (L* (activate-workspace 0)))

;; Switch to the second workspace
(bind-key global-keymap "F2" '(Mod4Mask)
          (L* (activate-workspace 1)))

;; Left-click to focus and raise window
(bind-button window-keymap 1 'ButtonPress '()
             (λ(ev)
               (define w (keymap-event-window ev))
               (raise-window w)
               (set-input-focus w)
               ))

;; Moving window with Ctrl-Button1
(bind-motion window-keymap 1 '(ControlMask)
             (motion-move-window))

;; Resizing window with Ctrl-Button3
(bind-motion window-keymap 3 '(ControlMask)
             (motion-resize-window))

