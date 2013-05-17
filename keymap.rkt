#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require ;"base.rkt" "util.rkt" "window-util.rkt"
         rwind/base 
         rwind/util
         rwind/window
         rwind/doc-string
         x11/x11
         ;x11/keysym-util
         x11/keysymdef
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
- add FocusIn, FocusOut, PointerIn, PointerOut? (or not as keybindings but as other callbacks?)
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

(define* modifier-XK-dict 
  "Dictionary that holds the modifier mask associated with a given XK-key."
  (make-hasheq))
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


(define* (string->mask s)
    (match s
      [(or "S" "Shift")    'ShiftMask]
      [(or "C" "Control")  'ControlMask]
      [(or "M" "Meta")     (keysym-symbol->modifier 'XK-Meta-L)]
      [(or "A" "Alt")      (keysym-symbol->modifier 'XK-Alt-L)]
      [(or "Super")        (keysym-symbol->modifier 'XK-Super-L)]
      [(or "H" "Hyper")    (keysym-symbol->modifier 'XK-Hyper-L)]
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

(define* (string->keysym str)
  "Returns the corresponding keysym if str is a keyboard key string.
If it is a mouse key string, it returns a list of the corresponding number and type."
  ;; direct translation of sawfish/src/keys.c
  (match str
    ["Press1" (list 1 'ButtonPress)]
    ["Press2" (list 2 'ButtonPress)]
    ["Press3" (list 3 'ButtonPress)]
    ["Release1" (list 1 'ButtonRelease)]
    ["Release2" (list 2 'ButtonRelease)]
    ["Release3" (list 3 'ButtonRelease)]
    ["Move1"  (list 1 'ButtonMove)]
    ["Move2"  (list 2 'ButtonMove)]
    ["Move3"  (list 3 'ButtonMove)]
    
    [(or "SPC" "Space") XK-space]
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
    [else (XStringToKeysym str)]))

(define* (string->key-list str)
  "Turns a string like \"M-C-t\" into '(<key-sym for \"t\"> Mod1Mask ControlMask)"
  (define-values (mods key) (split-at-right (string-split str "-") 1))
  (cons (string->keysym (car key)) (map string->mask mods)))

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

(define* root-keymap
  "Keymap for the true root window."
  (make-keymap))

(define* global-keymap
  "General keymap for all windows. It is applied to the virtual roots, but not to the root window."
  (make-keymap))

(define* window-keymap 
  "Keymap for actions that depend on the window."
  (make-keymap))

(define* (keymap-set! keymap key proc #:grab-mode [grab-mode 'GrabModeAsync])
  (when (hash-ref keymap key #f)
    (dprintf "Warning: keybinding already defined ~a. Replacing old one.\n" 
            key))
  (hash-set! keymap key (list grab-mode proc)))

(define* (keymap-ref keymap key)
  (define res (hash-ref keymap key #f))
  (unless res
    (dprintf "Binding ~a not found\n" key))
  res)

(define* (call-binding keymap km-ev)
  "Looks for the callback corresponding to the given event, calls it if found.
  Returns true if the callback was found, false otherwise."
  (match-define (keymap-event window key-code/button type modifiers)
    km-ev)
  (let* ([key (make-keymap-key key-code/button type modifiers)]
         [mode/proc (keymap-ref keymap key)])
    (when mode/proc
      (dprintf "Binding ~a found, calling thunk\n" (cons key-code/button modifiers))
      ((second mode/proc) km-ev))
    (not (not mode/proc))))

(define* (call-keymaps-binding km-ev)
  ; TODO: TO REVISE!
  ; set window to input focus? or leave at pointer root?
  (define window (keymap-event-window km-ev))
  (or (call-binding root-keymap km-ev)
      (and window (call-binding window-keymap km-ev)) ; window can be the virtual root or the window (what about the true root?)
      (call-binding global-keymap km-ev)))

(define (window-apply-keymap window keymap)
  ; TODO: First remove all grabbings?
  (dprintf "window-apply-keymap ~a\n" window)
  (for ([(k v) keymap])
    (define value (first k)) ; button-num or key-code
    (define type (second k))
    (define modifiers (cddr k))
    (define grab-mode (first v))
    (case type
      [(KeyPress KeyRelease)
       (grab-key window value modifiers)]
      [(ButtonPress ButtonRelease)
       (grab-button window value modifiers '(ButtonPressMask ButtonReleaseMask)
                    #:grab-mode grab-mode)]
      [(ButtonMove)
       ; It's not clear what InputMasks are required, 
       ; and I couldn't find the right smallest combination
       ; So I just use the same (more general) combination as in Sawfish.
       (grab-button window value modifiers pointer-grab-events)]
      [else (error "Event type not found in window-apply-keymap:" type)])))

(define* (virtual-root-apply-keymaps window)
  (window-apply-keymap window global-keymap)
  (window-apply-keymap window window-keymap))

;@@ add-binding 
(define* (add-binding keymap str proc #:grab-mode [grab-mode 'GrabModeAsync])
  (define l (string->key-list str))
  (define mods (rest l))
  (match (first l)
    [(list button-num 'ButtonMove)
     (bind-motion keymap button-num mods proc)]
    [(list button-num type)
     (bind-button keymap button-num type mods proc #:grab-mode grab-mode)]
    [keysym
     (bind-keycode keymap (keysym->keycode keysym) mods proc)]))

(define* (add-bindings keymap . str/procs)
  "(add-binding keymap str1 proc1 str2 proc2 ...)
Like add-binding, but for several str procs pairs."
  (let loop ([str/procs str/procs])
    (unless (empty? str/procs)
    (cond [(empty? (rest str/procs))
           (error "add-bindings: Wrong number of arguments. Last arg:" (car str/procs))]
          [else
           (add-binding keymap (first str/procs) (second str/procs))
           (loop (cddr str/procs))]))))

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
(define* (grab-key window keycode [modifiers '()])
  "Register KeyPress events
The given combination is done for all combinations of the *-Lock modifiers."
  (for ([lock-mods all-lock-combinations])
    (XGrabKey (current-display) keycode 
              (append modifiers lock-mods)
              window
              #f 'GrabModeAsync 'GrabModeAsync)))

(define* (bind-keycode keymap keycode modifiers proc)
  (define key (make-keymap-key keycode 'KeyPress modifiers))
  (keymap-set! keymap key proc))

;; KeyPress only is used, because it seems that XGrabKey cares only about them.
(define* (bind-key keymap key-string modifiers proc)
  (define keycode (XKeysymToKeycode (current-display) (string->keysym key-string)))
  (bind-keycode keymap keycode modifiers proc)
  )

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
(define* (grab-pointer window [mask pointer-grab-events] 
                       #:cursor [cursor None]
                       #:confine-to [confine-to None])
  (XGrabPointer (current-display) window #f mask
                'GrabModeAsync 'GrabModeAsync confine-to cursor CurrentTime))

;; Also ungrabs buttons
;; http://tronche.com/gui/x/xlib/input/XUngrabPointer.html
(define* (ungrab-pointer)
  (XUngrabPointer (current-display) CurrentTime))
  
;; can also use AnyButton for button-num.
;; http://tronche.com/gui/x/xlib/input/XGrabButton.html
(define* (grab-button window button-num modifiers mask #:grab-mode [grab-mode 'GrabModeAsync])
  (for ([lock-mods all-lock-combinations])
    (XGrabButton (current-display) button-num 
                 (append modifiers lock-mods)
                 window #f mask
                 grab-mode 'GrabModeAsync None None)))

;; http://tronche.com/gui/x/xlib/input/XUngrabButton.html
(define* (ungrab-button window button-num modifiers)
  (XUngrabButton (current-display) button-num modifiers window))

;; button-num: integer in [1 5]
(define* (button-modifier button-num)
  (string->symbol (format "Button~aMask" button-num)))

(define* (bind-button keymap button-num type modifiers proc
                     #:grab-mode [grab-mode 'GrabModeAsync])
  (let ([key (make-keymap-key button-num type modifiers)])
    (keymap-set! keymap key proc #:grab-mode grab-mode)))
  
(define* (bind-motion keymap button-num modifiers proc)
  "Like bind-button, but for press, move and release events.
  The keymap-event-type is set to 'ButtonPress, 'ButtonMove and 'ButtonRelease accordingly."
  (define motion-mask (string->symbol (format "Button~aMotionMask" button-num)))
  (bind-button keymap button-num 'ButtonPress modifiers 
               (λ(ev)
                 (proc ev)
                 ; Warning: It may happen that if some call fails, the grab is not released!
                 (let ([root (pointer-root-window)] )
                   (dprintf "Grabbing pointer by ~a\n" root)
                   (grab-pointer root;(keymap-event-window ev)
                                 (cons motion-mask pointer-grab-events)
                                 ; do not let the pointer get out of the window, 
                                 ; avoids losing windows by dragging them
                                 #:confine-to root)) 
                 ))
  ; Use the global keymap to catch events event when the pointer is not in the window itself
  ; Warning: This implies that the keymap-event-window is #f, and may be the cause of unintuitive behaviors?
  (bind-button global-keymap button-num 'ButtonMove modifiers
               proc)
  (bind-button global-keymap button-num 'ButtonRelease modifiers
               (λ(ev)
                 (dprintf "Ungrabbing-pointer in bind-motion")
                 (ungrab-pointer) ; before proc, in case it fails
                 (proc ev)))
  )

;;; To put in a separate file?

(define* (motion-move-window)
  "Returns a procedure to use with bind-motion or add-binding(s)."
  (let ([x-ini #f] [y-ini #f] [x #f] [y #f] [window #f])
    (λ(ev)
      (case (keymap-event-type ev)
        [(ButtonPress)
         (set! window (keymap-event-window ev))
         (set!-values (x-ini y-ini) (mouse-event-position ev))
         (set!-values (x y) (window-position window))
         #;(printf "@ Start dragging window ~a (~a)\n" window (window-name window))]
        [(ButtonMove)
         (when (and window (window-user-movable? window))
           (define-values (x-ev y-ev) (mouse-event-position ev))
           (define x-diff (- x-ev x-ini))
           (define y-diff (- y-ev y-ini))
           #;(printf "@ Dragging window ~a...\n" (window-name (keymap-event-window ev)))
           (move-window window (+ x x-diff) (+ y y-diff)))]
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
         (when (and window (window-user-resizable? window))
           (define-values (x-ev y-ev) (mouse-event-position ev))
           (define x-diff (- x-ev x-ini))
           (define y-diff (- y-ev y-ini))
           (define new-w (max 1 (+ w x-diff)))
           (define new-h (max 1 (+ h y-diff)))
           (dprintf "Resizing window to ~a\n" (list window new-w new-h))
           (resize-window window new-w new-h))]))))

(define* (init-keymap)
  
  (dprintf "root keymap:\n")
  (pretty-print root-keymap)
  (dprintf "global keymap:\n")
  (pretty-print global-keymap)
  (dprintf "window keymap:\n")
  (pretty-print window-keymap)
  
  (window-apply-keymap (true-root-window) root-keymap) 
  ; but not the window-keymap! (otherwise virtual roots will be considered as subwindows)
  )
