;;; (notasi json-writer) -- A small JSON writer.  See "JSON writing" in
;;; doc/design/05-typst-backend.md.
;;;
;;; Scheme values map to JSON as in guile-json: an alist is an object
;;; (keys in the given order), a vector is an array, the symbol `null'
;;; is null.  Output order is deterministic, which golden tests need.

(define-module (notasi json-writer)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (write-json
            json-string))

(define (json-error what value)
  (raise-exception
   (make-exception (make-error)
                   (make-exception-with-message
                    (string-append "cannot write as JSON: " what))
                   (make-exception-with-irritants (list value)))))

;;; ------------------------------------------------------------------
;;; Values

(define (json-number? x)
  (or (exact-integer? x)
      (and (real? x) (inexact? x)
           (not (nan? x)) (not (inf? x)))))

(define (scalar? x)
  "A value written on one line: a string, number, boolean or null."
  (or (string? x) (json-number? x) (boolean? x) (eq? x 'null)))

(define (object? x)
  (and (list? x) (every pair? x)))

(define (key->string key)
  (match key
    ((? symbol?) (symbol->string key))
    ((? string?) key)
    (_ (json-error "an object key must be a symbol or a string" key))))

(define (object-members alist)
  "ALIST's members as (KEY-STRING . VALUE), checking for repeated keys."
  (reverse
   (fold (lambda (member seen)
           (let ((key (key->string (car member))))
             (when (assoc key seen)
               (json-error "an object key is given twice" (car member)))
             (acons key (cdr member) seen)))
         '()
         alist)))

;;; ------------------------------------------------------------------
;;; Strings

(define (write-json-string str port)
  (write-char #\" port)
  (string-for-each
   (lambda (c)
     (match c
       (#\" (display "\\\"" port))
       (#\\ (display "\\\\" port))
       (#\newline (display "\\n" port))
       (#\return (display "\\r" port))
       (#\tab (display "\\t" port))
       (#\backspace (display "\\b" port))
       (#\page (display "\\f" port))
       ((? (lambda (c) (char<? c #\space)))
        (format port "\\u~4,'0x" (char->integer c)))
       (_ (write-char c port))))
   str)
  (write-char #\" port))

;;; ------------------------------------------------------------------
;;; Writing

(define (newline-indent port depth)
  (newline port)
  (display (make-string (* 2 depth) #\space) port))

(define (emit value port pretty? depth)
  "Write VALUE to PORT, at nesting DEPTH when PRETTY?."
  (define (sequence items write-item)
    ;; Items one per line (pretty) or separated by commas (compact).
    (let loop ((items items) (first? #t))
      (match items
        (() #t)
        ((item . rest)
         (unless first? (write-char #\, port))
         (when pretty? (newline-indent port (1+ depth)))
         (write-item item)
         (loop rest #f))))
    (when pretty? (newline-indent port depth)))
  (match value
    ('null (display "null" port))
    (#t (display "true" port))
    (#f (display "false" port))
    ((? string?) (write-json-string value port))
    ((? json-number?) (display (number->string value) port))
    (#() (display "[]" port))
    ((? vector?)
     (let ((items (vector->list value)))
       (write-char #\[ port)
       (if (and pretty? (every scalar? items))
           (let loop ((items items) (first? #t))
             (match items
               (() #t)
               ((item . rest)
                (unless first? (display ", " port))
                (emit item port pretty? depth)
                (loop rest #f))))
           (sequence items (lambda (item) (emit item port pretty? (1+ depth)))))
       (write-char #\] port)))
    (() (display "{}" port))
    ((? object?)
     (write-char #\{ port)
     (sequence (object-members value)
               (match-lambda
                 ((key . item)
                  (write-json-string key port)
                  (display (if pretty? ": " ":") port)
                  (emit item port pretty? (1+ depth)))))
     (write-char #\} port))
    (_ (json-error "not a JSON value" value))))

;;; ------------------------------------------------------------------
;;; Entry points

(define* (json-string value #:key (pretty? #t))
  "Return VALUE as JSON text, with no trailing newline.  Raise an
&error, naming the offending value, if VALUE can't be written."
  (call-with-output-string
    (lambda (port) (emit value port pretty? 0))))

(define* (write-json value #:optional (port (current-output-port))
                     #:key (pretty? #t))
  "Write VALUE as JSON to PORT, followed by a newline when PRETTY?.
Nothing is written if VALUE can't be: the &error is raised first."
  (display (json-string value #:pretty? pretty?) port)
  (when pretty? (newline port)))
