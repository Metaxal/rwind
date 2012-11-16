#lang racket/base
(require (for-syntax racket/base)
         racket/dict
         racket/string
         racket/list
         racket/format
         racket/path
         racket/contract
         )

#| Ideas
- to speed up loading, once the doc is generated, it can be saved in a separate file
that can be loaded only on demand (or reconstructed if outdated).

- define*/contract
to support contracts (the contract should appear before the doc-string)
and also document them.

|#

(define doc-dict (make-hash))

(struct location (value))

(define (add-doc sym-name loc header contract doc-string)
  (dict-set! doc-dict sym-name
             ; In case the id is exported from different modules,
             ; append the different strings
             (append (dict-ref! doc-dict sym-name '())
                     (list (and loc (location loc))
                           header contract doc-string
                           ""))))

(define (try-unpair l)
  (if (pair? l) (car l) l))

(provide define/doc)
(define-syntax-rule (define/doc name loc header doc-string . body)
  (begin (define header . body)
         ;(printf "~a\n" 'name)
         (let* (; work around for some strange heisenbug (or mandelbug?) in Racket 
                ; (not reported yet)
                ; that sometimes generates pairs and sometimes not (with the same code!)
                [n (try-unpair 'name)]
                [l (try-unpair 'loc)]
                [h 'header #;(try-unpair 'header)]
                )
           (add-doc n l h #f doc-string))
         (provide name)))

(provide define*)
(define-syntax (define* stx)
  (with-syntax ([loc (syntax-source stx)
                     #;(syntax-source-module stx #t)])
    (syntax-case stx ()
      [(_ (name . args) doc-string/body0 body1 . body)
       (if (string? (syntax->datum #'doc-string/body0))
           #'(define/doc name loc (name . args) doc-string/body0 body1 . body)
           #'(define/doc name loc (name . args) #f doc-string/body0 body1 . body))]
      [(_ (name . args) . body)
       #'(define/doc name loc (name . args) #f . body)]
      [(_ name doc-string expr)
       #'(define/doc name loc name doc-string expr)]
      [(_ name expr)
       #'(define/doc name loc name #f expr)]
      )))
; Warning: Using ... does not seem to handle (define* (foo . args) ....) correctly.

; documentation given later

(provide define/doc/contract)
(define-syntax-rule (define/doc/contract name loc header contract doc-string . body)
  (begin (define/contract header contract . body)
         ;(printf "~a\n" 'name)
         (let* (; work around for some strange heisenbug (or mandelbug?) in Racket 
                ; (not reported yet)
                ; that sometimes generates pairs and sometimes not (with the same code!)
                [n (try-unpair 'name)]
                [l (try-unpair 'loc)]
                [h 'header #;(try-unpair 'header)]
                )
           (add-doc n l h 'contract doc-string))
         (provide name)))

(provide define*/contract)
(define-syntax (define*/contract stx)
  (with-syntax ([loc (syntax-source stx)
                     #;(syntax-source-module stx #t)])
    (syntax-case stx ()
      [(_ (name . args) cont doc-string/body0 body1 . body)
       (if (string? (syntax->datum #'doc-string/body0))
           #'(define/doc/contract name loc (name . args) cont doc-string/body0 body1 . body)
           #'(define/doc/contract name loc (name . args) cont #f doc-string/body0 body1 . body))]
      [(_ (name . args) cont . body)
       #'(define/doc/contract name loc (name . args) cont #f . body)]
      [(_ name cont doc-string expr)
       #'(define/doc/contract name loc name cont doc-string expr)]
      [(_ name cont expr)
       #'(define/doc/contract name loc name cont #f expr)]
      )))

(define* (doc-proc sym-name str)
  "Sets (or replaces) some documentation about sym-name."
  (let ([res (dict-ref doc-dict 'name #f)])
    (dict-set! doc-dict sym-name 
               (list (if res (car res) #f) str))))

(provide doc)
(define-syntax-rule (doc name str)
  (add-doc (try-unpair 'name) #f #f #f str))
(doc doc
     "(doc name str)
Macro to add some documentation on a provided form.")

(define* (more-doc-proc sym-name str)
  "Procedure form of 'more-doc'."
  (define res (dict-ref doc-dict sym-name #f))
  (if res
      (dict-set! doc-dict sym-name (append res (list str)))
      (error "more-doc-proc: ~a not found in the documentation dictionary." sym-name)))

(define-syntax-rule (more-doc name str)
  (more-doc-proc (try-unpair 'name) str))
(provide more-doc)
(doc more-doc
     "(more-doc name str)
Adds (appends) some documentation so sym-name. 
Useful to avoid adding big strings (like examples) in the definition of a procedure.")

(define (contract-expr? e)
  (and (list? e)
       (eq? (car e) '->)))

(define* (describe-string symbol)
  "Returns a description string of the function or variable if found."
  (define res (hash-ref doc-dict symbol #f))
  (if res
      (string-join 
       (filter values 
               (map (λ(s)(cond [(string? s) s]
                               [(contract-expr? s)
                                (let-values ([(in out) (split-at s (sub1 (length s)))])
                                   (string-append
                                    "  "
                                    (string-join (map ~a (append (rest in)
                                                                 (cons (first in) out))))))]
                               [(location? s) (format "From ~a:" 
                                                      (file-name-from-path (location-value s)))]
                               ;[(module-path-index? s) (~a (module-path-index-resolve s))]
                               [s (~a s)]
                               [else s]))
                    res))
       "\n")
      (format "Symbol not found: ~a\n" symbol)))


(doc define*
     "(define* id maybe-doc-string expr)
(define* (id args ...) maybe-doc-string body ...)

Like define but provides id, and adds maybe-doc-string to the documentation, retrievable with 'describe'.
In case id is a procedure, the header is also added to the documentation.")

(doc define*/contract
     "(define*/contract id contract maybe-doc-string expr)
(define*/contract (id args ...) contract maybe-doc-string body ...)

Like define* but with a contract right after the header (if a procedure) or the identifier (if a variable).")

(define* (describe symbol)
  "Prints a description of the function or variable if found."
  (display (describe-string symbol)))

(define* (symbol<=? s1 s2)
  (string<=? (symbol->string s1) (symbol->string s2)))

(define* (known-identifiers [sort? #t])
  "Returns the list of all known variable or procedure names."
  (define ids (dict-keys doc-dict))
  (if sort (sort ids symbol<=?) ids))

(define* (search-identifiers rx)
  "Returns the list of identifiers that match the regular expression rx."
  (filter (λ(s)(regexp-match rx (symbol->string s)))
          (known-identifiers)))


(module+ test
  (require racket/contract)
  
  (define*/contract (foo x y)
    (number? symbol? . -> . string?)
    "Turns a number and a symbol into a string."
    (format "~a ~a" x y))
  
  (describe 'foo)
  
  (define* bar "some bar" 'babar)
  (describe 'bar)
  
  (define*/contract baz symbol? "some other baz" 'babaz)
  (describe 'baz)
  ;(set! baz 3) ;exn
  )

