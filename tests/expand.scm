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
;;;
;;; Slice feat/music-patterns (slice 5): `(expand-part tokens instrument
;;; #:key cycle pickup patterns)` → (values EVENTS LENGTH SPANS),
;;; `expand-tokens` gaining `#:patterns` (an alist from a pattern's name
;;; to (PATTERN . TOKENS)), and `(check-pattern tokens instrument #:key
;;; patterns)`. Written from 01-notation.md ("pattern"), 02-piece.md
;;; (`pattern`, `pattern-span`) and 03-reader.md (step 9, "Error
;;; reporting", the [patterns] cases and slice 5's decided bullets).
;;; Choices made where the docs are not explicit:
;;; - `uses` lists (NAME . LINE) for the patterns the offending token lies
;;;   inside, innermost first, LINE from the pattern record's location.
;;;   For undefined-pattern, wrong-instrument and pattern-cycle the
;;;   offending token is the use, so the pattern it names is not listed.
;;; - A leading `_` in a pattern extends the note before by the pattern's
;;;   duration, 1 pulse (the body starts at 1 pulse); the span starts at
;;;   the `_`.
;;; - After a `rep` whose body ends with a pattern, the duration is the
;;;   one before the pattern (the body's last duration).
;;; - `:step` composes through nesting, and moves chords note by note.
;;; - Option errors in a `(@ ...)` use carry `expansion-error-line`, the
;;;   `(@ ...)` list's line, as bad-pattern-use does.
;;; - Spans that start together are compared after sorting by depth.
;;; - check-pattern's return value is not tested, only that it returns;
;;;   its errors are tested for kind and time only.
;;; - `||` and `#:cycle`/`#:pickup` are tested through the reader.

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
  (make-pitch name (if alias (list alias) '()) display #f loc))

;; selisir: ding dong deng dung dang, aliases i o e u a.
(define selisir
  (make-scale 'selisir
              (list (deg 'ding 'i "i") (deg 'dong 'o "o") (deg 'deng 'e "e")
                    (deg 'dung 'u "u") (deg 'dang 'a "a"))
              #t loc))

(define gong-strokes
  (make-scale 'gong-strokes (list (deg 'G #f "G") (deg 'P #f "P")) #f loc))

(define (degree-index scale name)
  (list-index (lambda (d) (eq? (pitch-name d) name)) (scale-pitches scale)))

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

;;; ------------------------------------------------------------------
;;; Patterns (slice 5, feat/music-patterns)

;;; jarang: a pitched instrument with a gap (no dung1), so that moving
;;; by degree and moving by key differ.
;;; 1 deng1  2 dang1  3 ding2  4 dong2  5 deng2  (0-based indices 0 to 4)
(define jarang
  (make-instrument
   'jarang selisir
   (list->vector
    (map (match-lambda ((name octave) (pitched-note name octave)))
         '((deng 1) (dang 1) (ding 2) (dong 2) (deng 2))))
   loc))

(define* (pat name instrument line #:key short long)
  "A pattern record defined at LINE of test.nts, with the reader's
defaults: SHORT the name, LONG the short name."
  (let ((short (or short (symbol->string name))))
    (make-pattern name instrument short (or long short) #f
                  (make-source-location "test.nts" line))))

;;; Every pattern the tests use, as (NAME INSTRUMENT LINE BODY [SHORT LONG]).
;;; The LINE is the pattern form's line, which the uses report.
(define pattern-specs
  `((two        ,reyong 20 "3 4")
    (fast       ,reyong 21 "3:1/2 4")
    (rest       ,reyong 22 "3 -")
    (hold       ,reyong 23 "_ 3")
    (outer      ,reyong 24 "1:1/2 @two 2")
    (deep       ,reyong 25 "@outer @two")
    (checked    ,reyong 26 "1 |")
    (half-check ,reyong 27 "1:1/2 |")
    (bad        ,reyong 28 "1 9")
    (bad-inner  ,reyong 29 "2 @bad")
    (self       ,reyong 30 "1 @self")
    (ping       ,reyong 31 "1 @pong")
    (pong       ,reyong 32 "2 @ping")
    (degrees    ,reyong 33 "i2 o2")
    (keys       ,reyong 34 "4 5")
    (top        ,reyong 35 "a2")
    (top-key    ,reyong 36 "8")
    (bottom-key ,reyong 37 "1")
    (chord      ,reyong 38 "(i2 e2)")
    (stepped    ,reyong 39 "(@ degrees :step 1)")
    (named      ,reyong 40 "(@ two :short \"S\" :long \"L\")")
    (in-rep     ,reyong 41 "(rep 2 @two)")
    (uses-gong  ,reyong 42 "@g")
    (undefined-inner ,reyong 43 "1 @nope")
    (with-names ,reyong 44 "3 4" "1" "Norot on 1")
    (a2         ,reyong 45 "1")
    (g          ,gong   50 "G P")
    (gG         ,gong   51 "G")
    (jname      ,jarang 60 "a1 i2")
    (jgap       ,jarang 61 "e1")
    (jkey       ,jarang 62 "1")))

(define all-patterns
  (map (match-lambda
         ((name instrument line body)
          (cons name (cons (pat name instrument line) (toks body))))
         ((name instrument line body short long)
          (cons name (cons (pat name instrument line #:short short #:long long)
                           (toks body)))))
       pattern-specs))

(define (pattern-record name)
  (car (assq-ref all-patterns name)))

(define (span-fields s)
  "(NAME SHORT LONG START END DEPTH) of the pattern-span S."
  (list (pattern-name (pattern-span-pattern s))
        (pattern-span-short s) (pattern-span-long s)
        (pattern-span-start s) (pattern-span-end s)
        (pattern-span-depth s)))

(define (by-start-then-depth spans)
  "The span fields sorted by start, then depth: for comparing spans that
start together, whose order the docs leave open."
  (sort spans
        (lambda (a b)
          (or (< (list-ref a 3) (list-ref b 3))
              (and (= (list-ref a 3) (list-ref b 3))
                   (< (list-ref a 5) (list-ref b 5)))))))

(define (xpart str instrument)
  "(TRIPLES LENGTH SPANS) from expand-part with every test pattern, the
spans as span-fields in the order returned; or the raised object."
  (guard (c (#t c))
    (call-with-values
        (lambda () (expand-part (toks str) instrument #:patterns all-patterns))
      (lambda (events length spans texts)
        (list (map (lambda (e)
                     (list (event-start e) (event-duration e) (event-notes e)))
                   events)
              length
              (map span-fields spans))))))

(define (p-triples str instrument)
  (match (xpart str instrument)
    ((triples _ _) triples)
    (other other)))

(define (p-length str instrument)
  (match (xpart str instrument)
    ((_ length _) length)
    (other other)))

(define (p-spans str instrument)
  (match (xpart str instrument)
    ((_ _ spans) spans)
    (other other)))

(define (p-err str instrument)
  "(KIND TIME USES) of the &expansion-error expand-part raises for STR."
  (let ((c (xpart str instrument)))
    (if (expansion-error? c)
        (list (expansion-error-kind c) (expansion-error-time c)
              (expansion-error-uses c))
        c)))

(define (p-err-line str instrument)
  "(KIND TIME LINE USES) of the &expansion-error raised for STR."
  (let ((c (xpart str instrument)))
    (if (expansion-error? c)
        (list (expansion-error-kind c) (expansion-error-time c)
              (expansion-error-line c) (expansion-error-uses c))
        c)))

(define (check str instrument)
  "Run check-pattern on STR's tokens with every test pattern: ok when it
returns, else (KIND TIME) of the &expansion-error, or the raised object."
  (let ((c (guard (c (#t c))
             (check-pattern (toks str) instrument #:patterns all-patterns)
             'ok)))
    (if (expansion-error? c)
        (list (expansion-error-kind c) (expansion-error-time c))
        c)))

(define (pattern-event-tests cases)
  "CASES is a list of (NAME INSTRUMENT TOKENS TRIPLES)."
  (for-each
   (match-lambda
     ((name instrument tokens expected)
      (test-equal name expected (p-triples tokens instrument))))
   cases))

(define (pattern-error-tests kind cases)
  "CASES is a list of (NAME INSTRUMENT TOKENS TIME USES)."
  (for-each
   (match-lambda
     ((name instrument tokens time uses)
      (test-equal name (list kind time uses) (p-err tokens instrument))))
   cases))

;;; The interface

(test-group "patterns: expand-part returns events, a length and spans"
  (let ((result (xpart "1 @two 2" reyong)))
    (test-assert "three values" (and (list? result) (= 3 (length result))))
    (test-equal "the events"
      '((0 1 (0)) (1 1 (2)) (2 1 (3)) (3 1 (1)))
      (p-triples "1 @two 2" reyong))
    (test-equal "the length" 4 (p-length "1 @two 2" reyong))
    (test-equal "one span" '((two "two" "two" 1 3 0))
      (p-spans "1 @two 2" reyong)))
  (let ((spans (guard (c (#t c))
                 (call-with-values
                     (lambda () (expand-part (toks "1 @two") reyong
                                             #:patterns all-patterns))
                   (lambda (events length spans texts) spans)))))
    (test-assert "spans are pattern-span records"
      (and (list? spans) (pair? spans) (every pattern-span? spans)))
    (test-eq "a span holds the pattern record"
      (pattern-record 'two)
      (and (list? spans) (pair? spans) (pattern-span-pattern (car spans)))))
  (test-equal "no patterns: no spans" '() (p-spans "1 2 (rep 2 3)" reyong))
  (test-equal "expand-part without #:patterns" '(((0 1 (0)) (1 1 (1))) 2 ())
    (guard (c (#t c))
      (call-with-values (lambda () (expand-part (toks "1 2") reyong))
        (lambda (events length spans texts)
          (list (map (lambda (e)
                       (list (event-start e) (event-duration e) (event-notes e)))
                     events)
                length spans)))))
  (test-equal "expand-tokens with #:patterns: (EVENTS . LENGTH), without spans"
    '(((0 1 (0)) (1 1 (2)) (2 1 (3)) (3 1 (1))) . 4)
    (guard (c (#t c))
      (match (expand-tokens (toks "1 @two 2") reyong #:patterns all-patterns)
        ((events . length)
         (cons (map (lambda (e)
                      (list (event-start e) (event-duration e) (event-notes e)))
                    events)
               length))))))

;;; Playing a pattern

(test-group "patterns: events"
  (pattern-event-tests
   (list
    (list "@NAME plays the body" reyong "@two" '((0 1 (2)) (1 1 (3))))
    (list "(@ NAME) with no operators is the same" reyong "(@ two)"
          '((0 1 (2)) (1 1 (3))))
    (list "between notes" reyong "1 @two 2"
          '((0 1 (0)) (1 1 (2)) (2 1 (3)) (3 1 (1))))
    (list "twice in a row" reyong "@two @two"
          '((0 1 (2)) (1 1 (3)) (2 1 (2)) (3 1 (3))))
    (list "a trailing rest in the body takes time" reyong "@rest 2"
          '((0 1 (2)) (2 1 (1))))
    (list "strokes" gong "P @g" '((0 1 (1)) (1 1 (0)) (2 1 (1))))
    (list "a pattern named like a note: @a2 is the pattern, a2 the note"
          reyong "a2 @a2" '((0 1 (7)) (1 1 (0))))
    (list "in a rep" reyong "(rep 2 @two)"
          '((0 1 (2)) (1 1 (3)) (2 1 (2)) (3 1 (3))))))
  (test-equal "the length counts a trailing rest in the body" 3
    (p-length "@rest 2" reyong)))

(test-group "patterns: durations"
  (pattern-event-tests
   (list
    (list "the body starts at 1 pulse, whatever the part's duration"
          reyong "1:1/4 @two 2"
          '((0 1/4 (0)) (1/4 1 (2)) (5/4 1 (3)) (9/4 1/4 (1))))
    (list "the body's own suffix; the part's duration after it is what it was"
          reyong "1:1/4 @fast 2"
          '((0 1/4 (0)) (1/4 1/2 (2)) (3/4 1/2 (3)) (5/4 1/4 (1))))
    (list "a pattern first in the part, then the part's 1 pulse"
          reyong "@fast 2"
          '((0 1/2 (2)) (1/2 1/2 (3)) (1 1 (1))))
    (list "nested: the inner pattern starts at 1 pulse, and the outer's duration comes back"
          reyong "@outer"
          '((0 1/2 (0)) (1/2 1 (2)) (3/2 1 (3)) (5/2 1/2 (1))))
    (list "in a rep: the body still starts at 1 pulse"
          reyong "1:1/2 (rep 2 @two) 2"
          '((0 1/2 (0)) (1/2 1 (2)) (3/2 1 (3)) (5/2 1 (2)) (7/2 1 (3))
            (9/2 1/2 (1))))))
  (test-equal "the length with a fraction around a pattern" 5/2
    (p-length "1:1/4 @two 2" reyong))
  (test-equal "the length of a nested pattern" 3 (p-length "@outer" reyong)))

(test-group "patterns: a leading _ holds the note before the use"
  (pattern-event-tests
   (list
    (list "holds the part's note" reyong "1 @hold 2"
          '((0 2 (0)) (2 1 (2)) (3 1 (1))))
    (list "by the pattern's duration (1 pulse), not the part's"
          reyong "1:1/2 @hold"
          '((0 3/2 (0)) (3/2 1 (2))))
    (list "holds a chord" reyong "(1 3) @hold" '((0 2 (0 2)) (2 1 (2))))
    (list "holds the last note of the pattern before it" reyong "@two @hold"
          '((0 1 (2)) (1 2 (3)) (3 1 (2))))))
  (test-equal "the length with a lead hold" 4 (p-length "1 @hold 2" reyong)))

(test-group "patterns: :step"
  (pattern-event-tests
   (list
    (list "a name moves one degree up" reyong "(@ degrees :step 1)"
          '((0 1 (4)) (1 1 (5))))
    (list "and one down, across the octave" reyong "(@ degrees :step -1)"
          '((0 1 (2)) (1 1 (3))))
    (list "two down" reyong "(@ degrees :step -2)"
          '((0 1 (1)) (1 1 (2))))
    (list "three up" reyong "(@ degrees :step 3)"
          '((0 1 (6)) (1 1 (7))))
    (list ":step 0 changes nothing" reyong "(@ degrees :step 0)"
          '((0 1 (3)) (1 1 (4))))
    (list "key numbers move by keys" reyong "(@ keys :step 2)"
          '((0 1 (5)) (1 1 (6))))
    (list "a chord moves every note" reyong "(@ chord :step 1)"
          '((0 1 (4 6))))
    (list "a step inside a pattern" reyong "@stepped" '((0 1 (4)) (1 1 (5))))
    (list "steps add up through nesting" reyong "(@ stepped :step 1)"
          '((0 1 (5)) (1 1 (6))))
    (list "a step moves the notes of nested patterns" reyong "(@ outer :step 1)"
          '((0 1/2 (1)) (1/2 1 (3)) (3/2 1 (4)) (5/2 1/2 (2))))
    (list "by degree on an instrument with a gap: a1 i2 → i2 o2"
          jarang "(@ jname :step 1)" '((0 1 (2)) (1 1 (3))))
    (list "by key on an instrument with a gap: key 1 → key 2 (a1)"
          jarang "(@ jkey :step 1)" '((0 1 (1))))
    (list "by key to the last key" jarang "(@ jkey :step 4)" '((0 1 (4))))
    (list "a stroke moves one key" gong "(@ gG :step 1)" '((0 1 (1))))
    (list "the step keeps the durations" reyong "1:1/4 (@ fast :step 1) 2"
          '((0 1/4 (0)) (1/4 1/2 (3)) (3/4 1/2 (4)) (5/4 1/4 (1)))))))

;;; Spans

(test-group "patterns: spans"
  (for-each
   (match-lambda
     ((name instrument tokens expected)
      (test-equal name expected (p-spans tokens instrument))))
   (list
    (list "one use" reyong "1 @two 2" '((two "two" "two" 1 3 0)))
    (list "the end includes a trailing rest" reyong "@rest 2"
          '((rest "rest" "rest" 0 2 0)))
    (list "a lead hold: the span starts where the pattern does"
          reyong "1 @hold 2" '((hold "hold" "hold" 1 3 0)))
    (list "at fractional times" reyong "1:1/4 @fast 2"
          '((fast "fast" "fast" 1/4 5/4 0)))
    (list "two uses, sorted by start" reyong "@two 1 @two"
          '((two "two" "two" 0 2 0) (two "two" "two" 3 5 0)))
    (list "the pattern's names" reyong "@with-names"
          '((with-names "1" "Norot on 1" 0 2 0)))
    (list "names given at the use replace the pattern's" reyong
          "(@ with-names :short \"6\" :long \"Norot on 6\")"
          '((with-names "6" "Norot on 6" 0 2 0)))
    (list "names at a use with :step" reyong
          "(@ degrees :step -1 :short \"a\" :long \"Moved\")"
          '((degrees "a" "Moved" 0 2 0)))
    (list "a moved use keeps the pattern's names" reyong "(@ degrees :step 1)"
          '((degrees "degrees" "degrees" 0 2 0)))
    (list "a rep gives one span per repetition" reyong "1 (rep 2 @two)"
          '((two "two" "two" 1 3 0) (two "two" "two" 3 5 0)))
    (list "nested: the inner use at depth 1" reyong "1 @outer"
          '((outer "outer" "outer" 1 4 0) (two "two" "two" 3/2 7/2 1)))))
  (test-equal "names given inside a pattern, at depth 1"
    '((named "named" "named" 0 2 0) (two "S" "L" 0 2 1))
    (by-start-then-depth (p-spans "@named" reyong)))
  (test-equal "three levels"
    '((deep "deep" "deep" 1 6 0) (outer "outer" "outer" 1 4 1)
      (two "two" "two" 3/2 7/2 2) (two "two" "two" 4 6 1))
    (by-start-then-depth (p-spans "1 @deep" reyong)))
  (test-equal "a rep inside a pattern: one span per repetition, at depth 1"
    '((in-rep "in-rep" "in-rep" 0 4 0) (two "two" "two" 0 2 1)
      (two "two" "two" 2 4 1))
    (by-start-then-depth (p-spans "@in-rep" reyong)))
  (test-assert "spans are sorted by start"
    (let ((starts (map (lambda (s) (list-ref s 3))
                       (p-spans "@two (rep 2 @deep) @in-rep" reyong))))
      (and (pair? starts)
           (every <= starts (append (cdr starts) (list (last starts)))))))
  (test-assert "span times are exact"
    (every (lambda (s) (and (exact? (list-ref s 3)) (exact? (list-ref s 4))))
           (p-spans "1:1/3 @fast @outer" reyong))))

;;; | inside a pattern is checked where it is used

(test-group "patterns: | is checked where the pattern is used"
  (pattern-event-tests
   (list (list "on the pulse" reyong "@checked 2" '((0 1 (0)) (1 1 (1))))))
  (pattern-error-tests 'misplaced-pulse-check
   (list
    (list "off the pulse where it is used" reyong "1:1/2 @checked" 3/2
          '((checked . 26)))
    (list "off the pulse in the body" reyong "@half-check" 1/2
          '((half-check . 27))))))

;;; Errors at a use

(test-group "patterns: errors carry the chain of uses, innermost first"
  (pattern-error-tests 'note-out-of-range
   (list
    (list "in the body" reyong "2 @bad" 2 '((bad . 28)))
    (list "in a nested body" reyong "1 @bad-inner" 3
          '((bad . 28) (bad-inner . 29)))
    (list "in a rep: the first repetition" reyong "(rep 2 @bad)" 1
          '((bad . 28)))))
  (pattern-error-tests 'hold-without-note
   (list
    (list "a pattern starting with _ first in the part" reyong "@hold" 0
          '((hold . 23)))
    (list "after a rest" reyong "1 - @hold" 2 '((hold . 23))))))

(test-group "undefined-pattern"
  (pattern-error-tests 'undefined-pattern
   (list
    (list "@NAME" reyong "1 @nope" 1 '())
    (list "(@ NAME)" reyong "1:1/2 (@ nope :step 1)" 1/2 '())
    (list "inside a pattern: that pattern's use" reyong "@undefined-inner" 1
          '((undefined-inner . 43)))
    (list "in a rep" reyong "(rep 2 1 @nope)" 1 '())))
  (test-equal "without #:patterns"
    '(undefined-pattern 0 ())
    (let ((c (guard (c (#t c)) (expand-tokens (toks "@two") reyong))))
      (if (expansion-error? c)
          (list (expansion-error-kind c) (expansion-error-time c)
                (expansion-error-uses c))
          c))))

(test-group "pattern-cycle"
  (pattern-error-tests 'pattern-cycle
   (list
    (list "a pattern that uses itself" reyong "@self" 1 '((self . 30)))
    (list "through another" reyong "1 @ping" 3 '((pong . 32) (ping . 31)))))
  (pattern-event-tests
   (list
    (list "the same pattern twice in one body is not a cycle" reyong "@deep"
          '((0 1/2 (0)) (1/2 1 (2)) (3/2 1 (3)) (5/2 1/2 (1))
            (3 1 (2)) (4 1 (3)))))))

(test-group "wrong-instrument"
  (pattern-error-tests 'wrong-instrument
   (list
    (list "a gong pattern on the reyong" reyong "1 @g" 1 '())
    (list "a reyong pattern on the gong" gong "G @two" 1 '())
    (list "with operators" reyong "(@ g :step 1)" 0 '())
    (list "inside a pattern" reyong "1 @uses-gong" 1 '((uses-gong . 42))))))

(test-group "moved-note-out-of-range"
  (pattern-error-tests 'moved-note-out-of-range
   (list
    (list "a name moved above the top key" reyong "1 (@ top :step 1)" 1
          '((top . 35)))
    (list "a key moved above the last" reyong "(@ top-key :step 1)" 0
          '((top-key . 36)))
    (list "a key moved below the first" reyong "(@ bottom-key :step -1)" 0
          '((bottom-key . 37)))
    (list "the first note moved off" reyong "(@ degrees :step 5)" 0
          '((degrees . 33)))
    (list "the second note moved off: its time" reyong "(@ degrees :step 4)" 1
          '((degrees . 33)))
    (list "a degree that is not a key of the instrument" jarang
          "(@ jgap :step 1)" 0 '((jgap . 61)))
    (list "a stroke moved off" gong "(@ gG :step 2)" 0 '((gG . 51)))
    (list "a chord member moved off" reyong "1:1/2 (@ chord :step 3)" 1/2
          '((chord . 38)))
    (list "steps that add up through nesting" reyong "1 (@ stepped :step 4)" 1
          '((degrees . 33) (stepped . 39))))))

(test-group "bad-pattern-use, at the line of the (@ ...) list"
  (for-each
   (match-lambda
     ((name tokens time line)
      (test-equal name (list 'bad-pattern-use time line '())
        (p-err-line tokens reyong))))
   (list
    (list "no name" "(@)" 0 1)
    (list "a number as the name" "(@ 3)" 0 1)
    (list "a string as the name" "(@ \"two\")" 0 1)
    (list "a key where the name goes" "(@ :step 1)" 0 1)
    (list "a token after the name" "(@ two 1)" 0 1)
    (list "an improper list" "(@ two . x)" 0 1)
    (list "at its time and line" "1\n2:1/2 (@)" 3/2 2)))
  (test-equal "inside a pattern's rep, at its own line"
    '(bad-pattern-use 1 2 ())
    (p-err-line "(rep 2 1\n (@ 3))" reyong)))

(test-group "operator kinds, at the line of the (@ ...) list"
  (for-each
   (match-lambda
     ((name kind tokens)
      (test-equal name (list kind 1 2 '())
        (p-err-line (string-append "1\n" tokens) reyong))))
   (list
    (list ":step a fraction" 'bad-option "(@ two :step 1/2)")
    (list ":step inexact" 'bad-option "(@ two :step 1.0)")
    (list ":step a symbol" 'bad-option "(@ two :step x)")
    (list ":step a string" 'bad-option "(@ two :step \"1\")")
    (list ":step with no value" 'bad-option "(@ two :step)")
    (list ":short not a string" 'bad-option "(@ two :short 3)")
    (list ":long not a string" 'bad-option "(@ two :long x)")
    (list ":step twice" 'duplicate-option "(@ two :step 1 :step 2)")
    (list ":octave is not built" 'unknown-option "(@ two :octave 1)")
    (list ":drop-first is not built" 'unknown-option "(@ two :drop-first 1)")
    (list ":drop-last is not built" 'unknown-option "(@ two :drop-last 1)")
    (list "an unknown key" 'unknown-option "(@ two :foo 1)"))))

(test-group "patterns: errors left to right"
  (test-equal "a note before an undefined pattern" '(note-out-of-range 0 ())
    (p-err "9 @nope" reyong))
  (test-equal "an undefined pattern before a note" '(undefined-pattern 0 ())
    (p-err "@nope 9" reyong))
  (test-equal "a bad note in a body before a later undefined pattern"
    '(note-out-of-range 2 ((bad . 28)))
    (p-err "2 @bad @nope" reyong))
  (test-equal "uses are '() after a pattern has ended"
    '(note-out-of-range 2 ())
    (p-err "@two 9" reyong)))

;;; check-pattern: a pattern's body where it is defined (step 8)

(test-group "check-pattern"
  (for-each
   (match-lambda
     ((name instrument tokens)
      (test-equal name 'ok (check tokens instrument))))
   (list
    (list "ordinary tokens" reyong "1:1/4 i2 _ - (1 3) / 2")
    (list "a rep" reyong "(rep 2 1 2)")
    (list "a leading _ is allowed" reyong "_ 3")
    (list "| need not be on a pulse" reyong "1:1/2 |")
    (list "|| is not checked here" reyong "1 ||")
    (list "another pattern for the instrument" reyong "1 @two (@ two :step 1)")
    (list "strokes" gong "G @g")))
  (for-each
   (match-lambda
     ((name instrument tokens expected)
      (test-equal name expected (check tokens instrument))))
   (list
    (list "a key out of range" reyong "1 9" '(note-out-of-range 1))
    (list "an unknown note, at a time within the pattern" reyong "1:1/2 2 foo1"
          '(unknown-note 1))
    (list "a bad duration" reyong "1 2:0" '(bad-duration 1))
    (list "a bad chord" reyong "(1)" '(bad-chord 0))
    (list "an unknown token" reyong "1:1/4 \"x\"" '(unknown-token 1/4))
    (list "a bad rep" reyong "1 (rep 0 1)" '(bad-rep 1))
    (list "_ after a rest" reyong "1 - _" '(hold-without-note 2))
    (list "a pattern for another instrument" reyong "1 @g"
          '(wrong-instrument 1))
    (list "a time after a nested pattern" reyong "@two 9"
          '(note-out-of-range 2))
    (list "times start at 0 with 1 pulse" gong "G G:1/2 3"
          '(note-out-of-range 3/2)))))

;;; ------------------------------------------------------------------
;;; Slice feat/collapsed-annotation (iteration 5; 01, "Tokens" and
;;; "Free text", `pattern` and its operators; 02, "Iteration 5"; 03,
;;; "Iteration 5" and the [iteration 5] `bad-text` and `:annotation`
;;; cases; ADR 0057): `(text STRING)` and `(text STRING LENGTH)` tokens,
;;; free text that takes no time; `expand-part` returns (values EVENTS
;;; LENGTH SPANS TEXTS); each span's annotation in force (the use's,
;;; else the pattern's, else #f).
;;; Choices made where the docs are not explicit:
;;; - Patterns here are built with this slice's make-pattern (name
;;;   instrument short long annotation location), through apply and
;;;   inside a guard, so the file loads before the code exists.
;;; - Texts are compared as (START LENGTH TEXT), LENGTH #f for a point.
;;;   Two texts at one time keep the order written (sorting by start is
;;;   stable).
;;; - `expand-tokens` ("unchanged") accepts `(text ...)` and still
;;;   returns (EVENTS . LENGTH): the text makes no event.
;;; - LENGTH is a number as Guile reads it (`2`, `1/2`); a string, a
;;;   symbol, 0, a negative or an inexact number is `bad-text`, as is a
;;;   list of the wrong shape. bad-text's time is where the text is.
;;; - A bad text in a pattern's body, met where the pattern is used,
;;;   is bad-text with that pattern in `uses`, as a bad note in a body
;;;   is (the reader reports it first, where the pattern is defined).
;;; - Spans that start together are compared after sorting by depth.

(define (ann-proc name)
  "The procedure (notasi piece) exports as NAME, or one that raises."
  (let ((v (module-variable (resolve-interface '(notasi piece)) name)))
    (cond ((not v) (lambda args (error "not exported by (notasi piece):" name)))
          ((macro? (variable-ref v)) (eval name (resolve-module '(notasi piece))))
          (else (variable-ref v)))))

;;; (NAME INSTRUMENT LINE BODY SHORT LONG ANNOTATION)
(define ann-pattern-specs
  `((tp     ,reyong 70 "(text \"p\") 3 4"   "tp" "tp" #f)
    (tmid   ,reyong 71 "3 (text \"m\" 2) 4" "tmid" "tmid" #f)
    (touter ,reyong 72 "1 @tp"              "touter" "touter" #f)
    (thold  ,reyong 73 "(text \"h\") _ 3"   "thold" "thold" #f)
    (tbad   ,reyong 74 "1 (text 5)"         "tbad" "tbad" #f)
    (ann    ,reyong 75 "3 4"                "1" "Norot on 1" "norot on 1")
    (plain  ,reyong 76 "3 4"                "plain" "plain" #f)
    (aouter ,reyong 77 "@ann (@ plain :annotation \"inner\")"
            "AO" "Outer" "outer")
    (tgong  ,gong   78 "G (text \"g\") P"   "tgong" "tgong" #f)))

(define (ann-patterns)
  "The alist expand-part takes, from ann-pattern-specs; raises while
make-pattern has its old arity."
  (map (match-lambda
         ((name instrument line body short long annotation)
          (cons name
                (cons (apply make-pattern
                             (list name instrument short long annotation
                                   (make-source-location "test.nts" line)))
                      (toks body)))))
       ann-pattern-specs))

(define (text-fields t)
  "(START LENGTH TEXT) of the free-text T, or (not-free-text T)."
  (if ((ann-proc 'free-text?) t)
      (list ((ann-proc 'free-text-start) t) ((ann-proc 'free-text-length) t)
            ((ann-proc 'free-text-text) t))
      (list 'not-free-text t)))

(define (ann-span-fields s)
  "(NAME SHORT LONG ANNOTATION START END DEPTH) of the pattern-span S."
  (list (pattern-name (pattern-span-pattern s))
        (pattern-span-short s) (pattern-span-long s)
        ((ann-proc 'pattern-span-annotation) s)
        (pattern-span-start s) (pattern-span-end s)
        (pattern-span-depth s)))

(define (x4 str instrument)
  "(TRIPLES LENGTH SPANS TEXTS) from expand-part with the ann patterns,
spans as ann-span-fields sorted by start then depth and texts as
text-fields; TEXTS is no-fourth-value when expand-part returns three
values. Or the raised object."
  (guard (c (#t c))
    (call-with-values
        (lambda () (expand-part (toks str) instrument
                                #:patterns (ann-patterns)))
      (lambda (events length spans . rest)
        (list (map (lambda (e)
                     (list (event-start e) (event-duration e) (event-notes e)))
                   events)
              length
              (sort (map ann-span-fields spans)
                    (lambda (a b)
                      (or (< (list-ref a 4) (list-ref b 4))
                          (and (= (list-ref a 4) (list-ref b 4))
                               (< (list-ref a 6) (list-ref b 6))))))
              (match rest
                ((texts) (map text-fields texts))
                (_ 'no-fourth-value)))))))

(define (x4-triples str instrument)
  (match (x4 str instrument) ((triples _ _ _) triples) (other other)))
(define (x4-length str instrument)
  (match (x4 str instrument) ((_ length _ _) length) (other other)))
(define (x4-spans str instrument)
  (match (x4 str instrument) ((_ _ spans _) spans) (other other)))
(define (x4-texts str instrument)
  (match (x4 str instrument) ((_ _ _ texts) texts) (other other)))

(define (x4-err str instrument)
  "(KIND TIME LINE USES) of the &expansion-error expand-part raises for
STR, or what it returned or raised."
  (let ((c (x4 str instrument)))
    (if (expansion-error? c)
        (list (expansion-error-kind c) (expansion-error-time c)
              (expansion-error-line c) (expansion-error-uses c))
        c)))

(define (x4-check str instrument)
  "Run check-pattern on STR with the ann patterns: ok when it returns,
else (KIND TIME) of the &expansion-error, or the raised object."
  (let ((c (guard (c (#t c))
             (check-pattern (toks str) instrument #:patterns (ann-patterns))
             'ok)))
    (if (expansion-error? c)
        (list (expansion-error-kind c) (expansion-error-time c))
        c)))

(test-group "[annotation] expand-part returns four values"
  (let ((result (x4 "1 (text \"a\") 2" reyong)))
    (test-assert "four values"
      (and (list? result) (= 4 (length result))
           (not (eq? 'no-fourth-value (list-ref result 3))))))
  (test-equal "no text: '()" '() (x4-texts "1 2 @plain" reyong))
  (test-equal "without #:patterns" '((0 #f "a"))
    (guard (c (#t c))
      (call-with-values
          (lambda () (expand-part (toks "(text \"a\") 1") reyong))
        (lambda (events length spans . rest)
          (match rest
            ((texts) (map text-fields texts))
            (_ 'no-fourth-value))))))
  (test-assert "texts are free-text records"
    (guard (c (#t #f))
      (call-with-values
          (lambda () (expand-part (toks "(text \"a\") 1 (text \"b\" 2) 2") reyong))
        (lambda (events written spans . rest)
          (match rest
            ((texts) (and (= 2 (length texts))
                          (every (ann-proc 'free-text?) texts)))
            (_ #f)))))))

(test-group "[annotation] free text takes no time"
  (for-each
   (match-lambda
     ((name tokens triples length texts)
      (test-equal name (list triples length texts)
        (match (x4 tokens reyong)
          ((t l _ x) (list t l x))
          (other other)))))
   (list
    (list "a point between notes" "1 (text \"a\") 2"
          '((0 1 (0)) (1 1 (1))) 2 '((1 #f "a")))
    (list "at the start" "(text \"a\") 1"
          '((0 1 (0))) 1 '((0 #f "a")))
    (list "at the end" "1 2 (text \"end\")"
          '((0 1 (0)) (1 1 (1))) 2 '((2 #f "end")))
    (list "with a length" "(text \"a\" 2) 1 2 3"
          '((0 1 (0)) (1 1 (1)) (2 1 (2))) 3 '((0 2 "a")))
    (list "with a fractional length" "(text \"a\" 1/2) 1"
          '((0 1 (0))) 1 '((0 1/2 "a")))
    (list "a length longer than what follows" "1 (text \"a\" 4) 2"
          '((0 1 (0)) (1 1 (1))) 2 '((1 4 "a")))
    (list "after a fractional note: its time" "1:1/4 (text \"q\") 2"
          '((0 1/4 (0)) (1/4 1/4 (1))) 1/2 '((1/4 #f "q")))
    (list "the current duration is unchanged" "1:2 (text \"x\" 1/4) 2"
          '((0 2 (0)) (2 2 (1))) 4 '((2 1/4 "x")))
    (list "after a rest" "1 - (text \"r\") 2"
          '((0 1 (0)) (2 1 (1))) 3 '((2 #f "r")))
    (list "/ and | around it" "1 / (text \"a\") | 2"
          '((0 1 (0)) (1 1 (1))) 2 '((1 #f "a")))
    (list "two texts, sorted by start" "(text \"a\") 1 2 (text \"b\" 1) 3"
          '((0 1 (0)) (1 1 (1)) (2 1 (2))) 3 '((0 #f "a") (2 1 "b")))
    (list "two texts at one time: in the order written"
          "1 (text \"a\") (text \"b\" 2) 2"
          '((0 1 (0)) (1 1 (1))) 2 '((1 #f "a") (1 2 "b")))))
  (test-equal "strokes on a stroke instrument" '((1 #f "g"))
    (x4-texts "G (text \"g\") P" gong))
  (test-equal "expand-tokens: (EVENTS . LENGTH), the text making no event"
    '(((0 1 (0)) (1 1 (1))) . 2)
    (guard (c (#t c))
      (match (expand-tokens (toks "1 (text \"a\" 2) 2") reyong)
        ((events . length)
         (cons (map (lambda (e)
                      (list (event-start e) (event-duration e) (event-notes e)))
                    events)
               length))))))

(test-group "[annotation] _ after a text holds the note before it"
  (test-equal "a point" '((0 2 (0)) (2 1 (1)))
    (x4-triples "1 (text \"x\") _ 2" reyong))
  (test-equal "a text with a length" '((0 3 (0)))
    (x4-triples "1 (text \"x\" 2) _ _" reyong))
  (test-equal "the text stays at its point" '((1 #f "x"))
    (x4-texts "1 (text \"x\") _ 2" reyong))
  (test-equal "a pattern starting with a text, then _: holds the note before the use"
    '((0 2 (0)) (2 1 (2)))
    (x4-triples "1 @thold" reyong))
  (test-equal "and its text" '((1 #f "h"))
    (x4-texts "1 @thold" reyong))
  (test-equal "a text is not a note: _ at the start after it"
    '(hold-without-note 0)
    (match (x4-err "(text \"x\") _ 1" reyong)
      ((kind time _ _) (list kind time))
      (other other)))
  (test-equal "a text is not a note: _ after - and a text"
    '(hold-without-note 2)
    (match (x4-err "1 - (text \"x\") _" reyong)
      ((kind time _ _) (list kind time))
      (other other))))

(test-group "[annotation] free text in rep and patterns"
  (for-each
   (match-lambda
     ((name tokens texts)
      (test-equal name texts (x4-texts tokens reyong))))
   (list
    (list "rep repeats it" "(rep 2 1 (text \"x\"))" '((1 #f "x") (2 #f "x")))
    (list "rep: with a length, at each repetition" "(rep 2 (text \"x\" 1) 1 2)"
          '((0 1 "x") (2 1 "x")))
    (list "nested reps" "(rep 2 (rep 2 (text \"y\") 1))"
          '((0 #f "y") (1 #f "y") (2 #f "y") (3 #f "y")))
    (list "a rep with a fractional duration" "1:1/2 (rep 2 (text \"z\") 2)"
          '((1/2 #f "z") (1 #f "z")))
    (list "every use of a pattern carries it" "1 @tp @tp"
          '((1 #f "p") (3 #f "p")))
    (list "a text with a length in a pattern, at its time in the part"
          "1:1/2 @tmid" '((3/2 2 "m")))
    (list "through a nested pattern" "@touter" '((1 #f "p")))
    (list "in a rep of a pattern" "(rep 2 @tp)" '((0 #f "p") (2 #f "p")))
    (list ":step moves the notes, not the text" "(@ tp :step 1)" '((0 #f "p")))
    (list "the part's and the pattern's, sorted by start"
          "(text \"a\") 1 @tp (text \"b\") 2" '((0 #f "a") (1 #f "p") (3 #f "b")))))
  (test-equal ":step: the notes move" '((0 1 (3)) (1 1 (4)))
    (x4-triples "(@ tp :step 1)" reyong))
  (test-equal "a pattern with a text: its events and length" '(((0 1 (0)) (1 1 (2)) (2 1 (3))) 3)
    (match (x4 "1 @tp" reyong)
      ((t l _ _) (list t l))
      (other other)))
  (test-equal "strokes: a pattern with a text" '((1 #f "g"))
    (x4-texts "@tgong" gong)))

(test-group "[annotation] bad-text, at the text list's line"
  (for-each
   (match-lambda
     ((name tokens time line)
      (test-equal name (list 'bad-text time line '())
        (x4-err tokens reyong))))
   (list
    (list "no string" "(text)" 0 1)
    (list "a number" "(text 5)" 0 1)
    (list "a symbol" "(text angsel)" 0 1)
    (list "a list" "(text (\"a\"))" 0 1)
    (list "length 0" "(text \"a\" 0)" 0 1)
    (list "a negative length" "(text \"a\" -1)" 0 1)
    (list "a negative fraction" "(text \"a\" -1/2)" 0 1)
    (list "an inexact length" "(text \"a\" 0.5)" 0 1)
    (list "a length that is a symbol" "(text \"a\" x)" 0 1)
    (list "a length that is a string" "(text \"a\" \"2\")" 0 1)
    (list "a length with a suffix's colon" "(text \"a\" :2)" 0 1)
    (list "too many items" "(text \"a\" 1 2)" 0 1)
    (list "two strings" "(text \"a\" \"b\")" 0 1)
    (list "an improper list" "(text \"a\" . 2)" 0 1)
    (list "at its time" "1:1/2 2 (text)" 1 1)
    (list "at its own line" "1\n2 (text 5)" 2 2)
    (list "in a rep: its time and line" "1 (rep 2\n 2 (text 1))" 2 2)))
  (test-equal "in a pattern's body, where it is used: the pattern in uses"
    '(bad-text 2 ((tbad . 74)))
    (match (x4-err "1 @tbad" reyong)
      ((kind time _ uses) (list kind time uses))
      (other other))))

(test-group "[annotation] check-pattern checks text"
  (for-each
   (match-lambda
     ((name tokens)
      (test-equal name 'ok (x4-check tokens reyong))))
   (list
    (list "a point and a text with a length" "(text \"x\") 1 (text \"y\" 2) 2")
    (list "a text, then a leading _" "(text \"x\") _ 3")
    (list "in a rep" "(rep 2 1 (text \"x\"))")
    (list "a pattern with a text inside" "1 @tp")))
  (for-each
   (match-lambda
     ((name tokens expected)
      (test-equal name expected (x4-check tokens reyong))))
   (list
    (list "a bad text, at its time within the pattern" "1 (text 5)" '(bad-text 1))
    (list "a length 0" "1:1/2 2 (text \"a\" 0)" '(bad-text 1))
    (list "in a rep" "(rep 2 1 (text \"x\" -1))" '(bad-text 1)))))

(test-group "[annotation] the span's annotation in force"
  (for-each
   (match-lambda
     ((name tokens spans)
      (test-equal name spans (x4-spans tokens reyong))))
   (list
    (list "the pattern's" "@ann" '((ann "1" "Norot on 1" "norot on 1" 0 2 0)))
    (list "none: #f" "@plain" '((plain "plain" "plain" #f 0 2 0)))
    (list "the use's, on a pattern without one" "(@ plain :annotation \"x\")"
          '((plain "plain" "plain" "x" 0 2 0)))
    (list "the use's, over the pattern's" "(@ ann :annotation \"y\")"
          '((ann "1" "Norot on 1" "y" 0 2 0)))
    (list "names given at the use leave the annotation" "(@ ann :short \"6\" :long \"Norot on 6\")"
          '((ann "6" "Norot on 6" "norot on 1" 0 2 0)))
    (list "an annotation leaves the names" "(@ ann :annotation \"z\" :step 1)"
          '((ann "1" "Norot on 1" "z" 0 2 0)))
    (list "nested: each span its own"
          "@aouter"
          '((aouter "AO" "Outer" "outer" 0 4 0)
            (ann "1" "Norot on 1" "norot on 1" 0 2 1)
            (plain "plain" "plain" "inner" 2 4 1)))
    (list "nested: the outer use's annotation is the outer span's only"
          "(@ aouter :annotation \"o\")"
          '((aouter "AO" "Outer" "o" 0 4 0)
            (ann "1" "Norot on 1" "norot on 1" 0 2 1)
            (plain "plain" "plain" "inner" 2 4 1)))
    (list "each use its own" "@ann (@ ann :annotation \"b\") @ann"
          '((ann "1" "Norot on 1" "norot on 1" 0 2 0)
            (ann "1" "Norot on 1" "b" 2 4 0)
            (ann "1" "Norot on 1" "norot on 1" 4 6 0)))
    (list "an empty string is kept" "(@ plain :annotation \"\")"
          '((plain "plain" "plain" "" 0 2 0))))))

(test-group "[annotation] :annotation at a use: option kinds at the (@ ...) line"
  (for-each
   (match-lambda
     ((name kind tokens)
      (test-equal name (list kind 1 2 '())
        (x4-err (string-append "1\n" tokens) reyong))))
   (list
    (list "a number" 'bad-option "(@ plain :annotation 3)")
    (list "a symbol" 'bad-option "(@ plain :annotation x)")
    (list "no value" 'bad-option "(@ plain :annotation)")
    (list "twice" 'duplicate-option "(@ plain :annotation \"a\" :annotation \"b\")"))))

(define runner (test-runner-current))
(test-end "expand")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
