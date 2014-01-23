#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require rwind/policy/base
         rwind/doc-string
         rwind/util
         rwind/window
         rwind/workspace
         racket/class
         racket/list
         racket/match
         )

;;; Simple stacking policy
;;; This class defines a simple stacking policy for managing windows.

(define* policy-simple%
  (class policy%
    (init-field [selected-border-width 3]
                [normal-border-width 1]
                [selected-border-color "DarkRed"]
                [normal-border-color "DarkGreen"])
    
    (inherit relayout)

    (define bad-windows '())
    
    (define/public (current-workspace)
      (or (focus-workspace)
          (pointer-workspace)))
    
    (define/public (current-window)
      (or (focus-window)
          (pointer-window)))
    
    (define/public (give-focus [wk (current-workspace)])
      (activate-window (focus-window))
      #;(when wk
        (workspace-give-focus wk)))

    (define/override (on-map-request window new?)
      ; give the window the input focus (if viewable)
      (activate-window window))
        
    (define/override (activate-window window)
      ; Gives the focus to window.
      ; Remembers the window that has the focus
      ; so that switching between workspaces will restore the correct focus.
      ; Removes the old focus window border and adds a border around the new focus.
      (when window
        (define wk (find-window-workspace window))
        (when wk
          (define old-focus (focus-window))
          (define old-wk (and old-focus (find-window-workspace old-focus)))
          (when (and old-wk (not (window=? old-focus window)))
            (set-window-border-color old-focus normal-border-color)
            (set-window-border-width old-focus normal-border-width))
          (set-window-border-color window selected-border-color)
          (set-window-border-width window (if (net-window-fullscreen? window)
                                              0
                                              selected-border-width))
          (set-input-focus/raise window)
          (workspace-focus-in window))))
    
    ;; Gives the keyboard focus to the next window in the list of windows.
    ;; In (viewable-windows), the highest window is the last one (see XQueryTree).
    ;; xmonad uses a zipper for that (but requires to keep a window list in sync 
    ;; with the actual windows of the workspace)
    (define/override (activate-next-window)
      (define wf (focus-window))
      (when wf
        (lower-window (focus-window)))
      (define wl (viewable-windows))
      (unless (empty? wl)
        (activate-window (last wl))))
    
    (define/override (activate-previous-window)
      (define wl (viewable-windows))
      (unless (empty? wl)
        (activate-window (first wl))))
    
    (define/override (on-init-workspaces)
      (for* ([wk workspaces]
             [win (workspace-windows wk)])
        (set-window-border-color win normal-border-color)
        (set-window-border-width win normal-border-width))
      ; FIXME: Can't do this yet because crashes on BadWindow
      ; (the exception could be caught, but it seems to be a deeper problem)
      #;(relayout))
    
    (define/override (on-configure-request window value-mask
                                           x y width height border-width above stack-mode)
      ; honor configure request
      ; This should probably depend on the window type,
      ; e.g., splash windows should be centered
      ; fullscreen windows, etc.
      ; See the EWMH.
      ; This behavior specification belongs to the policy.
      (configure-window window value-mask x y width height border-width above stack-mode))
    

    ; TODO: _NET_WM_DESKTOP message:
    ; http://standards.freedesktop.org/wm-spec/1.3/ar01s05.html
    (define/override (on-client-message window atom fmt data)
     (cond [(atom=? atom _NET_WM_STATE)
            ; http://standards.freedesktop.org/wm-spec/wm-spec-1.3.html#id2731936
            (match-define (vector action at1 at2 source _other) data)
            (for ([at (list at1 at2)])
              (cond [(atom=? at _NET_WM_STATE_FULLSCREEN)
                     (define full? (net-window-fullscreen? window))
                     (cond [(and full? (or (= action 0) (= action 2)))
                            (dprintf "Switching back from fullscreen")
                            (delete-net-wm-state-property window at)
                            ; TODO:
                            #;(unmaximize-window window)]
                           [(and (not full?) (or (= action 1) (= action 2)))
                            (dprintf "Switching to fullscreen")
                            (add-net-wm-state-property window at)
                            (maximize-window window)])]))
            (relayout)]))

    (define/override (after-event)
      ; bad-windows are removed between events to avoid infinite loops 
      ; if removing them triggers a bad-window event
      (for ([w bad-windows])
        (define wk (find-window-workspace w))
        (when wk
          (dprintf "Removing bad window (~a) from its workspace\n" w)
          (remove-window-from-workspace w)))
      (set! bad-windows '()))
    
    (define/override (on-bad-window window)
      ; We just caught the error, but don't remove it now to avoid infinite loops
      ; One one computer, I had some uncaught bad-window errors after waking up from sleep mode
      ; (gnome-related problem?)
      (unless (member window bad-windows window=?)
        (set! bad-windows (cons window bad-windows))))
    
    (super-new)))
