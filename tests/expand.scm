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

(define runner (test-runner-current))
(test-end "expand")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
