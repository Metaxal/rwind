#!/usr/bin/env racket
#lang racket/gui
; launcher.rkt
(require rwind/base
         rwind/doc-string
         rwind/util
         rwind/launcher-base)

; history cycling
(define hist-hash (make-hash `((prime . ,(launcher-history))
                               (previous . ,empty)
                               (current . ,empty)
                               (next . ,(launcher-history)))))

(define (hist-up!)
  (define prime (hash-ref hist-hash 'prime))
  (define current (hash-ref hist-hash 'current))
  (define previous (hash-ref hist-hash 'previous))
  (define next (hash-ref hist-hash 'next))
  (unless (empty? next)
    ; clear current contents
    (send launcher-editor select-all)
    (send launcher-editor clear)
    (if (empty? current)
        (hash-set*! hist-hash
                    'current (first prime)
                    'next (rest prime))
        (hash-set*! hist-hash
                    'previous (cons current previous)
                    'current (first next)
                    'next (rest next)))
    ; insert from history
    (send launcher-editor insert (hash-ref hist-hash 'current))))

(define (hist-down!)
  (define prime (hash-ref hist-hash 'prime))
  (define current (hash-ref hist-hash 'current))
  (define previous (hash-ref hist-hash 'previous))
  (define next (hash-ref hist-hash 'next))
  ; clear current contents
  (send launcher-editor select-all)
  (send launcher-editor clear)
  (unless (empty? previous)
    (hash-set*! hist-hash
                'next (cons current next)
                'current (first previous)
                'previous (rest previous))
    ; insert from history
    (send launcher-editor insert (hash-ref hist-hash 'current))))

(define launcher-dialog
  (new dialog%
       [label "Rwind Launcher"]
       [min-width 400]))

(define msg-hpanel
  (new horizontal-panel%
       [parent launcher-dialog]
       [alignment '(left center)]))

(define msg
  (new message%
       [parent msg-hpanel]
       [label "Please enter a command:"]))

(define mtxt%
  (class text%
    (super-new)
    
    (define/override (on-char evt)
      (define key-code (send evt get-key-code))
      (cond [(eq? key-code 'up) (hist-up!)]
            [(eq? key-code 'down) (hist-down!)]
            [(eq? key-code #\return) (enter-callback)]
            [(eq? key-code 'numpad-enter) (enter-callback)]
            [else (send this on-default-char evt)]))))

(define launcher-editor (new mtxt%))
(send launcher-editor change-style
      (make-object style-delta% 'change-size 10))

(define (enter-callback)
  (define plst (process (send launcher-editor get-text)))
  ; add to history
  (add-launcher-history! (send launcher-editor get-text))
  ; close the launcher window
  (send launcher-editor select-all)
  (send launcher-editor clear)
  (send launcher-dialog show #f)
  ; explicitly close input/output ports
  (close-input-port (first plst))
  (close-output-port (second plst))
  (close-input-port (fourth plst)))

(define launcher-ecanvas
  (new editor-canvas%
       [parent launcher-dialog]
       [editor launcher-editor]
       [min-height 45]
       [min-width 400]
       [style '(no-vscroll)]))

(send launcher-ecanvas focus)
(send launcher-dialog show #t)
