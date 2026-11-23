;;; Tests for iteration 3, milestone 1 (feat/syntax): parts written
;;; `(part :instrument I :name N TOKEN ...)`, colotomy parts written as
;;; the same `part` form (ADR 0038), the **[parts]** error cases of
;;; 03-reader.md, and the `gilak` and `bapang` colotomies of the
;;; `gong-kebyar` template (ADR 0046).
;;;
;;; Written from doc/design/01-notation.md, 03-reader.md and ADRs 0038
;;; and 0046, before the implementation. Every fixture uses the new
;;; syntax only. Tests check the error kind and the location fields; an
;;; old-form error is also checked by its message containing the new
;;; form with the user's instrument (`(part :instrument gong`), as the
;;; milestone's "Decided when it started" bullets say.
;;;
;;; Choices made where the docs are not explicit:
;;; - Errors in a colotomy part are at the line of the part form inside
;;;   the colotomy (03, "Which line an error reports": the list to
;;;   blame; "an option error at the line of the list that holds the
;;;   option"). Colotomies whose part form is not a list (or where the
;;;   line could be the colotomy's) are written on one line, so both
;;;   lines agree.
;;; - `parts-need-names` inside a colotomy is at the second part's line,
;;;   as at the top level.
;;; - The old top-level form with `:name`, `(part pemade :name polos
;;;   ...)`, is `missing-option` with the new form in its message, like
;;;   `(part gong ...)`, rather than `option-after-body`: the milestone
;;;   says the old forms are errors whose messages show the new one.
;;; - The old form `(part gong ...)` inside a colotomy is
;;;   `missing-option` (it is a `part` form without `:instrument`, read
;;;   by the same code as a top-level part), and its message shows the
;;;   new form too.
;;; - The template's `bapang` is checked by its strokes' starts and
;;;   notes only; 01 gives its pulses but not how its durations are
;;;   written. `gilak` is checked as full (START DURATION NOTES) triples,
;;;   since 01 gives its exact tokens, `-:3 GL:1 P - P G`.
;;; - The `part` and `time` fields of the [parts] errors are not tested:
;;;   03 does not fix them for these cases.

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 match)
             (notasi piece)
             (notasi reader))

;;; ------------------------------------------------------------------
;;; Helpers (copied from tests/reader.scm)

