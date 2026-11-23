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
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
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

(define (time->text time)
  "The pulse at TIME, as a musician counts it (TIME 0 is pulse 1), with
a fraction as a mixed number: 3/2 is \"pulse 2 1/2\"."
  (let* ((pulse (+ time 1))
         (whole (floor pulse))
         (rest (- pulse whole)))
    (string-append "pulse " (number->string whole)
                   (if (zero? rest) "" (string-append " " (number->string rest))))))

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
(define not-yet-heads '(colotomy pattern score))

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

;;; The options a form accepts: (NAME VALID? . WHAT-IT-MUST-BE).  The
;;; piece takes none until colotomies (iteration 2, slice 4).
(define piece-options '())

(define part-options
  `((name ,(lambda (v) (and (symbol? v) (not (key? v)))) . "a name")))

(define (parse-piece-form form)
  "Build a piece with no parts from the `piece' form FORM, a (DATUM . LINE)."
  (match form
    ((('piece (? string? title) . items) . line)
     (match (split-options items line)
       ((options . ())
        (let ((opts (check-options options piece-options "a piece" line)))
          (make-piece title 0 '() '() '() '())))
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

(define definition-heads '(scale strokes instrument part))

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

(define (check-definition-shape form)
  (match form
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
(define merged-heads '(scale strokes instrument))

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
                       "a template holds only scale, strokes, instrument and use forms, not `~a'"
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
       (match (guard (e ((expansion-error? e)
                         (raise-syntax-error
                          (expansion-error-kind e) line name
                          (expansion-error-time e) (expansion-error-uses e)
                          (string-append "part `~a'~@[, ~a~]: ~a")
                          (list name
                                (and (expansion-error-time e)
                                     (time->text (expansion-error-time e)))
                                (exception-message e)))))
                (expand-tokens tokens instrument))
         ((events . written)
          (cons (make-part name instrument events (location line))
                written)))))))

;;; ------------------------------------------------------------------
;;; Item 11: parts have equal length

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
;;; Groups.  Until scores (iteration 2, milestone 2) every part is drawn
;;; in its own default group.

(define (default-groups parts)
  (map (lambda (part)
         (make-group (symbol->string (part-name part)) #f (list part) #f))
       parts))

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
  (let* ((piece (parse-piece-form (find-piece-form forms)))
         (_ (check-not-implemented forms))
         (definitions (file-definitions forms dir chain (make-hash-table))))
    (let* ((scales (build-each build-scale
                               (with-heads '(scale strokes) definitions)))
           (instruments (build-each
                         (lambda (form)
                           (build-instrument form (named scales scale-name)))
                         (with-heads '(instrument) definitions)))
           (part-forms (forms-with-heads forms '(part)))
           (parts+lengths
            (let loop ((todo part-forms) (done '()) (built '()))
              (match todo
                (() (reverse built))
                ((form . rest)
                 (let ((part+length
                        (build-part form (named instruments instrument-name)
                                    (lambda () (check-part-names form done)))))
                   (loop rest (cons form done) (cons part+length built)))))))
           (length (check-equal-lengths parts+lengths))
           (parts (map car parts+lengths))
           (groups (default-groups parts)))
      (make-piece (piece-title piece)
                  length scales instruments parts groups))))

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
