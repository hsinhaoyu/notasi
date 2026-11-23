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
;;;
;;; Slice feat/scores-contract (04, "Slices (iteration 2)", slice 2 and
;;; its decided bullets; 04, "Public interface", "Header and lines",
;;; "Sizes"; 05, "JSON contract (version 2)"; ADRs 0036, 0037): the
;;; figure is contract version 2. The figure gains `subtitle` (after
;;; `title`); `sizes` is `font_size` (the score's `:font-size`, or null),
;;; `label_width`, `lane_width`, `cell_width`, `cell_height`; each system
;;; has `header` (`label`, `cycles`, `pulses`) and `lines` between
;;; `steps` and `groups`; each group has `overlays`, #() in this slice.
;;; Choices made where the docs are not explicit (or disagree):
;;; - `lines` and the strings in `header.pulses` are Scheme strings
;;;   ("none", "pulse", "cycle"; "16"), since (notasi json) writes no
;;;   symbol but `null`.
;;; - The first column of every system has the line "none". 04 says
;;;   "`pulse` where another pulse starts", and 05's excerpt, whose
;;;   system starts on the pickup's pulse "16", has "none" there: a line
;;;   is a boundary inside the system, and the system's left edge is
;;;   not one. Only the tests in "lines: the first column" and the two
;;;   complete figures pin this; the other line tests look at columns 1
;;;   onwards (`lines-after-first`).
;;; - A cycle mark's `column` is relative to its system, like an event's
;;;   `start` (05's excerpt has one system starting at 0, so it can't
;;;   tell). A system in which no cycle starts has `cycles` #(), not
;;;   null: null is only for `cycle-numbers?` false or no colotomy.
;;; - A cycle starting on a system's first column gets its mark at
;;;   column 0 (it is "the first column of a cycle in the system").
;;; - The pickup is in no cycle: it has no cycle mark, and cycle 1 is
;;;   the first complete one (01, "cycle").
;;; - `:numbering gong-first` without a colotomy is not tested: "(k mod
;;;   N) + 1" needs a cycle length N.
;;; - `:cycle-numbers no` hides the cycle row only: the cycle lines
;;;   stay. `:pulse-numbers no` likewise leaves `lines` and `cycles`.
;;;
;;; Slice feat/scores-rows (04, "Slices (iteration 2)", slice 3 and its
;;; decided bullets; 04, "Groups and rows", "Note text, fill and holds",
;;; "Lane labels", "Sizes"; 05, `lanes` and `fill` null): `:rows parts`
;;; (one row per member, `lanes` its row labels, an event's `lane` its
;;; part's row) and `single` (`lanes` #(""), every lane 0); on these
;;; rows a chord is one event, its notes' names joined by a space, with
;;; its lowest note's look; with `note-names?` the text is the damped
;;; form when the note lasts no longer than one column (its whole
;;; length, even when cut), else the display form, on every kind of
;;; row; `:fill none` gives fill null; `:holds dash` gives the note's
;;; event its first column only and a one-column "-" event, fill null,
;;; in the same row for each later held column; `lane_width` counts row
;;; labels.
;;; Choices made where the docs are not explicit (or disagree):
;;; - 04's "Groups and rows" says a chord gives one event per note, "In
;;;   `parts` and `single` rows its notes share the row"; slice 3's
;;;   decided bullet makes it one event. The tests follow the bullet.
;;;   Tests write chords lowest note first, so whether the names are
;;;   joined in written or pitch order is not pinned.
;;; - A "-" event's `text_color` is not given by 04, so tests of dashes
;;;   leave it out (`shape`). With pastel1 every look's text colour is
;;;   dark, so events with fill null are tested with `dark`.
;;; - A "-" event is never cut (it is one column), so its `continued` is
;;;   #f, also at the start of a system after the note began in an
;;;   earlier one: drawn continued, its "-" would not show (05).
;;; - The note's own event under `:holds dash` shows the open form when
;;;   the note is held (its whole length counts, 04 slice 3).
;;; - A `notes` group without `note-names?` but with `:holds dash` is not
;;;   tested.
;;;
;;; Slice feat/scores-overlays (04, "Slices (iteration 2)", slice 4 and
;;; its decided bullets; 04, "Pattern names (overlays)", "The step",
;;; "The range and systems"; 05, overlays): with `pattern-names` short
;;; or long, each group's `overlays` has one overlay per merged span of
;;; its members at `pattern-level`: `start` and `dur` in columns from
;;; the system's start, `row` 0, `rows` the group's row count (lanes on
;;; notes rows, members on parts rows, 1 on a single row), `text` the
;;; short or long name in force at the use, `continued` false; sorted by
;;; start. Cut at system boundaries like a note, the later pieces
;;; `continued` true with the text kept. Span edges at the chosen level
;;; count towards the step.
;;; Choices made where the docs are not explicit:
;;; - Spans are merged when their start, end and chosen text agree: with
;;;   `short`, two spans whose long names differ make one overlay.
;;; - A span ending exactly on a system boundary is not cut, as for
;;;   notes; a system with no span in it has `overlays` #().
;;; - Spans of a group with `pattern-names` none, or at another level,
;;;   do not count towards the step.
;;; - Overlays of equal start (impossible after the reader's check) are
;;;   not tested for order.

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
                     #:key (title (piece-title piece)) (subtitle #f)
                     (caption #f) (system-length #f) (cycle-numbers? #f)
                     (pulse-numbers? #t) (numbering 'gong-last)
                     (pulse-label #f) (font-size #f)
                     (cell-width "2em") (cell-height "2em"))
  "A score record built by hand over the whole of PIECE."
  (make-score 'hand title subtitle caption 0 (piece-length piece)
              system-length '() cycle-numbers? pulse-numbers? numbering
              pulse-label font-size cell-width cell-height groups #f))

(define figure-keys
  '(version title subtitle steps_per_pulse sizes systems caption))
(define sizes-keys '(font_size label_width lane_width cell_width cell_height))
(define system-keys '(start steps header lines groups))
(define header-keys '(label cycles pulses))
(define mark-keys '(column text))
(define group-keys '(label subtitle lanes voices overlays))
(define voice-keys '(name events))
(define event-keys '(start dur lane text fill text_color continued))

(define (string-or-null? x) (or (string? x) (eq? x 'null)))

(define (well-formed? fig)
  "Does every object in FIG have exactly the documented keys, in order,
every array a vector, and every system a header and lines of one entry
per column?"
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
         (every-in (field g 'voices) voice-ok?)
         (vector? (field g 'overlays))))
  (define (mark-ok? m)
    (and (equal? (keys m) mark-keys)
         (integer? (field m 'column))
         (string? (field m 'text))))
  (define (header-ok? h steps)
    (and (equal? (keys h) header-keys)
         (string-or-null? (field h 'label))
         (let ((cycles (field h 'cycles)))
           (or (eq? cycles 'null) (every-in cycles mark-ok?)))
         (let ((pulses (field h 'pulses)))
           (or (eq? pulses 'null)
               (and (every-in pulses string-or-null?)
                    (= steps (vector-length pulses)))))))
  (define (system-ok? s)
    (and (equal? (keys s) system-keys)
         (header-ok? (field s 'header) (field s 'steps))
         (every-in (field s 'lines)
                   (lambda (l) (member l '("none" "pulse" "cycle"))))
         (= (field s 'steps) (vector-length (field s 'lines)))
         (every-in (field s 'groups) group-ok?)))
  (and (equal? (keys fig) figure-keys)
       (string-or-null? (field fig 'subtitle))
       (string-or-null? (field fig 'caption))
       (equal? (keys (field fig 'sizes)) sizes-keys)
       (every-in (field fig 'systems) system-ok?)))

(define (v2-sizes label-width lane-width)
  "The sizes of a figure with these label widths and every other size
at its default: font_size null, cells \"2em\"."
  `((font_size . null) (label_width . ,label-width)
    (lane_width . ,lane-width) (cell_width . "2em") (cell_height . "2em")))

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

(define (sys start steps header lines . groups)
  `((start . ,start) (steps . ,steps) (header . ,header) (lines . ,lines)
    (groups . ,(list->vector groups))))

(define (hdr label cycles pulses)
  `((label . ,label) (cycles . ,cycles) (pulses . ,pulses)))

(define (mark column text)
  "A cycle mark."
  `((column . ,column) (text . ,text)))

(define (grp label subtitle lanes . voices)
  "A group with no overlays (there are none until slice 4)."
  `((label . ,label) (subtitle . ,subtitle) (lanes . ,lanes)
    (voices . ,(list->vector voices)) (overlays . #())))

(define (voice name . events)
  `((name . ,name) (events . ,(list->vector events))))

;; Lanes of "Ugal": ding2 deng1 dong1 ding1 → i2 e1 o1 i1 (0 1 2 3).
;; No group has note names: text is null for pitched notes and strokes.
;; Lanes of "gong": G P (0 1). The built-in kempli is in no group.
(define tiny-expected
  `((version . 2)
    (title . "Tiny")
    (subtitle . null)
    (steps_per_pulse . 2)
    (sizes . ((font_size . null)
              (label_width . "10.5em")   ; "polos + sangsih": 15 chars
              (lane_width . "2.0em")     ; "i2": 2 chars
              (cell_width . "2em")
              (cell_height . "2em")))
    (systems
     . ,(vector
         ;; No colotomy: pulses numbered within the piece, no cycle row,
         ;; no cycle lines; a pulse line where pulses 2 and 3 start.
         (sys 0 5
              (hdr 'null 'null #("1" null "2" null "3"))
              #("none" "none" "pulse" "none" "pulse")
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
  `((version . 2)
    (title . "Tiny")
    (subtitle . null)
    (steps_per_pulse . 2)
    (sizes . ((font_size . null)
              (label_width . "10.5em")
              (lane_width . "2.0em")
              (cell_width . "2em")
              (cell_height . "2em")))
    (systems
     . ,(vector
         (sys 0 4
              (hdr 'null 'null #("1" null "2" null))
              #("none" "none" "pulse" "none")
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
         ;; Absolute numbering: column 4 is pulse 3.
         (sys 4 1
              (hdr 'null 'null #("3"))
              #("none")
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
  (test-equal "version 2" 2 (field (layout tiny) 'version))
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
    (v2-sizes "10.5em" "3.6em")
    (sizes-of
     "(piece \"Reyong kotekan\")"
     "(scale reyong-4 nang ning nong neng)"
     "(instrument reyong reyong-4 nang1 ning1 nong1 neng1)"
     "(part reyong :name polos    1 _ 1 2 / _ 1 2 _ / 2 1 _ 2)"
     "(part reyong :name sangsih  4 3 4 _ / 3 4 _ 3 / _ 4 3 _)"
     "(score s (group \"Reyong\" :subtitle \"polos + sangsih\" polos sangsih))"))

  (test-equal "no groups: 1.5em and 1.0em"
    (v2-sizes "1.5em" "1.0em")
    (sizes-of "(piece \"Empty\")"))

  (test-equal "one-letter label and stroke: 2.1em, 1.5em"
    (v2-sizes "2.1em" "1.5em")
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
    (v2-sizes "2.7em" "1.0em")
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
    (v2-sizes "5.1em" "2.0em")
    (field (layout tenzer) 'sizes))

  (test-equal "groups piece: \"sangsih + polos\" → 10.5em, \"e2\" → 2.0em"
    (v2-sizes "10.5em" "2.0em")
    (field (layout groups-piece) 'sizes)))

(test-group "sizes: the cell, from the score"
  (test-equal "default: \"2em\" each, as written"
    '("2em" "2em")
    (let ((s (tiny-sizes)))
      (list (field s 'cell_width) (field s 'cell_height))))
  (test-equal ":cell-width and :cell-height go into cell_width and cell_height"
    '("3em" "1.5em")
    (let ((s (tiny-sizes ":cell-width \"3em\"" ":cell-height \"1.5em\"")))
      (list (field s 'cell_width) (field s 'cell_height))))
  (test-equal "lengths are kept as written, any unit"
    '("4mm" "10pt")
    (let ((s (tiny-sizes ":cell-width \"4mm\"" ":cell-height \"10pt\"")))
      (list (field s 'cell_width) (field s 'cell_height))))
  (test-equal "only the width: the height stays \"2em\""
    '("2.5em" "2em")
    (let ((s (tiny-sizes ":cell-width \"2.5em\"")))
      (list (field s 'cell_width) (field s 'cell_height))))
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
      (list (field s 'cell_width) (field s 'cell_height)))))

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
;;; Contract version 2: subtitle, caption, font_size, header and lines
;;; (04, "Public interface", "Header and lines"; slice 2)

;;; A piece on a colotomy `c` of N pulses (a gong on the last pulse),
;;; with PICKUP pulses before the first cycle, a part m of TOKENS, and a
;;; score s of m with OPTIONS (a string). Without a score: the default
;;; score. The kempli is the built-in one, never printed.
(define* (colo-piece tokens #:key (cycle 4) (pickup 0) (options "")
                     (score? #t))
  (apply piece-of
         (append
          (list (string-append "(piece \"C\" :colotomy c"
                               (if (zero? pickup)
                                   ""
                                   (string-append " :pickup "
                                                  (number->string pickup)))
                               ")")
                "(scale s a b)"
                "(strokes gong-strokes G)"
                "(instrument u s a1 b1)"
                "(instrument gong gong-strokes G)"
                (string-append "(colotomy c " (number->string cycle)
                               " (gong gong -:" (number->string (- cycle 1))
                               " G:1))")
                (string-append "(part u :name m " tokens ")"))
          (if score?
              (list (string-append "(score s " options " (group \"m\" m))"))
              '()))))

(define (notes n)
  "N one-pulse notes, as part tokens."
  (string-join (map (lambda (i) (if (even? i) "1" "2")) (iota n)) " "))

(define (header-of fig s) (field (system-ref fig s) 'header))
(define (pulses-of fig s) (field (header-of fig s) 'pulses))
(define (cycles-of fig s) (field (header-of fig s) 'cycles))
(define (label-of fig s) (field (header-of fig s) 'label))
(define (lines-of fig s) (field (system-ref fig s) 'lines))

(define (lines-after-first fig s)
  "The lines of system S from its second column on, as a list (the first
column's line is tested on its own, in \"lines: the first column\")."
  (cdr (vector->list (lines-of fig s))))

(define-syntax-rule (layout-or-false expr)
  "EXPR's value, or #f if it raises, for figures bound outside a test."
  (guard (c (#t #f)) expr))

(define (marks . pairs)
  "A vector of cycle marks from (COLUMN TEXT) lists."
  (list->vector (map (lambda (p) (apply mark p)) pairs)))

(test-group "figure: subtitle and caption"
  (test-eq "no :subtitle: null" 'null (field (layout tiny) 'subtitle))
  (test-eq "no :caption: null" 'null (field (layout tiny) 'caption))
  (test-equal ":subtitle is the figure's subtitle" "pangecet"
    (field (layout (ten-score ":subtitle \"pangecet\"")) 'subtitle))
  (test-equal ":caption is the figure's caption" "From Tenzer, p. 12"
    (field (layout (ten-score ":caption \"From Tenzer, p. 12\"")) 'caption))
  (test-equal "both, kept as written, with the title in its place"
    '("T" "Sub · é" "Cap")
    (let ((fig (layout (ten-score ":title \"T\" :subtitle \"Sub · é\""
                                  ":caption \"Cap\""))))
      (list (field fig 'title) (field fig 'subtitle) (field fig 'caption))))
  (test-equal "a group's :subtitle is not the figure's" 'null
    (field (layout groups-piece) 'subtitle))
  (test-equal "a score built by hand: its subtitle and caption"
    '("s" "c")
    (let ((fig (layout-score
                tenzer
                (hand-score tenzer
                            (list (hand-group "ugal"
                                              (list (part-named tenzer 'ugal))))
                            #:subtitle "s" #:caption "c"))))
      (list (field fig 'subtitle) (field fig 'caption))))
  (test-assert "well-formed with both"
    (well-formed? (layout (ten-score ":subtitle \"s\" :caption \"c\"")))))

(test-group "sizes: font_size"
  (test-eq "no :font-size: null (the entry file uses 8pt, a document its own)"
    'null (field (tiny-sizes) 'font_size))
  (test-equal ":font-size as written" "10pt"
    (field (tiny-sizes ":font-size \"10pt\"") 'font_size))
  (test-equal ":font-size in another unit" "3.5mm"
    (field (tiny-sizes ":font-size \"3.5mm\"") 'font_size))
  (test-equal "the other sizes do not change with it"
    (v2-sizes "2.7em" "2.0em")
    (let ((s (tiny-sizes ":font-size \"12pt\"")))
      (cons '(font_size . null) (cdr s))))
  (test-equal "font_size comes first in sizes"
    sizes-keys
    (keys (tiny-sizes ":font-size \"12pt\"")))
  (test-equal "a score built by hand: its font size" "9pt"
    (field (field (layout-score
                   tenzer
                   (hand-score tenzer
                               (list (hand-group "ugal"
                                                 (list (part-named tenzer 'ugal))))
                               #:font-size "9pt"))
                  'sizes)
           'font_size)))

(test-group "header: pulse numbers, gong-last"
  (test-equal "no pickup: 1 to 4 in each cycle, the gong on 4"
    #("1" "2" "3" "4" "1" "2" "3" "4")
    (pulses-of (layout (colo-piece (notes 8))) 0))
  (test-equal "a pickup of 1: numbered as the last pulse of a cycle"
    #("4" "1" "2" "3" "4" "1" "2" "3" "4")
    (pulses-of (layout (colo-piece (notes 9) #:pickup 1)) 0))
  (test-equal "a pickup of 2: the last two pulses of a cycle"
    #("3" "4" "1" "2" "3" "4")
    (pulses-of (layout (colo-piece (notes 6) #:pickup 2)) 0))
  (test-equal "an 8-pulse cycle with a pickup of 1"
    #("8" "1" "2" "3" "4" "5" "6" "7" "8")
    (pulses-of (layout (colo-piece (notes 9) #:cycle 8 #:pickup 1)) 0))
  (test-equal "two-digit numbers: a 16-pulse cycle"
    (list->vector (map number->string (iota 16 1)))
    (pulses-of (layout (colo-piece (notes 16) #:cycle 16)) 0))
  (test-equal ":numbering gong-last written out is the default"
    (layout (colo-piece (notes 9) #:pickup 1))
    (layout (colo-piece (notes 9) #:pickup 1 #:options ":numbering gong-last")))
  (test-equal "the default score of a piece with a colotomy"
    #("4" "1" "2" "3" "4")
    (pulses-of (layout (colo-piece (notes 5) #:pickup 1 #:score? #f)) 0)))

(test-group "header: pulse numbers, gong-first"
  (test-equal "no pickup: pulse k is printed (k mod 4) + 1, the gong on 1"
    #("2" "3" "4" "1" "2" "3" "4" "1")
    (pulses-of (layout (colo-piece (notes 8) #:options ":numbering gong-first"))
               0))
  (test-equal "a pickup of 1: the gong pulse, printed 1"
    #("1" "2" "3" "4" "1" "2" "3" "4" "1")
    (pulses-of (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":numbering gong-first"))
               0))
  (test-equal "a pickup of 2"
    #("4" "1" "2" "3" "4" "1")
    (pulses-of (layout (colo-piece (notes 6) #:pickup 2
                                   #:options ":numbering gong-first"))
               0))
  (test-equal "only the printed numbers change: lines and cycles stay"
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1))))
      (list (lines-of fig 0) (cycles-of fig 0)))
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":numbering gong-first"))))
      (list (lines-of fig 0) (cycles-of fig 0))))
  (test-equal "a score built by hand: its numbering"
    #("2" "3" "4" "1" "2" "3" "4" "1")
    (let ((pc (colo-piece (notes 8))))
      (pulses-of (layout-score
                  pc
                  (hand-score pc (list (hand-group "m" (list (part-named pc 'm))))
                              #:cycle-numbers? #t #:numbering 'gong-first))
                 0))))

(test-group "header: pulse numbers in columns"
  ;; 05's excerpt: quarter pulses, a pickup of 1.
  (test-equal "quarter pulses: the number on a pulse's first column, null elsewhere"
    #("4" null null null "1" null null null "2" null null null
      "3" null null null "4" null null null)
    (pulses-of (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2" #:pickup 1)) 0))
  (test-equal "half pulses, gong-first"
    #("2" null "3" null "4" null "1" null)
    (pulses-of (layout (colo-piece "1:1/2 2 1:1 2 1"
                                   #:options ":numbering gong-first"))
               0))
  (test-equal "one entry per column"
    20
    (vector-length
     (pulses-of (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2" #:pickup 1)) 0))))

(test-group "header: pulse numbers without a colotomy"
  (test-equal "within the piece: 1 to 10"
    (list->vector (map number->string (iota 10 1)))
    (pulses-of (layout (ten-steps)) 0))
  (test-equal "tenzer1: 1 to 9 (it has no colotomy)"
    (list->vector (map number->string (iota 9 1)))
    (pulses-of (layout tenzer) 0))
  (test-equal "half pulses (tiny)"
    #("1" null "2" null "3")
    (pulses-of (layout tiny) 0)))

(test-group "header: cycle numbers"
  (test-equal "no pickup: cycle 1 on the first column, cycle 2 on the fifth"
    (marks '(0 "1") '(4 "2"))
    (cycles-of (layout (colo-piece (notes 8))) 0))
  (test-equal "a pickup of 1: the pickup has no mark; cycle 1 after it"
    (marks '(1 "1") '(5 "2"))
    (cycles-of (layout (colo-piece (notes 9) #:pickup 1)) 0))
  (test-equal "quarter pulses: the mark is at the cycle's first column"
    (marks '(4 "1"))
    (cycles-of (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2" #:pickup 1)) 0))
  (test-equal "the default score with a colotomy shows them"
    (marks '(1 "1"))
    (cycles-of (layout (colo-piece (notes 5) #:pickup 1 #:score? #f)) 0))
  (test-equal "cycle numbers past 9: ten 2-pulse cycles"
    (list->vector (map (lambda (c) (mark (* 2 c) (number->string (+ c 1))))
                       (iota 10)))
    (cycles-of (layout (colo-piece (notes 20) #:cycle 2)) 0))
  (test-equal ":cycle-numbers yes written out is the default with a colotomy"
    (layout (colo-piece (notes 9) #:pickup 1))
    (layout (colo-piece (notes 9) #:pickup 1 #:options ":cycle-numbers yes")))
  (test-eq ":cycle-numbers no: null" 'null
    (cycles-of (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":cycle-numbers no"))
               0))
  (test-equal ":cycle-numbers no: the pulse row and lines stay"
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1))))
      (list (pulses-of fig 0) (lines-of fig 0)))
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":cycle-numbers no"))))
      (list (pulses-of fig 0) (lines-of fig 0))))
  (test-eq "no colotomy: null" 'null (cycles-of (layout (ten-steps)) 0))
  (test-eq "no colotomy, :cycle-numbers yes: null (no cycles to number)" 'null
    (cycles-of (layout (ten-score ":cycle-numbers yes")) 0))
  (test-eq "no colotomy, a score built by hand with cycle-numbers? #t: null" 'null
    (cycles-of (layout-score
                tenzer
                (hand-score tenzer
                            (list (hand-group "ugal"
                                              (list (part-named tenzer 'ugal))))
                            #:cycle-numbers? #t))
               0))
  (test-equal "a score built by hand with a colotomy and cycle-numbers? #t"
    (marks '(0 "1") '(4 "2"))
    (let ((pc (colo-piece (notes 8))))
      (cycles-of (layout-score
                  pc
                  (hand-score pc (list (hand-group "m" (list (part-named pc 'm))))
                              #:cycle-numbers? #t))
                 0)))
  (test-eq "a score built by hand with a colotomy and cycle-numbers? #f: null" 'null
    (let ((pc (colo-piece (notes 8))))
      (cycles-of (layout-score
                  pc
                  (hand-score pc (list (hand-group "m" (list (part-named pc 'm))))
                              #:cycle-numbers? #f))
                 0))))

(test-group "header: :pulse-numbers and :pulse-label"
  (test-eq ":pulse-numbers no: null" 'null
    (pulses-of (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":pulse-numbers no"))
               0))
  (test-equal ":pulse-numbers no: cycles and lines stay"
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1))))
      (list (cycles-of fig 0) (lines-of fig 0)))
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":pulse-numbers no"))))
      (list (cycles-of fig 0) (lines-of fig 0))))
  (test-eq ":pulse-numbers no without a colotomy: null" 'null
    (pulses-of (layout (ten-score ":pulse-numbers no")) 0))
  (test-equal ":pulse-numbers yes written out is the default"
    (layout (ten-score ""))
    (layout (ten-score ":pulse-numbers yes")))
  (test-equal "both rows off: header label, cycles and pulses"
    '(null null null)
    (let ((fig (layout (colo-piece (notes 8)
                                   #:options ":cycle-numbers no :pulse-numbers no"))))
      (list (label-of fig 0) (cycles-of fig 0) (pulses-of fig 0))))
  (test-eq "a score built by hand with pulse-numbers? #f: null" 'null
    (pulses-of (layout-score
                tenzer
                (hand-score tenzer
                            (list (hand-group "ugal"
                                              (list (part-named tenzer 'ugal))))
                            #:pulse-numbers? #f))
               0))
  (test-eq "no :pulse-label: null" 'null (label-of (layout (ten-steps)) 0))
  (test-equal ":pulse-label is the header's label" "Beats"
    (label-of (layout (ten-score ":pulse-label \"Beats\"")) 0))
  (test-equal ":pulse-label in every system"
    '("Beats" "Beats" "Beats")
    (map (lambda (s) (label-of (layout (ten-score ":pulse-label \"Beats\""
                                                  ":system-length 4"))
                               s))
         '(0 1 2)))
  (test-equal "a score built by hand: its pulse label" "Pulse"
    (label-of (layout-score
               tenzer
               (hand-score tenzer
                           (list (hand-group "ugal"
                                             (list (part-named tenzer 'ugal))))
                           #:pulse-label "Pulse"))
              0)))

(test-group "lines"
  (test-equal "no pickup: a cycle line where cycle 2 starts, pulse lines elsewhere"
    '("pulse" "pulse" "pulse" "cycle" "pulse" "pulse" "pulse")
    (lines-after-first (layout (colo-piece (notes 8))) 0))
  (test-equal "a pickup of 1: cycle lines just after each gong"
    '("cycle" "pulse" "pulse" "pulse" "cycle" "pulse" "pulse" "pulse")
    (lines-after-first (layout (colo-piece (notes 9) #:pickup 1)) 0))
  (test-equal "quarter pulses: a line at a pulse's first column, none inside it"
    '("none" "none" "none" "cycle" "none" "none" "none"
      "pulse" "none" "none" "none" "pulse" "none" "none" "none"
      "pulse" "none" "none" "none")
    (lines-after-first (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2" #:pickup 1))
                       0))
  (test-equal "no colotomy: pulse lines only"
    (make-list 9 "pulse")
    (lines-after-first (layout (ten-steps)) 0))
  (test-equal "no colotomy, half pulses (tiny)"
    '("none" "pulse" "none" "pulse")
    (lines-after-first (layout tiny) 0))
  (test-equal "one entry per column"
    '(9 20)
    (list (vector-length (lines-of (layout (colo-piece (notes 9) #:pickup 1)) 0))
          (vector-length
           (lines-of (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2" #:pickup 1)) 0))))
  (test-equal "a 2-pulse cycle: cycle and pulse lines in turn"
    '("pulse" "cycle" "pulse" "cycle" "pulse")
    (lines-after-first (layout (colo-piece (notes 6) #:cycle 2)) 0)))

(test-group "lines: the first column"
  ;; See the header: the system's left edge is not a line (05's excerpt).
  (test-equal "a system starting with the pickup" "none"
    (vector-ref (lines-of (layout (colo-piece (notes 9) #:pickup 1)) 0) 0))
  (test-equal "a system starting with cycle 1" "none"
    (vector-ref (lines-of (layout (colo-piece (notes 8))) 0) 0))
  (test-equal "no colotomy" "none"
    (vector-ref (lines-of (layout (ten-steps)) 0) 0))
  (test-equal "every system, also one starting on a cycle or a pulse"
    '("none" "none" "none")
    (let ((fig (layout (colo-piece (notes 12) #:options ":system-length 4"))))
      (map (lambda (s) (vector-ref (lines-of fig s) 0)) '(0 1 2)))))

(test-group "header and lines across systems (:system-length)"
  ;; A pickup of 1, two 4-pulse cycles, systems of 3 pulses: pulses
  ;; 0-2, 3-5 and 6-8. Cycle 1 starts at pulse 1, cycle 2 at pulse 5.
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                 #:options ":system-length 3")))))
    (test-equal "systems" '((0 3) (3 3) (6 3)) (starts+steps fig))
    (test-equal "pulses continue across systems"
      '(#("4" "1" "2") #("3" "4" "1") #("2" "3" "4"))
      (map (lambda (s) (pulses-of fig s)) '(0 1 2)))
    (test-equal "cycle marks: in the system where the cycle starts, at its column"
      (list (marks '(1 "1")) (marks '(2 "2")) #())
      (map (lambda (s) (cycles-of fig s)) '(0 1 2)))
    (test-equal "lines, from the second column"
      '(("cycle" "pulse") ("pulse" "cycle") ("pulse" "pulse"))
      (map (lambda (s) (lines-after-first fig s)) '(0 1 2)))
    (test-assert "well-formed" (well-formed? fig)))
  (let ((fig (layout-or-false (layout (colo-piece (notes 12) #:options ":system-length 4")))))
    (test-equal "systems of one cycle: cycle marks at column 0"
      (list (marks '(0 "1")) (marks '(0 "2")) (marks '(0 "3")))
      (map (lambda (s) (cycles-of fig s)) '(0 1 2)))
    (test-equal "systems of one cycle: no cycle line inside them"
      (make-list 3 '("pulse" "pulse" "pulse"))
      (map (lambda (s) (lines-after-first fig s)) '(0 1 2))))
  (let ((fig (layout-or-false (layout (colo-piece "1:1/2 2 1 2 1:1 2 1 2 1 2"
                                 #:options ":system-length 3 :numbering gong-first")))))
    ;; Half pulses: systems of 6 columns, at 0, 6 and 12 (8 pulses).
    (test-equal "half pulses, gong-first: numbers by absolute column"
      '(#("2" null "3" null "4" null) #("1" null "2" null "3" null)
        #("4" null "1" null))
      (map (lambda (s) (pulses-of fig s)) '(0 1 2)))
    (test-equal "half pulses: cycle 2 starts on the second system's column 2"
      (list (marks '(0 "1")) (marks '(2 "2")) #())
      (map (lambda (s) (cycles-of fig s)) '(0 1 2)))
    (test-equal "half pulses: lines"
      '(("none" "pulse" "none" "pulse" "none")
        ("none" "cycle" "none" "pulse" "none")
        ("none" "pulse" "none"))
      (map (lambda (s) (lines-after-first fig s)) '(0 1 2))))
  (let ((fig (layout-or-false (layout (ten-score ":system-length 4")))))
    (test-equal "no colotomy: pulse numbers within the piece, across systems"
      '(#("1" "2" "3" "4") #("5" "6" "7" "8") #("9" "10"))
      (map (lambda (s) (pulses-of fig s)) '(0 1 2)))
    (test-equal "no colotomy: no cycle row in any system"
      '(null null null)
      (map (lambda (s) (cycles-of fig s)) '(0 1 2)))))

(test-group "contract version 2: well-formed"
  (test-assert "a colotomy with a pickup"
    (well-formed? (layout (colo-piece (notes 9) #:pickup 1))))
  (test-assert "quarter pulses"
    (well-formed? (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2" #:pickup 1))))
  (test-assert "every option of this slice"
    (well-formed? (layout (colo-piece (notes 9) #:pickup 1
                                      #:options (string-append
                                                 ":subtitle \"s\" :caption \"c\""
                                                 " :font-size \"10pt\""
                                                 " :pulse-label \"Beats\""
                                                 " :numbering gong-first"
                                                 " :system-length 2")))))
  (test-assert "both header rows off"
    (well-formed? (layout (colo-piece (notes 8) #:options
                                      ":cycle-numbers no :pulse-numbers no"))))
  (test-equal "every group has overlays, empty in this slice"
    '(#() #() #() #())
    (map (lambda (g) (field g 'overlays))
         (vector->list (field (system-ref (layout groups-piece) 0) 'groups))))
  (test-equal "the header's keys in order" header-keys
    (keys (header-of (layout (colo-piece (notes 8))) 0)))
  (test-equal "a cycle mark's keys in order" mark-keys
    (keys (vector-ref (cycles-of (layout (colo-piece (notes 8))) 0) 0)))
  (test-assert "json-string accepts a figure with a header"
    (string? (json-string (layout (colo-piece (notes 9) #:pickup 1
                                              #:options ":pulse-label \"B\""))))))

;;; ------------------------------------------------------------------
;;; Rows, damped names, fill and holds (slice feat/scores-rows; 04,
;;; "Groups and rows", "Note text, fill and holds", "Lane labels",
;;; "Sizes")

;;; A scale with damped forms for ding, dong and dang (colours as
;;; selisir's: ding-fill, dong-fill, ...); kendang's dag has one too.
;;; All one-pulse steps: one column is one pulse.
;;;   p: i2 (0-2), o2 (2), e2 (3), rest     → lanes of p: e2 o2 i2
;;;   q: rest, a1 (1-3), chord i2+o2 (3), rest
;;;   r: silent
;;;   s: u2 at 4 only (never sounds with p)
;;;   d: dag (0), dug (1-3), rests
(define rows-lines
  '("(piece \"R\")"
    "(scale sel (ding :alias i :display \"i\" :damped \"i'\")"
    "  (dong :alias o :display \"o\" :damped \"o'\") (deng :alias e :display \"e\")"
    "  (dung :alias u :display \"u\") (dang :alias a :display \"nang\" :damped \"na'\"))"
    "(strokes k (dag :display \"D\" :damped \"d\") dug)"
    "(instrument u sel a1 i2 o2 e2 u2)"
    "(instrument kendang k dag dug)"
    "(part u :name p i2:2 o2:1 e2 -)"
    "(part u :name q - a1 _ (i2 o2) -)"
    "(part u :name r - - - - -)"
    "(part u :name s - - - - u2)"
    "(part kendang :name d dag dug _ - -)"))

(define (rows-piece . score-lines)
  (apply piece-of (append rows-lines score-lines)))

(define (rows-fig . score-lines)
  "The figure of rows-piece with SCORE-LINES, or #f if it raises."
  (layout-or-false (layout (apply rows-piece score-lines))))

(define (shape e)
  "An event as (start dur lane text fill continued): its text_color
left out, for the \"-\" events of :holds dash, whose colour 04 doesn't
give."
  (map (lambda (k) (field e k)) '(start dur lane text fill continued)))

(define (shapes fig s g v) (map shape (events-of fig s g v)))

(define (dash start lane) (list start 1 lane "-" 'null #f))

(test-group ":rows parts"
  (let ((fig (rows-fig "(score s :note-names yes"
                       "  (group \"U\" :rows parts (p :label \"Polos\") q r))")))
    (test-equal "lanes: the row labels in member order, the default the part's name"
      #("Polos" "q" "r")
      (and fig (lanes-of fig 0 0)))
    (test-equal "voices: one per member, named after the part, not its label"
      '("p" "q" "r")
      (and fig (voice-names fig 0 0)))
    (test-equal "p: every event on row 0; damped names for one-column notes"
      (list (ev 0 2 0 "i" ding-fill dark #f)
            (ev 2 1 0 "o'" dong-fill dark #f)
            (ev 3 1 0 "e" deng-fill dark #f))
      (and fig (events-of fig 0 0 0)))
    (test-equal "q: row 1; a chord is one event, names joined, the lowest note's look"
      (list (ev 1 2 1 "nang" dang-fill dark #f)
            (ev 3 1 1 "i' o'" ding-fill dark #f))
      (and fig (events-of fig 0 0 1)))
    (test-equal "r: a silent part keeps its row, with no events"
      '()
      (and fig (events-of fig 0 0 2)))
    (test-assert "well-formed" (and fig (well-formed? fig))))
  (let ((fig (rows-fig "(score s :rows parts :note-names yes"
                       "  (group \"K\" (q :label \"Q\") (p :label \"P\")))")))
    (test-equal "the score's :rows parts; rows follow the members' order"
      (list #("Q" "P") '(0 0) '(1 1 1))
      (and fig (list (lanes-of fig 0 0)
                     (map (lambda (e) (field e 'lane)) (events-of fig 0 0 0))
                     (map (lambda (e) (field e 'lane)) (events-of fig 0 0 1))))))
  (let ((fig (rows-fig "(score s :rows parts :note-names yes"
                       "  (group \"U\" :rows notes p) (group \"K\" d))")))
    (test-equal "a group's :rows notes over the score's parts: note lanes"
      #("e2" "o2" "i2")
      (and fig (lanes-of fig 0 0)))
    (test-equal "strokes on a parts row: one row, damped names"
      (list #("d") (list (ev 0 1 0 "d" grey dark #f) (ev 1 2 0 "dug" grey dark #f)))
      (and fig (list (lanes-of fig 0 1) (events-of fig 0 1 0))))))

(test-group ":rows single"
  (let ((fig (rows-fig "(score s :note-names yes"
                       "  (group \"U\" :rows single p s))")))
    (test-equal "lanes: one row labelled \"\"" #("")
      (and fig (lanes-of fig 0 0)))
    (test-equal "voices: one per member" '("p" "s")
      (and fig (voice-names fig 0 0)))
    (test-equal "every event on lane 0"
      (list (list (ev 0 2 0 "i" ding-fill dark #f)
                  (ev 2 1 0 "o'" dong-fill dark #f)
                  (ev 3 1 0 "e" deng-fill dark #f))
            (list (ev 4 1 0 "u" dung-fill dark #f)))
      (and fig (list (events-of fig 0 0 0) (events-of fig 0 0 1))))
    (test-assert "well-formed" (and fig (well-formed? fig))))
  (let ((fig (rows-fig "(score s :rows single :note-names yes (group \"Q\" q))")))
    (test-equal "the score's :rows single; a chord is one event"
      (list #("") (list (ev 1 2 0 "nang" dang-fill dark #f)
                        (ev 3 1 0 "i' o'" ding-fill dark #f)))
      (and fig (list (lanes-of fig 0 0) (events-of fig 0 0 0))))))

(test-group "damped and open names"
  (let ((fig (rows-fig "(score s :note-names yes (group \"U\" p) (group \"K\" d))")))
    (test-equal "notes rows too: a one-column note shows its damped form"
      '("i" "o'" "e")
      (and fig (texts fig 0 0 0)))
    (test-equal "a stroke: damped when it lasts one column"
      '("d" "dug")
      (and fig (texts fig 0 1 0))))
  (test-equal "without :note-names: text null, whatever the length"
    '(null null null)
    (let ((fig (rows-fig "(score s (group \"U\" p))")))
      (and fig (texts fig 0 0 0))))
  (test-equal "columns, not pulses: a one-pulse note of two columns is open"
    '(("o'" 1) ("i" 2))
    (let ((fig (layout-or-false
                (layout (apply piece-of
                               (append (list-head rows-lines 6)
                                       '("(part u :name f o2:1/2 i2 _ - -:1 - -)"
                                         "(score s :note-names yes (group \"f\" f))")))))))
      (and fig (map (lambda (e) (list (field e 'text) (field e 'dur)))
                    (events-of fig 0 0 0)))))
  (test-equal "a note cut by a system break counts its whole length"
    '((("i" #f)) (("i" #t)))
    (let ((fig (layout-or-false
                (layout (apply piece-of
                               (append (list-head rows-lines 6)
                                       '("(part u :name h i2:2 - - -)"
                                         "(score s :note-names yes :system-length 1"
                                         "  (group \"h\" h))")))))))
      (and fig (map (lambda (s)
                      (map (lambda (e) (list (field e 'text) (field e 'continued)))
                           (events-of fig s 0 0)))
                    '(0 1)))))
  (test-equal "a one-column note at a system's end is damped"
    '("o'")
    (let ((fig (layout-or-false
                (layout (apply piece-of
                               (append (list-head rows-lines 6)
                                       '("(part u :name h - o2 - - -)"
                                         "(score s :note-names yes :system-length 2"
                                         "  (group \"h\" h))")))))))
      (and fig (texts fig 0 0 0)))))

(test-group ":fill none"
  (let ((fig (rows-fig "(score s :note-names yes :fill none"
                       "  (group \"U\" p) (group \"K\" d))")))
    (test-equal "pitched notes: fill null, text as before"
      (list (ev 0 2 2 "i" 'null dark #f)
            (ev 2 1 1 "o'" 'null dark #f)
            (ev 3 1 0 "e" 'null dark #f))
      (and fig (events-of fig 0 0 0)))
    (test-equal "strokes: fill null too"
      '((0 1 0 "d" null #f) (1 2 1 "dug" null #f))
      (and fig (shapes fig 0 1 0)))
    (test-assert "well-formed" (and fig (well-formed? fig))))
  (let ((fig (rows-fig "(score s :note-names yes"
                       "  (group \"U\" :fill none p) (group \"K\" d))")))
    (test-equal "on one group only: the other keeps its colours"
      (list '(null null null) (list grey grey))
      (and fig (list (map (lambda (e) (field e 'fill)) (events-of fig 0 0 0))
                     (map (lambda (e) (field e 'fill)) (events-of fig 0 1 0))))))
  (let ((fig (rows-fig "(score s :note-names yes :fill none"
                       "  (group \"U\" :rows single q))")))
    (test-equal "with :rows single: a chord with fill null"
      (list (ev 1 2 0 "nang" 'null dark #f) (ev 3 1 0 "i' o'" 'null dark #f))
      (and fig (events-of fig 0 0 0)))))

(test-group ":holds dash"
  (let ((fig (rows-fig "(score s :note-names yes :holds dash"
                       "  (group \"U\" :rows parts p q))")))
    (test-equal "a held note: its first column, then a \"-\" per held column"
      (list (list 0 1 0 "i" ding-fill #f) (dash 1 0)
            (list 2 1 0 "o'" dong-fill #f) (list 3 1 0 "e" deng-fill #f))
      (and fig (shapes fig 0 0 0)))
    (test-equal "the note's event keeps its look; its text is the open form"
      (ev 0 1 0 "i" ding-fill dark #f)
      (and fig (car (events-of fig 0 0 0))))
    (test-equal "q: the dash in q's row; the chord after it"
      (list (list 1 1 1 "nang" dang-fill #f) (dash 2 1) (list 3 1 1 "i' o'" ding-fill #f))
      (and fig (shapes fig 0 0 1)))
    (test-assert "well-formed" (and fig (well-formed? fig))))
  (let ((fig (rows-fig "(score s :note-names yes :holds dash (group \"U\" p))")))
    (test-equal "notes rows: the dash in the note's lane"
      (list (list 0 1 2 "i" ding-fill #f) (dash 1 2)
            (list 2 1 1 "o'" dong-fill #f) (list 3 1 0 "e" deng-fill #f))
      (and fig (shapes fig 0 0 0))))
  (let ((fig (rows-fig "(score s :note-names yes :holds dash"
                       "  (group \"K\" :rows single d))")))
    (test-equal "strokes on a single row"
      (list (list 0 1 0 "d" grey #f) (list 1 1 0 "dug" grey #f) (dash 2 0))
      (and fig (shapes fig 0 0 0))))
  (let ((fig (rows-fig "(score s :note-names yes :holds dash :fill none"
                       "  (group \"U\" :rows single q))")))
    (test-equal "with :fill none: the note and its dashes all fill null"
      (list (list 1 1 0 "nang" 'null #f) (dash 2 0) (list 3 1 0 "i' o'" 'null #f))
      (and fig (shapes fig 0 0 0))))
  (let ((fig (layout-or-false
              (layout (apply piece-of
                             (append (list-head rows-lines 6)
                                     '("(part u :name h u2:3 - -:1)"
                                       "(score s :note-names yes :holds dash"
                                       "  :system-length 2 (group \"h\" :rows parts h))")))))))
    (test-equal "across a system break: dashes in each system, one column each"
      (list (list (list 0 1 0 "u" dung-fill #f) (dash 1 0))
            (list (dash 0 0))
            '())
      (and fig (map (lambda (s) (shapes fig s 0 0)) '(0 1 2)))))
  (let ((fig (rows-fig "(score s :note-names yes (group \"U\" :rows parts p))")))
    (test-equal ":holds none (the default): no dashes, one event per note"
      '((0 2) (2 1) (3 1))
      (and fig (map (lambda (e) (list (field e 'start) (field e 'dur)))
                    (events-of fig 0 0 0))))))

(test-group "sizes: lane_width from row labels"
  (test-equal "parts rows: the row labels count, not the notes' labels"
    "1.5em"                         ; "P": 0.52 + 1; "nang1" would be 3.6em
    (let ((fig (rows-fig "(score s :note-names yes"
                         "  (group \"U\" :rows parts (q :label \"P\") (r :label \"S\")))")))
      (and fig (field (field fig 'sizes) 'lane_width))))
  (test-equal "parts rows: the longest row label"
    "9.3em"                         ; "sangsih kantilan": 16 chars
    (let ((fig (rows-fig "(score s :note-names yes"
                         "  (group \"U\" :rows parts (p :label \"sangsih kantilan\") q))")))
      (and fig (field (field fig 'sizes) 'lane_width))))
  (test-equal "a single row only: its label \"\" counts 0"
    "1.0em"
    (let ((fig (rows-fig "(score s :note-names yes (group \"U\" :rows single q))")))
      (and fig (field (field fig 'sizes) 'lane_width))))
  (test-equal "parts rows and notes rows: the longest of all"
    "3.6em"                         ; "nang1" in the notes group
    (let ((fig (rows-fig "(score s :note-names yes"
                         "  (group \"U\" :rows parts (p :label \"P\"))"
                         "  (group \"Q\" q))")))
      (and fig (field (field fig 'sizes) 'lane_width)))))

(test-group "rows: a complete system"
  (test-equal "parts rows with :fill none, written out"
    (sys 0 5
         (hdr 'null 'null #("1" "2" "3" "4" "5"))
         #("none" "pulse" "pulse" "pulse" "pulse")
         (grp "Sung" 'null #("polos" "s")
              (voice "p"
                     (ev 0 2 0 "i" 'null dark #f)
                     (ev 2 1 0 "o'" 'null dark #f)
                     (ev 3 1 0 "e" 'null dark #f))
              (voice "s"
                     (ev 4 1 1 "u" 'null dark #f))))
    (let ((fig (rows-fig "(score s :note-names yes :fill none"
                         "  (group \"Sung\" :rows parts (p :label \"polos\") s))")))
      (and fig (system-ref fig 0))))
  (test-assert "json-string accepts a figure with dashes and fill null"
    (let ((fig (rows-fig "(score s :note-names yes :fill none :holds dash"
                         "  (group \"U\" :rows single q) (group \"P\" :rows parts p s))")))
      (and fig (string? (json-string fig))))))

;;; ------------------------------------------------------------------
;;; Pattern names (slice feat/scores-overlays; 04, "Pattern names
;;; (overlays)", "The step", "The range and systems")

(define overlay-keys '(start dur row rows text continued))

(define (ov start dur row rows text continued)
  "An overlay object, keys in the documented order."
  `((start . ,start) (dur . ,dur) (row . ,row) (rows . ,rows)
    (text . ,text) (continued . ,continued)))

(define (overlays-of fig s g) (field (group-ref fig s g) 'overlays))

;;; One-pulse notes: one column is one pulse. Every part is 8 pulses.
;;;   p:  pair (P, 0-4; inside it U 0-2, D 2-4), up (U, 4-6), down (D, 6-8)
;;;   q:  pair (0-4), up (4-6), then plain notes: the same spans as p's
;;;       up to 6
;;;   r:  silent, no spans
;;;   t1: up at 4-6 only; t2: down at 0-2 only
;;;   t3: like p, its up renamed "Rise" in its long name only
;;;   t4: up at 4-6, renamed "U'" at the use
;;; A group of p and q uses i2 o2 e2: 3 lanes.
(define overlay-lines
  '("(piece \"O\")"
    "(scale sel (ding :alias i :display \"i\") (dong :alias o :display \"o\")"
    "  (deng :alias e :display \"e\") (dung :alias u :display \"u\")"
    "  (dang :alias a :display \"a\"))"
    "(instrument u sel a1 i2 o2 e2 u2)"
    "(pattern up :instrument u :short \"U\" :long \"Up\" i2 o2)"
    "(pattern down :instrument u :short \"D\" :long \"Down\" o2 i2)"
    "(pattern pair :instrument u :short \"P\" :long \"Pair\" @up @down)"
    "(part u :name p @pair @up @down)"
    "(part u :name q @pair @up e2 e2)"
    "(part u :name r - - - - - - - -)"
    "(part u :name t1 e2 e2 e2 e2 @up e2 e2)"
    "(part u :name t2 @down e2 e2 e2 e2 e2 e2)"
    "(part u :name t3 @pair (@ up :long \"Rise\") @down)"
    "(part u :name t4 e2 e2 e2 e2 (@ up :short \"U'\") e2 e2)"))

(define (overlay-fig . score-lines)
  "The figure of the overlay piece with SCORE-LINES, or #f if it raises."
  (layout-or-false (layout (apply piece-of (append overlay-lines score-lines)))))

(define pqd-short
  (vector (ov 0 4 0 3 "P" #f) (ov 4 2 0 3 "U" #f) (ov 6 2 0 3 "D" #f)))

(test-group "overlays: names at the chosen level"
  (let ((fig (overlay-fig "(score s :pattern-names short (group \"U\" p q))")))
    (test-equal "level 0, short: one overlay per span, identical ones merged"
      pqd-short
      (and fig (overlays-of fig 0 0)))
    (test-equal "an overlay's keys in order" overlay-keys
      (and fig (keys (vector-ref (overlays-of fig 0 0) 0))))
    (test-assert "well-formed" (and fig (well-formed? fig)))
    (test-assert "json-string accepts a figure with overlays"
      (and fig (string? (json-string fig))))
    (test-assert "the notes are as without pattern names"
      (let ((plain (overlay-fig "(score s (group \"U\" p q))")))
        (and fig plain
             (equal? (field (group-ref plain 0 0) 'voices)
                     (field (group-ref fig 0 0) 'voices))))))
  (test-equal "long: the long names"
    (vector (ov 0 4 0 3 "Pair" #f) (ov 4 2 0 3 "Up" #f) (ov 6 2 0 3 "Down" #f))
    (let ((fig (overlay-fig "(score s :pattern-names long (group \"U\" p q))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal "level 1: the spans inside pair"
    (vector (ov 0 2 0 3 "U" #f) (ov 2 2 0 3 "D" #f))
    (let ((fig (overlay-fig "(score s :pattern-names short :pattern-level 1"
                            "  (group \"U\" p q))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal "a level with no spans: none" #()
    (let ((fig (overlay-fig "(score s :pattern-names short :pattern-level 2"
                            "  (group \"U\" p q))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal ":pattern-names none (the default): none" #()
    (let ((fig (overlay-fig "(score s (group \"U\" p q))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal ":pattern-names none written out: none" #()
    (let ((fig (overlay-fig "(score s :pattern-names none (group \"U\" p q))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal "a group's own options over the score's"
    ;; t3 plays only i2 and o2: two lanes.
    ;; q alone has no `down' figure.
    (list #() (vector (ov 0 4 0 3 "P" #f) (ov 4 2 0 3 "U" #f))
          (vector (ov 0 2 0 2 "Up" #f) (ov 2 2 0 2 "Down" #f)))
    (let ((fig (overlay-fig "(score s :pattern-names short"
                            "  (group \"A\" :pattern-names none p)"
                            "  (group \"B\" q)"
                            "  (group \"C\" :pattern-names long :pattern-level 1 t3))")))
      (and fig (map (lambda (g) (overlays-of fig 0 g)) '(0 1 2)))))
  (test-equal "a group whose parts have no spans: none" #()
    (let ((fig (overlay-fig "(score s :pattern-names short (group \"R\" r))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal "sorted by start, whatever the members' order"
    (vector (ov 0 2 0 3 "D" #f) (ov 4 2 0 3 "U" #f))
    (let ((fig (overlay-fig "(score s :pattern-names short (group \"T\" t1 t2))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal "short: the same short name with different long names is merged"
    ;; p and t3 play only i2 and o2: two lanes.
    (vector (ov 0 4 0 2 "P" #f) (ov 4 2 0 2 "U" #f) (ov 6 2 0 2 "D" #f))
    (let ((fig (overlay-fig "(score s :pattern-names short (group \"U\" p t3))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal "the names given at a use"
    (vector (ov 4 2 0 3 "U'" #f))
    (let ((fig (overlay-fig "(score s :pattern-names short (group \"T\" t4))")))
      (and fig (overlays-of fig 0 0)))))

(test-group "overlays: the rows they cover"
  (test-equal "notes rows: every lane" 3
    ;; p and q together play i2, o2 and e2: three lanes.
    (let ((fig (overlay-fig "(score s :pattern-names short (group \"U\" p q))")))
      (and fig (field (vector-ref (overlays-of fig 0 0) 0) 'rows))))
  (test-equal "parts rows: every member, a silent one too"
    (vector (ov 0 4 0 3 "P" #f) (ov 4 2 0 3 "U" #f) (ov 6 2 0 3 "D" #f))
    (let ((fig (overlay-fig "(score s :pattern-names short :note-names yes"
                            "  (group \"U\" :rows parts p q r))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal "parts rows: two members, two rows"
    (vector (ov 0 4 0 2 "P" #f) (ov 4 2 0 2 "U" #f) (ov 6 2 0 2 "D" #f))
    (let ((fig (overlay-fig "(score s :pattern-names short :note-names yes"
                            "  (group \"U\" :rows parts p r))")))
      (and fig (overlays-of fig 0 0))))
  (test-equal "a single row: one row"
    (vector (ov 0 4 0 1 "P" #f) (ov 4 2 0 1 "U" #f) (ov 6 2 0 1 "D" #f))
    (let ((fig (overlay-fig "(score s :pattern-names short :note-names yes"
                            "  (group \"U\" :rows single p r))")))
      (and fig (overlays-of fig 0 0)))))

(test-group "overlays across systems"
  (test-equal "cut at each boundary: the later piece continued, its text kept"
    (list (vector (ov 0 3 0 3 "P" #f))
          (vector (ov 0 1 0 3 "P" #t) (ov 1 2 0 3 "U" #f))
          (vector (ov 0 2 0 3 "D" #f)))
    (let ((fig (overlay-fig "(score s :pattern-names short :system-length 3"
                            "  (group \"U\" p q))")))
      (and fig (map (lambda (s) (overlays-of fig s 0)) '(0 1 2)))))
  (test-equal "a span ending on a boundary is not cut"
    (list (vector (ov 0 4 0 3 "P" #f))
          (vector (ov 0 2 0 3 "U" #f) (ov 2 2 0 3 "D" #f)))
    (let ((fig (overlay-fig "(score s :pattern-names short :system-length 4"
                            "  (group \"U\" p q))")))
      (and fig (map (lambda (s) (overlays-of fig s 0)) '(0 1)))))
  (test-equal "cut at several boundaries: every later piece continued"
    (list (vector (ov 0 1 0 3 "Pair" #f)) (vector (ov 0 1 0 3 "Pair" #t))
          (vector (ov 0 1 0 3 "Pair" #t)) (vector (ov 0 1 0 3 "Pair" #t)))
    (let ((fig (overlay-fig "(score s :pattern-names long :system-length 1"
                            "  (group \"U\" p q))")))
      (and fig (map (lambda (s) (overlays-of fig s 0)) '(0 1 2 3)))))
  (test-equal "a system without a span in it: no overlays"
    (list (vector (ov 0 2 0 3 "D" #f)) #())
    (let ((fig (overlay-fig "(score s :pattern-names short :system-length 4"
                            "  (group \"T\" t2))")))
      (and fig (map (lambda (s) (overlays-of fig s 0)) '(0 1))))))

;;; For the step: rh is one pulse of i2 then half a pulse of rest; outer
;;; is rh then another half pulse, 2 pulses. Part h plays outer then o2:
;;; events i2 0-1 and o2 2-3 (whole pulses), outer 0-2 at depth 0 and rh
;;; 0-3/2 at depth 1. Lanes: o2 i2.
(define (span-step-fig . score-lines)
  (layout-or-false
   (layout (apply piece-of
                  (append (list-head overlay-lines 5)
                          '("(pattern rh :instrument u :short \"R\" i2:1 -:1/2)"
                            "(pattern outer :instrument u :short \"O\" @rh -:1/2)"
                            "(part u :name h @outer o2:1)")
                          score-lines)))))

(test-group "the step: pattern-span edges at the chosen level"
  (test-equal "without pattern names, the spans don't count: 1" 1
    (let ((fig (span-step-fig "(score s (group \"H\" h))")))
      (and fig (field fig 'steps_per_pulse))))
  (let ((fig (span-step-fig "(score s :pattern-names short (group \"H\" h))")))
    (test-equal "level 0: outer's edges are whole pulses: 1" 1
      (and fig (field fig 'steps_per_pulse)))
    (test-equal "level 0: its overlay" (vector (ov 0 2 0 2 "O" #f))
      (and fig (overlays-of fig 0 0))))
  (let ((fig (span-step-fig "(score s :pattern-names short :pattern-level 1"
                            "  (group \"H\" h))")))
    (test-equal "level 1: rh ends on a half pulse: 2" 2
      (and fig (field fig 'steps_per_pulse)))
    (test-equal "level 1: its overlay in half-pulse columns"
      (vector (ov 0 3 0 2 "R" #f))
      (and fig (overlays-of fig 0 0)))
    (test-equal "level 1: the notes in half-pulse columns"
      '((0 2 1 #f) (4 2 0 #f))
      (and fig (timing (events-of fig 0 0 0))))
    (test-equal "level 1: the system is 6 columns" '((0 6))
      (and fig (starts+steps fig))))
  (test-equal "a group's :pattern-names none over the score's level: its spans don't count" 1
    (let ((fig (span-step-fig "(score s :pattern-level 1"
                              "  (group \"H\" :pattern-names none h))")))
      (and fig (field fig 'steps_per_pulse)))))

(test-group "overlays: a group built by hand"
  ;; The piece read without a score; the group carries pattern-names
  ;; short and pattern-level 0 as the reader would fill them in.
  (let* ((piece (apply piece-of overlay-lines))
         (fig (and piece
                   (layout-or-false
                    (layout-score
                     piece
                     (hand-score
                      piece
                      (list (make-group "U" "U" #f 'first-long 'notes
                                        (map (lambda (n)
                                               (cons (part-named piece n)
                                                     (symbol->string n)))
                                             '(p q))
                                        #f 'colour 'none 'short 0
                                        'by-degree 'pastel1 '() #f))))))))
    (test-equal "the overlays" pqd-short
      (and fig (overlays-of fig 0 0)))))

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
