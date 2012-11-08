#lang racket/base

;;; User configuration file

(require rwind/keymap ; todo, make a main.rkt file that exports everything the user may usually want
         rwind/window
         rwind/util
         rwind/base
         racket/function)

;;; Some key/mouse bindings
;;; TODO: Place that in a user file (using dynamic-require and appropriate namespaces)

(bind-key global-keymap "t" '(Mod1Mask ControlMask)
          (thunk* (rwind-system "xterm")))
(bind-key global-keymap "c" '(Mod1Mask ControlMask)
          (thunk* (rwind-system "xclock -digital -update 1")))
(bind-key global-keymap "F2" '(Mod1Mask)
          (thunk* (rwind-system "gmrun")))
(bind-key global-keymap "F12" '(Mod1Mask)
          (thunk* (rwind-system "xterm -g 80x24+400+0 -e 'racket client.rkt'")))
(bind-key global-keymap "F10" '(Mod1Mask)
          (thunk* (open-user-config-file)))

;; Click to focus
(bind-button global-keymap 1 'ButtonPress '()
             (λ(ev)
               (define w (keymap-event-window ev))
               (set-input-focus w)
               (raise-window w)
               ))

(bind-button global-keymap 1 'ButtonPress '(Mod1Mask)
             (thunk* (printf "global Alt-Press1 called!\n")))

; Moving window
(let ([x-ini #f] [y-ini #f] [x #f] [y #f] [window #f])
  (bind-motion 
   global-keymap 1 '(ControlMask)
   (λ(ev)
     (case (keymap-event-type ev)
       [(ButtonPress)
        (set! window (keymap-event-window ev))
        (set!-values (x-ini y-ini) (mouse-event-position ev))
        (set!-values (x y) (window-position window))
        (printf "@ Start dragging window ~a\n" (window-name window))]
       [(ButtonMove)
        (define-values (x-ev y-ev) (mouse-event-position ev))
        (define x-diff (- x-ev x-ini))
        (define y-diff (- y-ev y-ini))
        (printf "@ Dragging window ~a...\n" (window-name (keymap-event-window ev)))
        (move-window window (+ x x-diff) (+ y y-diff))]
       [(ButtonRelease)
        (printf "@ Stop dragging window ~a.\n" (window-name (keymap-event-window ev)))]))))

; Resizing window
(let ([x-ini #f] [y-ini #f] [w #f] [h #f] [window #f])
  (bind-motion 
   global-keymap 3 '(ControlMask)
   (λ(ev)
     (case (keymap-event-type ev)
       [(ButtonPress)
        (set! window (keymap-event-window ev))
        (set!-values (x-ini y-ini) (mouse-event-position ev))
        (set!-values (w h) (window-dimensions window))]
       [(ButtonMove)
        (define-values (x-ev y-ev) (mouse-event-position ev))
        (define x-diff (- x-ev x-ini))
        (define y-diff (- y-ev y-ini))
        (resize-window window (max 1 (+ w x-diff)) (max 1 (+ h y-diff)))]))))

