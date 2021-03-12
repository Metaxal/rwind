#lang racket/base

;;; Author: Laurent Orseau
;;; License: LGPL

(require ; Need non-collection path when running with sudo
         "base.rkt"
         "doc-string.rkt"
         racket/system
         racket/list
         racket/contract
         racket/string
         racket/file
         racket/function)

(module+ test
  (require rackunit))

(define* (rwind-system . args)
  "Runs a command asynchronously."
  (system (string-append
           (string-join (map path-string->string args))
           " &")))

;; Todo: for macos, it should be a different path?
;; app-name: string?
;; (use bazaar/system find-config-path instead?)
(define* (find-user-config-dir app-name)
  "Returns the directory of application app-name (and may create it)."
  (let ([d (getenv "XDG_CONFIG_HOME")])
    (if (and d (directory-exists? d))
        (build-path d app-name)
        (let ([d (build-path (getenv "HOME") ".config" app-name)])
          (unless (directory-exists? d)
            (make-directory* d))
          d))))

(define* (find-user-config-file app-name file-name)
  "Returns the configuration-file path for application app-name (and may create the directory)."
  (build-path (find-user-config-dir app-name) file-name))

;; Uses the OS open facility
;; file: (or/c path? string?)
(define* (open-file file)
  "Tries to open file with xdg-open or mimeopen on Linux, and open on MacOS X."
  (case (system-type)
    [(macosx) (rwind-system "open" file)]
    [(unix) (cond [(find-executable-path "xdg-open")
                   => (λ(e)(rwind-system e file))]
                  [(find-executable-path "mimeopen")
                   => (λ(e)(rwind-system e "-L" "-n" file))]
                  )]))

;=================;
;=== Debugging ===;
;=================;

(define* (print-wait msg . args)
  "Prints a message followed by '...'"
  (apply printf msg args)
  (display "... ")
  (flush-output))

(define* (print-ok)
  "Prints 'Ok.'"
  (displayln "Ok.")
  (flush-output))

(define* debug-prefix
  "A parameter to control what string is printed before debug messages."
  (make-parameter ""))

(define* (dprintf fmt . args)
  "Like printf but only in debugging mode."
  (when (rwind-debug)
    (display (debug-prefix))
    (apply printf fmt args)
    (flush-output)))

(define* (dprint-wait . args)
  "Like print-wait, but for debugging."
  (when (rwind-debug)
    (display (debug-prefix))
    (apply print-wait args)))

(define* (dprint-ok)
  "Like print-ok, but for debugging."
  (when (rwind-debug)
    ; The prefix is written because in multithread there is a risk
    ; to lose this info if other threads write newlines in the middle of a "wait... ok."
    (display (debug-prefix))
    (print-ok)))

