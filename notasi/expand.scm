;;; (notasi expand) -- Part tokens to timed events.  See "Steps" (7 and
;;; 9) and "Modules" in doc/design/03-reader.md, and ADR 0035.
;;;
;;; Expansion knows instruments, not files or forms: its errors carry a
;;; time (in pulses) and the chain of pattern uses, and the reader adds
;;; the file, line and part.  Times are exact rationals in pulses
;;; (ADR 0025).
;;;
;;; Iteration 2, slice 2 (feat/music-durations): notes, key numbers,
;;; chords, durations, `_', `-', `/' and `|'.

(define-module (notasi expand)
  #:use-module (notasi piece)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (expand-tokens

            &expansion-error
            expansion-error?
            expansion-error-kind
            expansion-error-time
            expansion-error-uses

            ;; Shared with the reader, which resolves instrument notes.
            split-octave
            degree-names))

;;; ------------------------------------------------------------------
;;; The condition

(define &expansion-error
  (make-exception-type '&expansion-error &error '(kind time uses)))

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

(define (expansion-error kind time fmt . args)
  "Raise an &expansion-error of KIND at TIME, with a message built from
FMT and ARGS and no location: the reader adds that."
  (raise-exception
   (make-exception
    (make-expansion-error kind time '())
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

(define (degree-names degree)
  (cons (degree-name degree) (degree-aliases degree)))

(define (note-name-table instrument)
  "An alist from every way to write a note of INSTRUMENT to the note's
index: for a pitched note, each name and alias of its degree with the
octave (ding2, i2); for a stroke, each name and alias."
  (let ((degrees (list->vector (scale-degrees (instrument-scale instrument)))))
    (append-map
     (lambda (note i)
       (map (lambda (name)
              (cons (match (note-octave note)
                      (#f name)
                      (octave (symbol-append
                               name (string->symbol (number->string octave)))))
                    i))
            (degree-names (vector-ref degrees (note-degree note)))))
     (vector->list (instrument-notes instrument))
     (iota (vector-length (instrument-notes instrument))))))

;;; `|', built from a string: Guile's default reader, which reads this
;;; file, doesn't read a bare `|' as a symbol.
(define pulse-check (string->symbol "|"))

(define (structural-token? token)
  "A token that marks time or layout rather than naming a note."
  (or (memq token '(_ - /)) (eq? token pulse-check)))

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
;;; Tokens to events

(define (expand-tokens tokens instrument)
  "Turn TOKENS, a part's music on INSTRUMENT, into timed events.  Return
(EVENTS . LENGTH): event records with exact rational starts and
durations in pulses, sorted by start, and the written length in pulses
(trailing rests included).  Raise an &expansion-error on a mistake."
  (let ((table (note-name-table instrument)))
    (let loop ((tokens tokens)
               (time 0)
               (duration 1)
               (previous 'start)   ; start, note or rest
               (events '()))       ; (START DURATION NOTES), newest first
      (define (fail kind fmt . args)
        (apply expansion-error kind time fmt args))
      (define (strike notes rest duration)
        (loop rest (+ time duration) duration 'note
              (cons (list time duration notes) events)))
      (match tokens
        (()
         (cons (reverse-map (match-lambda
                              ((start duration notes)
                               (make-event start duration notes)))
                            events)
               time))
        ((token . rest)
         (match (split-duration token fail)
           (('/ . #f) (loop rest time duration previous events))
           (((? (lambda (t) (eq? t pulse-check))) . #f)
            (unless (integer? time)
              (fail 'misplaced-pulse-check
                    "`|' is not at the start of a pulse"))
            (loop rest time duration previous events))
           (('- . d)
            (let ((duration (or d duration)))
              (loop rest (+ time duration) duration 'rest events)))
           (('_ . #f)
            (match (cons previous events)
              (('note (start held notes) . earlier)
               (loop rest (+ time duration) duration 'note
                     (cons (list start (+ held duration) notes) earlier)))
              (_ (fail 'hold-without-note
                       (if (eq? previous 'start)
                           "a part cannot start with `_' (hold): there is no note to hold"
                           "`_' (hold) after a rest: there is no note to hold")))))
           (((and base (or (? exact-integer?) (? symbol?))) . d)
            (strike (list (resolve-note base instrument table fail))
                    rest (or d duration)))
           (((or (? pair?) ()) . #f)      ; a chord, perhaps an empty one
            (strike (resolve-chord token instrument table fail)
                    rest duration))
           (_ (fail 'unknown-token
                    "~s is not a note, a chord, `_', `-', `/' or `|'"
                    token))))))))

(define (reverse-map f lst)
  (fold (lambda (x acc) (cons (f x) acc)) '() lst))
