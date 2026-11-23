;;; Unit tests for (notasi expand): part tokens → timed events.
;;;
;;; Slice feat/music-durations (03-reader.md, "Slices (iteration 2)",
;;; slice 2): `(expand-tokens tokens instrument)` → (EVENTS . LENGTH),
;;; times as exact rationals in pulses (ADR 0025), duration suffixes and
;;; the current duration, `_` and `-` (ADR 0028), chords, `/`, `|`
;;; checks, and the [durations] error cases, raised as &expansion-error
;;; with a kind, a time and the pattern uses ('() until patterns).
;;;
;;; Written from doc/design/01-notation.md ("Tokens", "Durations",
;;; "Rests", "Rules"), 02-piece.md and 03-reader.md (step 7, step 9
;;; "Tokens to a fragment", "Parts and tokens"), not from the
;;; implementation. Tests check the kind, time and uses, never the
;;; message text.
;;;
;;; Choices made where the docs are not explicit:
;;; - Tokens are what the reader's `read` gives, with `keywords` and
;;;   `r7rs-symbols` off (03, step 1): `e2:1/4` and `5:2` are symbols,
;;;   `5` a number, `(2 5)` a list. The helper `toks` reads them that way.
;;; - A rest's suffix changes the current duration like a note's: in
;;;   `-:3 1` the note gets 3 pulses ("a duration suffix changes the
;;;   current duration first", 03 step 9; it "stays in force", 01).
;;; - `e2:` (an empty duration) is "not an exact positive number":
;;;   bad-duration. So is a suffix on `/` or `|` ("a suffix on anything
;;;   but a note, key number or `-`").
;;; - A chord's notes are sorted ascending by index, as the reader did in
;;;   v1 and still does.
;;; - Tokens that are only `/` give no events and length 0.
;;; - An error's time is where the offending token starts; for `|`, the
;;;   time of the check.
;;;
;;; Slice feat/music-rep (slice 3): `(rep N TOKEN ...)`, written from
;;; 01-notation.md ("Tokens", "Durations") and 03-reader.md (step 9,
;;; "Error reporting", the [rep] case and slice 3's decided bullets):
;;; every repetition identical, the body read with the duration in force
;;; before the rep and the duration after it the body's last; a leading
;;; `_` as a lead hold; nesting; `|` checked at every repetition, other
;;; mistakes at the first; `bad-rep` with `expansion-error-line`.
;;; Choices made where the docs are not explicit:
;;; - bad-rep's time is where the rep starts (as for any token).
;;; - `expansion-error-line` is 1-based from the source line Guile's
;;;   `read` records on the rep list (the toks helper reads from a string
;;;   port, so its first line is 1); #f for tokens built by hand.
;;; - `(rep N . x)` (an improper list), `(rep 2.0 1)` and `(rep :n 1)`
;;;   are bad-rep.
;;; - In a body, `/` before a leading `_` leaves it leading (`/` is
;;;   skipped), but `- _` is hold-without-note, as anywhere else.
;;; - The shape of a rep is checked before its body: `(rep 0 9)` is
;;;   bad-rep.

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 match)
             (notasi piece)
             (notasi expand))

;;; ------------------------------------------------------------------
;;; Fixtures

(define loc (make-source-location "test.nts" 1))

(define (deg name alias display)
  (make-degree name (if alias (list alias) '()) display #f loc))

;; selisir: ding dong deng dung dang, aliases i o e u a.
(define selisir
  (make-scale 'selisir
              (list (deg 'ding 'i "i") (deg 'dong 'o "o") (deg 'deng 'e "e")
                    (deg 'dung 'u "u") (deg 'dang 'a "a"))
              #t loc))

(define gong-strokes
  (make-scale 'gong-strokes (list (deg 'G #f "G") (deg 'P #f "P")) #f loc))

(define (degree-index scale name)
  (list-index (lambda (d) (eq? (degree-name d) name)) (scale-degrees scale)))

(define (pitched-note name octave)
  (make-note (symbol-append name (string->symbol (number->string octave)))
             (degree-index selisir name)
             octave))

;; reyong: 1 deng1  2 dung1  3 dang1  4 ding2  5 dong2  6 deng2  7 dung2  8 dang2
;; (0-based indices 0 to 7)
(define reyong
  (make-instrument
   'reyong selisir
   (list->vector
    (map (match-lambda ((name octave) (pitched-note name octave)))
         '((deng 1) (dung 1) (dang 1) (ding 2) (dong 2) (deng 2) (dung 2)
           (dang 2))))
   loc))

;; gong: 1 G  2 P
(define gong
  (make-instrument 'gong gong-strokes
                   (vector (make-note 'G 0 #f) (make-note 'P 1 #f))
                   loc))

;;; ------------------------------------------------------------------
;;; Helpers

(define (toks str)
  "The tokens in STR, read as the reader reads a part's body: with the
`keywords' and `r7rs-symbols' read options off."
  (let ((saved (read-options)))
    (dynamic-wind
      (lambda ()
        (read-set! keywords #f)
        (read-disable 'r7rs-symbols))
      (lambda ()
        (call-with-input-string str
          (lambda (port)
            (let loop ((acc '()))
              (let ((x (read port)))
                (if (eof-object? x)
                    (reverse acc)
                    (loop (cons x acc))))))))
      (lambda () (read-options saved)))))

(define (expand str instrument)
  "(EVENTS . LENGTH) for the tokens in STR, or the raised object."
  (guard (c (#t c))
    (expand-tokens (toks str) instrument)))

(define (triples str instrument)
  "The events of STR as (START DURATION NOTES) triples, or the raised
object (or the result) unchanged when it is not a pair of events."
  (match (expand str instrument)
    (((? list? events) . (? number?))
     (if (every event? events)
         (map (lambda (e)
                (list (event-start e) (event-duration e) (event-notes e)))
              events)
         (list 'not-events events)))
    (other other)))

(define (len str instrument)
  "The length of STR in pulses, or the raised object."
  (match (expand str instrument)
    ((_ . (? number? length)) length)
    (other other)))

(define (err str instrument)
  "(KIND TIME USES) of the &expansion-error raised for STR, or what
expanding returned or raised, unchanged."
  (let ((c (expand str instrument)))
    (if (expansion-error? c)
        (list (expansion-error-kind c) (expansion-error-time c)
              (expansion-error-uses c))
        c)))

(define (error-tests kind cases)
  "CASES is a list of (NAME INSTRUMENT TOKENS TIME): expanding TOKENS
raises KIND at TIME, with no uses."
  (for-each
   (match-lambda
     ((name instrument tokens time)
      (test-equal name (list kind time '()) (err tokens instrument))))
   cases))

(define (event-tests cases)
  "CASES is a list of (NAME INSTRUMENT TOKENS TRIPLES)."
  (for-each
   (match-lambda
     ((name instrument tokens expected)
      (test-equal name expected (triples tokens instrument))))
   cases))

;;; ------------------------------------------------------------------

(test-begin "expand")

;;; The interface

(test-group "expand-tokens returns events and a length"
  (let ((result (guard (c (#t c))
                  (expand-tokens (toks "1 2 3") reyong))))
    (test-assert "a pair" (pair? result))
    (test-assert "a list of event records"
      (and (pair? result) (list? (car result)) (every event? (car result))))
    (test-equal "three events" 3 (and (pair? result) (length (car result))))
    (test-equal "the length in pulses" 3 (and (pair? result) (cdr result)))))

(test-group "the toks helper reads as the reader does"
  (test-equal "durations are symbols, numbers numbers, chords lists"
    (list 'e2:1/4 (string->symbol "5:1/4") 5 '(2 5) '-:3 '_ '/ (string->symbol "|"))
    (toks "e2:1/4 5:1/4 5 (2 5) -:3 _ / |")))

;;; One pulse each, as in v1 (the default duration)

(test-group "default duration: one pulse"
  (event-tests
   (list
    (list "notes by number, 0-based" reyong "1 2 8"
          '((0 1 (0)) (1 1 (1)) (2 1 (7))))
    (list "notes by name" reyong "deng1 ding2 dang2"
          '((0 1 (0)) (1 1 (3)) (2 1 (7))))
    (list "notes by alias, resolved" reyong "e1 i2 a2"
          '((0 1 (0)) (1 1 (3)) (2 1 (7))))
    (list "strokes by name and number" gong "G 2 P 1"
          '((0 1 (0)) (1 1 (1)) (2 1 (1)) (3 1 (0))))
    (list "_ extends by one pulse" reyong "1 _ _ 2 _ 3"
          '((0 3 (0)) (3 2 (1)) (5 1 (2))))
    (list "- leaves a gap of one pulse" reyong "1 - 2 - - 3"
          '((0 1 (0)) (2 1 (1)) (5 1 (2))))
    (list "a rest first" reyong "- 1" '((1 1 (0))))
    (list "a rest ends a held note" reyong "1 _ - 2" '((0 2 (0)) (3 1 (1))))
    (list "only rests: no events" gong "- - -" '())
    (list "/ takes no time" reyong "1 / 2 / / 3"
          '((0 1 (0)) (1 1 (1)) (2 1 (2))))
    (list "_ after / extends the note before it" reyong "1 / _ 2"
          '((0 2 (0)) (2 1 (1))))
    (list "only /: no events" reyong "/ /" '())))
  (test-equal "only /: length 0" 0 (len "/ /" reyong)))

;;; Durations

(test-group "duration suffixes"
  (event-tests
   (list
    (list "a note with a duration of 2" reyong "1:2" '((0 2 (0))))
    (list "the duration stays in force" reyong "1:2 2 3"
          '((0 2 (0)) (2 2 (1)) (4 2 (2))))
    (list "01's example: four notes of two pulses" reyong "a1:2 o2 e1 i2"
          '((0 2 (2)) (2 2 (4)) (4 2 (0)) (6 2 (3))))
    (list "a later suffix changes it" reyong "1:2 2 3:1 4"
          '((0 2 (0)) (2 2 (1)) (4 1 (2)) (5 1 (3))))
    (list "a fraction" reyong "1:1/4 2 3 4"
          '((0 1/4 (0)) (1/4 1/4 (1)) (1/2 1/4 (2)) (3/4 1/4 (3))))
    (list "a suffix on a key number" reyong "5:1/2 1"
          '((0 1/2 (4)) (1/2 1/2 (0))))
    (list "a suffix on a name" reyong "ding2:1/2 dang2"
          '((0 1/2 (3)) (1/2 1/2 (7))))
    (list "a suffix on an alias" reyong "i2:3 a2"
          '((0 3 (3)) (3 3 (7))))
    (list "a suffix on a stroke" gong "G:4 P:1/2"
          '((0 4 (0)) (4 1/2 (1))))
    (list "a fraction that is not in lowest terms" reyong "1:2/4 2"
          '((0 1/2 (0)) (1/2 1/2 (1))))
    (list "a duration over one pulse that is not whole" reyong "1:3/2 2:1/2"
          '((0 3/2 (0)) (3/2 1/2 (1))))
    (list "thirds" reyong "1:1/3 2 3"
          '((0 1/3 (0)) (1/3 1/3 (1)) (2/3 1/3 (2))))
    (list "halves and thirds mixed" reyong "1:1/2 2:1/3 3:1/6"
          '((0 1/2 (0)) (1/2 1/3 (1)) (5/6 1/6 (2))))))
  (test-equal "the length with durations" 8 (len "a1:2 o2 e1 i2" reyong))
  (test-equal "a length that is a fraction" 3/4 (len "1:1/4 2 3" reyong))
  (test-equal "the length is exact" #t
    (exact? (len "1:1/3 2" reyong))))

(test-group "times and durations are exact rationals"
  (let ((events (match (expand "1:1/4 2 3:1/3 4" reyong)
                  ((events . _) events)
                  (_ '()))))
    (test-equal "four events" 4 (length events))
    (test-assert "every start is exact"
      (every (lambda (e) (exact? (event-start e))) events))
    (test-assert "every duration is exact"
      (every (lambda (e) (exact? (event-duration e))) events))
    (test-assert "every duration is positive"
      (every (lambda (e) (> (event-duration e) 0)) events))
    (test-equal "1/4 + 1/4 + 1/3 = 5/6, not 0.8333…" 5/6
      (and (= 4 (length events)) (event-start (list-ref events 3))))))

(test-group "chords"
  (event-tests
   (list
    (list "a chord takes the current duration" reyong "1:2 (1 3)"
          '((0 2 (0)) (2 2 (0 2))))
    (list "a chord first: one pulse" reyong "(2 5)" '((0 1 (1 4))))
    (list "a chord at a fraction" reyong "1:1/4 (2 5) 3"
          '((0 1/4 (0)) (1/4 1/4 (1 4)) (1/2 1/4 (2))))
    (list "chord members by name, sorted ascending" reyong "(i2 deng1)"
          '((0 1 (0 3))))
    (list "a chord held with _" reyong "1:1/2 (1 3) _ 2"
          '((0 1/2 (0)) (1/2 1 (0 2)) (3/2 1/2 (1))))
    (list "a chord of strokes" gong "(P G)" '((0 1 (0 1)))))))

(test-group "holds"
  (event-tests
   (list
    (list "_ extends by the current duration" reyong "1:2 _"
          '((0 4 (0))))
    (list "_ after a fraction" reyong "1:1/4 _ 2"
          '((0 1/2 (0)) (1/2 1/4 (1))))
    (list "_ uses the duration in force, not the note's" reyong "1:1/4 2:1 _"
          '((0 1/4 (0)) (1/4 2 (1))))
    (list "several holds" reyong "1:1/2 _ _ _" '((0 2 (0))))
    (list "Gold's . 1 . 6 after a note" reyong "1 _ 4 _ 3"
          '((0 2 (0)) (2 2 (3)) (4 1 (2))))
    (list "_ across / and |" reyong "1 / _ | _"
          '((0 3 (0))))))
  (test-equal "the length counts holds" 4 (len "1:2 _" reyong)))

(test-group "rests"
  (event-tests
   (list
    (list "- advances by the current duration" reyong "1:2 - 2"
          '((0 2 (0)) (4 2 (1))))
    (list "a rest with a duration" reyong "1 -:3 2:1"
          '((0 1 (0)) (4 1 (1))))
    (list "a rest's duration stays in force" reyong "-:3 1"
          '((3 3 (0))))
    (list "01's sangsih: -:1/4 e3 - e3" reyong "-:1/4 u2 - u2"
          '((1/4 1/4 (6)) (3/4 1/4 (6))))
    (list "01's colotomy: -:3 G:1 P - P G" gong "-:3 G:1 P - P G"
          '((3 1 (0)) (4 1 (1)) (6 1 (1)) (7 1 (0))))
    (list "a rest of a fraction ends a held note" reyong "1 _ -:1/2 2"
          '((0 2 (0)) (5/2 1/2 (1))))))
  (test-equal "trailing rests count towards the length" 5
    (len "1 2 -:3" reyong))
  (test-equal "trailing rests of a fraction" 5/2 (len "1 2 -:1/2" reyong))
  (test-equal "only rests: the length" 7/2 (len "-:3 -:1/2" gong))
  (test-equal "only rests: no events" '() (triples "-:3 -:1/2" gong))
  (test-equal "01's colotomy part is 8 pulses" 8 (len "-:3 G:1 P - P G" gong)))

;;; The pulse check

(test-group "| is a pulse check"
  (event-tests
   (list
    (list "| takes no time" reyong "1 | 2 | 3"
          '((0 1 (0)) (1 1 (1)) (2 1 (2))))
    (list "| at the start" reyong "| 1" '((0 1 (0))))
    (list "| at the end" reyong "1:1/2 2 |" '((0 1/2 (0)) (1/2 1/2 (1))))
    (list "| after quarters that fill a pulse" reyong "1:1/4 2 3 4 | 5"
          '((0 1/4 (0)) (1/4 1/4 (1)) (1/2 1/4 (2)) (3/4 1/4 (3)) (1 1/4 (4))))
    (list "| after a held note" reyong "1:1/2 _ | 2" '((0 1 (0)) (1 1/2 (1))))
    (list "| after a rest" reyong "1:1/2 - | 2" '((0 1/2 (0)) (1 1/2 (1))))
    (list "| after thirds" reyong "1:1/3 2 3 | 4"
          '((0 1/3 (0)) (1/3 1/3 (1)) (2/3 1/3 (2)) (1 1/3 (3))))
    (list "| after two pulses" reyong "1:2 | 2" '((0 2 (0)) (2 2 (1))))
    (list "| twice" reyong "1 | | 2" '((0 1 (0)) (1 1 (1))))))
  (test-equal "| does not count towards the length" 2 (len "| 1 | 2 |" reyong)))

;;; Errors

(test-group "expansion-error condition"
  (let ((c (expand "1 9" reyong)))
    (test-assert "expansion-error?" (expansion-error? c))
    (test-assert "is an &error" (error? c))
    (test-assert "carries a &message" (exception-with-message? c))
    (test-assert "the message is a string"
      (and (exception-with-message? c) (string? (exception-message c))))
    (test-equal "kind" 'note-out-of-range
      (and (expansion-error? c) (expansion-error-kind c)))
    (test-equal "time" 1 (and (expansion-error? c) (expansion-error-time c)))
    (test-equal "uses: '() until patterns" '()
      (and (expansion-error? c) (expansion-error-uses c))))
  (test-assert "the predicate is #f for other conditions"
    (not (expansion-error?
          (make-exception (make-error) (make-exception-with-message "x")))))
  (test-assert "the predicate is #f for non-conditions"
    (not (expansion-error? 'note-out-of-range))))

(test-group "bad-duration"
  (error-tests 'bad-duration
   (list
    (list "zero" reyong "e2:0" 0)
    (list "negative" reyong "e2:-1" 0)
    (list "a word" reyong "e2:x" 0)
    (list "inexact" reyong "e2:0.5" 0)
    (list "inexact whole number" reyong "e2:1.0" 0)
    (list "empty" reyong "e2:" 0)
    (list "zero on a key number" reyong "1:0" 0)
    (list "on a rest" reyong "-:0" 0)
    (list "a negative fraction on a rest" reyong "1 -:-1/2" 1)
    (list "on a stroke" gong "G:x" 0)
    (list "on _" reyong "1 _:2" 1)
    (list "on /" reyong "1 /:2" 1)
    (list "on |" reyong "1 |:2" 1)
    (list "after a fraction: the time of the token" reyong "1:1/2 2 3:0" 1)
    (list "after a rest" reyong "1 -:3 2:x" 4))))

(test-group "hold-without-note"
  (error-tests 'hold-without-note
   (list
    (list "_ first" reyong "_ 1" 0)
    (list "_ after -" reyong "1 - _" 2)
    (list "_ after a rest first" gong "- _" 1)
    (list "_ after / at the start" reyong "/ _ 1" 0)
    (list "_ after | at the start" reyong "| _ 1" 0)
    (list "_ after a held note and a rest" reyong "1 _ - _" 3)
    (list "_ after a rest with a duration" reyong "1 -:2 _" 3)
    (list "_ after a rest of a fraction" reyong "1 -:1/2 _" 3/2)
    (list "_ after a rest and /" reyong "1:1/4 - / _" 1/2))))

(test-group "misplaced-pulse-check"
  (error-tests 'misplaced-pulse-check
   (list
    (list "after a half pulse" reyong "1:1/2 | 2" 1/2)
    (list "after three quarters" reyong "1:1/4 2 3 | 4" 3/4)
    (list "after a pulse and a half" reyong "1:3/2 |" 3/2)
    (list "after a rest" reyong "-:1/2 |" 1/2)
    (list "after a hold" reyong "1:1/4 _ _ |" 3/4)
    (list "after thirds that do not fill a pulse" reyong "1:1/3 2 | 3" 2/3)
    (list "a second check off the pulse" reyong "1 | 2:1/2 | 3" 3/2))))

(test-group "v1 token errors, at times in pulses"
  (error-tests 'note-out-of-range
   (list
    (list "0" reyong "1 0 2" 1)
    (list "n+1" reyong "1 2 9" 2)
    (list "negative" reyong "-1 1" 0)
    (list "n+1 on a stroke instrument" gong "G 3" 1)
    (list "after a fraction" reyong "1:1/2 2 9" 1)
    (list "with a suffix" reyong "1 9:2" 1)
    (list "in a chord" reyong "1:1/4 (1 9)" 1/4)))
  (error-tests 'unknown-note
   (list
    (list "not in the scale" reyong "1 foo1" 1)
    (list "without an octave" reyong "ding" 0)
    (list "not on the instrument" reyong "ding1" 0)
    (list "with a suffix" reyong "1 ding1:2" 1)
    (list "after a hold of a fraction" reyong "1:1/2 _ foo1" 1)
    (list "a pitched note on a stroke instrument" gong "ding2" 0)
    (list "· is not a rest" reyong "1 · 2" 1)
    (list "in a chord" reyong "1:2 (1 foo1)" 2)))
  (error-tests 'bad-chord
   (list
    (list "empty" reyong "1 ()" 1)
    (list "one note" reyong "1:1/2 (1)" 1/2)
    (list "the same note twice" reyong "(ding2 i2)" 0)
    (list "member _" reyong "(1 _)" 0)
    (list "member -" reyong "(1 -)" 0)
    (list "member a string" reyong "(1 \"x\")" 0)))
  (error-tests 'unknown-token
   (list
    (list "a string" reyong "1 \"x\"" 1)
    (list "#t" reyong "#t" 0)
    (list "1.5" reyong "1:1/3 2 1.5" 2/3)
    (list "a vector" reyong "1 #(1 2)" 1))))

(test-group "errors: left to right"
  (test-equal "bad-duration before a later unknown-note"
    '(bad-duration 1 ())
    (err "1 2:0 foo1" reyong))
  (test-equal "unknown-note before a later bad-duration"
    '(unknown-note 1 ())
    (err "1 foo1 2:0" reyong))
  (test-equal "a misplaced check before a later out-of-range note"
    '(misplaced-pulse-check 1/2 ())
    (err "1:1/2 | 9" reyong))
  (test-equal "an out-of-range note before a later misplaced check"
    '(note-out-of-range 0 ())
    (err "9:1/2 |" reyong))
  (test-equal "hold-without-note before a later bad-duration"
    '(hold-without-note 0 ())
    (err "_ 1:0" reyong)))

;;; ------------------------------------------------------------------
;;; rep (slice 3, feat/music-rep)

(define (rep-err str instrument)
  "(KIND TIME LINE) of the &expansion-error raised for STR, or what
expanding returned or raised, unchanged."
  (let ((c (expand str instrument)))
    (if (expansion-error? c)
        (list (expansion-error-kind c) (expansion-error-time c)
              (expansion-error-line c))
        c)))

(define (expand-list tokens instrument)
  "(EVENTS . LENGTH) for TOKENS built by hand (no source positions), or
the raised object."
  (guard (c (#t c))
    (expand-tokens tokens instrument)))

(test-group "rep: repeating tokens"
  (event-tests
   (list
    (list "two notes twice" reyong "(rep 2 1 2)"
          '((0 1 (0)) (1 1 (1)) (2 1 (0)) (3 1 (1))))
    (list "once is the body itself" reyong "(rep 1 1 2)"
          '((0 1 (0)) (1 1 (1))))
    (list "notes before and after" reyong "1 (rep 3 2) 3"
          '((0 1 (0)) (1 1 (1)) (2 1 (1)) (3 1 (1)) (4 1 (2))))
    (list "names and aliases in the body" reyong "(rep 2 i2 dang2)"
          '((0 1 (3)) (1 1 (7)) (2 1 (3)) (3 1 (7))))
    (list "strokes" gong "(rep 2 G P)"
          '((0 1 (0)) (1 1 (1)) (2 1 (0)) (3 1 (1))))
    (list "a chord in the body" reyong "(rep 2 (1 3))"
          '((0 1 (0 2)) (1 1 (0 2))))
    (list "a chord next to a rep is still a chord" reyong "(1 3) (rep 1 2)"
          '((0 1 (0 2)) (1 1 (1))))
    (list "holds and rests in the body" reyong "(rep 2 1 _ - 2)"
          '((0 2 (0)) (3 1 (1)) (4 2 (0)) (7 1 (1))))
    (list "/ in the body takes no time" reyong "(rep 2 1 / 2)"
          '((0 1 (0)) (1 1 (1)) (2 1 (0)) (3 1 (1))))
    (list "a rest first in the body" reyong "(rep 2 - 1)"
          '((1 1 (0)) (3 1 (0))))
    (list "a body of only rests" gong "(rep 3 -)" '())
    (list "two reps in a row" reyong "(rep 2 1) (rep 2 2)"
          '((0 1 (0)) (1 1 (0)) (2 1 (1)) (3 1 (1))))))
  (test-equal "the length" 4 (len "(rep 2 1 2)" reyong))
  (test-equal "the length with tokens around it" 5 (len "1 (rep 3 2) 3" reyong))
  (test-equal "trailing rests in the body count" 6 (len "(rep 3 1 -)" reyong))
  (test-equal "a body of only rests: the length" 3 (len "(rep 3 -)" gong))
  (test-equal "the length is exact" #t (exact? (len "(rep 3 1:1/3)" reyong)))
  (test-equal "repeated events are event records" #t
    (match (expand "(rep 3 1 2)" reyong)
      (((? list? events) . _) (and (= 6 (length events)) (every event? events)))
      (_ #f)))
  (test-equal "tokens built by hand"
    '(((0 1 (0)) (1 1 (1)) (2 1 (0)) (3 1 (1))) . 4)
    (match (expand-list (list (list 'rep 2 1 2)) reyong)
      (((? list? events) . length)
       (cons (map (lambda (e)
                    (list (event-start e) (event-duration e) (event-notes e)))
                  events)
             length))
      (other other))))

(test-group "rep: durations"
  (event-tests
   (list
    (list "the body takes the duration in force before the rep"
          reyong "1:2 (rep 2 2) 3"
          '((0 2 (0)) (2 2 (1)) (4 2 (1)) (6 2 (2))))
    (list "a fraction in force before the rep" reyong "1:1/2 (rep 2 2 3) 4"
          '((0 1/2 (0)) (1/2 1/2 (1)) (1 1/2 (2)) (3/2 1/2 (1)) (2 1/2 (2))
            (5/2 1/2 (3))))
    (list "every repetition is identical: each starts with the duration before the rep"
          reyong "1:1/2 (rep 2 2 3:1)"
          '((0 1/2 (0)) (1/2 1/2 (1)) (1 1 (2)) (2 1/2 (1)) (5/2 1 (2))))
    (list "after the rep, the duration is the body's last"
          reyong "1:1/2 (rep 2 2 3:1) 4"
          '((0 1/2 (0)) (1/2 1/2 (1)) (1 1 (2)) (2 1/2 (1)) (5/2 1 (2))
            (7/2 1 (3))))
    (list "a suffix first in the body" reyong "(rep 2 1:1/4 2) 3"
          '((0 1/4 (0)) (1/4 1/4 (1)) (1/2 1/4 (0)) (3/4 1/4 (1)) (1 1/4 (2))))
    (list "a rest's suffix in the body sets it too" reyong "(rep 2 -:1/2 1) 2"
          '((1/2 1/2 (0)) (3/2 1/2 (0)) (2 1/2 (1))))
    (list "a body with no suffix leaves the duration unchanged"
          reyong "1:1/3 (rep 2 2) 3"
          '((0 1/3 (0)) (1/3 1/3 (1)) (2/3 1/3 (1)) (1 1/3 (2))))
    (list "_ in the body extends by the duration in force" reyong "1:1/2 (rep 2 2 _)"
          '((0 1/2 (0)) (1/2 1 (1)) (3/2 1 (1))))))
  (test-equal "the length with a fraction in force" 9/2
    (len "1:1/2 (rep 2 2 3:1) 4" reyong)))

(test-group "rep: a leading _ (lead hold)"
  (event-tests
   (list
    (list "holds the note before the rep, then the body's last note"
          reyong "1 (rep 2 _ 2)"
          '((0 2 (0)) (2 2 (1)) (4 1 (1))))
    (list "four times" reyong "1 (rep 4 _ 2)"
          '((0 2 (0)) (2 2 (1)) (4 2 (1)) (6 2 (1)) (8 1 (1))))
    (list "the body's last note, not its first" reyong "1 (rep 2 _ 2 3)"
          '((0 2 (0)) (2 1 (1)) (3 2 (2)) (5 1 (1)) (6 1 (2))))
    (list "by the duration in force before the rep" reyong "1:1/2 (rep 2 _ 2)"
          '((0 1 (0)) (1 1 (1)) (2 1/2 (1))))
    (list "holds a chord before the rep" reyong "(1 3) (rep 2 _ 2)"
          '((0 2 (0 2)) (2 2 (1)) (4 1 (1))))
    (list "_ after / at the start of the body is still leading"
          reyong "1 (rep 2 / _ 2)"
          '((0 2 (0)) (2 2 (1)) (4 1 (1))))
    (list "a held last note is held further" reyong "1 (rep 2 _ 2 _)"
          '((0 2 (0)) (2 3 (1)) (5 2 (1))))))
  (test-equal "the length with a lead hold" 5 (len "1 (rep 2 _ 2)" reyong))
  (error-tests 'hold-without-note
   (list
    (list "a part starting with a rep that starts with _" reyong "(rep 2 _ 1)" 0)
    (list "a rest before the rep" reyong "1 - (rep 2 _ 2)" 2)
    (list "only / before the rep" reyong "/ (rep 2 _ 1)" 0)
    (list "the body ends in a rest: the second time" reyong "1 (rep 2 _ 2 -)" 4)
    (list "the body ends in a rest: the second time, at a fraction"
          reyong "1:1/3 (rep 3 _ 2 -)" 4/3)
    (list "_ after a rest inside the body: the first time" reyong "1 (rep 2 - _ 2)" 2)
    (list "_ after a rest later in the body" reyong "(rep 2 1 - _)" 2))))

(test-group "rep: nested"
  (event-tests
   (list
    (list "a rep inside a rep" reyong "(rep 2 1 (rep 2 2))"
          '((0 1 (0)) (1 1 (1)) (2 1 (1)) (3 1 (0)) (4 1 (1)) (5 1 (1))))
    (list "three levels" reyong "(rep 2 (rep 2 (rep 2 1)))"
          '((0 1 (0)) (1 1 (0)) (2 1 (0)) (3 1 (0))
            (4 1 (0)) (5 1 (0)) (6 1 (0)) (7 1 (0))))
    (list "the inner body takes the duration in force in the outer body"
          reyong "(rep 2 1:1/2 (rep 3 2)) 3"
          '((0 1/2 (0)) (1/2 1/2 (1)) (1 1/2 (1)) (3/2 1/2 (1))
            (2 1/2 (0)) (5/2 1/2 (1)) (3 1/2 (1)) (7/2 1/2 (1))
            (4 1/2 (2))))
    (list "the inner rep's last duration carries out of both"
          reyong "(rep 2 1 (rep 1 2:1/2)) 3"
          '((0 1 (0)) (1 1/2 (1)) (3/2 1 (0)) (5/2 1/2 (1)) (3 1/2 (2))))
    (list "a nested lead hold" reyong "1 (rep 2 (rep 2 _ 2))"
          '((0 2 (0)) (2 2 (1)) (4 2 (1)) (6 2 (1)) (8 1 (1))))))
  (test-equal "the length of a nested rep" 6 (len "(rep 2 1 (rep 2 2))" reyong))
  (test-equal "the length of three levels" 8
    (len "(rep 2 (rep 2 (rep 2 1)))" reyong))
  (test-equal "hold-without-note in a nested body"
    '(hold-without-note 0 ())
    (err "(rep 2 (rep 2 _ 1))" reyong)))

(test-group "rep: | is checked at every repetition"
  (event-tests
   (list
    (list "| on the pulse every time" reyong "(rep 4 1:1/2 2 |)"
          '((0 1/2 (0)) (1/2 1/2 (1)) (1 1/2 (0)) (3/2 1/2 (1))
            (2 1/2 (0)) (5/2 1/2 (1)) (3 1/2 (0)) (7/2 1/2 (1))))
    (list "| first in the body, on the pulse every time" reyong "(rep 2 | 1 2)"
          '((0 1 (0)) (1 1 (1)) (2 1 (0)) (3 1 (1))))))
  (error-tests 'misplaced-pulse-check
   (list
    (list "off the pulse the first time" reyong "(rep 2 1:1/4 2 3 |)" 3/4)
    (list "a body of 3/4 pulse: passes the first time, fails the second"
          reyong "(rep 2 | 1:1/4 2 3)" 3/4)
    (list "fails the second time at the end of the body"
          reyong "1:1/2 (rep 2 2 |)" 3/2)
    (list "after a note before the rep" reyong "1 (rep 3 | 2:1/2)" 3/2)
    (list "a body of 3/4 pulse in a nested rep" reyong "(rep 2 | (rep 3 1:1/4))" 3/4)
    (list "in the inner body, on a later outer repetition"
          reyong "(rep 2 (rep 2 | 1:1/2 2) 3)" 5/2)
    (list "after the rep" reyong "(rep 3 1:1/2) |" 3/2))))

(test-group "rep: other mistakes in the body, at the first repetition"
  (error-tests 'note-out-of-range
   (list
    (list "a key number" reyong "1 (rep 3 2 9)" 2)
    (list "in a chord" reyong "1:1/2 (rep 2 2 (1 9))" 1)
    (list "in a nested body" reyong "(rep 2 1 (rep 2 2 9))" 2)))
  (error-tests 'unknown-note
   (list (list "a note name" reyong "(rep 2 1 foo1)" 1)))
  (error-tests 'bad-duration
   (list (list "a suffix" reyong "(rep 2 1 2:0)" 1)
         (list "a suffix on _" reyong "1 (rep 2 _:2)" 1)))
  (error-tests 'bad-chord
   (list (list "a chord of one note" reyong "1 (rep 2 (1))" 1)))
  (error-tests 'unknown-token
   (list (list "a string" reyong "(rep 2 1 \"x\")" 1)
         (list "#t" reyong "1:1/2 (rep 2 #t)" 1/2))))

(test-group "bad-rep"
  (for-each
   (match-lambda
     ((name tokens time)
      (test-equal name (list 'bad-rep time 1) (rep-err tokens reyong))))
   (list
    (list "no count and no tokens" "(rep)" 0)
    (list "a count but no tokens" "(rep 2)" 0)
    (list "a count of 0" "(rep 0 1)" 0)
    (list "a negative count" "(rep -1 1)" 0)
    (list "an inexact count" "(rep 1.5 1)" 0)
    (list "an inexact whole count" "(rep 2.0 1)" 0)
    (list "a fraction" "(rep 3/2 1)" 0)
    (list "a symbol" "(rep x 1)" 0)
    (list "a string" "(rep \"2\" 1)" 0)
    (list "a :key" "(rep :n 1)" 0)
    (list "a list as the count" "(rep (2) 1)" 0)
    (list "an improper list" "(rep 2 1 . 2)" 0)
    (list "at the time where the rep starts" "1 2:1/2 (rep 0 3)" 3/2)
    (list "nested: the time of the inner rep" "(rep 2 1 (rep 0 2))" 1)))
  (test-equal "the line of the rep, when it is not the first"
    '(bad-rep 3 2)
    (rep-err "1 2\n3 (rep 0 1)" reyong))
  (test-equal "the line of a nested rep"
    '(bad-rep 2 3)
    (rep-err "(rep 2 1\n  2\n  (rep x 3))" reyong))
  (test-equal "the line of the outer rep when it is the bad one"
    '(bad-rep 0 2)
    (rep-err "\n(rep 0\n 1\n (rep 2 3))" reyong))
  (test-equal "the shape is checked before the body" '(bad-rep 0 1)
    (rep-err "(rep 0 9)" reyong))
  (test-equal "a mistake before a bad nested rep comes first"
    '(note-out-of-range 0 #f)
    (rep-err "(rep 2 9 (rep 0 1))" reyong))
  (let ((c (expand-list (list 1 (list 'rep 0 1)) reyong)))
    (test-equal "tokens built by hand: kind" 'bad-rep
      (and (expansion-error? c) (expansion-error-kind c)))
    (test-equal "tokens built by hand: time" 1
      (and (expansion-error? c) (expansion-error-time c)))
    (test-equal "tokens built by hand: line #f" #f
      (and (expansion-error? c) (expansion-error-line c))))
  (let ((c (expand "(rep 0 1)" reyong)))
    (test-assert "bad-rep is an &expansion-error" (expansion-error? c))
    (test-assert "and an &error" (error? c))
    (test-equal "uses '()" '()
      (and (expansion-error? c) (expansion-error-uses c)))))

(test-group "expansion-error-line is #f for errors that do not set it"
  (for-each
   (match-lambda
     ((name tokens expected)
      (test-equal name expected (rep-err tokens reyong))))
   (list
    (list "a token error outside a rep" "1\n9" '(note-out-of-range 1 #f))
    (list "a token error inside a rep" "(rep 2\n 1 9)" '(note-out-of-range 1 #f))
    (list "misplaced-pulse-check inside a rep" "(rep 2 | 1:1/4 2 3)"
          '(misplaced-pulse-check 3/4 #f))
    (list "hold-without-note inside a rep" "(rep 2 _ 1)" '(hold-without-note 0 #f))
    (list "bad-duration" "1:0" '(bad-duration 0 #f)))))

(test-group "rep: errors left to right"
  (test-equal "an error before the rep comes first" '(note-out-of-range 0 ())
    (err "9 (rep 0 1)" reyong))
  (test-equal "a bad rep before a later error" '(bad-rep 1 ())
    (err "1 (rep 0 1) 9" reyong))
  (test-equal "an error in the body before one after the rep"
    '(unknown-note 1 ())
    (err "(rep 2 1 foo1) 9" reyong))
  (test-equal "an error after the rep, at its time" '(note-out-of-range 4 ())
    (err "(rep 2 1 2) 9" reyong)))

(define runner (test-runner-current))
(test-end "expand")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
