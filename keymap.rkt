#lang racket/base

(require ;"base.rkt" "util.rkt" "window-util.rkt"
         rwind/base 
         rwind/util
         rwind/window
         rwind/doc-string
         x11-racket/x11
         ;x11-racket/keysym-util
         x11-racket/keysymdef
         ;"../racket/common/debug.rkt"
         racket/list
         racket/match
         )

#| TODO
- add border-keymap (requires a border)
- it would be simpler if we could use (mouse-event-window ev)
  instead of needing to call (keymap-event-window ev) 
  (that's because mouse-event derives from keymap-event)
  Not sure how to do it tough.
|#

;; WARNING: Apparently, the button modifiers must NOT appear in the modifiers list,
;; but they ARE received for such event! (go figure...)


;; InputMask
#;(NoEventMask
   KeyPressMask
   KeyReleaseMask
   ButtonPressMask
   ButtonReleaseMask
   EnterWindowMask
   LeaveWindowMask
   PointerMotionMask
   PointerMotionHintMask
   Button1MotionMask
   Button2MotionMask
   Button3MotionMask
   Button4MotionMask
   Button5MotionMask
   ButtonMotionMask
   KeymapStateMask
   ExposureMask
   VisibilityChangeMask
   StructureNotifyMask
   ResizeRedirectMask
   SubstructureNotifyMask
   SubstructureRedirectMask
   FocusChangeMask
   PropertyChangeMask
   ColormapChangeMask
   OwnerGrabButtonMask)
;; + Any in some functions?

(define* pointer-grab-events
  ; If PointerMotionHintMask is included,
  ; MotionNotify events are triggered only when crossing the window's boundaries
  '(ButtonPressMask ButtonReleaseMask PointerMotionMask)); PointerMotionHintMask))


;; All modifiers
#;(ShiftMask
   LockMask ; CapsLock
   ControlMask
   Mod1Mask ; Alt/meta
   Mod2Mask ; NumLock
   Mod3Mask ; Super
   Mod4Mask ; 
   Mod5Mask ; AltGr
   Button1Mask
   Button2Mask
   Button3Mask
   Button4Mask
   Button5Mask
   Any)
;; + AnyModifier in some functions

#;(define key-modifiers
  '(ShiftMask
    LockMask
    ControlMask
    Mod1Mask
    Mod2Mask
    Mod3Mask
    Mod4Mask
    Mod5Mask
    ))

(define* button-modifiers
  '(Button1Mask
    Button2Mask
    Button3Mask
    Button4Mask
    Button5Mask))