(define-syntax-rule (debug-var var)
  (dprintf "Var ~a: ~v\n" 'var var))
(provide debug-var)

(define-syntax-rule (debug-expr expr)
  (let ([res expr])
    (dprintf "Expr: ~a -> ~a\n" 'expr res)
    res))
(provide debug-expr)

;; I tried to use (call/debug proc . args) instead,
;; so that keyword arguments could be dealt with, but did not succeed.
(define-syntax-rule (call/debug proc args ...)
  (let ([largs (list args ...)])
    (dprintf "Call: ~a\n" (list* 'proc largs))
    (apply proc largs)))
(provide call/debug)
(doc call/debug
     "(call/debug proc args ...
Prints (proc args ...) before calling it."
     )

;===================;
;=== Compilation ===;
;===================;

#;(define* (compile-collection . collections)
  (dprint-wait (string-append* "Recompiling " (add-between collections "/")))
  (apply compile-collection-zos collections)
  (dprint-ok))


;; Tries to recompile RWind.
(define* (recompile-rwind)
  (system "raco setup -D rwind")
  #;(recompile (λ(e)
               (dprintf "Error: Something went wrong during compilation:\n")
               (displayln (exn-message e))
               (dprintf "Aborting procedure.\n"))))

;; Tries to recompile RWind.
;; Returns #t on success, #f otherwise (+ logging)
#;(define* (recompile-rwind)
  (with-handlers ([exn:fail?
                     (λ(e)
                       (dprintf "Error: Something went wrong during compilation:\n")
                       (displayln (exn-message e))
                       (dprintf "Aborting procedure.\n")
                       #f)])
      #;(compile-collection "x11")
      (compile-collection "rwind")
      #t))

(define* (full-command-line-arguments)
  "Returns the list of all the command line arguments that were used to start the current process.
(Currently Linux-specific)."
  ;; TODO: Use, through FFI:
  ;; GetCommandLineW() for Windows, and _NSGetArgc() and _NSGetArgv() for MacOS X.
  (string-split (file->string "/proc/self/cmdline") "\u0000"))

(define* (start-rwind-process)
  "Starts a new instance of the rwind process.
Warning: This assumes the process is started in the same working directory as the parent process."
  (dprint-wait "Running child")
  (define full-cmd-line (full-command-line-arguments))
  (debug-var full-cmd-line)
  (define-values (sp a b c)
    (call/debug
     apply subprocess
     (current-output-port) (current-input-port) (current-error-port)
     ;(find-executable-path (find-system-path 'exec-file))
     ;this-file-string
     (find-executable-path (first full-cmd-line))
     (rest full-cmd-line)
     ))
  (dprint-ok))

;============;
;=== Misc ===;
;============;

(define* (bound-value val lower-bound upper-bound)
  "Returns `val' if it is in [lower-bound upper-bound], or the nearest bound otherwise."
  (max lower-bound (min upper-bound val)))

(provide ++ -- += -=)

(define-syntax-rule (++ var)
  (set! var (+ var 1)))

(define-syntax-rule (-- var)
  (set! var (- var 1)))

(define-syntax-rule (+= var n)
  (set! var (+ var n)))

(define-syntax-rule (-= var n)
  (set! var (- var n)))

(provide cons!)
(define-syntax-rule (cons! elt list-var)
  (set! list-var (cons elt list-var)))

(provide L)
(define-syntax-rule (L args body ...)
  (lambda args body ...))
(doc L "Synonym for lambda.")

(provide L*)
(define-syntax-rule (L* body ...)
  (thunk* body ...))
(doc L* "Synonym for thunk*.")

(provide while)
(define-syntax-rule (while test body ...)
  (let loop ()
    (when test
      body ...
      (loop))))
(doc while "(while test body ...)")

(provide until)
(define-syntax-rule (until test body ...)
  (let loop ()
    (unless test
      body ...
      (loop))))
(doc until "(until test body ...)")

;; Returns #f if:
;; - the result of obj is #f,
;; - or any test applied to this result is #f
;; Otherwise returns the result of the last test applied to obj.
;; The `test's must be arity-1 predicates.
;; Usefull for struct attributes on objects that may be #f
(provide and=>)
(define-syntax-rule (and=> obj test ...)
  (let ([v obj])
    (and v (test v) ...)))

(module+ test
  (struct foo (x y))
  (define bar (foo 'a 8))
  (check-equal? (and=> bar foo-x) 'a)
  (check-false (and=> #f foo-x))
  (check-false (and=> 'a foo? foo-x)))


(define* (call/values->list proc . args)
  "Calls proc on args and turns the returned (multiple) values into a list."
  (call-with-values (λ()(apply proc args)) list))

(more-doc
 call/values->list
 "Example:
> (call/values->list values 1 2 3)
'(1 2 3)")

(define* cvl
  "Same as 'call/values->list'. Convenience procedure for the command line."
  call/values->list)

(define* (write-data/flush data [out (current-output-port)])
  "'write's the data to the output port, and flushes it.
To ensure that the data is really sent as is, a space is added before flushing.
(otherwise non-self-delimited data is not 'read' correctly, as the reader
waits for the delimiter to be read, and would thus hang)."
  (write data out)
  (display "  " out)
  (flush-output out))

#| write and non-delimited data
> (with-input-from-string
      (with-output-to-string (λ() (write 'x) (write 'y)))
    read)
'xy
> (with-input-from-string
      (with-output-to-string (λ() (write 'x) (print " ")(write 'y)))
    (λ() (list (read) (read) (read))))
'(x " " y)
> (with-input-from-string
      (with-output-to-string (λ() (write 'x) (display " ")(write 'y)))
    (λ() (list (read) (read) (read))))
'(x y #<eof>)
|#

(define (all-combinations-elt e cbs)
  (append cbs
          (map (λ(cb)(cons e cb))
               cbs)))

;; l: list
;; Returns the list of all the combinations of the elements of l,
;; including the empty list.
(define* (all-combinations l)
  "Returns the partition list of list l."
  (if (empty? l)
      '(())
      (all-combinations-elt (first l)
                            (all-combinations (rest l)))))


(module+ test
  (check-equal? (all-combinations '()) '(()))
  (check-equal? (all-combinations '(a b c))
                '(() (c) (b) (b c) (a) (a c) (a b) (a b c)))
  #;(all-combinations '(a b c d))
  )

(define* (path-string->string ps)
  (if (path? ps)
      (path->string ps)
      ps))

(define* (split-at-item l item [=? equal?])
  (let loop ([pre '()] [post l])
    (if (empty? post)
        (values l '())
        (let ([a (first post)])
          (if (=? a item)
              (values (reverse pre) post)
              (loop (cons a pre) (rest post)))))))

(module+ test
  (check-equal? (cvl split-at-item (range 5) 2)
                '((0 1) (2 3 4)))
  (check-equal? (cvl split-at-item (range 5) 10)
                '((0 1 2 3 4) ()))
  (check-equal? (cvl split-at-item (range 5) 0)
                '(()(0 1 2 3 4)))
  )

(define* (move-item-down l a [=? equal?])
  (define-values (pre post) (split-at-item l a =?))
  (cond [(empty? post) l]
        [(empty? (rest post))
         (cons a pre)]
        [else
         (append pre (list (second post)) (list a) (cddr post))]))

(module+ test
  (check-equal? (move-item-down (range 5) 2)
                '(0 1 3 2 4))
  (check-equal? (move-item-down (range 5) 0)
                '(1 0 2 3 4))
  (check-equal? (move-item-down (range 5) 4)
                '(4 0 1 2 3))
  (check-equal? (move-item-down (range 5) 10)
                '(0 1 2 3 4))
  )

(define* (move-item-up l item [=? equal?])
  (let loop ([pre '()] [post l])
    (if (empty? post)
        l
        (let ([a (first post)])
          (if (=? a item)
              (if (empty? pre)
                  (append (rest post) (list a))
                  (append (reverse (rest pre)) (list a (first pre)) (cdr post)))
              (loop (cons a pre) (rest post)))))))

(module+ test
  (check-equal? (move-item-up (range 5) 2)
                '(0 2 1 3 4))
  (check-equal? (move-item-up (range 5) 0)
                '(1 2 3 4 0))
  (check-equal? (move-item-up (range 5) 4)
                '(0 1 2 4 3))
  (check-equal? (move-item-up (range 5) 10)
                '(0 1 2 3 4))
  )

(define* regexp*? (or/c string? bytes? regexp? byte-regexp?))

(define* 0+-integer? exact-nonnegative-integer?)
(define* 1+-integer? exact-positive-integer?)
