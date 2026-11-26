;;; (notasi expand) -- Part tokens to timed events.  See "Steps" (7 and
;;; 9) and "Modules" in doc/design/03-reader.md, and ADR 0035.
;;;
;;; Expansion knows instruments, not files or forms: its errors carry a
;;; time (in pulses) and the chain of pattern uses, and the reader adds
;;; the file, line and part.  Times are exact rationals in pulses
;;; (ADR 0025).
;;;
;;; Iteration 2, slice 2 (feat/music-durations): notes, key numbers,
;;; chords, durations, `_', `-', `/' and `|'.  Slice 3 (feat/music-rep):
;;; `rep', built on fragments (03, step 9).  Slice 5
;;; (feat/music-patterns): pattern uses, `:step', spans and the chain
;;; of uses in errors.

(define-module (notasi expand)
  #:use-module (notasi piece)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-11)
  #:export (expand-tokens
            expand-part
            check-pattern

            &expansion-error
            expansion-error?
            expansion-error-kind
            expansion-error-time
            expansion-error-uses
            expansion-error-line

            ;; Shared with the reader, which resolves instrument notes.
            split-octave
            pitch-names))

;;; ------------------------------------------------------------------
;;; The condition

(define &expansion-error
  (make-exception-type '&expansion-error &error '(kind time uses line)))

(define make-expansion-error
  (record-constructor &expansion-error))

(define expansion-error?
  (exception-predicate &expansion-error))

(define (field name)
  (exception-accessor &expansion-error
                      (record-accessor &expansion-error name)))

(define expansion-error-kind (field 'kind))
(define expansion-error-time (field 'time))
(define expansion-error-uses (field 'uses))
(define expansion-error-line (field 'line))

(define (expansion-error kind time fmt . args)
  "Raise an &expansion-error of KIND at TIME, with a message built from
FMT and ARGS and no location: the reader adds that."
  (apply expansion-error-at kind time #f fmt args))

;;; The pattern uses the music being expanded lies inside, innermost
;;; first, as (PATTERN-NAME . LINE-OF-ITS-DEFINITION).
(define current-uses (make-parameter '()))

(define (expansion-error-at kind time line fmt . args)
  "Like `expansion-error', for a mistake in a list with its own LINE
