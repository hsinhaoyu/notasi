;;; Unit tests for (notasi layout): layout-score → figure.
;;;
;;; Written from doc/design/04-layout.md ("Public interface", "Systems",
;;; "Groups and lanes", "Lane labels", "Sizes", "Note style") and
;;; doc/design/05-typst-backend.md ("JSON contract (version 1)", "JSON
;;; writing"), with ADRs 0002, 0005, 0006, 0009 and 0017, not from the
;;; implementation.
;;;
;;; The figure is the JSON value itself: alists with symbol keys in the
;;; documented order, vectors for arrays, the symbol `null` for null.
;;; Every call to layout-score happens inside a test, so a failing or
;;; missing layout-score fails tests instead of stopping the file.
;;;
;;; Choices made where the doc is not explicit:
;;; - Sizes count characters (string-length), not bytes: "Kempli · Gong"
;;;   is 13 characters → 0.6 × 13 + 1.5 = "9.3em".
;;; - Lengths always carry one decimal, also for whole numbers: a lane
;;;   label of 2 characters gives 0.52 × 2 + 1 = 2.04 → "2.0em".
;;; - A group whose parts are all rests has lanes #() and adds 0 to the
;;;   longest lane label; its voices still appear, with events #().
;;; - A piece of length 0 has systems #(); its sizes are not tested when
;;;   it has groups (the doc says sizes are "for the whole figure (all
;;;   systems)", which is unclear when there are no systems).  With no
;;;   groups at all: "1.5em" and "1.0em".
;;; - A note cut at a boundary keeps its own lane, text and look in
;;;   every piece; only start, dur and continued change.
;;; - An event that ends exactly on a boundary, or starts on one, is not
;;;   cut: one piece, continued #f.
;;; - A chord crossing a boundary is cut note by note: each of its
;;;   events is cut like a single note.
;;;
;;; Slice feat/music-syntax (03, "Slices (iteration 2)"): no note shows
;;; its name until scores, and a piece read from text has every part in
;;; its own default group (label = part name, subtitle null).
;;;
;;; Slice feat/music-durations (03, slice 2; 04, "The step"): the piece
;;; has no steps-per-pulse or steps-per-system. Layout derives the step,
;;; the largest duration dividing 1 pulse and every event start and end,
;;; so `steps_per_pulse` is k for a step of 1/k pulse, and every time
;;; becomes a whole number of columns. Test pieces keep their length a
;;; multiple of the step, so it does not matter whether the piece's end
;;; also counts towards the step (04 says `to` does).
;;;
;;; Slice feat/music-colotomy (03, slice 4): the reader always generates
;;; the timekeeper `kempli` (on the piece's `kempli` instrument, or on a
;;; built-in one that is never printed), so a written part may not be
;;; called `kempli`. Fixtures that wrote a kempli part either use the
;;; generated one (groups-piece: the same strokes) or play an instrument
;;; called `kajar` instead (ten-steps, the one-letter sizes test).
;;; examples/tenzer1.nts has no written kempli part, so its generated
;;; kempli group comes last.
;;;
;;; Slice feat/scores-form (04, "Slices (iteration 2)", slice 1 and its
;;; decided bullets; ADRs 0031 to 0034): `layout-piece` is gone;
;;; `(layout-score piece score)` lays out one score, and these tests lay
;;; out the piece's first score (its default score when it has none)
;;; unless they name another. The figure stays contract version 1, with
;;; the score's `:cell-width` and `:cell-height` in `step_width` and
;;; `row_height` as written ("2em" by default, no longer "2.0em").
;;; Groups written by hand in earlier slices (`regroup`) are now `score`
;;; forms. Colours come from each group's `scheme`, `palette` and
;;; `colors`, so the `#:style` tests are now score and group options.
;;; Choices made where the docs are not explicit:
;;; - An event's `text` is the look's text when its group has
;;;   `note-names?` (the damped and open names are slice 3), else null.
;;;   Degrees with a `:damped` form are not used here, so the two rules
;;;   agree on every test.
;;; - v1's custom-scheme test (a procedure given through `#:style`) is
;;;   gone: a group's `scheme` is a symbol (02), and `by-degree` is the
;;;   only one, so there is no way left to give layout a procedure.
;;; - A member's `:label` (a row label, for `:rows parts`) does not
;;;   change its voice's name, which stays the part's name.
;;; - Some tests build score and group records by hand (ADR 0033: groups
;;;   carry their effective settings, so layout reads them as given).

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 match)
             (notasi piece)
             (notasi reader)
             (notasi style)
             (notasi json)
             (notasi layout))

;;; ------------------------------------------------------------------
;;; Helpers

