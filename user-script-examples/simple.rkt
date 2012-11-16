#lang racket/base

;;; User configuration file

(require rwind/keymap
         rwind/window
         rwind/util
         rwind/base
         rwind/user
         racket/function)

;;; Some key/mouse bindings
;; Mod1Mask is Alt/Meta

(bind-key global-keymap "t" '(Mod1Mask ControlMask)
          (thunk* (rwind-system "xterm")))
(bind-key global-keymap "c" '(Mod1Mask ControlMask)
          (thunk* (rwind-system "xclock -digital -update 1")))
(bind-key global-keymap "F2" '(Mod1Mask)
          (thunk* (rwind-system "gmrun")))
(bind-key global-keymap "F12" '(Mod1Mask)
          (thunk* (rwind-system "xterm -g 80x24+400+0 -e 'racket -e \"(require rwind/client)\"'")))
(bind-key global-keymap "F10" '(Mod1Mask)
          (thunk* (open-user-config-file)))

;; Left-click to focus and raise window
(bind-button global-keymap 1 'ButtonPress '()
             (λ(ev)
               (define w (keymap-event-window ev))
               (set-input-focus w)
               (raise-window w)
               ))

;; Moving window with Ctrl-Button1
(bind-motion global-keymap 1 '(ControlMask)
             (motion-move-window))

;; Resizing window with Ctrl-Button3
(bind-motion global-keymap 3 '(ControlMask)
             (motion-resize-window))