(1-based, or #f), which the reader reports instead of the part's."
  (raise-exception
   (make-exception
    (make-expansion-error kind time (current-uses) line)
    (make-exception-with-message (apply format #f fmt args)))))

;;; ------------------------------------------------------------------
;;; Note names

(define (ascii-digit? c)
  (and (char<=? #\0 c) (char<=? c #\9)))

(define (split-octave name)
  "Split NAME, e.g. ding2, into (ding . 2).  Return #f if NAME has no
octave number, or one with a leading zero (only 0 itself may start
with 0)."
  (let* ((s (symbol->string name))
         (end (string-index-right s (lambda (c) (not (ascii-digit? c)))))
         (digits (if end (substring s (1+ end)) "")))
    (and end
         (not (string-null? digits))
         (or (string=? digits "0")
             (not (char=? (string-ref digits 0) #\0)))
         (cons (string->symbol (substring s 0 (1+ end)))
               (string->number digits)))))

(define (pitch-names pitch)
  (cons (pitch-name pitch) (pitch-aliases pitch)))

(define (note-name-table instrument)
  "An alist from every way to write a note of INSTRUMENT to the note's
index: for a pitched note, each name and alias of its pitch with the
octave (ding2, i2); for a stroke, each name and alias."
  (let ((pitches (list->vector (scale-pitches (instrument-scale instrument)))))
    (append-map
     (lambda (note i)
       (map (lambda (name)
              (cons (match (note-octave note)
                      (#f name)
                      (octave (symbol-append
                               name (string->symbol (number->string octave)))))
                    i))
            (pitch-names (vector-ref pitches (note-pitch note)))))
     (vector->list (instrument-notes instrument))
     (iota (vector-length (instrument-notes instrument))))))

;;; `|', built from a string: Guile's default reader, which reads this
;;; file, doesn't read a bare `|' as a symbol.
(define pulse-check (string->symbol "|"))
(define cycle-check (string->symbol "||"))

(define (structural-token? token)
  "A token that marks time or layout rather than naming a note."
  (or (memq token '(_ - /)) (eq? token pulse-check) (eq? token cycle-check)))

(define (resolve-note token instrument table fail)
  "The 0-based index of the note TOKEN (a key number or a name) on
INSTRUMENT.  FAIL is called with a kind, a message format and its
arguments."
  (let ((size (vector-length (instrument-notes instrument))))
    (match token
      ((? exact-integer? n)
       (unless (<= 1 n size)
         (fail 'note-out-of-range
               "note ~a does not exist on instrument `~a' (it has ~a notes)"
               n (instrument-name instrument) size))
       (1- n))
      ((? symbol? name)
       (match (assq name table)
         ((_ . i) i)
         (#f (fail 'unknown-note
                   (if (and (scale-pitched? (instrument-scale instrument))
                            (not (split-octave name)))
                       "`~a' is not a note of instrument `~a'; pitched notes need an octave number, e.g. ~a1"
                       "`~a' is not a note of instrument `~a'")
                   name (instrument-name instrument) name)))))))

(define (chord-member? x)
  (or (exact-integer? x)
      (and (symbol? x) (not (structural-token? x)))))

(define (resolve-chord members instrument table fail)
  "The sorted note indices of the chord MEMBERS."
  (unless (and (list? members) (>= (length members) 2)
               (every chord-member? members))
    (fail 'bad-chord
          "a chord needs two or more notes, each a number or a note name: ~s"
          members))
  (let ((notes (map (lambda (m) (resolve-note m instrument table fail))
                    members)))
    (unless (= (length notes) (length (delete-duplicates notes)))
      (fail 'bad-chord "a chord has the same note twice: ~s" members))
    (sort notes <)))

;;; ------------------------------------------------------------------
;;; Durations

(define (split-duration token fail)
  "Split TOKEN into (BASE . DURATION): `e2:1/4' is (e2 . 1/4), `5:2' is
(5 . 2), `-:3' is (- . 3).  DURATION is #f when there is no suffix.
FAIL is called for a bad duration."
  (match token
    ((? symbol?)
     (let* ((s (symbol->string token))
            (colon (and (> (string-length s) 1)
                        (string-index s #\: 1))))
       (if (not colon)
           (cons token #f)
           (let* ((base-text (substring s 0 colon))
                  (base (or (and (string-every char-numeric? base-text)
                                 (string->number base-text))
                            (string->symbol base-text)))
                  (text (substring s (1+ colon)))
                  (d (string->number text)))
             (unless (and d (exact-rational? d) (positive? d))
               (fail 'bad-duration
                     "`~a': a duration is a whole number or a fraction of pulses above zero, e.g. ~a:2 or ~a:1/4"
                     token base-text base-text))
             (when (and (symbol? base) (structural-token? base)
                        (not (eq? base '-)))
               (fail 'bad-duration
                     "`~a': only a note, a key number or `-' takes a duration"
                     token))
             (cons base d)))))
    (_ (cons token #f))))

(define (exact-rational? x)
  (and (exact? x) (rational? x)))

;;; ------------------------------------------------------------------
;;; Tokens to events, through fragments (03, step 9)

;;; A fragment: music timed from 0, to be placed in a part (or another
;;; fragment) at some time.  EVENTS are (START DURATION NOTES), newest
;;; first; CHECKS are (TIME . KIND) for its `|' and `||'; SPANS are
;;; (START END DEPTH PATTERN SHORT LONG ANNOTATION) for its pattern uses,
;;; and (START END text STRING LENGTH) for its free text (ADR 0057),
;;; END being START + LENGTH, or START for a point, so that placing a
;;; fragment shifts both alike; LENGTH is
;;; its length; DURATION the current duration at its end; LEAD the
;;; length of a leading `_', which holds the note before the fragment;
;;; LAST what ends it: note, rest, lead (only a lead hold) or none; USES
;;; the pattern uses it was expanded in, for an error about its lead.
(define-record-type <fragment>
  (make-fragment events checks spans length duration lead last uses)
  fragment?
  (events   fragment-events)
  (checks   fragment-checks)
  (spans    fragment-spans)
  (length   fragment-length)
  (duration fragment-duration)
  (lead     fragment-lead)
  (last     fragment-last)
  (uses     fragment-uses))          ; the uses its lead hold lies in

;;; What expansion knows besides the tokens: the instrument and its note
;;; table, the meter for `||' (or #f), the patterns (an alist from name
;;; to (PATTERN . TOKENS)), the :step in force, the depth of pattern
;;; uses, and whether a pattern is being checked where it is defined
;;; (then nested patterns are not expanded and `|' is not checked).
(define-record-type <context>
  (make-context instrument table meter patterns step depth checking?)
  context?
  (instrument context-instrument)
  (table      context-table)
  (meter      context-meter)
  (patterns   context-patterns)
  (step       context-step)
  (depth      context-depth)
  (checking?  context-checking?))

(define (list-line datum)
  "The 1-based line Guile read DATUM, a list, from, or #f."
  (match (source-property datum 'line)
    ((? integer? line) (1+ line))
    (_ #f)))

(define (rep-form? token)
  (and (pair? token) (eq? (car token) 'rep)))

(define (text-form? token)
  (and (pair? token) (eq? (car token) 'text)))

(define (positive-exact-rational? x)
  (and (number? x) (exact-rational? x) (positive? x)))

(define (pattern-use-form? token)
  (and (pair? token) (eq? (car token) '@)))

(define (pattern-token? token)
  "Is TOKEN `@NAME'?"
  (and (symbol? token)
       (let ((s (symbol->string token)))
         (and (> (string-length s) 1) (char=? (string-ref s 0) #\@)))))

(define (key? x)
  (and (symbol? x)
       (let ((s (symbol->string x)))
         (and (> (string-length s) 1)
              (char=? (string-ref s 0) #\:)
              (char-alphabetic? (string-ref s 1))))))

;;; ------------------------------------------------------------------
;;; Moving notes (`:step')

(define (move-note index named? context fail)
  "Move the note at INDEX by the context's step: a note written by name
on a pitched instrument moves along the scale, any other note moves
keys."
  (let* ((step (context-step context))
         (instrument (context-instrument context))
         (notes (instrument-notes instrument))
         (size (vector-length notes)))
    (define (off)
      (fail 'moved-note-out-of-range
            "moved by ~a, note `~a' leaves instrument `~a'"
            step (note-name (vector-ref notes index))
            (instrument-name instrument)))
    (cond
     ((zero? step) index)
     ((and named? (scale-pitched? (instrument-scale instrument)))
      (let ((target (+ step (note-pitch-index instrument
                                              (vector-ref notes index)))))
        (or (list-index (lambda (n) (= (note-pitch-index instrument n) target))
                        (vector->list notes))
            (off))))
     (else
      (let ((target (+ index step)))
        (if (and (<= 0 target) (< target size)) target (off)))))))

(define (strike-notes token context fail)
  "The sorted note indices TOKEN (a note, key number or chord) strikes,
moved by the context's step."
  (let* ((instrument (context-instrument context))
         (table (context-table context))
         (named (lambda (t) (symbol? t)))
         (resolve (lambda (t)
                    (move-note (resolve-note t instrument table fail)
                               (named t) context fail))))
    (if (pair? token)
        (begin
          (resolve-chord token instrument table fail)  ; checks the chord
          (sort (map resolve token) <))
        (list (resolve token)))))

;;; ------------------------------------------------------------------
;;; Pattern uses

(define (use-options items line time)
  "The operators of a pattern use, `:key value' pairs, as an alist."
  (define (bad kind fmt . args)
    (apply expansion-error-at kind time line fmt args))
  (let loop ((items items) (seen '()))
    (match items
      (() (reverse seen))
      (((? key? key))
       (bad 'bad-option "option `~a' needs a value" key))
      (((? key? key) (? key? next) . _)
       (bad 'bad-option "option `~a' needs a value, but `~a' follows it" key next))
      (((? key? key) value . rest)
       (let ((name (string->symbol (substring (symbol->string key) 1))))
         (unless (memq name '(step short long annotation))
           (bad 'unknown-option "a pattern use has no option `~a'" key))
         (when (assq name seen)
           (bad 'duplicate-option "option `~a' given twice" key))
         (unless (match name
                   ('step (exact-integer? value))
                   (_ (string? value)))
           (bad 'bad-option "`~a' must be ~a, not ~s" key
                (if (eq? name 'step) "a whole number" "a string") value))
         (loop rest (acons name value seen))))
      ((item . _)
       (bad 'bad-pattern-use
            "a pattern use is (@ NAME :step N :short \"S\" :long \"L\"), not ~s"
            item)))))

(define (pattern-use token time)
  "TOKEN, `@NAME' or (@ NAME :key value ...), as (NAME . OPTIONS)."
  (match token
    ((? pattern-token?)
     (cons (string->symbol (substring (symbol->string token) 1)) '()))
    (('@ (? symbol? name) . items)
     (=> bad)
     (if (and (list? items) (not (key? name)))
         (cons name (use-options items (list-line token) time))
         (bad)))
    (_ (expansion-error-at
        'bad-pattern-use time (list-line token)
        "a pattern use is (@ NAME :step N :short \"S\" :long \"L\"), not ~s"
        token))))

(define (lookup-pattern name time context)
  "The (PATTERN . TOKENS) called NAME, checked for this use."
  (let ((entry (or (assq-ref (context-patterns context) name)
                   (expansion-error 'undefined-pattern time
                                    "there is no pattern called `~a'" name))))
    (when (assq name (current-uses))
      (expansion-error 'pattern-cycle time
                       "pattern `~a' uses itself" name))
    (unless (eq? (instrument-name (pattern-instrument (car entry)))
                 (instrument-name (context-instrument context)))
      (expansion-error 'wrong-instrument time
                       "pattern `~a' is written for `~a', not `~a'"
                       name
                       (instrument-name (pattern-instrument (car entry)))
                       (instrument-name (context-instrument context))))
    entry))

(define (pattern-line pattern)
  (match (pattern-location pattern)
    (#f #f)
    (loc (source-location-line loc))))

(define (expand-use token time offset context)
  "Expand the pattern use TOKEN at local TIME into a fragment with its
own span, or #f when only checking a definition."
  (match (pattern-use token (+ offset time))
    ((name . options)
     (if (context-checking? context)
         (begin
           ;; Where a pattern is defined, a nested use is checked only for
           ;; its instrument; unknown patterns and cycles are found where
           ;; the pattern is used.
           (match (assq-ref (context-patterns context) name)
             (#f #f)
             ((pattern . tokens)
              (unless (eq? (instrument-name (pattern-instrument pattern))
                           (instrument-name (context-instrument context)))
                (expansion-error 'wrong-instrument (+ offset time)
                                 "pattern `~a' is written for `~a', not `~a'"
                                 name
                                 (instrument-name (pattern-instrument pattern))
                                 (instrument-name (context-instrument context))))
              ;; Its length places what follows; a cycle is left to the use.
              (and (not (assq name (current-uses)))
                   (let ((fragment
                          (parameterize ((current-uses
                                          (cons (cons name (pattern-line pattern))
                                                (current-uses))))
                            (guard (e ((expansion-error? e) #f))
                              (expand-fragment tokens 1 (+ offset time) #f
                                               context)))))
                     (and fragment
                          (make-fragment '() '() '()
                                         (fragment-length fragment) #f 0
                                         'none '())))))))
         (match (lookup-pattern name (+ offset time) context)
           ((pattern . tokens)
            (let* ((short (or (assq-ref options 'short) (pattern-short pattern)))
                   (long (or (assq-ref options 'long) (pattern-long pattern)))
                   ;; The annotation in force: the use's, else the
                   ;; pattern's (ADR 0057).
                   (annotation (or (assq-ref options 'annotation)
                                   (pattern-annotation pattern)))
                   (fragment
                    (parameterize ((current-uses
                                    (cons (cons name (pattern-line pattern))
                                          (current-uses))))
                      (expand-fragment
                       tokens 1 (+ offset time) #f
                       (make-context (context-instrument context)
                                     (context-table context)
                                     (context-meter context)
                                     (context-patterns context)
                                     (+ (context-step context)
                                        (or (assq-ref options 'step) 0))
                                     (1+ (context-depth context))
                                     #f)))))
              (make-fragment (fragment-events fragment)
                             (fragment-checks fragment)
                             (cons (list 0 (fragment-length fragment)
                                         (context-depth context)
                                         pattern short long annotation)
                                   (fragment-spans fragment))
                             (fragment-length fragment)
                             #f          ; the part's duration is kept
                             (fragment-lead fragment)
                             (fragment-last fragment)
                             (fragment-uses fragment)))))))))

;;; ------------------------------------------------------------------
;;; Expanding

(define (check! kind time context)
  "Check a `|' (KIND pulse) or `||' (KIND cycle) at TIME in the piece."
  (unless (context-checking? context)
    (match kind
      ('pulse
       (unless (integer? time)
         (expansion-error 'misplaced-pulse-check time
                          "`|' is not at the start of a pulse")))
      ('cycle
       (match (context-meter context)
         (#f (expansion-error 'no-colotomy time
                              "`||' marks the end of a gong cycle, but the piece has no :colotomy"))
         ((cycle . pickup)
          (unless (integer? (/ (- time pickup) cycle))
            (expansion-error 'misplaced-cycle-check time
                             "`||' is not at the end of a gong cycle"))))))))

(define (expand-fragment tokens duration offset top? context)
  "Expand TOKENS into a fragment, starting with DURATION.  OFFSET is the
fragment's time in the piece where it is first placed, so errors give
times there.  At the top of a part (TOP?), a leading `_' has nothing to
hold; inside a `rep' or a pattern it becomes the fragment's lead."
  (let loop ((tokens tokens)
             (time 0)
             (duration duration)
             (previous 'start)     ; start, note or rest
             (events '())
             (checks '())
             (spans '())
             (lead 0))
    (define (fail kind fmt . args)
      (apply expansion-error kind (+ offset time) fmt args))
    (define (strike notes rest duration)
      (loop rest (+ time duration) duration 'note
            (cons (list time duration notes) events) checks spans lead))
    (define (place fragment times rest)
      ;; Place FRAGMENT TIMES times from TIME, then go on with REST.
      (let place-loop ((i 0) (time time) (previous previous)
                       (events events) (checks checks) (spans spans)
                       (lead lead))
        (define (at t) (+ offset time t))
        (if (= i times)
            (loop rest time (or (fragment-duration fragment) duration)
                  previous events checks spans lead)
            (let*-values
                (((events lead)
                  (let ((hold (fragment-lead fragment)))
                    (cond
                     ((zero? hold) (values events lead))
                     ((eq? previous 'note)
                      (match events
                        (((start held notes) . earlier)
                         (values (cons (list start (+ held hold) notes) earlier)
                                 lead))))
                     ((and (eq? previous 'start) (not top?))
                      (values events (+ lead hold)))
                     (else
                      (parameterize ((current-uses (fragment-uses fragment)))
                       (expansion-error
                       'hold-without-note (at 0)
                       (if (eq? previous 'start)
                           "a part cannot start with `_' (hold): there is no note to hold"
                           "`_' (hold) after a rest: there is no note to hold"))))))))
              (when (> i 0)
                (for-each (match-lambda
                            ((t . kind) (check! kind (at t) context)))
                          (reverse (fragment-checks fragment))))
              (place-loop (1+ i)
                          (+ time (fragment-length fragment))
                          (match (fragment-last fragment)
                            ((or 'none 'lead) previous)
                            (last last))
                          (append (map (match-lambda
                                         ((start held notes)
                                          (list (+ time start) held notes)))
                                       (fragment-events fragment))
                                  events)
                          (append (map (match-lambda
                                         ((t . kind) (cons (+ time t) kind)))
                                       (fragment-checks fragment))
                                  checks)
                          (append (map (match-lambda
                                         ((start end . rest)
                                          (cons* (+ time start) (+ time end)
                                                 rest)))
                                       (fragment-spans fragment))
                                  spans)
                          lead)))))
    (match tokens
      (()
       (make-fragment events checks spans time duration lead
                      (match previous
                        ('start (if (zero? lead) 'none 'lead))
                        (other other))
                      (current-uses)))
      (((? rep-form? token) . rest)
       (match token
         (('rep (? exact-integer? times) _ ..1)
          (=> bad)
          (if (and (positive? times) (list? token))
              (place (expand-fragment (cddr token) duration (+ offset time)
                                      #f context)
                     times rest)
              (bad)))
         (_ (expansion-error-at
             'bad-rep (+ offset time) (list-line token)
             "a repeat is (rep N TOKEN ...), with N a whole number above zero: ~s"
             token))))
      (((and token (or (? pattern-use-form?) (? pattern-token?))) . rest)
       (match (expand-use token time offset context)
         (#f (loop rest time duration previous events checks spans lead))
         (fragment (place fragment 1 rest))))
      (((? text-form? token) . rest)
       ;; Free text (ADR 0057): takes no time, and the duration and what
       ;; came before stay as they were, so `_' after it holds the note
       ;; before it.
       (match token
         (('text (? string? text))
          (loop rest time duration previous events checks
                (cons (list time time 'text text #f) spans) lead))
         (('text (? string? text) (? positive-exact-rational? length))
          (loop rest time duration previous events checks
                (cons (list time (+ time length) 'text text length) spans)
                lead))
         (_ (expansion-error-at
             'bad-text (+ offset time) (list-line token)
             "free text is (text \"TEXT\") or (text \"TEXT\" LENGTH), LENGTH a number of pulses above zero: ~s"
             token))))
      ((token . rest)
       (match (split-duration token fail)
         (('/ . #f) (loop rest time duration previous events checks spans lead))
         (((and check (or (? (lambda (t) (eq? t pulse-check)))
                          (? (lambda (t) (eq? t cycle-check))))) . #f)
          (let ((kind (if (eq? check pulse-check) 'pulse 'cycle)))
            (check! kind (+ offset time) context)
            (loop rest time duration previous events
                  (cons (cons time kind) checks) spans lead)))
         (('- . d)
          (let ((duration (or d duration)))
            (loop rest (+ time duration) duration 'rest events checks spans
                  lead)))
         (('_ . #f)
          (match (cons previous events)
            (('note (start held notes) . earlier)
             (loop rest (+ time duration) duration 'note
                   (cons (list start (+ held duration) notes) earlier)
                   checks spans lead))
            (_ (cond
                ((and (eq? previous 'start) (not top?))
                 (loop rest (+ time duration) duration 'start
                       events checks spans (+ lead duration)))
                (else
                 (fail 'hold-without-note
                       (if (eq? previous 'start)
                           "a part cannot start with `_' (hold): there is no note to hold"
                           "`_' (hold) after a rest: there is no note to hold")))))))
         (((and base (or (? exact-integer?) (? symbol?))) . d)
          (strike (strike-notes base context fail) rest (or d duration)))
         (((or (? pair?) ()) . #f)      ; a chord, perhaps an empty one
          (strike (if (pair? token)
                      (strike-notes token context fail)
                      (resolve-chord token (context-instrument context)
                                     (context-table context) fail))
                  rest duration))
         (_ (fail 'unknown-token
                  "~s is not a note, a chord, a repeat, a pattern, `_', `-', `/', `|' or `||'"
                  token)))))))

(define (top-context instrument cycle pickup patterns checking?)
  (make-context instrument (note-name-table instrument)
                (and cycle (cons cycle pickup)) patterns 0 0 checking?))

(define* (expand-part tokens instrument #:key cycle (pickup 0) (patterns '()))
  "Turn TOKENS, a part's music on INSTRUMENT, into timed events.  Return
(values EVENTS LENGTH SPANS TEXTS): event records with exact rational
starts and durations in pulses, sorted by start; the written length in
pulses (trailing rests included); a pattern-span for each pattern use,
sorted by start; and a free-text for each `(text ...)', sorted by start,
in the order written at one time.  CYCLE and PICKUP are the piece's
colotomy length and pickup, for `||' checks; without CYCLE, `||' is an
error.  PATTERNS is an alist from a pattern's name to (PATTERN .
TOKENS).  Raise an &expansion-error on a mistake."
  (let* ((fragment (parameterize ((current-uses '()))
                     (expand-fragment tokens 1 0 #t
                                      (top-context instrument cycle pickup
                                                   patterns #f))))
         (written (reverse (fragment-spans fragment))))
    (values (reverse-map (match-lambda
                           ((start duration notes)
                            (make-event start duration notes)))
                         (fragment-events fragment))
            (fragment-length fragment)
            (sort (filter-map (match-lambda
                                ((_ _ 'text . _) #f)
                                ((start end depth pattern short long annotation)
                                 (make-pattern-span pattern short long annotation
                                                    start end depth)))
                              written)
                  (lambda (a b)
                    (< (pattern-span-start a) (pattern-span-start b))))
            (stable-sort (filter-map (match-lambda
                                       ((start _ 'text text length)
                                        (make-free-text start length text))
                                       (_ #f))
                                     written)
                         (lambda (a b)
                           (< (free-text-start a) (free-text-start b)))))))

(define* (expand-tokens tokens instrument #:key cycle (pickup 0) (patterns '()))
  "Like `expand-part', returning (EVENTS . LENGTH)."
  (call-with-values
      (lambda () (expand-part tokens instrument #:cycle cycle #:pickup pickup
                              #:patterns patterns))
    (lambda (events length spans texts) (cons events length))))

(define* (check-pattern tokens instrument #:key (patterns '()))
  "Check a pattern's body TOKENS where it is defined, against its
INSTRUMENT: its notes, its chords, its holds and repeats, and the
instrument of each pattern it uses.  Errors give times within the
pattern.  Unknown patterns and cycles are found where it is used."
  (parameterize ((current-uses '()))
    (expand-fragment tokens 1 0 #f
                     (top-context instrument #f 0 patterns #t)))
  #t)

(define (reverse-map f lst)
  (fold (lambda (x acc) (cons (f x) acc)) '() lst))
