;;; (notasi reader) -- Read notation (.nts) into a piece.
;;; See doc/design/03-reader.md.
;;;
;;; v1 (four slices): the public interface, &notasi-syntax-error, forms,
;;; scales, stroke sets, instruments, parts and templates.  Iteration 2,
;;; slice 1 (feat/music-syntax): `:key value' options, (part INSTRUMENT
;;; :name NAME ...), degrees with :alias, :display and :damped, no
;;; instrument options, no `·' and no top-level groups.  `colotomy',
;;; `pattern' and `score' raise `not-implemented' until their slices.

(define-module (notasi reader)
  #:use-module (notasi piece)
  #:use-module (notasi expand)
  #:use-module (notasi style)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:export (read-piece-file
            read-piece-port
            read-piece-string

            &notasi-syntax-error
            notasi-syntax-error?
            notasi-syntax-error-kind
            notasi-syntax-error-file
            notasi-syntax-error-line
            notasi-syntax-error-part
            notasi-syntax-error-time
            notasi-syntax-error-uses))

;;; ------------------------------------------------------------------
;;; The condition type

(define &notasi-syntax-error
  (make-exception-type '&notasi-syntax-error &error
                       '(kind file line part time uses)))

(define make-notasi-syntax-error
  (record-constructor &notasi-syntax-error))

(define notasi-syntax-error?
  (exception-predicate &notasi-syntax-error))

(define-syntax-rule (define-field-accessors (accessor field) ...)
  (begin
    (define accessor
      (exception-accessor &notasi-syntax-error
                          (record-accessor &notasi-syntax-error 'field)))
    ...))

(define-field-accessors
  (notasi-syntax-error-kind kind)
  (notasi-syntax-error-file file)
  (notasi-syntax-error-line line)
  (notasi-syntax-error-part part)
  (notasi-syntax-error-time time)
  (notasi-syntax-error-uses uses))

;;; The file being read, or #f for a string or port.  Set once per read,
;;; so error reports don't need it passed through every check.
(define current-source-file (make-parameter #f))

(define (raise-syntax-error kind line part time uses fmt args)
  "Raise a &notasi-syntax-error of KIND at LINE (1-based, or #f) in the
current source file, for PART at TIME (pulses, or #f) through the
pattern USES, with a message built from FMT and ARGS."
  (let ((file (current-source-file)))
    (raise-exception
     (make-exception
      (make-notasi-syntax-error kind file line part time uses)
      (make-exception-with-message
       (format #f "~a~@[:~a~]: ~?" (or file "<string>") line fmt args))))))

(define (syntax-error kind line fmt . args)
  "Raise a &notasi-syntax-error of KIND at LINE, not tied to a part."
  (raise-syntax-error kind line #f #f '() fmt args))

(define (mixed-number x)
  "X as a musician writes it: 3/2 is \"1 1/2\"."
  (let* ((whole (floor x))
         (rest (- x whole)))
    (string-append (number->string whole)
                   (if (zero? rest) "" (string-append " " (number->string rest))))))

;;; The piece's meter while its parts are read: (CYCLE . PICKUP), or #f
;;; without a colotomy.  Positions in messages are written with it.
(define current-meter (make-parameter #f))

(define (time->text time)
  "TIME as a position: \"cycle C, pulse P\" with a colotomy (the pickup
is cycle 0), else \"pulse P\" (TIME 0 is pulse 1), fractions as mixed
numbers: \"pulse 2 1/2\"."
  (match (current-meter)
    (#f (string-append "pulse " (mixed-number (+ time 1))))
    ((cycle . pickup)
     (let* ((t (- time pickup))
            (c (floor (/ t cycle))))
       (string-append "cycle " (number->string (+ c 1))
                      ", pulse " (mixed-number (+ (- t (* c cycle)) 1)))))))

(define (part-error kind line part time fmt . args)
  "Raise a &notasi-syntax-error of KIND about PART at TIME (pulses, or
#f).  The message names the part and, when given, the pulse."
  (raise-syntax-error kind line part time '()
                      (string-append "part `~a'~@[, ~a~]: " fmt)
                      (cons* part (and time (time->text time)) args)))

;;; ------------------------------------------------------------------
;;; Step 1: read forms

(define (read-error? e)
  ;; exception-kind returns '%exception for conditions with no kind.
  (eq? (exception-kind e) 'read-error))

(define (with-notation-read-options thunk)
  "Call THUNK with Guile's `keywords' and `r7rs-symbols' read options
off, so that `:key', `|' and `||' read as ordinary symbols, and restore
the caller's read options afterwards, also when THUNK raises."
  (let ((saved (read-options)))
    (dynamic-wind
      (lambda ()
        (read-set! keywords #f)
        (read-disable 'r7rs-symbols))
      thunk
      (lambda () (read-options saved)))))

(define (read-forms port)
  "Read every datum from PORT.  Return a list of (DATUM . LINE), with
1-based lines: a list's own line, or for an atom the line where it ends."
  (with-notation-read-options (lambda () (read-all-forms port))))

(define (read-all-forms port)
  (define (next)
    (guard (e ((read-error? e)
               (syntax-error 'read-error (1+ (port-line port))
                             "cannot read the notation (~a)"
                             (exception-message-text e))))
      (read port)))
  (let loop ((forms '()))
    (let ((datum (next)))
      (if (eof-object? datum)
          (reverse forms)
          (loop (cons (cons datum (datum-line datum port)) forms))))))

(define (call-with-source-file path proc)
  "Call PROC with a port open on PATH.  The port is named PATH exactly,
so Guile's own read errors name the file as the user wrote it, not
relative to some %load-path entry."
  (call-with-input-file path
    (lambda (port)
      (set-port-filename! port path)
      (proc port))))

(define (datum-line datum port)
  (match (and (pair? datum) (source-property datum 'line))
    ((? integer? line) (1+ line))
    (_ (1+ (port-line port)))))

(define (exception-message-text e)
  "The text of Guile's read error E, with its format arguments applied."
  (match (exception-args e)
    ((_ fmt args . _) (apply format #f fmt (or args '())))
    (_ "read error")))

;;; ------------------------------------------------------------------
;;; Step 2: dispatch

(define known-heads
  '(piece use scale strokes instrument colotomy pattern part score))

;;; Known forms that later slices of iteration 2 build.
(define not-yet-heads '())

(define (check-form form)
  "Raise an error unless FORM, a (DATUM . LINE) pair, is a proper list
with a known head symbol."
  (match form
    (((? pair? datum) . line)
     (unless (list? datum)
       (syntax-error 'improper-form line
                     "a form contains a lone `.'; use `-' for a rest"))
     (when (eq? (car datum) 'group)
       (syntax-error 'group-outside-score line
                     "a group is written inside a score: (score NAME (group \"LABEL\" PART ...))"))
     (unless (memq (car datum) known-heads)
       (syntax-error 'unknown-form line "unknown form `~s'" (car datum))))
    ((datum . line)
     (syntax-error 'unknown-form line "~s is not a form" datum))))

;;; ------------------------------------------------------------------
;;; Step 3: the piece form is present, first and only once

(define (piece-form? form)
  (eq? (car (car form)) 'piece))

(define (find-piece-form forms)
  "Return the (DATUM . LINE) of the only `piece' form, which must be the
first form."
  (match (filter piece-form? forms)
    (() (syntax-error 'missing-piece #f "no (piece TITLE ...) form"))
    ((first . rest)
     (unless (eq? first (car forms))
       (syntax-error 'piece-not-first (cdr (car forms))
                     "the (piece ...) form must come first"))
     (match rest
       (() first)
       (((_ . line) . _)
        (syntax-error 'duplicate-piece line "a second (piece ...) form"))))))

;;; ------------------------------------------------------------------
;;; Step 4: options, written `:key value' (ADR 0026)

(define (key? x)
  "Is X an option key: a symbol of `:' followed by a letter?"
  (and (symbol? x)
       (let ((s (symbol->string x)))
         (and (> (string-length s) 1)
              (char=? (string-ref s 0) #\:)
              (char-alphabetic? (string-ref s 1))))))

(define (key-name key)
  (string->symbol (substring (symbol->string key) 1)))

(define (list-line datum fallback)
  "The 1-based line of DATUM if it is a list read with a position, else
FALLBACK.  Atoms carry no position."
  (match (and (pair? datum) (source-property datum 'line))
    ((? integer? line) (1+ line))
    (_ fallback)))

(define (split-options items line)
  "Split ITEMS into (OPTIONS . BODY): the leading `:key value' pairs, as
a list of (KEY . VALUE) in order, and the rest.  A key with no value is
a `bad-option' at LINE."
  (let loop ((items items) (options '()))
    (match items
      (((? key? key))
       (syntax-error 'bad-option line "option `~a' needs a value" key))
      (((? key? key) (? key? next) . _)
       (syntax-error 'bad-option line
                     "option `~a' needs a value, but `~a' follows it" key next))
      (((? key? key) value . rest)
       (loop rest (cons (cons key value) options)))
      (body (cons (reverse options) body)))))

(define (reject-keys body line)
  "Raise `option-after-body' if a key appears in BODY: options come
before the body."
  (match (find key? body)
    (#f #t)
    (key (syntax-error 'option-after-body line
                       "option `~a' comes after the music; options go first"
                       key))))

(define (check-options options spec form-word line)
  "Check OPTIONS, a list of (KEY . VALUE), against SPEC, a list of
(NAME VALID? . WHAT-IT-MUST-BE).  Return an alist from NAME to value.
BAD, when given, is called instead of `bad-option' for a wrong value."
  (reverse
   (fold (match-lambda*
           (((key . value) seen)
            (let ((name (key-name key)))
              (match (assq name spec)
                (#f (syntax-error 'unknown-option line
                                  "~a has no option `~a'" form-word key))
                ((_ valid? . what)
                 (when (assq name seen)
                   (syntax-error 'duplicate-option line
                                 "option `~a' given twice" key))
                 (unless (valid? value)
                   (syntax-error 'bad-option line "`~a' must be ~a, not ~s"
                                 key what value))
                 (acons name value seen))))))
         '() options)))

(define (positive-whole-number? x)
  (and (exact-integer? x) (positive? x)))

;;; The options a form accepts: (NAME VALID? . WHAT-IT-MUST-BE).
(define piece-options
  `((colotomy ,(lambda (v) (and (symbol? v) (not (key? v)))) . "a colotomy's name")
    (pickup ,(lambda (v) (and (number? v) (exact? v))) . "a whole number of pulses")))

(define part-options
  `((name ,(lambda (v) (and (symbol? v) (not (key? v)))) . "a name")))

(define (parse-piece-form form)
  "The title and options of the `piece' form FORM, a (DATUM . LINE), as
(TITLE . OPTIONS), OPTIONS an alist."
  (match form
    ((('piece (? string? title) . items) . line)
     (match (split-options items line)
       ((options . ())
        (cons title (check-options options piece-options "a piece" line)))
       ((_ . (item . _))
        (syntax-error 'bad-option line
                      "after the title, a piece takes only options, not ~s"
                      item))))
    ((_ . line)
     (syntax-error 'bad-title line
                   "the piece needs a title string: (piece \"Title\" ...)"))))

;;; ------------------------------------------------------------------
;;; Selecting forms

(define (form-head form)
  (car (car form)))

(define (forms-with-heads forms heads)
  "The forms in FORMS, a list of (DATUM . LINE), whose head is in HEADS,
in file order."
  (filter (lambda (form) (memq (form-head form) heads)) forms))

(define (location line)
  (make-source-location (current-source-file) line))

(define (check-not-implemented forms)
  "Raise `not-implemented' at the first form that a later slice builds."
  (match (forms-with-heads forms not-yet-heads)
    (() #t)
    ((((head . _) . line) . _)
     (syntax-error 'not-implemented line
                   "the `~a' form is not supported yet" head))))

;;; ------------------------------------------------------------------
;;; Item 6: the shape and options of scale, strokes, instrument and part
;;; forms

(define definition-heads '(scale strokes instrument colotomy pattern part score))

(define (note-name? x)
  (and (symbol? x) (not (key? x))))

(define (check-set-shape form)
  "A `scale' or `strokes' FORM: a name, no options, then its degrees."
  (match form
    (((head (? note-name?) . items) . line)
     (match (split-options items line)
       ((() . ()) (bad-set-form head line))
       ((() . degrees) (reject-keys degrees line))
       ((options . _)
        (check-options options '()
                       (if (eq? head 'scale) "a scale" "a stroke set") line))))
    (((head . _) . line) (bad-set-form head line))))

(define (bad-set-form head line)
  (if (eq? head 'scale)
      (syntax-error 'bad-form line
                    "a scale needs a name and its degrees: (scale NAME DEGREE ...)")
      (syntax-error 'bad-form line
                    "a stroke set needs a name and its strokes: (strokes NAME STROKE ...)")))

(define (split-part form)
  "The (INSTRUMENT OPTIONS . TOKENS) of a well-formed `part' FORM."
  (match form
    ((('part instrument . items) . line)
     (match (split-options items line)
       ((options . tokens)
        (cons* instrument (check-options options part-options "a part" line)
               tokens))))))

(define (part-form-name form)
  "The name of the `part' FORM: its :name, else its instrument's name."
  (match (split-part form)
    ((instrument options . _) (or (assq-ref options 'name) instrument))))

(define (named-part-form? form)
  (match (split-part form)
    ((_ options . _) (and (assq 'name options) #t))))

(define (colotomy-part-form? x)
  (match x
    (((? note-name?) (? note-name?) _ ..1) #t)
    (_ #f)))

(define (check-colotomy-shape form)
  "A `colotomy' FORM: a name, a cycle length in pulses, no options, then
its parts, (PART INSTRUMENT TOKEN ...)."
  (match form
    ((('colotomy (? note-name?) (? positive-whole-number?) . items) . line)
     (match (split-options items line)
       ((() . (? pair? parts))
        (reject-keys parts line)
        (unless (every colotomy-part-form? parts)
          (bad-colotomy-form line)))
       ((() . ()) (bad-colotomy-form line))
       ((options . _) (check-options options '() "a colotomy" line))))
    ((_ . line) (bad-colotomy-form line))))

(define (bad-colotomy-form line)
  (syntax-error 'bad-form line
                "a colotomy needs a name, its length in pulses and its parts: (colotomy NAME LENGTH (PART INSTRUMENT TOKEN ...) ...)"))

(define pattern-options
  `((instrument ,(lambda (v) (and (symbol? v) (not (key? v)))) . "an instrument's name")
    (short ,string? . "a string")
    (long ,string? . "a string")))

(define (pattern-name? x)
  (and (symbol? x)
       (let ((s (symbol->string x)))
         (not (or (string-prefix? ":" s) (string-prefix? "@" s))))))

(define (split-pattern form)
  "The (NAME OPTIONS . TOKENS) of a well-formed `pattern' FORM."
  (match form
    ((('pattern name . items) . line)
     (match (split-options items line)
       ((options . tokens)
        (cons* name (check-options options pattern-options "a pattern" line)
               tokens))))))

(define (check-pattern-shape form)
  (match form
    ((('pattern (? pattern-name?) . items) . line)
     (match (split-pattern form)
       ((_ _ . ())
        (syntax-error 'bad-form line
                      "a pattern needs its music: (pattern NAME :instrument INSTRUMENT TOKEN ...)"))
       ((_ _ . tokens) (reject-keys tokens line))))
    ((_ . line)
     (syntax-error 'bad-form line
                   "a pattern needs a name (not starting with : or @) and its music: (pattern NAME :instrument INSTRUMENT TOKEN ...)"))))

(define (member-form? x)
  (match x
    ((? note-name?) #t)
    (((? note-name?) . items)
     (and (list? items)
          (match (split-member-options items)
            (#f #f)
            (_ #t))))
    (_ #f)))

(define (split-member-options items)
  "A member's options, `:label STRING', as an alist, or #f."
  (match items
    (() '())
    ((':label (? string? label)) `((label . ,label)))
    (_ #f)))

(define (group-form? x)
  "Is X the shape of a group?  Its options are checked with the score's
(check 16), so a key with no value, or a key among the members, passes
here."
  (match x
    (('group (? string?) . items)
     (and (list? items)
          (match (split-options-quietly items)
            (#f #t)
            ((_ . (? pair? members))
             (every (lambda (m) (or (key? m) (member-form? m))) members))
            (_ #f))))
    (_ #f)))

(define (split-options-quietly items)
  "Like `split-options', but #f instead of an error for a key with no
value."
  (let loop ((items items) (options '()))
    (match items
      (((? key?)) #f)
      (((? key?) (? key?) . _) #f)
      (((? key? key) value . rest) (loop rest (cons (cons key value) options)))
      (body (cons (reverse options) body)))))

(define (check-score-shape form)
  "A `score' FORM: a name, options, then its groups."
  (match form
    ((('score (? note-name?) . items) . line)
     (match (split-options items line)
       ((_ . (? pair? groups))
        (reject-keys groups line)
        (for-each (lambda (group)
                    (unless (group-form? group)
                      (syntax-error 'bad-form (list-line group line)
                                    "a group is (group \"LABEL\" :key value ... PART ...), not ~s"
                                    group)))
                  groups))
       (_ (bad-score-form line))))
    ((_ . line) (bad-score-form line))))

(define (bad-score-form line)
  (syntax-error 'bad-form line
                "a score needs a name and its groups: (score NAME :key value ... (group \"LABEL\" PART ...) ...)"))

(define (check-definition-shape form)
  (match form
    ((('colotomy . _) . _) (check-colotomy-shape form))
    ((('score . _) . _) (check-score-shape form))
    ((('pattern . _) . _) (check-pattern-shape form))
    ((((or 'scale 'strokes) . _) . _) (check-set-shape form))
    ((('instrument (? note-name?) (? note-name?) (? note-name?) ..1) . _) #t)
    ((('part (? note-name?) . items) . line)
     (match (split-part form)
       ((_ _ . ())
        (syntax-error 'bad-form line
                      "a part needs its music: (part INSTRUMENT TOKEN ...)"))
       ((_ _ . tokens) (reject-keys tokens line))))
    ((('instrument . _) . line)
     (syntax-error 'bad-form line
                   "an instrument needs a name, a scale or stroke set, and its notes, and takes no options: (instrument NAME SCALE NOTE ...)"))
    ((('part . _) . line)
     (syntax-error 'bad-form line
                   "a part needs an instrument and its music: (part INSTRUMENT :name NAME TOKEN ...)"))))

;;; ------------------------------------------------------------------
;;; Item 7: duplicate definitions.  Scales and stroke sets share one set
;;; of names, since an instrument refers to either; instruments and parts
;;; each have their own.  A part's name is its :name, else its
;;; instrument's name.

(define (namespace head)
  (match head
    ((or 'scale 'strokes) 'scale)
    (other other)))

(define (definition-name form)
  (match form
    ((('part . _) . _) (part-form-name form))
    (((_ name . _) . _) name)))

(define (same-instrument-unnamed? a b)
  "Are the `part' forms A and B on one instrument, one of them without
:name?  Item 13 reports that as `parts-need-names' (ADR 0027)."
  (and (eq? (car (split-part a)) (car (split-part b)))
       (not (and (named-part-form? a) (named-part-form? b)))))

(define (check-duplicates definitions)
  "Raise on the second definition of a name in DEFINITIONS, in file
order.  Two parts on one instrument, one without :name, are left to
item 13."
  (fold (lambda (form seen)
          (let* ((head (form-head form))
                 (key (cons (namespace head) (definition-name form))))
            (match (assoc key seen)
              (#f #t)
              ((_ . earlier)
               (unless (and (eq? head 'part)
                            (same-instrument-unnamed? earlier form))
                 (syntax-error 'duplicate-definition (cdr form)
                               "`~a' is already defined in this file"
                               (definition-name form)))))
            (acons key form seen)))
        '()
        definitions))

(define (check-part-names form earlier)
  "Item 13: the `part' FORM against EARLIER, the part forms before it."
  (when (any (lambda (other) (same-instrument-unnamed? other form)) earlier)
    (syntax-error 'parts-need-names (cdr form)
                  "instrument `~a' has two parts; give them names with :name"
                  (car (split-part form)))))

;;; ------------------------------------------------------------------
;;; Item 5 (step 3): templates.  A definition is (FILE . FORM): the file
;;; it came from (#f for a string or port) and its (DATUM . LINE).

(define template-heads '(scale strokes instrument colotomy pattern use))
(define merged-heads '(scale strokes instrument colotomy pattern))

(define (definition-key form)
  (match form
    (((head name . _) . _) (cons (namespace head) name))))

(define (use-target form)
  "The template a `use' FORM names: a symbol or a string."
  (match form
    ((('use (and target (or (? symbol?) (? string?)))) . _) target)
    ((_ . line)
     (syntax-error 'bad-form line
                   "a use names one template: (use NAME) or (use \"file.nts\")"))))

(define (check-use-forms forms)
  "Item 5.1: every `use' in FORMS comes before the other forms (after
`piece'), then each names one template."
  (let loop ((forms forms) (after-other? #f))
    (match forms
      (() #t)
      ((form . rest)
       (match (form-head form)
         ('piece (loop rest after-other?))
         ('use
          (when after-other?
            (syntax-error 'use-not-first (cdr form)
                          "a use must come before the definitions, parts and scores"))
          (loop rest after-other?))
         (_ (loop rest #t))))))
  (for-each use-target (forms-with-heads forms '(use))))

(define (template-path target dir)
  "The file TARGET names, or #f if there is none.  A name is looked up
as templates/NAME.nts along %load-path; a string is relative to DIR."
  (match target
    ((? symbol?)
     (search-path %load-path
                  (string-append "templates/" (symbol->string target) ".nts")))
    ((? string?)
     ;; Inside the current directory, the path is the string itself, so
     ;; messages show `my-gamelan.nts', not `./my-gamelan.nts'.
     (let ((path (if (or (absolute-file-name? target) (string=? dir "."))
                     target
                     (in-vicinity dir target))))
       (and (file-exists? path)
            (not (file-is-directory? path))
            path)))))

(define (use-template form dir chain table)
  "Item 5.2: the definitions the template named by the `use' FORM makes
visible.  CHAIN holds the canonical paths being loaded; TABLE maps the
canonical path of each template already loaded to its definitions."
  (let* ((line (cdr form))
         (target (use-target form))
         (path (template-path target dir))
         (id (and path (canonicalize-path path))))
    (cond
     ((and id (member id chain))
      (syntax-error 'template-cycle line
                    "template ~s uses itself, through a cycle of uses" target))
     ((not path)
      (match target
        ((? symbol?)
         (syntax-error 'template-not-found line
                       "no template called `~a' (looked for templates/~a.nts)"
                       target target))
        (_ (syntax-error 'template-not-found line
                         "no template file ~s in ~a" target dir))))
     ((hash-ref table id))
     (else
      (let ((definitions (load-template path (cons id chain) table)))
        (hash-set! table id definitions)
        definitions)))))

(define (load-template path chain table)
  "Read the template at PATH and return the definitions it makes visible."
  (parameterize ((current-source-file path))
    (let ((forms (call-with-source-file path read-forms)))
      (for-each check-form forms)
      (match (find (lambda (form) (not (memq (form-head form) template-heads)))
                   forms)
        (#f #t)
        ((datum . line)
         (syntax-error 'not-in-template line
                       "a template holds only scale, strokes, instrument, colotomy, pattern and use forms, not `~a'"
                       (car datum))))
      (check-not-implemented forms)
      (file-definitions forms (dirname path) chain table))))

(define (own-keys forms)
  "The keys of the scales, stroke sets and instruments FORMS define."
  (filter-map (match-lambda
                ((((? symbol? head) (? symbol? name) . _) . _)
                 (and (memq head merged-heads)
                      (cons (namespace head) name)))
                (_ #f))
              forms))

(define (merge-templates lists keys)
  "Item 5.3: join the definitions in LISTS, one list per `use', in
order.  A definition reached twice keeps its first place; one whose key
is in KEYS (defined by the file itself) is dropped; any other name
defined twice is a `template-conflict'."
  (reverse
   (fold (lambda (definition merged)
           (let ((key (definition-key (cdr definition))))
             (cond
              ((memq definition merged) merged)
              ((member key keys) merged)
              ((find (lambda (other)
                       (equal? key (definition-key (cdr other))))
                     merged)
               => (lambda (first) (template-conflict definition first)))
              (else (cons definition merged)))))
         '()
         (concatenate lists))))

(define (template-conflict definition first)
  (match definition
    ((file . ((_ name . _) . line))
     (parameterize ((current-source-file file))
       (syntax-error 'template-conflict line
                     "`~a' is also defined in ~a; two templates used by one file can't define the same name"
                     name (or (car first) "<string>"))))))

(define (file-definitions forms dir chain table)
  "Items 5 to 7 for one file's FORMS: load its templates, check its own
definitions, and return the scales, stroke sets and instruments visible
from it, as definitions in merged order."
  (check-use-forms forms)
  (let* ((lists (map (lambda (form) (use-template form dir chain table))
                     (forms-with-heads forms '(use))))
         (merged (merge-templates lists (own-keys forms)))
         (definitions (forms-with-heads forms definition-heads)))
    (for-each check-definition-shape definitions)
    (check-duplicates definitions)
    (append merged
            (map (lambda (form) (cons (current-source-file) form))
                 (forms-with-heads forms merged-heads)))))

;;; ------------------------------------------------------------------
;;; Item 8: scales and stroke sets

(define (ascii-digit? c)
  (and (char<=? #\0 c) (char<=? c #\9)))

(define (ends-in-digit? name)
  (let ((s (symbol->string name)))
    (and (not (string-null? s))
         (ascii-digit? (string-ref s (1- (string-length s)))))))

(define (alias-list? v)
  (or (note-name? v)
      (and (pair? v) (list? v) (every note-name? v))))

;;; A degree's options.  A wrong value is a `bad-degree', not a
;;; `bad-option' (03, "Definitions").
(define degree-options
  `((alias ,alias-list? . "a name or a list of names")
    (display ,string? . "a string")
    (damped ,string? . "a string")))

(define reserved-names '(rep @))

(define (parse-degree datum set-line)
  "Build a degree record from DATUM: a name, or (NAME :key value ...).  A
bare name has no position, so it takes SET-LINE, its scale's line."
  (let ((line (list-line datum set-line)))
    (define (bad fmt . args)
      (apply syntax-error 'bad-degree line fmt args))
    (match datum
      ((? note-name? name)
       (make-degree name '() (symbol->string name) #f (location line)))
      (((? note-name? name) . items)
       (match (split-options items line)
         ((options . ())
          (for-each (match-lambda
                      ((key . value)
                       (match (assq (key-name key) degree-options)
                         ((_ valid? . what)
                          (unless (valid? value)
                            (bad "`~a' must be ~a, not ~s" key what value)))
                         (#f #t))))
                    options)
          (let ((opts (check-options options degree-options "a degree" line)))
            (make-degree name
                         (match (assq-ref opts 'alias)
                           (#f '())
                           ((? symbol? a) (list a))
                           (names names))
                         (or (assq-ref opts 'display) (symbol->string name))
                         (assq-ref opts 'damped)
                         (location line))))
         ((_ . (item . _))
          (bad "a degree is NAME or (NAME :alias A :display \"TEXT\" :damped \"TEXT\"), not ~s"
               datum))))
      (_ (bad "a degree must be a name or (NAME :key value ...), not ~s" datum)))))

(define (build-scale form)
  "Build a scale record from a `scale' or `strokes' FORM."
  (match form
    (((head name . data) . set-line)
     (let ((pitched? (eq? head 'scale)))
       (let loop ((data data) (used '()) (degrees '()))
         (match data
           (()
            (make-scale name (reverse degrees) pitched? (location set-line)))
           ((datum . rest)
            (let* ((degree (parse-degree datum set-line))
                   (line (source-location-line (degree-location degree))))
              (for-each
               (lambda (n)
                 (when (memq n reserved-names)
                   (syntax-error 'reserved-name line
                                 "`~a' can't name a degree or stroke: it is reserved"
                                 n)))
               (degree-names degree))
              (when pitched?
                (for-each
                 (lambda (n)
                   (when (ends-in-digit? n)
                     (syntax-error 'degree-ends-in-digit line
                                   "scale `~a': `~a' ends in a digit, which would be read as an octave"
                                   name n)))
                 (degree-names degree)))
              (loop rest
                    (fold (lambda (n used)
                            (when (memq n used)
                              (syntax-error 'duplicate-degree line
                                            "`~a' is used twice in `~a'" n name))
                            (cons n used))
                          used
                          (degree-names degree))
                    (cons degree degrees))))))))))

;;; ------------------------------------------------------------------
;;; Item 9: instruments

(define (name-table scale)
  "An alist from every degree name and alias of SCALE to its index."
  (append-map (lambda (degree i)
                (map (lambda (n) (cons n i)) (degree-names degree)))
              (scale-degrees scale)
              (iota (length (scale-degrees scale)))))

(define (resolve-note name scale table instrument line)
  "The note record for NAME on INSTRUMENT, whose scale is SCALE."
  (define (canonical i)
    (degree-name (list-ref (scale-degrees scale) i)))
  (define (unknown)
    (syntax-error 'unknown-note line
                  "instrument `~a': `~a' is not a note of `~a'"
                  instrument name (scale-name scale)))
  (if (scale-pitched? scale)
      (match (split-octave name)
        (#f (if (assq name table)
                (syntax-error 'unknown-note line
                              "instrument `~a': `~a' needs an octave number, e.g. ~a1"
                              instrument name name)
                (unknown)))
        ((degree . octave)
         (match (assq degree table)
           (#f (unknown))
           ((_ . i)
            (make-note (symbol-append (canonical i)
                                      (string->symbol (number->string octave)))
                       i octave)))))
      (match (assq name table)
        (#f (unknown))
        ((_ . i) (make-note (canonical i) i #f)))))

(define (pitch<? a b)
  (or (< (note-octave a) (note-octave b))
      (and (= (note-octave a) (note-octave b))
           (< (note-degree a) (note-degree b)))))

(define (check-note-order note earlier pitched? instrument line)
  "Check NOTE against EARLIER, the notes before it, latest first."
  (if pitched?
      (match earlier
        ((previous . _)
         (unless (pitch<? previous note)
           (syntax-error 'notes-not-ascending line
                         "instrument `~a': `~a' comes after `~a'; list notes from low to high"
                         instrument (note-name note) (note-name previous))))
        (() #t))
      (when (any (lambda (n) (= (note-degree n) (note-degree note))) earlier)
        (syntax-error 'duplicate-note line
                      "instrument `~a': `~a' is listed twice"
                      instrument (note-name note)))))

(define (build-instrument form scales)
  "Build an instrument record from FORM.  SCALES is an alist from name to
scale record."
  (match form
    ((('instrument name scale-name . note-names) . line)
     (let* ((scale (or (assq-ref scales scale-name)
                       (syntax-error 'undefined-scale line
                                     "instrument `~a': no scale or stroke set called `~a'"
                                     name scale-name)))
            (table (name-table scale))
            (notes (fold (lambda (note-name earlier)
                           (let ((note (resolve-note note-name scale table
                                                     name line)))
                             (check-note-order note earlier
                                               (scale-pitched? scale) name line)
                             (cons note earlier)))
                         '()
                         note-names)))
       (make-instrument name scale (list->vector (reverse notes))
                        (location line))))))

;;; ------------------------------------------------------------------
;;; Item 10: parts

(define (call-with-expansion thunk line name)
  "Call THUNK, which expands the music of part NAME at LINE, turning an
&expansion-error into a &notasi-syntax-error."
  (guard (e ((expansion-error? e)
             (raise-syntax-error
              (expansion-error-kind e)
              (or (expansion-error-line e) line) name
              (expansion-error-time e) (expansion-error-uses e)
              (string-append "part `~a'~@[, ~a~]: ~a")
              (list name
                    (and (expansion-error-time e)
                         (time->text (expansion-error-time e)))
                    (exception-message e)))))
    (thunk)))

(define current-patterns (make-parameter '()))

(define (build-part form instruments check-name)
  "Build a part record from FORM.  INSTRUMENTS is an alist from name to
instrument record; CHECK-NAME checks the part's name against the parts
before it, after its instrument and before its tokens.  Return
(PART . STEPS), STEPS being its written length."
  (match form
    ((('part . _) . line)
     (let* ((split (split-part form))
            (instrument-name (car split))
            (name (or (assq-ref (cadr split) 'name) instrument-name))
            (tokens (cddr split))
            (instrument
            (or (assq-ref instruments instrument-name)
                (part-error 'undefined-instrument line name #f
                            "no instrument called `~a'" instrument-name))))
       (check-name)
       (call-with-values
           (lambda ()
             (call-with-expansion
              (lambda ()
                (match (current-meter)
                  (#f (expand-part tokens instrument
                                   #:patterns (current-patterns)))
                  ((cycle . pickup)
                   (expand-part tokens instrument
                                #:cycle cycle #:pickup pickup
                                #:patterns (current-patterns)))))
              line name))
         (lambda (events written spans)
           (cons (make-part name instrument events 'written spans
                            (location line))
                 written)))))))

;;; ------------------------------------------------------------------
;;; Item 11: patterns, checked where they are defined

(define (build-pattern form instruments patterns)
  "Build (PATTERN . TOKENS) from FORM, checking its body against its
instrument.  PATTERNS is an alist of every pattern, from name to
(PATTERN . TOKENS), for the instruments of the patterns it uses."
  (match (split-pattern form)
    ((name options . tokens)
     (let* ((line (cdr form))
            (instrument-name
             (or (assq-ref options 'instrument)
                 (syntax-error 'missing-option line
                               "pattern `~a' needs :instrument, the instrument it is written for"
                               name)))
            (instrument
             (or (assq-ref instruments instrument-name)
                 (syntax-error 'undefined-instrument line
                               "pattern `~a': no instrument called `~a'"
                               name instrument-name)))
            (short (or (assq-ref options 'short) (symbol->string name))))
       (guard (e ((expansion-error? e)
                  (raise-syntax-error
                   (expansion-error-kind e)
                   (or (expansion-error-line e) line) #f
                   (expansion-error-time e) (expansion-error-uses e)
                   "pattern `~a'~@[, at ~a~]: ~a"
                   (list name
                         (and (expansion-error-time e)
                              (mixed-number (expansion-error-time e)))
                         (exception-message e)))))
         (check-pattern tokens instrument #:patterns patterns))
       (cons (make-pattern name instrument short
                           (or (assq-ref options 'long) short)
                           (location line))
             tokens)))))

(define (pattern-shadows definitions instruments)
  "For checking patterns where they are defined: an alist from each
pattern's name to (PATTERN . TOKENS), for those whose instrument is
known, so a pattern used inside another can be checked for its
instrument and measured."
  (filter-map (match-lambda
                ((file . form)
                 (match (split-pattern form)
                   ((name options . tokens)
                    (let ((instrument (assq-ref instruments
                                                (assq-ref options 'instrument))))
                      (and instrument
                           (cons name
                                 (cons (make-pattern name instrument "" ""
                                                     (make-source-location
                                                      file (cdr form)))
                                       tokens))))))))
              definitions))

;;; ------------------------------------------------------------------
;;; Item 10: colotomies

(define (repeat-events events length times)
  "EVENTS, LENGTH pulses of music, played TIMES times in a row."
  (append-map (lambda (i)
                (map (lambda (e)
                       (make-event (+ (event-start e) (* i length))
                                   (event-duration e) (event-notes e)))
                     events))
              (iota times)))

(define (build-colotomy form instruments)
  "Build a colotomy record from FORM, each part written out over one
cycle.  INSTRUMENTS is an alist from name to instrument record."
  (match form
    ((('colotomy name cycle . parts) . line)
     (make-colotomy
      name cycle 'kempli
      (map (match-lambda
             ((part-name instrument-name . tokens)
              (let ((instrument
                     (or (assq-ref instruments instrument-name)
                         (part-error 'undefined-instrument line part-name #f
                                     "no instrument called `~a'"
                                     instrument-name))))
                (match (call-with-expansion
                        (lambda () (expand-tokens tokens instrument))
                        line part-name)
                  ((events . length)
                   (unless (and (positive? length)
                                (integer? (/ cycle length)))
                     (part-error 'colotomy-part-length line part-name #f
                                 "lasts ~a pulses, which doesn't divide colotomy `~a''s cycle of ~a"
                                 length name cycle))
                   (make-part part-name instrument
                              (repeat-events events length (/ cycle length))
                              'colotomy '() (location line)))))))
           parts)
      (location line)))))

(define (piece-meter title+options colotomies line)
  "Item 12: the piece's colotomy and pickup, as (COLOTOMY . PICKUP),
COLOTOMY #f without one."
  (let* ((options (cdr title+options))
         (name (assq-ref options 'colotomy))
         (pickup (assq-ref options 'pickup))
         (colotomy (and name
                        (or (assq-ref colotomies name)
                            (syntax-error 'undefined-colotomy line
                                          "no colotomy called `~a'" name)))))
    (when (and pickup (not colotomy))
      (syntax-error 'no-colotomy line
                    ":pickup counts pulses before a gong cycle, but the piece has no :colotomy"))
    (when (and pickup
               (not (and (exact-integer? pickup)
                         (<= 0 pickup (colotomy-length colotomy)))))
      (syntax-error 'bad-pickup line
                    ":pickup must be a whole number of pulses from 0 to ~a (one cycle), not ~a"
                    (colotomy-length colotomy) pickup))
    (cons colotomy (or pickup 0))))

;;; ------------------------------------------------------------------
;;; Item 11: parts have equal length

(define (check-whole-cycles parts length colotomy pickup)
  "With a colotomy, the piece is its pickup plus whole cycles."
  (when (and colotomy (pair? parts)
             (not (integer? (/ (- length pickup)
                               (colotomy-length colotomy)))))
    (let ((first (car parts)))
      (if (zero? pickup)
          (part-error 'incomplete-cycle
                      (source-location-line (part-location first))
                      (part-name first) #f
                      "the piece lasts ~a pulses, which is not a whole number of ~a-pulse cycles"
                      length (colotomy-length colotomy))
          (part-error 'incomplete-cycle
                      (source-location-line (part-location first))
                      (part-name first) #f
                      "the piece lasts ~a pulses, which is not the pickup of ~a plus whole ~a-pulse cycles"
                      length pickup (colotomy-length colotomy))))))

(define (check-equal-lengths parts+lengths)
  "PARTS+STEPS is a list of (PART . STEPS) in file order.  Return the
piece length: the common step count, or 0 with no parts."
  (match parts+lengths
    (() 0)
    (((first . length) . others)
     (for-each
      (match-lambda
        ((part . written)
         (unless (= written length)
           (part-error 'unequal-length
                       (source-location-line (part-location part))
                       (part-name part) #f
                       "lasts ~a pulses, but part `~a' lasts ~a; every part must have the same length"
                       written (part-name first) length))))
      others)
     length)))

;;; ------------------------------------------------------------------
;;; Item 15 (step 11): generated parts

;;; The kempli a piece gets when it defines none.  Its timekeeper is in
;;; the music but never printed.
(define built-in-kempli
  (make-instrument
   'kempli
   (make-scale 'kempli-strokes (list (make-degree 'K '() "K" #f #f)) #f #f)
   (vector (make-note 'K 0 #f))
   #f))

(define (clip-events events from length)
  "EVENTS shifted to start at FROM, cut to the piece's [0, LENGTH)."
  (filter-map (lambda (e)
                (let ((start (max 0 (+ from (event-start e))))
                      (end (min length (+ from (event-start e)
                                          (event-duration e)))))
                  (and (< start end)
                       (make-event start (- end start) (event-notes e)))))
              events))

(define (lay-colotomy-part part cycle pickup length)
  "PART, one cycle long, laid over the piece so every cycle ends on the
cycle's last pulse: from PICKUP - CYCLE, cycle after cycle."
  (let loop ((from (- pickup cycle)) (events '()))
    (if (>= from length)
        (make-part (part-name part) (part-instrument part) events
                   'colotomy '() (part-location part))
        (loop (+ from cycle)
              (append events (clip-events (part-events part) from length))))))

(define (timekeeper instruments length colotomy)
  "The part `kempli': one stroke per pulse, each a pulse long, the last
cut at the piece's end, on the piece's kempli or a built-in one."
  (make-part 'kempli
             (or (assq-ref instruments 'kempli) built-in-kempli)
             (map (lambda (t) (make-event t (min 1 (- length t)) '(0)))
                  (iota (ceiling length)))
             'timekeeper '()
             (and colotomy (colotomy-location colotomy))))

(define (generated-parts instruments colotomy pickup length)
  (append
   (if colotomy
       (map (lambda (part)
              (lay-colotomy-part part (colotomy-length colotomy) pickup length))
            (colotomy-parts colotomy))
       '())
   (list (timekeeper instruments length colotomy))))

(define (check-generated-names written generated)
  "A written part can't take a generated part's name."
  (for-each (lambda (part)
              (when (memq (part-name part) (map part-name generated))
                (part-error 'duplicate-definition
                            (source-location-line (part-location part))
                            (part-name part) #f
                            "is a part notasi makes for you (the timekeeper or a colotomy's part); give yours another name, or leave it out")))
            written))

;;; ------------------------------------------------------------------
;;; Item 16 (step 12): scores (ADRs 0031, 0033, 0034)

;;; Options a later slice of milestone 2 builds: `not-implemented' until
;;; then.
(define score-options-not-yet
  '(rows fill holds pattern-names pattern-level labels short from to
    breaks cycle-numbers pulse-numbers numbering pulse-label subtitle
    caption font-size))

(define group-options-not-yet
  '(rows fill holds pattern-names pattern-level labels short
    from to breaks cycle-numbers pulse-numbers numbering pulse-label
    caption font-size))

(define (colour? x)
  (and (string? x)
       (= (string-length x) 7)
       (char=? (string-ref x 0) #\#)
       (string-every char-set:hex-digit x 1)))

(define (palette? v)
  (or (and (symbol? v) (memq v (palette-names)) #t)
      (and (pair? v) (list? v) (every colour? v))))

(define (colors? v)
  (and (list? v)
       (every (match-lambda
                (((? note-name?) (? colour?)) #t)
                (_ #f))
              v)))

(define (length-string? v)
  (and (string? v)
       (regexp-match? (string-match "^[0-9]+(\\.[0-9]+)?(em|pt|mm|cm|in)$" v))))

(define (yes-no? v) (memq v '(yes no)))

(define style-options
  `((note-names ,yes-no? . "yes or no")
    (scheme ,(lambda (v) (eq? v 'by-degree)) . "a colour scheme: by-degree")
    (palette ,palette? . "a palette name or a list of \"#rrggbb\" colours")
    (colors ,colors? . "a list of (DEGREE \"#rrggbb\")")))

(define score-only-options
  `((title ,string? . "a string")
    (system-length ,positive-whole-number? . "a whole number of pulses")
    (cell-width ,length-string? . "a length such as \"2em\"")
    (cell-height ,length-string? . "a length such as \"2em\"")))

(define group-only-options
  `((subtitle ,string? . "a string")))

(define (check-not-yet options not-yet line)
  (for-each (match-lambda
              ((key . _)
               (when (memq (key-name key) not-yet)
                 (syntax-error 'not-implemented line
                               "the option `~a' is not supported yet" key))))
            options))

(define (score-settings options line)
  (check-not-yet options score-options-not-yet line)
  (check-options options (append score-only-options style-options)
                 "a score" line))

(define (group-settings options line)
  (check-not-yet options group-options-not-yet line)
  (for-each (match-lambda
              ((key . _)
               (when (assq (key-name key) score-only-options)
                 (syntax-error 'option-wrong-level line
                               "`~a' is set on the score, not on a group" key))))
            options)
  (check-options options (append group-only-options style-options)
                 "a group" line))

(define (setting name own score default)
  "A group's effective setting NAME: its own, else the score's, else
DEFAULT (ADR 0033)."
  (cond ((assq name own) => cdr)
        ((assq name score) => cdr)
        (else default)))

(define (make-score-group label subtitle members own score-opts location)
  (let ((colors (setting 'colors own score-opts '())))
    (make-group label label subtitle 'first-long 'notes members
                (eq? (setting 'note-names own score-opts 'no) 'yes)
                'colour 'none 'none 0
                (setting 'scheme own score-opts 'by-degree)
                (setting 'palette own score-opts 'pastel1)
                (map (match-lambda ((degree colour) (cons degree colour)))
                     colors)
                location)))

(define (printable-parts parts)
  "PARTS a score may print: all but a timekeeper on the built-in kempli."
  (remove (lambda (part) (eq? (part-instrument part) built-in-kempli))
          parts))

(define (check-group-instruments members line)
  "ADRs 0011 and 0034: one pitched instrument, or only stroke
instruments."
  (match members
    (() #t)
    (((first . _) . others)
     (let ((pitched? (lambda (part)
                       (scale-pitched? (instrument-scale (part-instrument part))))))
       (for-each
        (match-lambda
          ((part . _)
           (cond
            ((not (eq? (pitched? part) (pitched? first)))
             (part-error 'pitched-with-strokes line (part-name part) #f
                         "a group holds pitched instruments or gongs and drums, not both; put `~a' in a group of its own"
                         (part-name part)))
            ((and (pitched? part)
                  (not (eq? (part-instrument part) (part-instrument first))))
             (part-error 'mixed-pitched-group line (part-name part) #f
                         "a group can hold one pitched instrument, but this one has `~a' and `~a'; put them in separate groups"
                         (instrument-name (part-instrument first))
                         (instrument-name (part-instrument part)))))))
        others)))))

(define (build-score form parts title length colotomy)
  "Build a score record from FORM.  PARTS are the parts a score may
print."
  (match form
    ((('score name . items) . line)
     (match (split-options items line)
       ((options . groups)
        (let* ((opts (score-settings options line))
               (used '())
               (built
                (map (lambda (group)
                       (let ((gline (list-line group line)))
                         (match group
                           (('group label . gitems)
                            (match (split-options gitems gline)
                              ((goptions . member-forms)
                               (reject-keys member-forms gline)
                               (let* ((own (group-settings goptions gline))
                                      (members
                                       (map (lambda (member)
                                              (let* ((name (if (pair? member)
                                                               (car member)
                                                               member))
                                                     (label (or (and (pair? member)
                                                                     (assq-ref (split-member-options
                                                                                (cdr member))
                                                                               'label))
                                                                (symbol->string name)))
                                                     (part (or (find (lambda (p)
                                                                       (eq? (part-name p) name))
                                                                     parts)
                                                               (part-error 'undefined-part gline name #f
                                                                           "no part with this name"))))
                                                (when (memq name used)
                                                  (part-error 'part-in-two-groups gline name #f
                                                              "is already in a group of this score; a part can be in only one"))
                                                (set! used (cons name used))
                                                (cons part label)))
                                            member-forms)))
                                 (check-group-instruments members gline)
                                 (make-score-group label (assq-ref own 'subtitle)
                                                   members own opts
                                                   (location gline)))))))))
                     groups)))
          (make-score name (or (assq-ref opts 'title) title) #f #f 0 length
                      (assq-ref opts 'system-length) '()
                      (and colotomy #t) #t 'gong-last #f #f
                      (or (assq-ref opts 'cell-width) "2em")
                      (or (assq-ref opts 'cell-height) "2em")
                      built (location line))))))))

(define (default-score parts title length colotomy)
  "A file with no score gets this one: every part in its own group."
  (make-score 'default title #f #f 0 length #f '() (and colotomy #t) #t
              'gong-last #f #f "2em" "2em"
              (map (lambda (part)
                     (let ((name (symbol->string (part-name part))))
                       (make-group name name #f 'first-long 'notes
                                   (list (cons part name))
                                   #f 'colour 'none 'none 0
                                   'by-degree 'pastel1 '() #f)))
                   parts)
              #f))

;;; ------------------------------------------------------------------
;;; Entry points

(define (read-piece forms dir chain)
  "Check FORMS, a list of (DATUM . LINE), and build the piece.  DIR is
where `(use \"file.nts\")' looks; CHAIN holds the canonical path of the
piece file, if any.  The checks run in the order given in 03-reader.md,
so a file with several problems always reports the same one."
  (define (named records name-of)
    (map (lambda (record) (cons (name-of record) record)) records))
  (define (build-each build definitions)
    ;; Each definition is built in the context of its own file, so its
    ;; locations and errors name that file.
    (map (match-lambda
           ((file . form)
            (parameterize ((current-source-file file))
              (build form))))
         definitions))
  (define (with-heads heads definitions)
    (filter (lambda (definition) (memq (form-head (cdr definition)) heads))
            definitions))
  (for-each check-form forms)
  (let* ((piece-form (find-piece-form forms))
         (piece (parse-piece-form piece-form))
         (_ (check-not-implemented forms))
         (definitions (file-definitions forms dir chain (make-hash-table))))
    (let* ((scales (build-each build-scale
                               (with-heads '(scale strokes) definitions)))
           (instruments (build-each
                         (lambda (form)
                           (build-instrument form (named scales scale-name)))
                         (with-heads '(instrument) definitions)))
           (colotomies (build-each
                        (lambda (form)
                          (build-colotomy form (named instruments
                                                      instrument-name)))
                        (with-heads '(colotomy) definitions)))
           (pattern-definitions (with-heads '(pattern) definitions))
           (patterns+tokens
            (let ((shadows (pattern-shadows pattern-definitions
                                            (named instruments
                                                   instrument-name))))
              (build-each
               (lambda (form)
                 (build-pattern form (named instruments instrument-name)
                                shadows))
               pattern-definitions)))
           (meter (piece-meter piece (named colotomies colotomy-name)
                               (cdr piece-form)))
           (colotomy (car meter))
           (pickup (cdr meter))
           (part-forms (forms-with-heads forms '(part)))
           (parts+lengths
            (parameterize ((current-meter
                            (and colotomy
                                 (cons (colotomy-length colotomy) pickup)))
                           (current-patterns
                            (map (lambda (entry)
                                   (cons (pattern-name (car entry)) entry))
                                 patterns+tokens)))
              (let loop ((todo part-forms) (done '()) (built '()))
                (match todo
                  (() (reverse built))
                  ((form . rest)
                   (let ((part+length
                          (build-part form (named instruments instrument-name)
                                      (lambda () (check-part-names form done)))))
                     (loop rest (cons form done) (cons part+length built))))))))
           (length (check-equal-lengths parts+lengths))
           (written (map car parts+lengths))
           (_ (check-whole-cycles written length colotomy pickup))
           (generated (generated-parts (named instruments instrument-name)
                                       colotomy pickup length))
           (_ (check-generated-names written generated))
           (parts (append written generated)))
      (make-piece (car piece) length pickup
                  (if colotomy (list (cons 0 colotomy)) '())
                  scales instruments (map car patterns+tokens)
                  parts
                  (let ((printable (printable-parts parts))
                        (forms (forms-with-heads forms '(score))))
                    (if (null? forms)
                        (list (default-score printable (car piece) length
                                             colotomy))
                        (map (lambda (form)
                               (build-score form printable (car piece)
                                            length colotomy))
                             forms)))))))

(define (read-port port dir chain)
  (read-piece (read-forms port) dir chain))

(define* (read-piece-port port #:key directory)
  "Read a piece from PORT.  Raise a &notasi-syntax-error on any error.
DIRECTORY is where `(use \"file.nts\")' looks; it defaults to the
current directory."
  (read-port port (or directory (getcwd)) '()))

(define* (read-piece-string str #:key directory)
  "Read a piece from the string STR.  See `read-piece-port'."
  (call-with-input-string str
    (lambda (port) (read-piece-port port #:directory directory))))

(define (read-piece-file path)
  "Read a piece from the file at PATH.  Errors report PATH as their file."
  (parameterize ((current-source-file path))
    (call-with-source-file path
      (lambda (port)
        (read-port port (dirname path) (list (canonicalize-path path)))))))