(define (field obj key)
  "The value of KEY in the JSON object OBJ (an alist); an error if absent."
  (match (assq key obj)
    ((_ . value) value)
    (#f (error "missing key" key obj))))

(define (keys obj) (map car obj))

(define (systems fig) (vector->list (field fig 'systems)))

(define (system-ref fig s) (vector-ref (field fig 'systems) s))

(define (group-ref fig s g)
  (vector-ref (field (system-ref fig s) 'groups) g))

(define (voice-ref fig s g v)
  (vector-ref (field (group-ref fig s g) 'voices) v))

(define (events-of fig s g v)
  "The events of voice V of group G in system S, as a list."
  (vector->list (field (voice-ref fig s g v) 'events)))

(define (timing events)
  "Each event as (start dur lane continued)."
  (map (lambda (e)
         (list (field e 'start) (field e 'dur) (field e 'lane)
               (field e 'continued)))
       events))

(define (ev start dur lane text fill text-color continued)
  "An event object, keys in the documented order."
  `((start . ,start) (dur . ,dur) (lane . ,lane) (text . ,text)
    (fill . ,fill) (text_color . ,text-color) (continued . ,continued)))

(define (lanes-of fig s g)
  (field (group-ref fig s g) 'lanes))

(define (piece-of . lines)
  "Read LINES as a piece, or #f if reading raises (with a note on the
error port), so that a fixture the reader can't read yet fails the
tests that use it instead of stopping the file."
  (guard (c (#t (format (current-error-port) "fixture not read: ~a~%"
                        (if (exception-with-message? c)
                            (exception-message c)
                            c))
                #f))
    (read-piece-string (string-join lines "\n"))))

(define (layout piece)
  "PIECE laid out with its first score: its default score when the file
has none."
  (layout-score piece (car (piece-scores piece))))

(define (layout-named piece name)
  "PIECE laid out with its score NAME."
  (layout-score piece (or (piece-score piece name) (error "no score" name))))

(define (part-named piece name)
  (or (find (lambda (p) (eq? (part-name p) name)) (piece-parts piece))
      (error "no such part" name)))

(define (instrument-named piece name)
  (find (lambda (i) (eq? (instrument-name i) name))
        (piece-instruments piece)))

(define (note-named instrument name)
  (find (lambda (n) (eq? (note-name n) name))
        (vector->list (instrument-notes instrument))))

(define* (expected-look style piece instrument-name* note-name*
                        #:key (names? #f))
  "The (text fill text_color) an event of that note should have, from
(notasi style), with fill #f as null; text is the look's text with
NAMES? (the group's note-names?), else null."
  (let* ((instrument (instrument-named piece instrument-name*))
         (look (note-look style instrument
                          (note-named instrument note-name*))))
    (list (if names? (look-text look) 'null)
          (or (look-fill look) 'null)
          (look-text-color look))))

(define (event-look e)
  (list (field e 'text) (field e 'fill) (field e 'text_color)))

(define* (hand-group label parts
                     #:key (subtitle #f) (note-names? #f) (scheme 'by-degree)
                     (palette 'pastel1) (colors '()))
  "A group record built by hand, as the reader fills it in (ADR 0033):
PARTS with their names as row labels, every other setting at its
default unless given."
  (make-group label label subtitle 'first-long 'notes
              (map (lambda (p) (cons p (symbol->string (part-name p)))) parts)
              note-names? 'colour 'none 'none 0 scheme palette colors #f))

(define* (hand-score piece groups
                     #:key (title (piece-title piece)) (system-length #f)
                     (cell-width "2em") (cell-height "2em"))
  "A score record built by hand over the whole of PIECE."
  (make-score 'hand title #f #f 0 (piece-length piece) system-length '()
              #f #t 'gong-last #f #f cell-width cell-height groups #f))

(define figure-keys '(version title steps_per_pulse sizes systems caption))
(define sizes-keys '(label_width lane_width step_width row_height))
(define system-keys '(start steps groups))
(define group-keys '(label subtitle lanes voices))
(define voice-keys '(name events))
(define event-keys '(start dur lane text fill text_color continued))

(define (well-formed? fig)
  "Does every object in FIG have exactly the documented keys, in order,
and every array a vector?"
  (define (every-in vec ok?)
    (and (vector? vec) (every ok? (vector->list vec))))
  (define (event-ok? e) (equal? (keys e) event-keys))
  (define (voice-ok? v)
    (and (equal? (keys v) voice-keys)
         (string? (field v 'name))
         (every-in (field v 'events) event-ok?)))
  (define (group-ok? g)
    (and (equal? (keys g) group-keys)
         (every-in (field g 'lanes) string?)
         (every-in (field g 'voices) voice-ok?)))
  (define (system-ok? s)
    (and (equal? (keys s) system-keys)
         (every-in (field s 'groups) group-ok?)))
  (and (equal? (keys fig) figure-keys)
       (equal? (keys (field fig 'sizes)) sizes-keys)
       (every-in (field fig 'systems) system-ok?)))

(define white "#ffffff")
(define dark "#222222")
(define grey "#cccccc")              ; strokes (ADRs 0019, 0021)
;; pastel1 (the default, ADR 0021), degree k → colour k; all take dark text
(define ding-fill "#fbb4ae")
(define dong-fill "#b3cde3")
(define deng-fill "#ccebc5")
(define dung-fill "#decbe4")
(define dang-fill "#fed9a6")

(define selisir-lines
  '("(scale selisir"
    "  (ding :alias i :display \"i\")"
    "  (dong :alias o :display \"o\")"
    "  (deng :alias e :display \"e\")"
    "  (dung :alias u :display \"u\")"
    "  (dang :alias a :display \"a\"))"))

(define (selisir-piece . more)
  "A piece P with selisir, then the lines MORE."
  (apply piece-of (append '("(piece \"P\")") selisir-lines more)))

;;; ------------------------------------------------------------------
;;; Fixtures

;; A small piece used for the complete figure: half pulses (so 2 steps
;; per pulse), 5 steps in one system, a held note, a chord, a group of
;; two parts with a subtitle and a stroke group. A second score cuts it
;; into systems of 2 pulses.
(define tiny
  (piece-of
   "(piece \"Tiny\")"
   "(scale selisir (ding :display \"i\") (dong :display \"o\") (deng :display \"e\"))"
   "(strokes gong-strokes G P)"
   "(instrument ugal selisir ding1 dong1 deng1 ding2)"
   "(instrument gong gong-strokes G P)"
   "(part ugal :name polos    1:1/2 _ 2 _ _)"
   "(part ugal :name sangsih  -:1/2 4 _ (1 3) -)"
   "(part gong                2:1/2 - - 1 -)"
   "(score tiny"
   "  (group \"Ugal\" :subtitle \"polos + sangsih\"  polos sangsih)"
   "  (group \"gong\"  gong))"
   "(score split :system-length 2"
   "  (group \"Ugal\" :subtitle \"polos + sangsih\"  polos sangsih)"
   "  (group \"gong\"  gong))"))

(define (sys start steps . groups)
  `((start . ,start) (steps . ,steps) (groups . ,(list->vector groups))))

(define (grp label subtitle lanes . voices)
  `((label . ,label) (subtitle . ,subtitle) (lanes . ,lanes)
    (voices . ,(list->vector voices))))

(define (voice name . events)
  `((name . ,name) (events . ,(list->vector events))))

;; Lanes of "Ugal": ding2 deng1 dong1 ding1 → i2 e1 o1 i1 (0 1 2 3).
;; No group has note names: text is null for pitched notes and strokes.
;; Lanes of "gong": G P (0 1). The built-in kempli is in no group.
(define tiny-expected
  `((version . 1)
    (title . "Tiny")
    (steps_per_pulse . 2)
    (sizes . ((label_width . "10.5em")   ; "polos + sangsih": 15 chars
              (lane_width . "2.0em")     ; "i2": 2 chars
              (step_width . "2em")
              (row_height . "2em")))
    (systems
     . ,(vector
         (sys 0 5
              (grp "Ugal" "polos + sangsih" #("i2" "e1" "o1" "i1")
                   (voice "polos"
                          (ev 0 2 3 'null ding-fill dark #f)
                          (ev 2 3 2 'null dong-fill dark #f))
                   (voice "sangsih"
                          (ev 1 2 0 'null ding-fill dark #f)
                          (ev 3 1 1 'null deng-fill dark #f)
                          (ev 3 1 3 'null ding-fill dark #f)))
              (grp "gong" 'null #("G" "P")
                   (voice "gong"
                          (ev 0 1 1 'null grey dark #f)
                          (ev 3 1 0 'null grey dark #f))))))
    (caption . null)))

;; The same, as score `split` cuts it: systems of 2 pulses (4 columns),
;; the second 1 column long. polos's dong1 (columns 2 to 5) is cut at 4.
(define split-expected
  `((version . 1)
    (title . "Tiny")
    (steps_per_pulse . 2)
    (sizes . ((label_width . "10.5em")
              (lane_width . "2.0em")
              (step_width . "2em")
              (row_height . "2em")))
    (systems
     . ,(vector
         (sys 0 4
              (grp "Ugal" "polos + sangsih" #("i2" "e1" "o1" "i1")
                   (voice "polos"
                          (ev 0 2 3 'null ding-fill dark #f)
                          (ev 2 2 2 'null dong-fill dark #f))
                   (voice "sangsih"
                          (ev 1 2 0 'null ding-fill dark #f)
                          (ev 3 1 1 'null deng-fill dark #f)
                          (ev 3 1 3 'null ding-fill dark #f)))
              (grp "gong" 'null #("G" "P")
                   (voice "gong"
                          (ev 0 1 1 'null grey dark #f)
                          (ev 3 1 0 'null grey dark #f))))
         (sys 4 1
              (grp "Ugal" "polos + sangsih" #("i2" "e1" "o1" "i1")
                   (voice "polos"
                          (ev 0 1 2 'null dong-fill dark #t))
                   (voice "sangsih"))
              (grp "gong" 'null #("G" "P")
                   (voice "gong")))))
    (caption . null)))

;; A piece of 10 pulses, one note or rest per pulse, then the lines MORE
;; (scores).
(define (ten-steps . more)
  (apply piece-of
         "(piece \"Ten\")"
         "(scale s a b)"
         "(strokes k-strokes K)"
         "(instrument u s a1 b1)"
         "(instrument kajar k-strokes K)"
         "(part u :name melody  1 2 1 2 1 2 1 2 1 2)"
         "(part u :name rests   1 - - - - - - - - -)"
         "(part kajar           K - K - K - K - K -)"
         more))

(define (ten-score . options)
  "ten-steps with a score of its three parts, with OPTIONS (a string)."
  (ten-steps (string-append "(score s " (string-join options " ")
                            " (group \"melody\" melody)"
                            " (group \"rests\" rests)"
                            " (group \"kajar\" kajar))")))

;; Groups of one part and of several, pitched and stroke, written in a
;; score; and a second score with fewer groups.
(define groups-piece
  (apply piece-of
         (append
          (list "(piece \"Groups\")")
          selisir-lines
          (list
           "(strokes kempli-strokes K)"
           "(strokes gong-strokes G P)"
           "(instrument ugal selisir o1 e1 u1 a1 i2 o2 e2)"
           "(instrument kempli kempli-strokes K)"
           "(instrument gong gong-strokes G P)"
           "(part ugal :name melody   a1 o2 i2 e2)"
           ;; kempli: the generated timekeeper, K on every pulse
           "(part ugal :name polos    i2 -  e2 -)"
           "(part ugal :name sangsih  -  u1 -  o2)"
           "(part gong                P  -  G  -)"
           "(part ugal :name silent   -  -  -  -)"
           "(score groups"
           "  (group \"melody\" melody)"
           "  (group \"Colotomic\" gong kempli)"
           "  (group \"Reyong-ish\" :subtitle \"sangsih + polos\" sangsih polos)"
           "  (group \"silent\" silent))"
           "(score short"
           "  (group \"Kotekan\" (polos :label \"P\") (sangsih :label \"S\"))"
           "  (group \"\" melody))"))))

(define tenzer
  (guard (c (#t #f)) (read-piece-file "examples/tenzer1.nts")))

(define (sizes-of . lines)
  (field (layout (apply piece-of lines)) 'sizes))

;;; ------------------------------------------------------------------

(test-begin "layout")

;;; ------------------------------------------------------------------
;;; The figure's top level

(test-group "figure top level"
  (test-equal "keys in the documented order"
    figure-keys
    (keys (layout tiny)))
  (test-equal "version 1" 1 (field (layout tiny) 'version))
  (test-equal "title: the score's, by default the piece's title"
    "Tiny" (field (layout tiny) 'title))
  (test-equal "steps_per_pulse derived: half pulses give 2"
    2 (field (layout tiny) 'steps_per_pulse))
  (test-equal "steps_per_pulse derived: whole pulses give 1"
    1 (field (layout (ten-steps)) 'steps_per_pulse))
  (test-equal "tenzer1: steps_per_pulse 1"
    1 (field (layout tenzer) 'steps_per_pulse))
  (test-equal "tenzer1: title"
    "Eight-pulse gong cycle" (field (layout tenzer) 'title))
  (test-eq "caption is the symbol null"
    'null (field (layout tiny) 'caption))
  (test-assert "systems is a vector"
    (vector? (field (layout tiny) 'systems)))
  (test-assert "every object has its keys in order, arrays are vectors"
    (well-formed? (layout tiny)))
  (test-assert "well-formed: groups piece"
    (well-formed? (layout groups-piece)))
  (test-assert "well-formed: several systems"
    (well-formed? (layout-named tiny 'split)))
  (test-assert "well-formed: tenzer1"
    (well-formed? (layout tenzer)))
  (test-assert "json-string accepts the figure"
    (string? (json-string (layout tiny))))
  (test-assert "json-string accepts the figure (compact)"
    (string? (json-string (layout tenzer) #:pretty? #f)))
  (test-assert "json-string accepts a figure with no systems"
    (string? (json-string (layout (piece-of "(piece \"Empty\")")))))
  (test-equal "a score with its colour and size options at their defaults = the default score"
    (layout (piece-of "(piece \"P\")" "(scale s a b)" "(instrument u s a1 b1)"
                      "(part u :name p 1 2 _ 1)"))
    (layout (piece-of "(piece \"P\")" "(scale s a b)" "(instrument u s a1 b1)"
                      "(part u :name p 1 2 _ 1)"
                      "(score s :note-names no :scheme by-degree :palette pastel1"
                      "  :cell-width \"2em\" :cell-height \"2em\""
                      "  (group \"p\" :note-names no :scheme by-degree :palette pastel1 p))"))))

;;; ------------------------------------------------------------------
;;; The score: which one, its title (04, "Public interface")

(test-group "the score"
  (let ((pc (piece-of "(piece \"Piece title\")" "(scale s a b)"
                      "(instrument u s a1 b1)"
                      "(part u :name p 1 2)"
                      "(part u :name q 2 1)"
                      "(score first :title \"Score title\" (group \"P\" p))"
                      "(score second (group \"Q\" q) (group \"P\" p))")))
    (test-equal ":title is the figure's title" "Score title"
      (field (layout pc) 'title))
    (test-equal "without :title, the piece's title" "Piece title"
      (field (layout-named pc 'second) 'title))
    (test-equal "the first score: its groups" '("P")
      (map (lambda (g) (field g 'label))
           (vector->list (field (system-ref (layout pc) 0) 'groups))))
    (test-equal "another score: its own groups, in its order" '("Q" "P")
      (map (lambda (g) (field g 'label))
           (vector->list (field (system-ref (layout-named pc 'second) 0)
                                'groups))))
    (test-equal "the same part in two scores: the same events"
      (events-of (layout pc) 0 0 0)
      (events-of (layout-named pc 'second) 0 1 0))
    (test-equal ":title \"\" is kept as written" ""
      (field (layout (piece-of "(piece \"P\")" "(scale s a)"
                               "(instrument u s a1)" "(part u :name p 1)"
                               "(score s :title \"\" (group \"p\" p))"))
             'title)))
  (test-equal "a score built by hand: its title"
    "By hand"
    (field (layout-score tenzer
                         (hand-score tenzer
                                     (list (hand-group "ugal"
                                                       (list (part-named tenzer 'ugal))))
                                     #:title "By hand"))
           'title)))

;;; ------------------------------------------------------------------
;;; Sizes

(define (tiny-sizes . options)
  "The sizes of a one-part piece with a score with OPTIONS."
  (field (layout (piece-of "(piece \"P\")" "(scale s a)" "(instrument u s a1)"
                           "(part u :name ab 1)"
                           (string-append "(score s " (string-join options " ")
                                          " (group \"ab\" ab))")))
         'sizes))

(test-group "sizes"
  (test-equal "the prototype: \"polos + sangsih\" → 10.5em, \"neng1\" → 3.6em"
    '((label_width . "10.5em") (lane_width . "3.6em")
      (step_width . "2em") (row_height . "2em"))
    (sizes-of
     "(piece \"Reyong kotekan\")"
     "(scale reyong-4 nang ning nong neng)"
     "(instrument reyong reyong-4 nang1 ning1 nong1 neng1)"
     "(part reyong :name polos    1 _ 1 2 / _ 1 2 _ / 2 1 _ 2)"
     "(part reyong :name sangsih  4 3 4 _ / 3 4 _ 3 / _ 4 3 _)"
     "(score s (group \"Reyong\" :subtitle \"polos + sangsih\" polos sangsih))"))

  (test-equal "no groups: 1.5em and 1.0em"
    '((label_width . "1.5em") (lane_width . "1.0em")
      (step_width . "2em") (row_height . "2em"))
    (sizes-of "(piece \"Empty\")"))

  (test-equal "one-letter label and stroke: 2.1em, 1.5em"
    '((label_width . "2.1em") (lane_width . "1.5em")
      (step_width . "2em") (row_height . "2em"))
    (sizes-of "(piece \"P\")"
              "(strokes k-strokes K)"
              "(instrument kajar k-strokes K)"
              "(part kajar :name x K -)"))

  (test-equal "lane label of 4 chars: 3.08 rounds up to 3.1em"
    "3.1em"
    (field (sizes-of "(piece \"P\")"
                     "(scale s (a :display \"abc\"))"
                     "(instrument u s a1)"
                     "(part u :name x 1)")
           'lane_width))

  (test-equal "lane label of 7 chars: 4.64 rounds down to 4.6em"
    "4.6em"
    (field (sizes-of "(piece \"P\")"
                     "(scale s (a :display \"abcdef\"))"
                     "(instrument u s a1)"
                     "(part u :name x 1)")
           'lane_width))

  (test-equal "lane label of 9 chars: 5.68 rounds up to 5.7em"
    "5.7em"
    (field (sizes-of "(piece \"P\")"
                     "(scale s (a :display \"abcdefgh\"))"
                     "(instrument u s a1)"
                     "(part u :name x 1)")
           'lane_width))

  (test-equal "degree name without display: \"dong2\" → 3.6em"
    "3.6em"
    (field (sizes-of "(piece \"P\")"
                     "(scale s ding dong)"
                     "(instrument u s ding2 dong2)"
                     "(part u :name x 2)")
           'lane_width))

  (test-equal "a subtitle longer than every label counts (20 chars → 13.5em)"
    "13.5em"
    (field (sizes-of "(piece \"P\")"
                     "(strokes k-strokes K)"
                     "(instrument kempli k-strokes K)"
                     "(part kempli :name a K)"
                     "(part kempli :name b K)"
                     "(score s (group \"a\" a)"
                     "  (group \"Bb\" :subtitle \"twenty chars long xx\" b))")
           'label_width))

  (test-equal "longest label over all groups (the last one here)"
    "6.3em"                             ; "Eight ch": 8 chars
    (field (sizes-of "(piece \"P\")"
                     "(strokes k-strokes K)"
                     "(instrument kempli k-strokes K)"
                     "(part kempli :name a K)"
                     "(part kempli :name b K)"
                     "(score s (group \"a\" a) (group \"Eight ch\" b))")
           'label_width))

  (test-equal "longest lane label over all groups (not the first)"
    "4.6em"                             ; "abcdef1" in group y
    (field (sizes-of "(piece \"P\")"
                     "(scale s a (b :display \"abcdef\"))"
                     "(instrument u s a1 b1)"
                     "(part u :name x 1)"
                     "(part u :name y 2)")
           'lane_width))

  (test-equal "characters, not bytes: \"Kempli · Gong\" → 9.3em"
    "9.3em"
    (field (sizes-of "(piece \"P\")"
                     "(strokes k-strokes K)"
                     "(instrument kempli k-strokes K)"
                     "(part kempli :name a K)"
                     "(score s (group \"Kempli · Gong\" a))")
           'label_width))

  (test-equal "a group of rests adds no lane label"
    '((label_width . "2.7em") (lane_width . "1.0em")
      (step_width . "2em") (row_height . "2em"))
    (sizes-of "(piece \"P\")"
              "(scale s a)"
              "(instrument u s a1)"
              "(part u :name ab - -)"))

  (test-equal "only the score's groups count, not every part"
    "2.7em"                             ; "ab", not "a much longer name"
    (field (sizes-of "(piece \"P\")"
                     "(scale s a)"
                     "(instrument u s a1)"
                     "(part u :name ab 1)"
                     "(part u :name a-much-longer-name 1)"
                     "(score s (group \"ab\" ab))")
           'label_width))

  (test-equal "an empty label: 1.5em"
    "1.5em"
    (field (sizes-of "(piece \"P\")" "(scale s a)" "(instrument u s a1)"
                     "(part u :name ab 1)"
                     "(score s (group \"\" ab))")
           'label_width))

  (test-equal "tenzer1: \"kempli\" → 5.1em, \"e2\" → 2.0em"
    '((label_width . "5.1em") (lane_width . "2.0em")
      (step_width . "2em") (row_height . "2em"))
    (field (layout tenzer) 'sizes))

  (test-equal "groups piece: \"sangsih + polos\" → 10.5em, \"e2\" → 2.0em"
    '((label_width . "10.5em") (lane_width . "2.0em")
      (step_width . "2em") (row_height . "2em"))
    (field (layout groups-piece) 'sizes)))

(test-group "sizes: the cell, from the score"
  (test-equal "default: \"2em\" each, as written"
    '("2em" "2em")
    (let ((s (tiny-sizes)))
      (list (field s 'step_width) (field s 'row_height))))
  (test-equal ":cell-width and :cell-height go into step_width and row_height"
    '("3em" "1.5em")
    (let ((s (tiny-sizes ":cell-width \"3em\"" ":cell-height \"1.5em\"")))
      (list (field s 'step_width) (field s 'row_height))))
  (test-equal "lengths are kept as written, any unit"
    '("4mm" "10pt")
    (let ((s (tiny-sizes ":cell-width \"4mm\"" ":cell-height \"10pt\"")))
      (list (field s 'step_width) (field s 'row_height))))
  (test-equal "only the width: the height stays \"2em\""
    '("2.5em" "2em")
    (let ((s (tiny-sizes ":cell-width \"2.5em\"")))
      (list (field s 'step_width) (field s 'row_height))))
  (test-equal "the label widths do not change with the cell"
    '("2.7em" "2.0em")
    (let ((s (tiny-sizes ":cell-width \"5em\"" ":cell-height \"5em\"")))
      (list (field s 'label_width) (field s 'lane_width))))
  (test-equal "a score built by hand: its cell sizes"
    '("1em" "3em")
    (let ((s (field (layout-score
                     tenzer
                     (hand-score tenzer
                                 (list (hand-group "ugal"
                                                   (list (part-named tenzer 'ugal))))
                                 #:cell-width "1em" #:cell-height "3em"))
                    'sizes)))
      (list (field s 'step_width) (field s 'row_height)))))

;;; ------------------------------------------------------------------
;;; Systems

(define (starts+steps fig)
  (map (lambda (s) (list (field s 'start) (field s 'steps))) (systems fig)))

(test-group "systems"
  (test-equal "one system of the whole piece"
    '((0 10))
    (starts+steps (layout (ten-steps))))
  (test-equal "tenzer1: one system of 9 steps"
    '((0 9))
    (starts+steps (layout tenzer)))
  (test-equal "one system, whatever the step: tiny is 5 half pulses"
    '((0 5))
    (starts+steps (layout tiny)))
  (test-equal "a long piece is one system without :system-length"
    '((0 16))
    (starts+steps (layout (piece-of "(piece \"Long\")"
                                    "(scale s a)"
                                    "(instrument u s a1)"
                                    "(part u :name p 1:1/4 _ _ _ -:15)"))))

  (test-equal "a piece of length 0 (no parts) has no systems"
    #()
    (field (layout (piece-of "(piece \"Empty\")")) 'systems))
  (test-equal "a piece of length 0 with a group has no systems"
    #()
    (field (layout (piece-of "(piece \"Zero\")"
                             "(scale s a)"
                             "(instrument u s a1)"
                             "(part u :name p /)"))
           'systems))

  (test-equal "every group in the system, in the score's order"
    '("melody" "rests" "kajar")
    (map (lambda (g) (field g 'label))
         (vector->list (field (system-ref (layout (ten-steps)) 0)
                              'groups))))
  (test-equal "events start at the piece's start"
    '((0 1 0 #f) (2 1 0 #f) (4 1 0 #f) (6 1 0 #f) (8 1 0 #f))
    (timing (events-of (layout (ten-steps)) 0 2 0)))
  (test-equal "a held note through the whole piece is not cut"
    '((3 6 0 #f))
    (timing (events-of (layout
                        (piece-of "(piece \"P\")"
                                  "(scale s a)"
                                  "(instrument u s a1)"
                                  "(part u :name two - - - 1 _ _ _ _ _ - - - - - - -)"))
                       0 0 0))))

;;; :system-length (04, "The range and systems")

(define held-piece
  ;; 16 pulses; a note held from pulse 3 for 6 pulses (3 to 9).
  (piece-of "(piece \"P\")"
            "(scale s a b)"
            "(instrument u s a1 b1)"
            "(part u :name p - - - 1 _ _ _ _ _ - - - - - - -)"
            "(score four :system-length 4 (group \"p\" p))"
            "(score two :system-length 2 (group \"p\" p))"))

(test-group "systems: :system-length"
  (test-equal "systems of 4 pulses; the last is shorter"
    '((0 4) (4 4) (8 2))
    (starts+steps (layout (ten-score ":system-length 4"))))
  (test-equal "system-length dividing the piece: equal systems"
    '((0 5) (5 5))
    (starts+steps (layout (ten-score ":system-length 5"))))
  (test-equal "system-length 1: one system per pulse"
    (map (lambda (i) (list i 1)) (iota 10))
    (starts+steps (layout (ten-score ":system-length 1"))))
  (test-equal "system-length the piece's length: one system"
    '((0 10))
    (starts+steps (layout (ten-score ":system-length 10"))))
  (test-equal "system-length longer than the piece: one system"
    '((0 10))
    (starts+steps (layout (ten-score ":system-length 32"))))
  (test-equal "in columns: half pulses, systems of 2 pulses are 4 columns"
    '((0 4) (4 1))
    (starts+steps (layout-named tiny 'split)))
  (test-equal "a piece of length 0 with a system length: no systems"
    #()
    (field (layout (piece-of "(piece \"Zero\")" "(scale s a)"
                             "(instrument u s a1)" "(part u :name p /)"
                             "(score s :system-length 4 (group \"p\" p))"))
           'systems))

  (test-equal "every group in every system, in the score's order"
    '(("melody" "rests" "kajar") ("melody" "rests" "kajar")
      ("melody" "rests" "kajar"))
    (map (lambda (s)
           (map (lambda (g) (field g 'label))
                (vector->list (field s 'groups))))
         (systems (layout (ten-score ":system-length 4")))))
  (test-equal "a group with no events in a system still has its voice"
    '(((0 1 0 #f)) () ())
    (map (lambda (s) (timing (events-of (layout (ten-score ":system-length 4"))
                                        s 1 0)))
         '(0 1 2)))
  (test-equal "voices in every system"
    '(("rests") ("rests") ("rests"))
    (map (lambda (s)
           (map (lambda (v) (field v 'name))
                (vector->list (field (group-ref (layout (ten-score ":system-length 4"))
                                                s 1)
                                     'voices))))
         '(0 1 2)))
  (test-equal "lanes are the same in every system"
    '(#("b1" "a1") #("b1" "a1") #("b1" "a1"))
    (map (lambda (s) (lanes-of (layout (ten-score ":system-length 4")) s 0))
         '(0 1 2)))
  (test-equal "a group's lanes come from the whole piece, not the system"
    '(#("a1") #("a1"))
    (map (lambda (s) (lanes-of (layout (ten-score ":system-length 5")) s 1))
         '(0 1)))
  (test-equal "event starts are relative to their system"
    '(((0 1 0 #f) (2 1 0 #f))
      ((0 1 0 #f) (2 1 0 #f))
      ((0 1 0 #f)))
    (map (lambda (s) (timing (events-of (layout (ten-score ":system-length 4"))
                                        s 2 0)))
         '(0 1 2)))
  (test-equal "with an odd system length, events fall where they are"
    '(((0 1 0 #f) (2 1 0 #f))
      ((1 1 0 #f))
      ((0 1 0 #f) (2 1 0 #f))
      ())
    (map (lambda (s) (timing (events-of (layout (ten-score ":system-length 3"))
                                        s 2 0)))
         '(0 1 2 3)))

  (test-equal "a note crossing boundaries is cut at each; later pieces continued"
    '(((3 1 0 #f)) ((0 4 0 #t)) ((0 1 0 #t)) ())
    (map (lambda (s) (timing (events-of (layout-named held-piece 'four) s 0 0)))
         '(0 1 2 3)))
  (test-equal "a note crossing several boundaries: one piece per system"
    '(() ((1 1 0 #f)) ((0 2 0 #t)) ((0 2 0 #t)) ((0 1 0 #t)) () () ())
    (map (lambda (s) (timing (events-of (layout-named held-piece 'two) s 0 0)))
         (iota 8)))
  (test-equal "a cut note keeps its lane and look in every piece"
    1
    (let ((fig (layout-named held-piece 'four)))
      (length
       (delete-duplicates
        (map (lambda (e) (list (field e 'lane) (event-look e)))
             (append (events-of fig 0 0 0) (events-of fig 1 0 0)
                     (events-of fig 2 0 0)))))))
  (test-equal "a note ending on a boundary is not cut"
    '(((2 2 0 #f)) ())
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a)"
                                 "(instrument u s a1)"
                                 "(part u :name p - - 1 _ - - - -)"
                                 "(score s :system-length 4 (group \"p\" p))"))))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1))))
  (test-equal "a note starting on a boundary is not cut"
    '(() ((0 2 0 #f)))
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a)"
                                 "(instrument u s a1)"
                                 "(part u :name p - - - - 1 _ - -)"
                                 "(score s :system-length 4 (group \"p\" p))"))))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1))))
  (test-equal "a chord crossing a boundary is cut note by note"
    ;; lanes: b1 (0), a1 (1); the chord sounds from 1 to 4
    '(((1 1 0 #f) (1 1 1 #f)) ((0 2 0 #t) (0 2 1 #t)))
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a b)"
                                 "(instrument u s a1 b1)"
                                 "(part u :name p - (1 2) _ _)"
                                 "(score s :system-length 2 (group \"p\" p))"))))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1))))
  (test-equal "quarter pulses: a cut note in columns"
    ;; k = 4; systems of 1 pulse are 4 columns; the note from 3/4 to 3/2
    '((0 4) (4 4))
    (starts+steps (layout (piece-of "(piece \"P\")" "(scale s a)"
                                    "(instrument u s a1)"
                                    "(part u :name p -:3/4 1:1/4 _ _ -:1/2)"
                                    "(score s :system-length 1 (group \"p\" p))"))))
  (test-equal "quarter pulses: the note is cut at column 4"
    '(((3 1 0 #f)) ((0 2 0 #t)))
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a)"
                                 "(instrument u s a1)"
                                 "(part u :name p -:3/4 1:1/4 _ _ -:1/2)"
                                 "(score s :system-length 1 (group \"p\" p))"))))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1))))
  (test-equal "the sizes do not depend on the systems"
    (field (layout tiny) 'sizes)
    (field (layout-named tiny 'split) 'sizes))
  (test-equal "a score built by hand: its system length"
    '((0 4) (4 4) (8 1))
    (starts+steps
     (layout-score tenzer
                   (hand-score tenzer
                               (list (hand-group "ugal"
                                                 (list (part-named tenzer 'ugal))))
                               #:system-length 4)))))

;;; ------------------------------------------------------------------
;;; The step (04, "The step")

(define (step-piece . tokens)
  "A piece with one part on u (keys a1 b1) for each string in TOKENS."
  (apply piece-of
         "(piece \"Step\")" "(scale s a b)" "(instrument u s a1 b1)"
         (map (lambda (t i)
                (string-append "(part u :name p" (number->string i) " " t ")"))
              tokens (iota (length tokens)))))

(define (step-of . tokens)
  (field (layout (apply step-piece tokens)) 'steps_per_pulse))

(test-group "the step"
  (test-equal "whole pulses: 1" 1 (step-of "1 2 1 2"))
  (test-equal "notes of two pulses: still 1 (the step divides a pulse)" 1
    (step-of "1:2 2 1 2"))
  (test-equal "half pulses: 2" 2 (step-of "1:1/2 2 1 2"))
  (test-equal "quarter pulses: 4" 4 (step-of "1:1/4 2 1 2"))
  (test-equal "thirds: 3" 3 (step-of "1:1/3 2 1"))
  (test-equal "halves and thirds: 6" 6 (step-of "1:1/2 2:1/3 1:1/6"))
  (test-equal "the fastest part sets it" 4
    (step-of "1 2 1 2" "1:1/4 2 1 2 1:1 2 1"))
  (test-equal "quarters in one place only" 4 (step-of "1 2 1:1/4 2 1 2 1:1"))
  (test-equal "a start off the pulse counts, not only durations" 2
    (step-of "-:1/2 1:1 -:1/2"))
  (test-equal "an end off the pulse counts: a held quarter" 4
    (step-of "1:1/4 _ _ -:1/4 -:1"))
  (test-equal "the largest step: halves written as quarters" 2
    (step-of "1:1/4 _ 2 _ 1 _ 2 _"))
  (test-equal "no parts: 1" 1
    (field (layout (piece-of "(piece \"Empty\")")) 'steps_per_pulse))

  (let ((fig (layout (step-piece "1:1/4 2 1:1/2 2:1 1:1/4 2 -:1/2"))))
    (test-equal "times become whole columns"
      ;; lanes: b1 (0), a1 (1); k = 4
      '((0 1 1 #f) (1 1 0 #f) (2 2 1 #f) (4 4 0 #f) (8 1 1 #f) (9 1 0 #f))
      (timing (events-of fig 0 0 0)))
    (test-equal "the system's steps are the length in columns" '((0 12))
      (starts+steps fig))
    (test-assert "every start and dur is an exact integer"
      (every (lambda (e) (and (exact-integer? (field e 'start))
                              (exact-integer? (field e 'dur))))
             (events-of fig 0 0 0)))
    (test-assert "json-string accepts it (no rationals left)"
      (string? (json-string fig))))

  (let ((fig (layout (step-piece "1:1/3 2 1 2:1" "1:2"))))
    (test-equal "thirds: columns" '((0 1 1 #f) (1 1 0 #f) (2 1 1 #f) (3 3 0 #f))
      (timing (events-of fig 0 0 0)))
    (test-equal "thirds: a two-pulse note is 6 columns" '((0 6 0 #f))
      (timing (events-of fig 0 1 0)))
    (test-equal "thirds: 6 columns" '((0 6)) (starts+steps fig))))

;;; ------------------------------------------------------------------
;;; Groups and lanes

(define (group-labels fig s)
  (map (lambda (g) (field g 'label))
       (vector->list (field (system-ref fig s) 'groups))))

(define (voice-names fig s g)
  (map (lambda (v) (field v 'name))
       (vector->list (field (group-ref fig s g) 'voices))))

(define (groups-score-groups)
  (score-groups (piece-score groups-piece 'groups)))

(test-group "groups and lanes"
  (test-equal "the score's groups, in the order written"
    '("melody" "Colotomic" "Reyong-ish" "silent")
    (group-labels (layout groups-piece) 0))
  (test-equal "group order follows score-groups"
    (map group-label (groups-score-groups))
    (group-labels (layout groups-piece) 0))
  (test-equal "subtitle: a string or null"
    '(null null "sangsih + polos" null)
    (map (lambda (g) (field (group-ref (layout groups-piece) 0 g)
                            'subtitle))
         '(0 1 2 3)))
  (test-equal "lanes: pitched notes used, highest first"
    #("e2" "o2" "i2" "a1")
    (lanes-of (layout groups-piece) 0 0))
  (test-equal "lanes: union of the group's parts, highest first"
    #("e2" "o2" "i2" "u1")
    (lanes-of (layout groups-piece) 0 2))
  (test-equal "lanes: strokes in instrument order, instruments in part order"
    #("G" "P" "K")
    (lanes-of (layout groups-piece) 0 1))
  (test-equal "lanes: a group of rests has none"
    #()
    (lanes-of (layout groups-piece) 0 3))
  (test-equal "lanes are note-label of group-lanes"
    (map (lambda (g)
           (list->vector
            (map (lambda (note)
                   (note-label (part-instrument (car (car (group-members g))))
                               note))
                 (group-lanes g))))
         (filter (lambda (g) (not (equal? (group-label g) "Colotomic")))
                 (groups-score-groups)))
    (map (lambda (g) (lanes-of (layout groups-piece) 0 g))
         '(0 2 3)))
  (test-equal "voices: one per member, in the group's order, as strings"
    '(("melody") ("gong" "kempli") ("sangsih" "polos") ("silent"))
    (map (lambda (g) (voice-names (layout groups-piece) 0 g))
         '(0 1 2 3)))
  (test-equal "lane index: melody a1 o2 i2 e2"
    '((0 1 3 #f) (1 1 1 #f) (2 1 2 #f) (3 1 0 #f))
    (timing (events-of (layout groups-piece) 0 0 0)))
  (test-equal "lane index: strokes of two instruments"
    '(((0 1 1 #f) (2 1 0 #f))
      ((0 1 2 #f) (1 1 2 #f) (2 1 2 #f) (3 1 2 #f)))
    (list (timing (events-of (layout groups-piece) 0 1 0))
          (timing (events-of (layout groups-piece) 0 1 1))))
  (test-equal "lane index: two parts sharing lanes"
    '(((1 1 3 #f) (3 1 1 #f))
      ((0 1 2 #f) (2 1 0 #f)))
    (list (timing (events-of (layout groups-piece) 0 2 0))
          (timing (events-of (layout groups-piece) 0 2 1))))
  (test-equal "a silent voice has events #()"
    #()
    (field (voice-ref (layout groups-piece) 0 3 0) 'events))

  ;; The second score: other groups, in another order, with row labels.
  (test-equal "another score of the same piece: its groups only"
    '("Kotekan" "")
    (group-labels (layout-named groups-piece 'short) 0))
  (test-equal "an empty label is printed as \"\""
    ""
    (field (group-ref (layout-named groups-piece 'short) 0 1) 'label))
  (test-equal "member order: polos then sangsih this time"
    '("polos" "sangsih")
    (voice-names (layout-named groups-piece 'short) 0 0))
  (test-equal "a member's :label does not rename its voice"
    '("polos" "sangsih")
    (voice-names (layout-named groups-piece 'short) 0 0))
  (test-equal "lanes do not depend on member order"
    #("e2" "o2" "i2" "u1")
    (lanes-of (layout-named groups-piece 'short) 0 0))
  (test-equal "the same events whatever the member order"
    (list (events-of (layout groups-piece) 0 2 1)
          (events-of (layout groups-piece) 0 2 0))
    (list (events-of (layout-named groups-piece 'short) 0 0 0)
          (events-of (layout-named groups-piece 'short) 0 0 1)))
  (test-equal "parts in no group are not printed"
    '(("polos" "sangsih") ("melody"))
    (map (lambda (g) (voice-names (layout-named groups-piece 'short) 0 g))
         '(0 1)))

  (test-equal "a group built by hand: its label, subtitle and voices"
    (list "Hand" "made" '("gong" "ugal"))
    (let* ((fig (layout-score
                 tenzer
                 (hand-score tenzer
                             (list (hand-group "Hand"
                                               (list (part-named tenzer 'gong))
                                               #:subtitle "made")
                                   (hand-group "U"
                                               (list (part-named tenzer 'ugal)))))))
           (g (group-ref fig 0 0)))
      (list (field g 'label) (field g 'subtitle)
            (append (voice-names fig 0 0) (voice-names fig 0 1))))))

;;; ------------------------------------------------------------------
;;; Events

(test-group "events"
  (test-equal "start and dur of notes and holds"
    '((0 3 1 #f) (3 1 0 #f) (4 2 1 #f))
    (timing (events-of (layout
                        (piece-of "(piece \"P\")"
                                  "(scale s a b)"
                                  "(instrument u s a1 b1)"
                                  "(part u :name p 1 _ _ 2 1 _ -)"))
                       0 0 0)))
  (test-equal "a chord: one event per note, same start and dur, by lane"
    ;; lanes: b1 (0), a1 (1); chord (1 2) at 0 for 2, then 2 at 2
    '((0 2 0 #f) (0 2 1 #f) (2 1 0 #f))
    (timing (events-of (layout
                        (piece-of "(piece \"P\")"
                                  "(scale s a b)"
                                  "(instrument u s a1 b1)"
                                  "(part u :name p (1 2) _ 2)"))
                       0 0 0)))
  (test-equal "a chord written high-to-low is still sorted by lane"
    '((0 1 0 #f) (0 1 1 #f) (0 1 2 #f))
    (timing (events-of (layout
                        (piece-of "(piece \"P\")"
                                  "(scale s a b c)"
                                  "(instrument u s a1 b1 c1)"
                                  "(part u :name p (c1 a1 b1))"))
                       0 0 0)))
  (test-equal "a stroke chord: lanes in instrument order"
    '((0 1 0 #f) (0 1 1 #f) (1 1 2 #f))
    (timing (events-of (layout
                        (piece-of "(piece \"P\")"
                                  "(strokes k dag dug du)"
                                  "(instrument kendang k dag dug du)"
                                  "(part kendang :name p (dug dag) du)"))
                       0 0 0)))

  (test-equal "the default score shows no names: text null, colours kept"
    (list (ev 0 1 0 'null dung-fill dark #f)
          (ev 1 1 1 'null dang-fill dark #f))
    (events-of (layout (selisir-piece "(instrument u selisir a1 u2)"
                                      "(part u :name p u2 a1)"))
               0 0 0))
  (test-equal "strokes show no name by default either: grey boxes, text null"
    (list (ev 0 1 0 'null grey dark #f))
    (events-of (layout
                (piece-of "(piece \"P\")"
                          "(strokes k dag)"
                          "(instrument kendang k dag)"
                          "(part kendang :name p dag)"))
               0 0 0))
  (test-equal "default colours, hard-coded: selisir degrees in pastel1"
    (list (ev 0 1 0 'null dung-fill dark #f)
          (ev 1 1 1 'null deng-fill dark #f)
          (ev 2 1 2 'null dong-fill dark #f)
          (ev 3 1 3 'null ding-fill dark #f)
          (ev 4 1 4 'null dang-fill dark #f))
    (events-of (layout (selisir-piece "(instrument u selisir a1 i2 o2 e2 u2)"
                                      "(part u :name p u2 e2 o2 i2 a1)"))
               0 0 0))
  (test-equal "degree without :display: the lane label is the degree name"
    #("dong1")
    (lanes-of (layout (piece-of "(piece \"P\")"
                                "(scale s ding dong)"
                                "(instrument u s ding1 dong1)"
                                "(part u :name p 2)"))
              0 0))
  (test-equal "a selisir with :display \"i\" labels its lane \"i1\", not \"ding1\""
    #("i1")
    (lanes-of (layout
               (piece-of "(piece \"P\")"
                         "(scale selisir (ding :display \"i\") dong)"
                         "(instrument u selisir ding1 dong1)"
                         "(part u :name p ding1)"))
              0 0))
  (test-equal "strokes: grey, text null, text colour #222222 (ADR 0019)"
    (list (ev 0 1 0 'null grey dark #f)
          (ev 1 1 1 'null grey dark #f))
    (events-of (layout
                (piece-of "(piece \"P\")"
                          "(strokes k (dag :display \"D\") dug du)"
                          "(instrument kendang k dag dug du)"
                          "(part kendang :name p dag dug)"))
               0 0 0))
  (test-equal "strokes: lanes show the display form"
    #("D" "dug")
    (lanes-of (layout
               (piece-of "(piece \"P\")"
                         "(strokes k (dag :display \"D\") dug du)"
                         "(instrument kendang k dag dug du)"
                         "(part kendang :name p dag dug)"))
              0 0))

  (test-equal "tenzer1: one default group per part, in part order"
    '("ugal" "gong" "kempli")
    (group-labels (layout tenzer) 0))
  (test-equal "tenzer1: lanes of the three groups"
    (list #("e2" "o2" "i2" "a1") #("G" "P") #("K"))
    (map (lambda (g) (lanes-of (layout tenzer) 0 g)) '(0 1 2)))
  (test-equal "tenzer1: labels, subtitles and voice names"
    '(("ugal" null ("ugal"))
      ("gong" null ("gong"))
      ("kempli" null ("kempli")))
    (map (lambda (g)
           (let ((group (group-ref (layout tenzer) 0 g)))
             (list (field group 'label) (field group 'subtitle)
                   (voice-names (layout tenzer) 0 g))))
         '(0 1 2)))
  (test-equal "tenzer1: the ugal's events: colours, no names"
    (list (ev 0 1 3 'null dang-fill dark #f)
          (ev 1 1 1 'null dong-fill dark #f)
          (ev 2 1 2 'null ding-fill dark #f)
          (ev 3 1 0 'null deng-fill dark #f)
          (ev 4 1 1 'null dong-fill dark #f)
          (ev 5 1 3 'null dang-fill dark #f)
          (ev 6 1 1 'null dong-fill dark #f)
          (ev 7 1 2 'null ding-fill dark #f)
          (ev 8 1 3 'null dang-fill dark #f))
    (events-of (layout tenzer) 0 0 0))
  (test-equal "tenzer1: the generated kempli on every step"
    (map (lambda (i) (ev i 1 0 'null grey dark #f)) (iota 9))
    (events-of (layout tenzer) 0 2 0))
  (test-equal "tenzer1: gong and kempur"
    (list (ev 0 1 0 'null grey dark #f)
          (ev 4 1 0 'null grey dark #f)
          (ev 5 1 1 'null grey dark #f)
          (ev 7 1 1 'null grey dark #f)
          (ev 8 1 0 'null grey dark #f))
    (events-of (layout tenzer) 0 1 0)))

;;; ------------------------------------------------------------------
;;; :note-names (04, "Note text, fill and holds"; ADR 0031)

(define names-lines
  '("(instrument u selisir a1 i2 o2 e2 u2)"
    "(strokes k (dag :display \"D\") dug du)"
    "(instrument kendang k dag dug du)"
    "(part u :name p u2 e2 o2 i2 a1)"
    "(part kendang :name d dag dug - - -)"))

(define (names-piece . score-lines)
  (apply selisir-piece (append names-lines score-lines)))

(define (texts fig s g v)
  (map (lambda (e) (field e 'text)) (events-of fig s g v)))

(test-group ":note-names"
  (test-equal "score :note-names yes: pitched notes show their degree's display form"
    (list (ev 0 1 0 "u" dung-fill dark #f)
          (ev 1 1 1 "e" deng-fill dark #f)
          (ev 2 1 2 "o" dong-fill dark #f)
          (ev 3 1 3 "i" ding-fill dark #f)
          (ev 4 1 4 "a" dang-fill dark #f))
    (events-of (layout (names-piece "(score s :note-names yes"
                                    "  (group \"U\" p) (group \"K\" d))"))
               0 0 0))
  (test-equal "score :note-names yes: strokes show their display form, still grey"
    (list (ev 0 1 0 "D" grey dark #f)
          (ev 1 1 1 "dug" grey dark #f))
    (events-of (layout (names-piece "(score s :note-names yes"
                                    "  (group \"U\" p) (group \"K\" d))"))
               0 1 0))
  (test-equal ":note-names no on the score: null everywhere"
    '((null null null null null) (null null))
    (let ((fig (layout (names-piece "(score s :note-names no"
                                    "  (group \"U\" p) (group \"K\" d))"))))
      (list (texts fig 0 0 0) (texts fig 0 1 0))))
  (test-equal "a score without :note-names: null (the default is no)"
    '((null null null null null) (null null))
    (let ((fig (layout (names-piece "(score s (group \"U\" p) (group \"K\" d))"))))
      (list (texts fig 0 0 0) (texts fig 0 1 0))))
  (test-equal "on one group only: that group shows names"
    '((null null null null null) ("D" "dug"))
    (let ((fig (layout (names-piece "(score s (group \"U\" p)"
                                    "  (group \"K\" :note-names yes d))"))))
      (list (texts fig 0 0 0) (texts fig 0 1 0))))
  (test-equal "a group's no overrides the score's yes"
    '(("u" "e" "o" "i" "a") (null null))
    (let ((fig (layout (names-piece "(score s :note-names yes (group \"U\" p)"
                                    "  (group \"K\" :note-names no d))"))))
      (list (texts fig 0 0 0) (texts fig 0 1 0))))
  (test-equal "names do not change the colours"
    (map (lambda (e) (list (field e 'fill) (field e 'text_color)))
         (events-of (layout (names-piece "(score s (group \"U\" p) (group \"K\" d))"))
                    0 0 0))
    (map (lambda (e) (list (field e 'fill) (field e 'text_color)))
         (events-of (layout (names-piece "(score s :note-names yes"
                                         "  (group \"U\" p) (group \"K\" d))"))
                    0 0 0)))
  (test-equal "a degree without :display shows its name"
    '("ding" "dong")
    (texts (layout (piece-of "(piece \"P\")" "(scale s ding dong)"
                             "(instrument u s ding1 dong2)"
                             "(part u :name p 1 2)"
                             "(score s :note-names yes (group \"p\" p))"))
           0 0 0))
  (test-equal "a held note shows its name once, on its one event"
    '((0 3 0 #f "u"))
    (map (lambda (e) (list (field e 'start) (field e 'dur) (field e 'lane)
                           (field e 'continued) (field e 'text)))
         (events-of (layout (selisir-piece "(instrument u selisir u2)"
                                           "(part u :name p u2 _ _)"
                                           "(score s :note-names yes (group \"p\" p))"))
                    0 0 0)))
  (test-equal "a cut note shows its name again in the next system"
    '(("u") ("u"))
    (let ((fig (layout (selisir-piece "(instrument u selisir u2)"
                                      "(part u :name p - u2 _ -)"
                                      "(score s :note-names yes :system-length 2"
                                      "  (group \"p\" p))"))))
      (list (texts fig 0 0 0) (texts fig 1 0 0))))
  (test-equal "a chord: each note shows its own name"
    '("o" "i")
    (texts (layout (selisir-piece "(instrument u selisir i2 o2)"
                                  "(part u :name p (i2 o2))"
                                  "(score s :note-names yes (group \"p\" p))"))
           0 0 0))
  (test-equal "the text is the look's text (tenzer1, a group built by hand)"
    (map (lambda (name) (expected-look (default-style) tenzer 'ugal name
                                       #:names? #t))
         '(dang1 dong2 ding2 deng2 dong2 dang1 dong2 ding2 dang1))
    (map event-look
         (events-of (layout-score
                     tenzer
                     (hand-score tenzer
                                 (list (hand-group "ugal"
                                                   (list (part-named tenzer 'ugal))
                                                   #:note-names? #t))))
                    0 0 0))))

;;; ------------------------------------------------------------------
;;; One style per group, from its scheme, palette and colors (04, "Note
;;; style"; ADR 0032)

(define colour-lines
  '("(instrument u selisir i2 o2)"
    "(part u :name a i2 o2)"
    "(part u :name b i2 o2)"
    "(part u :name c i2 o2)"
    "(part u :name d i2 o2)"))

(define (colour-piece . score-lines)
  (apply selisir-piece (append colour-lines score-lines)))

(define (looks-of fig g)
  (map event-look (events-of fig 0 g 0)))

(define (style-looks piece . style-args)
  "The looks of i2 and o2 on u with (apply make-style STYLE-ARGS)."
  (let ((style (apply make-style style-args)))
    (map (lambda (n) (expected-look style piece 'u n)) '(ding2 dong2))))

(test-group "colours: one style per group"
  (test-equal "score :palette set1, hard-coded"
    (list (list 'null "#e41a1c" white) (list 'null "#377eb8" white))
    (looks-of (layout (colour-piece "(score s :palette set1 (group \"a\" a))"))
              0))
  (test-equal "score :colors, hard-coded: dong black, white text"
    (list (list 'null ding-fill dark) (list 'null "#000000" white))
    (looks-of (layout (colour-piece
                       "(score s :colors ((dong \"#000000\")) (group \"a\" a))"))
              0))
  (test-equal "score :palette as a list of colours"
    (list (list 'null "#111111" white) (list 'null "#eeeeee" dark))
    (looks-of (layout (colour-piece
                       "(score s :palette (\"#111111\" \"#eeeeee\") (group \"a\" a))"))
              0))
  (test-equal ":scheme by-degree is the default"
    (looks-of (layout (colour-piece "(score s (group \"a\" a))")) 0)
    (looks-of (layout (colour-piece "(score s :scheme by-degree"
                                    "  (group \"a\" :scheme by-degree a))"))
              0))
  (test-equal "the default: pastel1"
    (list (list 'null ding-fill dark) (list 'null dong-fill dark))
    (looks-of (layout (colour-piece "(score s (group \"a\" a))")) 0))

  (let* ((pc (colour-piece
              "(score s :palette set1 :colors ((dong \"#000000\"))"
              "  (group \"a\" a)"
              "  (group \"b\" :palette dark2 b)"
              "  (group \"c\" :colors ((ding \"#ffffff\")) c)"
              "  (group \"d\" :palette (\"#111111\" \"#eeeeee\") d))"))
         (fig (layout pc)))
    (test-equal "a group without colour options: the score's palette and colors"
      (style-looks pc #:palette 'set1 #:degree-colors '((dong . "#000000")))
      (looks-of fig 0))
    (test-equal "a group's :palette overrides the score's; the score's :colors stay"
      (style-looks pc #:palette 'dark2 #:degree-colors '((dong . "#000000")))
      (looks-of fig 1))
    (test-equal "a group's :colors replace the score's; the score's palette stays"
      (style-looks pc #:palette 'set1 #:degree-colors '((ding . "#ffffff")))
      (looks-of fig 2))
    (test-equal "a group's :colors, hard-coded: ding white with dark text, dong set1"
      (list (list 'null "#ffffff" dark) (list 'null "#377eb8" white))
      (looks-of fig 2))
    (test-equal "a group's list palette"
      (style-looks pc #:palette '("#111111" "#eeeeee")
                   #:degree-colors '((dong . "#000000")))
      (looks-of fig 3))
    (test-assert "the four groups are coloured differently"
      (let ((all (map (lambda (g) (looks-of fig g)) '(0 1 2 3))))
        (= 4 (length (delete-duplicates all))))))

  (test-equal "strokes stay grey whatever the palette and colors"
    (list (list 'null grey dark) (list 'null grey dark))
    (looks-of (layout (names-piece
                       "(score s :palette dark2 :colors ((ding \"#000000\"))"
                       "  (group \"K\" d))"))
              0))
  (test-equal "colours and names together: a group's own palette, the score's names"
    (list (list "i" "#e41a1c" white) (list "o" "#377eb8" white))
    (looks-of (layout (colour-piece "(score s :note-names yes"
                                    "  (group \"a\" :palette set1 a))"))
              0))
  (test-equal "looks match note-look for every event (pastel2, a group built by hand)"
    (let ((style (make-style #:palette 'pastel2)))
      (map (lambda (name) (expected-look style tenzer 'ugal name))
           '(dang1 dong2 ding2 deng2 dong2 dang1 dong2 ding2 dang1)))
    (map event-look
         (events-of (layout-score
                     tenzer
                     (hand-score tenzer
                                 (list (hand-group "ugal"
                                                   (list (part-named tenzer 'ugal))
                                                   #:palette 'pastel2))))
                    0 0 0)))
  (test-equal "hand-built groups: each its own palette and colors"
    (list (let ((style (make-style #:palette 'set3)))
            (map (lambda (name) (expected-look style tenzer 'ugal name))
                 '(dang1 dong2 ding2)))
          (let ((style (make-style #:degree-colors '((dang . "#123456")))))
            (map (lambda (name) (expected-look style tenzer 'ugal name))
                 '(dang1 dong2 ding2))))
    (let* ((ugal (part-named tenzer 'ugal))
           (fig (layout-score
                 tenzer
                 (hand-score tenzer
                             (list (hand-group "one" (list ugal) #:palette 'set3)
                                   (hand-group "two" (list ugal)
                                               #:colors '((dang . "#123456"))))))))
      (list (map event-look (take (events-of fig 0 0 0) 3))
            (map event-look (take (events-of fig 0 1 0) 3))))))

;;; ------------------------------------------------------------------
;;; A complete figure

(test-group "complete figure"
  (test-equal "tiny: the whole figure, written out"
    tiny-expected
    (layout tiny))
  (test-equal "tiny: the same with layout-score and the score by name"
    tiny-expected
    (layout-score tiny (piece-score tiny 'tiny)))
  (test-equal "tiny, score split: systems of 2 pulses, written out"
    split-expected
    (layout-named tiny 'split)))

(define runner (test-runner-current))
(test-end "layout")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
