#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

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
         racket/function
         racket/pretty
         racket/string
         racket/dict
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

(define* modifier-XK-dict (make-hasheq))
(define* num-lock-mask #f)
(define* scroll-lock-mask #f)
(define* caps-lock-mask 'LockMask)
(define* lock-masks #f)
(define* all-lock-combinations #f)

(define* default-mask (make-fun-box 'Mod4Mask))

(define* (keycode->keysym code [index 0])
  (XKeycodeToKeysym (current-display) code index))

(define* (keysym->keycode sym)
  (XKeysymToKeycode (current-display) sym))

(define* (keysym-symbol->modifier sym)
  (dict-ref modifier-XK-dict sym #f))

;; Adapted from:
;; http://code.google.com/p/jnativehook/source/browse/branches/test_code/linux/XGrabKey.c?r=297
;; Sawfish, see src/keys.(h|c), lisp/sawfish/wm/util/decode-events.jl
(define* (find-modifiers)
  "Creates the modifier dictionary, and find the *-Lock modifiers ModMasks,
since there is no fixed value for them."
  (define modmap (XGetModifierMapping (current-display)))
  (define mods (XModifierKeymap->vector modmap))
  (define mod-list (vector->list mods))
  
  (displayln mod-list)
  
  (cond
    [modmap
     ;; Search for the *-lock modifiers
     (define keypermod (XModifierKeymap-max-keypermod modmap))
     ;; Memorize the dictionary
     (for* ([i 8]
            [j keypermod])
       (define code (vector-ref mods (+ (* i keypermod) j)))
       (define mask (vector-ref keyboard-modifiers i))
       (define sym0 (keycode->keysym code 0))
       ;; Search for both index 0 and 1 (shifted),
       ;; because some keys like Meta (on my keyboard) need shift-Alt for example
       ;; (but we don't care about the shift in the dictionary)
       (for ([index 2])
         (define sym (keycode->keysym code index))
         (unless (zero? sym)
           (dict-set! modifier-XK-dict 
                      (keysym-number->symbol sym) mask))))

     ;; Find the num-lock and scrol-lock masks
     (set! num-lock-mask    (keysym-symbol->modifier 'XK-Num-Lock))
     (set! scroll-lock-mask (keysym-symbol->modifier 'XK-Scroll-Lock))
     ;; Remove the modifiers that were not fould if any
     (set! lock-masks (filter values (list caps-lock-mask num-lock-mask scroll-lock-mask)))
     ;; Create the list of all possible combinations of *-Lock modifiers
     (set! all-lock-combinations
           (all-combinations lock-masks))
     
     (dprintf "All lock combinations: ~a\n" all-lock-combinations)
     (XFreeModifiermap modmap)]
    [else
     (printf "Warning: Could not find modifiers!\n")]))

(module+ test
  (define dpy (XOpenDisplay #f))
  (current-display dpy)
  (find-modifiers)
  modifier-XK-dict
  ; when shift is pressed (strangely there are more of them):
  (keysym-number->symbol (keycode->keysym (keysym->keycode XK-Scroll-Lock)))
  (XCloseDisplay dpy)
  )

;==============;
;=== Keymap ===;
;==============;

(provide (struct-out keymap-event))
(struct keymap-event 
  (window ; the window in which the event was sent (may be #f)
   value ; key-code or mouse-button
   type ; (one-of 'KeyPress 'KeyRelease 'ButtonPress 'ButtonMove 'ButtonRelease)
   modifiers ; see above
   )
  #:mutable)

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
  "Looks for the callback corresponding to the given event, calls it if found.
  Returns true if the callback was found, false otherwise."
  (match-define (keymap-event window key-code/button type modifiers)
    km-ev)
  (let* ([key (make-keymap-key key-code/button type modifiers)]
         [proc (keymap-ref keymap key)])
    (when proc
      (printf "Binding ~a (~a) found, calling thunk\n" key-code/button modifiers)
      (proc km-ev))
    (not (not proc))))

(define* (call-keymaps-binding km-ev)
  (define window (keymap-event-window km-ev))
  (or (and window (call-binding window-keymap km-ev))
      (begin
        ; if it is not called on a window, then the window value is meaningless
        (set-keymap-event-window! km-ev #f)
        (call-binding global-keymap km-ev))))

(define (window-apply-keymap window keymap)
  ; TODO: First remove all grabbings?
  (printf "window-apply-keymap ~a\n" window)
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

(define* (window-apply-keymaps window)
  (window-apply-keymap window global-keymap)
  (window-apply-keymap window window-keymap))

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
  "Like bind-button, but for press, move and release events.
  The keymap-event-type is set to 'ButtonPress, 'ButtonMove and 'ButtonRelease accordingly."
  (define motion-mask (string->symbol (format "Button~aMotionMask" button-num)))
  (bind-button keymap button-num 'ButtonPress modifiers 
               (λ(ev)
                 (proc ev)
                 ; Warning: It may happen that if some call fails, the grab is not released!
                 (grab-pointer (current-root-window);(keymap-event-window ev)
                               (list* motion-mask pointer-grab-events))
                 ))
  (bind-button keymap button-num 'ButtonMove modifiers
               proc)
  (bind-button keymap button-num 'ButtonRelease modifiers
               (λ(ev)
                 (ungrab-pointer) ; before proc-release, in case it fails
                 (proc ev)))
  )

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

(define* (init-keymap)
  ;; TODO: Make a "root" keymap, that remains on top of the global one, 
  ;; and that cannot be modified by the user?
  (bind-key global-keymap "Escape" '(Mod1Mask) 
            (thunk*
             (dprintf "Now exiting.\n")
             (exit-rwind? #t)))
  #;(bind-key global-keymap "Escape" '(ControlMask Mod1Mask) 
              (thunk*
               (printf "Restarting...\n")
               (set! exit? #t)
               (set! restart? #t)))
  
  (dprintf "global keymap:\n")
  (pretty-print global-keymap)
  (dprintf "window keymap:\n")
  (pretty-print window-keymap) ; not really used currently?
  
  (window-apply-keymap (true-root-window) global-keymap) 
  ; but not the window-keymap! (otherwise virtual roots will be considered as subwindows)
  )

(define* (string->mask s)
    (match s
      [(or "S" "Shift") 'ShiftMask]
      [(or "C" "Control") 'ControlMask]
      [(or "M" "Meta") (keysym-symbol->modifier 'XK-Meta-L)]
      [(or "A" "Alt") (keysym-symbol->modifier 'XK-Alt-L)]
      [(or "Super") (keysym-symbol->modifier 'XK-Super-L)]
      [(or "H" "Hyper") (keysym-symbol->modifier 'XK-Hyper-L)]
      ["Mod1" 'Mod1Mask]
      ["Mod2" 'Mod2Mask]
      ["Mod3" 'Mod3Mask]
      ["Mod4" 'Mod4Mask]
      ["Mod5" 'Mod5Mask]
      ["Button1" 'Button1Mask]
      ["Button2" 'Button2Mask]
      ["Button3" 'Button3Mask]
      ["Button4" 'Button4Mask]
      ["Button5" 'Button5Mask]
      ["W" default-mask]
      [else (error "Modifier not found:" s)]))

(define* (string->keysym s)
  ;; direct translation of sawfish/src/keys.c
  (match s
    ["SPC" XK-space]
    ["Space" XK-space]
    ["TAB" XK-Tab]
    ["RET" XK-Return]
    ["ESC" XK-Escape]
    ["BS" XK-BackSpace]
    ["DEL" XK-Delete]

    [" " XK-space]
    ["!" XK-exclam]
    ["\"" XK-quotedbl]
    ["#" XK-numbersign]
    ["$" XK-dollar]
    ["%" XK-percent]
    ["&" XK-ampersand]
    ["'" XK-quoteright]
    ["(" XK-parenleft]
    [")" XK-parenright]
    ["*" XK-asterisk]
    ["+" XK-plus]
    ["," XK-comma]
    ["-" XK-minus]
    ["." XK-period]
    ["/" XK-slash]
    [":" XK-colon]
    [";" XK-semicolon]
    ["<" XK-less]
    ["=" XK-equal]
    [">" XK-greater]
    ["?" XK-question]
    ["@" XK-at]
    ["[" XK-bracketleft]
    ["\\" XK-backslash]
    ["]" XK-bracketright]
    ["^" XK-asciicircum]
    ["_" XK-underscore]
    ["`" XK-quoteleft]
    ["{" XK-braceleft]
    ["|" XK-bar]
    ["}" XK-braceright]
    ["~" XK-asciitilde]
    [else (XStringToKeysym s)]))


#;(define (string->mask s)
  (define d '(("S" . ShiftMask)
              ("Shift" . ShiftMask)
              ("C" . ControlMask)
              ("Control" . ControlMask)
              ("M" . Mod1Mask)
              ("Meta" . Mod1Mask)
              ("Alt" . Mod1Mask)
              ("Super" . Mod4Mask)
              ;("Hyper" . Mod5Mask);?
              ))
  (dict-ref d s))

(define* (string->key-list str)
  "Turns a string like \"M-C-t\" into '(\"t\" Mod1Mask ControlMask)"
  (define-values (mods key) (split-at-right (string-split str "-") 1))
  (cons (string->keysym (car key)) (map string->mask mods)))

  