(define* num-lock-mask #f)
(define* scroll-lock-mask #f)
(define* caps-lock-mask 'LockMask)
(define* lock-masks #f)
(define* all-lock-combinations #f)

;; Translated from:
;; http://code.google.com/p/jnativehook/source/browse/branches/test_code/linux/XGrabKey.c?r=297
(define* (find-lock-modifiers)
  "Find the *-Lock modifiers ModMasks, since there is no fixed value for them."
  (define nlock (XKeysymToKeycode (current-display) XK-Num-Lock))
  (define slock (XKeysymToKeycode (current-display) XK-Scroll-Lock))
  (define modmap (XGetModifierMapping (current-display)))
  (define mods (XModifierKeymap->vector modmap))
  
  (cond
    [modmap
     (define keypermod (XModifierKeymap-max-keypermod modmap))
     (for* ([i 8]
            [j keypermod])
       (define code (vector-ref mods (+ (* i keypermod) j)))
       (define mask (vector-ref keyboard-modifiers i))
       (cond [(= code nlock)
              (set! num-lock-mask mask)]
             [(= code slock)
              (set! scroll-lock-mask code)]))
     
     ;; Remove the modifiers that were not fould if any
     (set! lock-masks (filter values (list caps-lock-mask num-lock-mask scroll-lock-mask)))
     ;; Create the list of all possible combinations of *-Lock modifiers
     (set! all-lock-combinations
           (all-combinations lock-masks))
     
     (dprintf "~a\n" all-lock-combinations)
     
     (XFreeModifiermap modmap)]
    [else
     (printf "Warning: Could not find modifiers!\n")]))

;==============;
;=== Keymap ===;
;==============;

(provide (struct-out keymap-event))
(struct keymap-event 
  (window ; the window in which the event was sent (may be #f)
   value ; key-code or mouse-button
   type ; (one-of 'KeyPress 'KeyRelease 'ButtonPress 'ButtonMove 'ButtonRelease)
   modifiers ; see above
   ))

;; That's not very efficient...
;; but ensure that the code can be found.
;; Maybe we could get the corresponding ctype-value?
(define* (make-keymap-key key/mouse-code type modifiers)
  ; remove *-lock modifiers
  (let* ([modifiers (remove* lock-masks modifiers)]
         [modifiers (remove* button-modifiers modifiers)])
    (list* key/mouse-code type (sort modifiers symbol<=?))))

(define* make-keymap 
  "Returns an empty keymap."
  make-hash)

(define* global-keymap
  "General keymap for all windows."
  (make-keymap))

(define* window-keymap 
  "Keymap for actions that may differ from window to window."
  (make-keymap))

(define* (keymap-set! keymap key proc)
  (when (hash-ref keymap key #f)
    (printf "Warning: keybinding already defined ~a. Replacing old one.\n" 
            key))
  (hash-set! keymap key proc))

(define* (keymap-ref keymap key)
  (define res (hash-ref keymap key #f))
  (unless res
    (printf "Binding ~a not found\n" key))
  res)

(define* (call-binding keymap km-ev)
  (match-define (keymap-event window key-code/button type modifiers)
    km-ev)
  (let* ([key (make-keymap-key key-code/button type modifiers)]
         [proc (keymap-ref keymap key)])
    (when proc
      (printf "Binding ~a (~a) found, calling thunk\n" key-code/button modifiers)
      (proc km-ev))
    (not (not proc))))

(define* (call-keymaps-binding km-ev)
  (or (call-binding window-keymap km-ev)
      (call-binding global-keymap km-ev)))

(define* (window-apply-keymap window keymap)
  ; TODO: First remove all grabbings?
  (printf "window-apply-keymap ~a\n" (window-name window))
  (for ([(k v) keymap])
    (define value (first k)) ; button-num or key-code
    (define type (second k))
    (define modifiers (cddr k))
    (case type
      [(KeyPress KeyRelease)
       (grab-key window value modifiers)]
      [(ButtonPress ButtonRelease)
       (grab-button window value modifiers '(ButtonPressMask ButtonReleaseMask))]
      [(ButtonMove)
       ; It's not clear what InputMasks are required, 
       ; and I couldn't find the right smallest combination
       ; So I just use the same (more general) combination as in Sawfish.
       (grab-button window value modifiers pointer-grab-events)]
      [else (error "Event type not found in window-apply-keymap:" type)])))

;================;
;=== Keyboard ===;
;================;

;; event-type: (one-of 'KeyPress 'KeyRelease)
;; TODO: add 'FocusIn and 'FocusOut ?
(provide (struct-out keyboard-event))
(struct keyboard-event keymap-event ()) ; no additional info
(define* (keyboard-event-key-code event) ; just a wrapper
  (keymap-event-value event))

;; http://tronche.com/gui/x/xlib/input/XGrabKey.html
(define* (grab-key window key-code [modifiers '()])
  "Register KeyPress events
The given combination is done for all combinations of the *-Lock modifiers."
  (for ([lock-mods all-lock-combinations])
    (XGrabKey (current-display) key-code 
              (append modifiers lock-mods)
              window
              #f 'GrabModeAsync 'GrabModeAsync)))

;; KeyPress only is used, because it seems that XGrabKey cares only about them.
(define* (bind-key keymap key-string modifiers proc [window (current-root-window)])
  (define key-code (XKeysymToKeycode (current-display) (XStringToKeysym key-string)))
  (define key (make-keymap-key key-code 'KeyPress modifiers))
  (keymap-set! keymap key proc)
  )

#;(define (call-key-binding keymap kb-ev)
  (match-define (keyboard-event window key-code type modifiers)
    kb-ev)
  (let* ([key-sym (XKeycodeToKeysym (current-display) key-code 0)]
         [key-string (XKeysymToString key-sym)]
         [key (make-keymap-key key-code type modifiers)]
         [proc (keymap-ref keymap key)])
    (when proc
      (printf "Key-binding ~a (~a) ~a found, calling thunk\n" key-code key-string modifiers)
      (proc kb-ev))
    (not (not proc)))) ; return boolean (and don't return the thunk itself)

;=============;
;=== Mouse ===;
;=============;

;; event-type: (one-of 'ButtonPress 'ButtonMove 'ButtonRelease)
;; TODO: add 'Enter and 'Leave ? ('PointerIn 'PointerOut)
(provide (struct-out mouse-event))
(struct mouse-event keymap-event (x y))
(define* (mouse-event-position ev)
  (values (mouse-event-x ev)
          (mouse-event-y ev)))

(define* (find-modifiers-button modifiers)
  "Takes a list of modifiers and returns the number of the button that is pressed (first found), or #f if none is found.
Useful for 'MotionNotify events (where the button is not specified)."
  (for/or ([m modifiers])
    (case m
      [(Button1Mask) 1]
      [(Button2Mask) 2]
      [(Button3Mask) 3]
      [(Button4Mask) 4]
      [(Button5Mask) 5]
      [else #f])))

;; http://tronche.com/gui/x/xlib/input/XGrabPointer.html
(define* (grab-pointer [window (current-root-window)] [mask pointer-grab-events] [cursor None])
  (XGrabPointer (current-display) window #t mask
                'GrabModeAsync 'GrabModeAsync None cursor CurrentTime))

;; Also ungrabs buttons
;; http://tronche.com/gui/x/xlib/input/XUngrabPointer.html
(define* (ungrab-pointer)
  (XUngrabPointer (current-display) CurrentTime))
  
;; can also use AnyButton for button-num.
;; http://tronche.com/gui/x/xlib/input/XGrabButton.html
(define* (grab-button window button-num modifiers mask)
  (for ([lock-mods all-lock-combinations])
    (XGrabButton (current-display) button-num 
                 (append modifiers lock-mods)
                 window #f mask
                 'GrabModeAsync 'GrabModeAsync None None)))

;; http://tronche.com/gui/x/xlib/input/XUngrabButton.html
(define* (ungrab-button window button-num modifiers)
  (XUngrabButton (current-display) button-num modifiers window))

;; button-num: integer in [1 5]
(define* (button-modifier button-num)
  (string->symbol (format "Button~aMask" button-num)))

(define* (bind-button keymap button-num type modifiers proc
                     [window (current-root-window)])
  (let ([key (make-keymap-key button-num type modifiers)])
    (keymap-set! keymap key proc)
    ))
  
(define* (bind-motion keymap button-num modifiers proc)
  (define motion-mask (string->symbol (format "Button~aMotionMask" button-num)))
  (bind-button keymap button-num 'ButtonPress modifiers 
               (λ(ev)
                 (proc ev)
                 (grab-pointer (keymap-event-window ev)
                               (list* motion-mask pointer-grab-events))
                 ))
  (bind-button keymap button-num 'ButtonMove modifiers
               proc)
  (bind-button keymap button-num 'ButtonRelease modifiers
               (λ(ev)
                 (ungrab-pointer) ; before proc-release, in case it fails
                 (proc ev)))
  )

#;(define (call-mouse-binding keymap mouse-ev)
  (match-define (mouse-event window button-num type modifiers _x _y)
    mouse-ev)
  (let* ([key (make-keymap-key button-num type modifiers)]
         ; (but keep other modifiers, since they contain mouse masks)
         [proc (keymap-ref keymap key)])
    (when proc
      (printf "Mouse-binding ~a found, calling thunk\n" key)
      (proc mouse-ev))
    (not (not proc)))) ; return boolean (and don't return the thunk itself)


;;; To put in a separate file?

(define* (motion-move-window)
  "Returns a procedure to use with bind-motion."
  (let ([x-ini #f] [y-ini #f] [x #f] [y #f] [window #f])
    (λ(ev)
      (case (keymap-event-type ev)
        [(ButtonPress)
         (set! window (keymap-event-window ev))
         (set!-values (x-ini y-ini) (mouse-event-position ev))
         (set!-values (x y) (window-position window))
         #;(printf "@ Start dragging window ~a\n" (window-name window))]
        [(ButtonMove)
         (define-values (x-ev y-ev) (mouse-event-position ev))
         (define x-diff (- x-ev x-ini))
         (define y-diff (- y-ev y-ini))
         #;(printf "@ Dragging window ~a...\n" (window-name (keymap-event-window ev)))
         (move-window window (+ x x-diff) (+ y y-diff))]
        #;[(ButtonRelease)
         (printf "@ Stop dragging window ~a.\n" (window-name (keymap-event-window ev)))]))))

(define* (motion-resize-window)
  "Returns a procedure to use with bind-motion."
  (let ([x-ini #f] [y-ini #f] [w #f] [h #f] [window #f])
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