(define (catch-syntax-error thunk)
  "Run THUNK. Return the condition it raises, or the symbol no-error
if it returns normally."
  (guard (c (#t c))
    (thunk)
    'no-error))

(define (string-error str)
  "(KIND LINE) of the &notasi-syntax-error raised reading STR, or the
raised object (or no-error) unchanged."
  (let ((c (catch-syntax-error (lambda () (read-piece-string str)))))
    (if (notasi-syntax-error? c)
        (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c))
        c)))

(define (string-message str)
  "The message of the error raised reading STR, or #f."
  (let ((c (catch-syntax-error (lambda () (read-piece-string str)))))
    (and (notasi-syntax-error? c)
         (exception-with-message? c)
         (exception-message c))))

(define (message-contains? str text)
  (let ((m (string-message str)))
    (and (string? m) (string-contains m text) #t)))

(define (lines . strs)
  "Join STRS with newlines, so line numbers in tests are easy to see."
  (string-join strs "\n"))

(define (try-read-string . strs)
  "Read the lines STRS as a piece, or #f if reading raises."
  (guard (c (#t #f)) (read-piece-string (apply lines strs))))

(define (find-named name-of name lst)
  (or (find (lambda (x) (eq? (name-of x) name)) lst)
      (error "nothing named:" name)))

(define (part-named pc name) (find-named part-name name (piece-parts pc)))
(define (instrument-named pc name)
  (find-named instrument-name name (piece-instruments pc)))

(define (event-triple e)
  (list (event-start e) (event-duration e) (event-notes e)))

(define (part-triples pc name)
  "The events of part NAME as (START DURATION NOTES) triples."
  (map event-triple (part-events (part-named pc name))))

(define (part-onsets pc name)
  "The events of part NAME as (START NOTES) pairs."
  (map (lambda (e) (list (event-start e) (event-notes e)))
       (part-events (part-named pc name))))

(define (safe thunk)
  "THUNK's value, or #f if it raises."
  (guard (c (#t #f)) (thunk)))

;;; ------------------------------------------------------------------
;;; Fixtures
;;;
;;; Definitions; forms added after them start on line 8.
;;;   ugal (6 notes):   0 o1  1 e1  2 u1  3 a1  4 i2  5 o2
;;;   gong (4 notes):   0 G  1 GL  2 P  3 T
;;;   kempli (1 note):  0 K
(define defs
  (lines "(piece \"Syntax\")"                                      ; 1
         "(scale selisir (ding :alias i) (dong :alias o) (deng :alias e) (dung :alias u) (dang :alias a))" ; 2
         "(strokes gong-strokes G GL P T)"                         ; 3
         "(strokes kempli-strokes K)"                              ; 4
         "(instrument ugal selisir o1 e1 u1 a1 i2 o2)"             ; 5
         "(instrument gong gong-strokes G GL P T)"                 ; 6
         "(instrument kempli kempli-strokes K)"))                  ; 7

(define (defs+ . more)
  "defs followed by the lines MORE, which start on line 8."
  (apply lines defs more))

(define (read-defs+ . more)
  (try-read-string (apply defs+ more)))

;;; The same definitions under a piece form with OPTIONS.
(define (defs-with options . more)
  (apply lines
         (string-append "(piece \"Syntax\" " options ")")
         (append (cdr (string-split defs #\newline)) more)))

(define (read-defs-with options . more)
  (try-read-string (apply defs-with options more)))

;;; ------------------------------------------------------------------
(test-begin "syntax")

;;; ------------------------------------------------------------------
;;; 1. The new part form

(test-group "[parts] (part :instrument I ...)"
  (let ((pc (read-defs+ "(part :instrument ugal 1 2 3)")))           ; 8
    (test-assert "reads" (piece? pc))
    (test-equal "named after its instrument" '(ugal kempli)
      (and pc (map part-name (piece-parts pc))))
    (test-assert "plays its instrument"
      (and pc (eq? (part-instrument (part-named pc 'ugal))
                   (instrument-named pc 'ugal))))
    (test-equal "its tokens" '((0 1 (0)) (1 1 (1)) (2 1 (2)))
      (and pc (part-triples pc 'ugal)))
    (test-equal "its line" 8
      (and pc (source-location-line (part-location (part-named pc 'ugal))))))

  (let ((pc (read-defs+ "(part :instrument ugal :name p 1 2)")))
    (test-assert ":instrument then :name: reads" (piece? pc))
    (test-equal ":instrument then :name: the part's name" '(p)
      (and pc (map part-name (filter (lambda (p) (eq? (part-origin p) 'written))
                                     (piece-parts pc)))))
    (test-equal ":instrument then :name: its tokens" '((0 1 (0)) (1 1 (1)))
      (and pc (part-triples pc 'p))))

  (let ((pc (read-defs+ "(part :name p :instrument ugal 1 2)")))
    (test-assert ":name then :instrument: reads" (piece? pc))
    (test-assert ":name then :instrument: plays ugal"
      (and pc (eq? (part-instrument (part-named pc 'p))
                   (instrument-named pc 'ugal))))
    (test-equal ":name then :instrument: its tokens" '((0 1 (0)) (1 1 (1)))
      (and pc (part-triples pc 'p))))

  (let ((pc (read-defs+ "(part :instrument ugal :name polos 1 2)"
                        "(part :instrument ugal :name sangsih 3 4)")))
    (test-assert "two named parts on one instrument read" (piece? pc))
    (test-equal "two named parts: names in order" '(polos sangsih kempli)
      (and pc (map part-name (piece-parts pc)))))

  (let ((pc (read-defs+ "(part :instrument ugal 1 2)"
                        "(part :instrument gong G P)")))
    (test-equal "one part on each of two instruments: named after them"
      '(ugal gong kempli)
      (and pc (map part-name (piece-parts pc))))))

(test-group "[parts] parts-need-names"
  (test-equal "two parts on one instrument, neither named"
    '(parts-need-names 9)
    (string-error (defs+ "(part :instrument ugal 1 2)"                ; 8
                         "(part :instrument ugal 3 4)")))             ; 9
  (test-equal "two parts on one instrument, the second unnamed"
    '(parts-need-names 9)
    (string-error (defs+ "(part :instrument ugal :name polos 1 2)"   ; 8
                         "(part :instrument ugal 3 4)")))             ; 9
  (test-equal "two parts on one instrument, the first unnamed"
    '(parts-need-names 9)
    (string-error (defs+ "(part :instrument ugal 1 2)"                ; 8
                         "(part :instrument ugal :name sangsih 3 4)"))))  ; 9

;;; ------------------------------------------------------------------
;;; 2. Parts inside a colotomy

(test-group "[parts] colotomy parts are part forms"
  (let ((pc (read-defs-with ":colotomy c"
                            "(colotomy c 4 (part :instrument gong G - - -))" ; 8
                            "(part :instrument ugal 1:8)")))              ; 9
    (test-assert "reads" (piece? pc))
    (test-equal "generates part gong, named after its instrument"
      '((ugal written) (gong colotomy) (kempli timekeeper))
      (and pc (map (lambda (p) (list (part-name p) (part-origin p)))
                   (piece-parts pc))))
    (test-assert "the generated part plays gong"
      (and pc (eq? (part-instrument (part-named pc 'gong))
                   (instrument-named pc 'gong))))
    (test-equal "its events over two cycles" '((0 1 (0)) (4 1 (0)))
      (and pc (part-triples pc 'gong)))
    (test-equal "the colotomy record's part" '(gong)
      (and pc (map part-name (colotomy-parts (cdar (piece-colotomies pc)))))))

  (let ((pc (read-defs-with ":colotomy c"
                            "(colotomy c 4 (part :instrument gong :name gongs G - - -))"
                            "(part :instrument ugal 1:4)")))
    (test-equal ":name inside a colotomy names the generated part"
      '(ugal gongs kempli)
      (and pc (map part-name (piece-parts pc))))
    (test-equal ":name inside a colotomy: its events" '((0 1 (0)))
      (and pc (part-triples pc 'gongs))))

  (let ((pc (read-defs-with ":colotomy c"
                            "(colotomy c 4 (part :name gongs :instrument gong G - - -))"
                            "(part :instrument ugal 1:4)")))
    (test-equal ":name before :instrument inside a colotomy"
      '(ugal gongs kempli)
      (and pc (map part-name (piece-parts pc)))))

  (let ((pc (read-defs-with ":colotomy c"
                            "(colotomy c 4"                                ; 8
                            "  (part :instrument gong :name wadon G - - -)" ; 9
                            "  (part :instrument gong :name lanang - GL - -))" ; 10
                            "(part :instrument ugal 1:4)")))
    (test-equal "two named colotomy parts on one instrument"
      '(ugal wadon lanang kempli)
      (and pc (map part-name (piece-parts pc))))
    (test-equal "the second one's events" '((1 1 (1)))
      (and pc (part-triples pc 'lanang))))

  (test-equal "two colotomy parts on one instrument, neither named"
    '(parts-need-names 10)
    (string-error (defs-with ":colotomy c"
                             "(colotomy c 4"                        ; 8
                             "  (part :instrument gong G - - -)"    ; 9
                             "  (part :instrument gong - GL - -))"  ; 10
                             "(part :instrument ugal 1:4)")))
  (test-equal "two colotomy parts on one instrument, one named"
    '(parts-need-names 10)
    (string-error (defs-with ":colotomy c"
                             "(colotomy c 4"                                 ; 8
                             "  (part :instrument gong :name wadon G - - -)" ; 9
                             "  (part :instrument gong - GL - -))"           ; 10
                             "(part :instrument ugal 1:4)"))))

;;; ------------------------------------------------------------------
;;; 3. [parts] errors

(test-group "[parts] a part without :instrument"
  (test-equal "the old form (part gong ...): missing-option"
    '(missing-option 8)
    (string-error (defs+ "(part gong G - - -)")))
  (test-assert "the old form: the message shows (part :instrument gong ...)"
    (message-contains? (defs+ "(part gong G - - -)") "(part :instrument gong"))
  (test-equal "the old form with :name: missing-option"
    '(missing-option 8)
    (string-error (defs+ "(part ugal :name polos 1 2)")))
  (test-assert "the old form with :name: the message shows (part :instrument ugal ...)"
    (message-contains? (defs+ "(part ugal :name polos 1 2)")
                       "(part :instrument ugal"))
  (test-equal ":name only: missing-option"
    '(missing-option 8)
    (string-error (defs+ "(part :name p 1 2)")))
  (test-equal "tokens only: missing-option"
    '(missing-option 8)
    (string-error (defs+ "(part 1 2)")))
  (test-equal "at its own line, after a good part"
    '(missing-option 9)
    (string-error (defs+ "(part :instrument ugal 1 2)"   ; 8
                         "(part gong G P)"))))           ; 9

(test-group "[parts] :instrument that is not a symbol"
  (for-each
   (match-lambda
     ((name form)
      (test-equal name '(bad-option 8) (string-error (defs+ form)))))
   (list (list "a number" "(part :instrument 3 1 2)")
         (list "a string" "(part :instrument \"ugal\" 1 2)")
         (list "a list" "(part :instrument (ugal) 1 2)")
         (list "with :name" "(part :name p :instrument 3 1 2)"))))

(test-group "[parts] inside a colotomy, only part forms"
  (test-equal "the old form (gong gong ...): bad-form"
    '(bad-form 8)
    (string-error (defs-with ":colotomy c"
                             "(colotomy c 4 (gong gong G - - -))"   ; 8
                             "(part :instrument ugal 1:4)")))
  (test-assert "the old form: the message shows (part :instrument gong ...)"
    (message-contains? (defs-with ":colotomy c"
                                  "(colotomy c 4 (gong gong G - - -))"
                                  "(part :instrument ugal 1:4)")
                       "(part :instrument gong"))
  (test-equal "the old form, in a colotomy no piece uses: bad-form"
    '(bad-form 8)
    (string-error (defs+ "(colotomy c 4 (gong gong G - - -))")))
  (for-each
   (match-lambda
     ((name form)
      (test-equal name '(bad-form 8) (string-error (defs+ form)))))
   (list (list "another head" "(colotomy c 4 (pattern p :instrument gong G))")
         (list "a list headed by a non-symbol" "(colotomy c 4 (1 G - - -))")
         (list "an atom" "(colotomy c 4 G)")
         (list "a good part, then another head"
               "(colotomy c 4 (part :instrument gong G - - -) (kempli kempli K))")))

  (test-equal "a colotomy part without :instrument: missing-option"
    '(missing-option 9)
    (string-error (defs+ "(colotomy c 4"            ; 8
                         "  (part :name g G - - -))")))  ; 9
  (test-equal "the old part form inside a colotomy: missing-option"
    '(missing-option 9)
    (string-error (defs+ "(colotomy c 4"            ; 8
                         "  (part gong G - - -))")))     ; 9
  (test-assert "the old part form inside a colotomy: the message shows the new one"
    (message-contains? (defs+ "(colotomy c 4" "  (part gong G - - -))")
                       "(part :instrument gong"))
  (test-equal "a colotomy part's :instrument not a symbol: bad-option"
    '(bad-option 9)
    (string-error (defs+ "(colotomy c 4"                    ; 8
                         "  (part :instrument 3 G - - -))"))))  ; 9

;;; ------------------------------------------------------------------
;;; 4. The template's gilak and bapang

;;; gilak's gong over one cycle (01): GL on pulse 4, P on 5 and 7, G on
;;; 8; strokes G GL P T are indices 0 1 2 3.
(define gilak-cycle '((3 1 (1)) (4 1 (2)) (6 1 (2)) (7 1 (0))))

(define (shift-triples triples by)
  (map (match-lambda ((s d n) (list (+ s by) d n))) triples))

;;; bapang's gong over one cycle (01): P on 4 and 12, T on 8, G on 16.
(define bapang-onsets '((3 (2)) (7 (3)) (11 (2)) (15 (0))))

(test-group "[template] gilak"
  (let ((pc (try-read-string "(piece \"G\" :colotomy gilak)"   ; 1
                             "(use gong-kebyar)"               ; 2
                             "(part :instrument ugal 1:8)")))  ; 3
    (test-assert "a piece with :colotomy gilak and no colotomy form reads"
      (piece? pc))
    (test-equal "parts: ugal, the generated gong, kempli"
      '((ugal written) (gong colotomy) (kempli timekeeper))
      (and pc (map (lambda (p) (list (part-name p) (part-origin p)))
                   (piece-parts pc))))
    (test-equal "length: one cycle of 8" 8 (and pc (piece-length pc)))
    (test-equal "the gong's events over one cycle" gilak-cycle
      (and pc (safe (lambda () (part-triples pc 'gong)))))
    (test-assert "the gong part plays the template's gong"
      (and pc (safe (lambda ()
                      (eq? (part-instrument (part-named pc 'gong))
                           (instrument-named pc 'gong))))))
    (test-equal "the colotomy is gilak, 8 pulses" '(gilak 8)
      (and pc (safe (lambda ()
                      (let ((c (cdar (piece-colotomies pc))))
                        (list (colotomy-name c) (colotomy-length c))))))))

  (let ((pc (try-read-string "(piece \"G\" :colotomy gilak)"
                             "(use gong-kebyar)"
                             "(part :instrument ugal 1:16)")))
    (test-equal "two cycles: gilak laid end to end"
      (append gilak-cycle (shift-triples gilak-cycle 8))
      (and pc (safe (lambda () (part-triples pc 'gong))))))

  (let ((pc (try-read-string "(piece \"G\")"
                             "(use gong-kebyar)"
                             "(part :instrument ugal 1 2)")))
    (test-assert "a piece without :colotomy still reads" (piece? pc))
    (test-equal "and has no colotomy" '()
      (and pc (piece-colotomies pc)))))

(test-group "[template] bapang"
  (let ((pc (try-read-string "(piece \"B\" :colotomy bapang)"
                             "(use gong-kebyar)"
                             "(part :instrument ugal 1:16)")))
    (test-assert "a piece with :colotomy bapang and no colotomy form reads"
      (piece? pc))
    (test-equal "length: one cycle of 16" 16 (and pc (piece-length pc)))
    (test-equal "the colotomy is bapang, 16 pulses" '(bapang 16)
      (and pc (safe (lambda ()
                      (let ((c (cdar (piece-colotomies pc))))
                        (list (colotomy-name c) (colotomy-length c)))))))
    (test-equal "the gong's strokes over one cycle" bapang-onsets
      (and pc (safe (lambda () (part-onsets pc 'gong)))))
    (test-equal "parts: ugal, the generated gong, kempli"
      '((ugal written) (gong colotomy) (kempli timekeeper))
      (and pc (map (lambda (p) (list (part-name p) (part-origin p)))
                   (piece-parts pc))))))

(test-group "[template] a piece's own colotomy replaces the template's"
  (let ((pc (try-read-string "(piece \"G\" :colotomy gilak)"              ; 1
                             "(use gong-kebyar)"                          ; 2
                             "(colotomy gilak 4 (part :instrument gong G:4))" ; 3
                             "(part :instrument ugal 1:8)")))             ; 4
    (test-assert "reads" (piece? pc))
    (test-equal "its own events win" '((0 4 (0)) (4 4 (0)))
      (and pc (safe (lambda () (part-triples pc 'gong)))))
    (test-equal "its own length" 4
      (and pc (safe (lambda () (colotomy-length (cdar (piece-colotomies pc)))))))
    (test-equal "its own location" 3
      (and pc (safe (lambda ()
                      (source-location-line
                       (colotomy-location (cdar (piece-colotomies pc))))))))))

(define runner (test-runner-current))
(test-end "syntax")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
