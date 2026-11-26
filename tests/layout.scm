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
;;; examples/demos/tenzer1.nts has no written kempli part, so its generated
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
;;;   gone: a group's `scheme` is a symbol (02), and `by-pitch` is the
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
;;; `label_width`, `row_label_width`, `cell_width`, `cell_height`; each system
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
;;; in the same row for each later held column; `row_label_width` counts row
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
;;;
;;; Slice feat/scores-range (04, "Slices (iteration 2)", slice 5 and its
;;; decided bullets; 04, "The range and systems", "The step", "Groups
;;; and rows", "Pattern names (overlays)", "Sizes"): a score prints the
;;; piece from `from` to `to`, notes and overlays cut there with
;;; `continued`; systems start at every break and every `system-length`
;;; pulses from `from`; each system keeps its absolute start column and
;;; the piece's numbering; `from`, `to` and breaks count towards the
;;; step; each group's label is long or short per system as its
;;; `labels` says, and `label_width` comes from the labels printed.
;;; `hand-score` takes `#:from`, `#:to` and `#:breaks` (times), and
;;; `hand-group` `#:short` and `#:labels`, both defaulting as before.
;;; Choices made where the docs are not explicit:
;;; - Breaks and the system length combine as one set of boundaries:
;;;   every break, and every `system-length` pulses counted from `from`
;;;   (not restarted at a break), as 04 words it.
;;; - A break at the piece's start, at `from`, or outside the range
;;;   changes nothing.
;;; - A note or span wholly outside the range is not printed; one cut
;;;   at `to` keeps `continued` false (it is the first piece).
;;; - Whether a group's lanes come from the range or the whole piece is
;;;   not tested: the range tests use ranges where both agree, or don't
;;;   look at lanes and rows.
;;; - Breaks and ranges at fractional times are tested only with scores
;;;   built by hand (the reader's positions are whole pulses in every
;;;   test).

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
         (list (field e 'start) (field e 'dur) (field e 'row)
               (field e 'continued)))
       events))

(define (ev start dur lane text fill text-color continued)
  "An event object, keys in the documented order."
  `((start . ,start) (dur . ,dur) (row . ,lane) (text . ,text)
    (fill . ,fill) (text_color . ,text-color) (continued . ,continued)))

(define (lanes-of fig s g)
  (field (group-ref fig s g) 'rows))

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
                     #:key (subtitle #f) (note-label 'none)
                     (note-label-octave? #t) (scheme 'by-pitch)
                     (palette 'pastel1) (colors '()) (short label)
                     (labels 'first-long) (background 'grid))
  "A group record built by hand, as the reader fills it in (ADR 0033):
PARTS with their names as row labels, every other setting at its
default unless given."
  (make-group label short subtitle labels 'notes
              (map (lambda (p) (cons p (symbol->string (part-name p)))) parts)
              note-label note-label-octave? 'colour 'none #f 'used #t #f
              'pitch-display-name '() '()
              scheme palette colors background #f))

(define* (hand-score piece groups
                     #:key (title (piece-title piece)) (subtitle #f)
                     (caption #f) (system-length #f) (cycle-numbers? #f)
                     (pulse-numbers? #t) (numbering 'gong-last)
                     (background 'grid)
                     (cycle-label #f) (pulse-label #f) (font-size #f)
                     (cell-width "2em") (cell-height "2em")
                     (from 0) (to (piece-length piece)) (breaks '()))
  "A score record built by hand, over the whole of PIECE unless FROM and
TO (times) say otherwise."
  (make-score 'hand title subtitle caption from to
              system-length breaks cycle-numbers? pulse-numbers? numbering
              background cycle-label pulse-label font-size cell-width cell-height
              groups #f))

(define figure-keys
  '(version title subtitle steps_per_pulse sizes systems caption))
(define sizes-keys '(font_size label_width key_width row_label_width cell_width cell_height))
(define system-keys '(start steps header lines groups))
(define header-keys '(cycle_label pulse_label cycles pulses pulse_lines))
(define mark-keys '(column text))
(define group-json-keys
  '(label subtitle rows key_numbers voices annotation pulse_lines row_lines))
(define voice-keys '(name marker events))
(define event-keys '(start dur row text fill text_color continued))

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
    (and (equal? (keys g) group-json-keys)
         (every-in (field g 'rows) string?)
         (every-in (field g 'voices) voice-ok?)
         (let ((a (field g 'annotation)))
           (or (eq? a 'null) (vector? (field a 'items))))))
  (define (mark-ok? m)
    (and (equal? (keys m) mark-keys)
         (integer? (field m 'column))
         (string? (field m 'text))))
  (define (header-ok? h steps)
    (and (equal? (keys h) header-keys)
         (string-or-null? (field h 'cycle_label))
         (string-or-null? (field h 'pulse_label))
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
  `((font_size . null) (label_width . ,label-width) (key_width . "0.0em")
    (row_label_width . ,lane-width) (cell_width . "2em") (cell_height . "2em")))

(define white "#ffffff")
(define dark "#222222")
(define grey "#e6e6e6")              ; strokes (ADRs 0019, 0021, 0041)
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
   "(part :instrument ugal :name polos    1:1/2 _ 2 _ _)"
   "(part :instrument ugal :name sangsih  -:1/2 4 _ (1 3) -)"
   "(part :instrument gong                2:1/2 - - 1 -)"
   "(score tiny"
   "  (group \"Ugal\" :subtitle \"polos + sangsih\"  polos sangsih)"
   "  (group \"gong\"  gong))"
   "(score split :system-length 2"
   "  (group \"Ugal\" :subtitle \"polos + sangsih\"  polos sangsih)"
   "  (group \"gong\"  gong))"))

(define (sys start steps header lines . groups)
  `((start . ,start) (steps . ,steps) (header . ,header) (lines . ,lines)
    (groups . ,(list->vector groups))))

(define* (hdr label cycles pulses #:optional (cycle-label 'null))
  "A version 3 header: LABEL is the pulse row's label (ADR 0043)."
  `((cycle_label . ,cycle-label) (pulse_label . ,label)
    (cycles . ,cycles) (pulses . ,pulses) (pulse_lines . #t)))

(define (mark column text)
  "A cycle mark."
  `((column . ,column) (text . ,text)))

(define (grp label subtitle lanes . voices)
  "A group with no annotation row, and the default `grid' lines (ADR 0041)."
  `((label . ,label) (subtitle . ,subtitle) (rows . ,lanes)
    (key_numbers . null)
    (voices . ,(list->vector voices)) (annotation . null)
    (pulse_lines . #t) (row_lines . #t)))

(define (voice name . events)
  "A voice with no marks (marker null, ADR 0056)."
  `((name . ,name) (marker . null) (events . ,(list->vector events))))

;; Lanes of "Ugal": ding2 deng1 dong1 ding1 → i2 e1 o1 i1 (0 1 2 3).
;; No group has note names: text is null for pitched notes and strokes.
;; Lanes of "gong": G P (0 1). The built-in kempli is in no group.
(define tiny-expected
  `((version . 4)
    (title . "Tiny")
    (subtitle . null)
    (steps_per_pulse . 2)
    (sizes . ((font_size . null)
              (label_width . "10.5em")   ; "polos + sangsih": 15 chars
              (key_width . "0.0em")      ; no key numbers
              (row_label_width . "2.0em")     ; "i2": 2 chars
              (cell_width . "2em")
              (cell_height . "2em")))
    (systems
     . ,(vector
         ;; No colotomy: pulses numbered within the piece, no cycle row,
         ;; no cycle lines; a pulse line where pulses 2 and 3 start.
         (sys 0 5
              (hdr "Pulse" 'null #("1" null "2" null "3"))
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
  `((version . 4)
    (title . "Tiny")
    (subtitle . null)
    (steps_per_pulse . 2)
    (sizes . ((font_size . null)
              (label_width . "10.5em")
              (key_width . "0.0em")
              (row_label_width . "2.0em")
              (cell_width . "2em")
              (cell_height . "2em")))
    (systems
     . ,(vector
         (sys 0 4
              (hdr "Pulse" 'null #("1" null "2" null))
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
              (hdr "Pulse" 'null #("3"))
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
         "(part :instrument u :name melody  1 2 1 2 1 2 1 2 1 2)"
         "(part :instrument u :name rests   1 - - - - - - - - -)"
         "(part :instrument kajar           K - K - K - K - K -)"
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
           "(part :instrument ugal :name melody   a1 o2 i2 e2)"
           ;; kempli: the generated timekeeper, K on every pulse
           "(part :instrument ugal :name polos    i2 -  e2 -)"
           "(part :instrument ugal :name sangsih  -  u1 -  o2)"
           "(part :instrument gong                P  -  G  -)"
           "(part :instrument ugal :name silent   -  -  -  -)"
           "(score groups"
           "  (group \"melody\" melody)"
           "  (group \"Colotomic\" gong kempli)"
           "  (group \"Reyong-ish\" :subtitle \"sangsih + polos\" sangsih polos)"
           "  (group \"silent\" silent))"
           "(score short"
           "  (group \"Kotekan\" (polos :label \"P\") (sangsih :label \"S\"))"
           "  (group \"\" melody))"))))

(define tenzer
  (guard (c (#t #f)) (read-piece-file "examples/demos/tenzer1.nts")))

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
  (test-equal "version 4" 4 (field (layout tiny) 'version))
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
                      "(part :instrument u :name p 1 2 _ 1)"))
    (layout (piece-of "(piece \"P\")" "(scale s a b)" "(instrument u s a1 b1)"
                      "(part :instrument u :name p 1 2 _ 1)"
                      "(score s :note-label none :scheme by-pitch :palette pastel1"
                      "  :cell-width \"2em\" :cell-height \"2em\""
                      "  (group \"p\" :note-label none :scheme by-pitch :palette pastel1 p))"))))

;;; ------------------------------------------------------------------
;;; The score: which one, its title (04, "Public interface")

(test-group "the score"
  (let ((pc (piece-of "(piece \"Piece title\")" "(scale s a b)"
                      "(instrument u s a1 b1)"
                      "(part :instrument u :name p 1 2)"
                      "(part :instrument u :name q 2 1)"
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
                               "(instrument u s a1)" "(part :instrument u :name p 1)"
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
                           "(part :instrument u :name ab 1)"
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
     "(part :instrument reyong :name polos    1 _ 1 2 / _ 1 2 _ / 2 1 _ 2)"
     "(part :instrument reyong :name sangsih  4 3 4 _ / 3 4 _ 3 / _ 4 3 _)"
     "(score s (group \"Reyong\" :subtitle \"polos + sangsih\" polos sangsih))"))

  (test-equal "no groups: 1.5em and 1.0em"
    (v2-sizes "1.5em" "1.0em")
    (sizes-of "(piece \"Empty\")"))

  (test-equal "one-letter label and stroke: \"Pulse\" sets 4.5em, 1.5em"
    (v2-sizes "4.5em" "1.5em") ; the default "Pulse" label (5 chars) is the widest (ADR 0039)
    (sizes-of "(piece \"P\")"
              "(strokes k-strokes K)"
              "(instrument kajar k-strokes K)"
              "(part :instrument kajar :name x K -)"))

  (test-equal "lane label of 4 chars: 3.08 rounds up to 3.1em"
    "3.1em"
    (field (sizes-of "(piece \"P\")"
                     "(scale s (a :display \"abc\"))"
                     "(instrument u s a1)"
                     "(part :instrument u :name x 1)")
           'row_label_width))

  (test-equal "lane label of 7 chars: 4.64 rounds down to 4.6em"
    "4.6em"
    (field (sizes-of "(piece \"P\")"
                     "(scale s (a :display \"abcdef\"))"
                     "(instrument u s a1)"
                     "(part :instrument u :name x 1)")
           'row_label_width))

  (test-equal "lane label of 9 chars: 5.68 rounds up to 5.7em"
    "5.7em"
    (field (sizes-of "(piece \"P\")"
                     "(scale s (a :display \"abcdefgh\"))"
                     "(instrument u s a1)"
                     "(part :instrument u :name x 1)")
           'row_label_width))

  (test-equal "degree name without display: \"dong2\" → 3.6em"
    "3.6em"
    (field (sizes-of "(piece \"P\")"
                     "(scale s ding dong)"
                     "(instrument u s ding2 dong2)"
                     "(part :instrument u :name x 2)")
           'row_label_width))

  ;; A one-row group: its subtitle follows the label, "Bb", two spaces
  ;; and the 20 characters (feat/targets).
  (test-equal "a subtitle longer than every label counts (24 chars → 15.9em)"
    "15.9em"
    (field (sizes-of "(piece \"P\")"
                     "(strokes k-strokes K)"
                     "(instrument kempli k-strokes K)"
                     "(part :instrument kempli :name a K)"
                     "(part :instrument kempli :name b K)"
                     "(score s (group \"a\" a)"
                     "  (group \"Bb\" :subtitle \"twenty chars long xx\" b))")
           'label_width))

  (test-equal "longest label over all groups (the last one here)"
    "6.3em"                             ; "Eight ch": 8 chars
    (field (sizes-of "(piece \"P\")"
                     "(strokes k-strokes K)"
                     "(instrument kempli k-strokes K)"
                     "(part :instrument kempli :name a K)"
                     "(part :instrument kempli :name b K)"
                     "(score s (group \"a\" a) (group \"Eight ch\" b))")
           'label_width))

  (test-equal "longest lane label over all groups (not the first)"
    "4.6em"                             ; "abcdef1" in group y
    (field (sizes-of "(piece \"P\")"
                     "(scale s a (b :display \"abcdef\"))"
                     "(instrument u s a1 b1)"
                     "(part :instrument u :name x 1)"
                     "(part :instrument u :name y 2)")
           'row_label_width))

  (test-equal "characters, not bytes: \"Kempli · Gong\" → 9.3em"
    "9.3em"
    (field (sizes-of "(piece \"P\")"
                     "(strokes k-strokes K)"
                     "(instrument kempli k-strokes K)"
                     "(part :instrument kempli :name a K)"
                     "(score s (group \"Kempli · Gong\" a))")
           'label_width))

  (test-equal "a group of rests adds no lane label"
    (v2-sizes "4.5em" "1.0em") ; the default "Pulse" label (5 chars) is the widest (ADR 0039)
    (sizes-of "(piece \"P\")"
              "(scale s a)"
              "(instrument u s a1)"
              "(part :instrument u :name ab - -)"))

  (test-equal "only the score's groups count, not every part"
    "2.7em"                             ; "ab", not "a much longer name"
    (field (sizes-of "(piece \"P\")"
                     "(scale s a)"
                     "(instrument u s a1)"
                     "(part :instrument u :name ab 1)"
                     "(part :instrument u :name a-much-longer-name 1)"
                     "(score s :pulse-label \"\" (group \"ab\" ab))")
           'label_width))

  (test-equal "an empty label: 1.5em"
    "1.5em"
    (field (sizes-of "(piece \"P\")" "(scale s a)" "(instrument u s a1)"
                     "(part :instrument u :name ab 1)"
                     "(score s :pulse-label \"\" (group \"\" ab))")
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
    (let ((s (tiny-sizes ":cell-width \"5em\"" ":cell-height \"5em\""
                         ":pulse-label \"\"")))
      (list (field s 'label_width) (field s 'row_label_width))))
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
                                    "(part :instrument u :name p 1:1/4 _ _ _ -:15)"))))

  (test-equal "a piece of length 0 (no parts) has no systems"
    #()
    (field (layout (piece-of "(piece \"Empty\")")) 'systems))
  (test-equal "a piece of length 0 with a group has no systems"
    #()
    (field (layout (piece-of "(piece \"Zero\")"
                             "(scale s a)"
                             "(instrument u s a1)"
                             "(part :instrument u :name p /)"))
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
                                  "(part :instrument u :name two - - - 1 _ _ _ _ _ - - - - - - -)"))
                       0 0 0))))

;;; :system-length (04, "The range and systems")

(define held-piece
  ;; 16 pulses; a note held from pulse 3 for 6 pulses (3 to 9).
  (piece-of "(piece \"P\")"
            "(scale s a b)"
            "(instrument u s a1 b1)"
            "(part :instrument u :name p - - - 1 _ _ _ _ _ - - - - - - -)"
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
                             "(instrument u s a1)" "(part :instrument u :name p /)"
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
        (map (lambda (e) (list (field e 'row) (event-look e)))
             (append (events-of fig 0 0 0) (events-of fig 1 0 0)
                     (events-of fig 2 0 0)))))))
  (test-equal "a note ending on a boundary is not cut"
    '(((2 2 0 #f)) ())
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a)"
                                 "(instrument u s a1)"
                                 "(part :instrument u :name p - - 1 _ - - - -)"
                                 "(score s :system-length 4 (group \"p\" p))"))))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1))))
  (test-equal "a note starting on a boundary is not cut"
    '(() ((0 2 0 #f)))
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a)"
                                 "(instrument u s a1)"
                                 "(part :instrument u :name p - - - - 1 _ - -)"
                                 "(score s :system-length 4 (group \"p\" p))"))))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1))))
  (test-equal "a chord crossing a boundary is cut note by note"
    ;; lanes: b1 (0), a1 (1); the chord sounds from 1 to 4
    '(((1 1 0 #f) (1 1 1 #f)) ((0 2 0 #t) (0 2 1 #t)))
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a b)"
                                 "(instrument u s a1 b1)"
                                 "(part :instrument u :name p - (1 2) _ _)"
                                 "(score s :system-length 2 (group \"p\" p))"))))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1))))
  (test-equal "quarter pulses: a cut note in columns"
    ;; k = 4; systems of 1 pulse are 4 columns; the note from 3/4 to 3/2
    '((0 4) (4 4))
    (starts+steps (layout (piece-of "(piece \"P\")" "(scale s a)"
                                    "(instrument u s a1)"
                                    "(part :instrument u :name p -:3/4 1:1/4 _ _ -:1/2)"
                                    "(score s :system-length 1 (group \"p\" p))"))))
  (test-equal "quarter pulses: the note is cut at column 4"
    '(((3 1 0 #f)) ((0 2 0 #t)))
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a)"
                                 "(instrument u s a1)"
                                 "(part :instrument u :name p -:3/4 1:1/4 _ _ -:1/2)"
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
                (string-append "(part :instrument u :name p" (number->string i) " " t ")"))
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
  (test-equal "lanes are note-row-label of group-row-keys"
    (map (lambda (g)
           (list->vector
            (map (lambda (note)
                   (note-row-label (part-instrument (car (car (group-members g))))
                               note))
                 (group-row-keys g))))
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
                                  "(part :instrument u :name p 1 _ _ 2 1 _ -)"))
                       0 0 0)))
  (test-equal "a chord: one event per note, same start and dur, by lane"
    ;; lanes: b1 (0), a1 (1); chord (1 2) at 0 for 2, then 2 at 2
    '((0 2 0 #f) (0 2 1 #f) (2 1 0 #f))
    (timing (events-of (layout
                        (piece-of "(piece \"P\")"
                                  "(scale s a b)"
                                  "(instrument u s a1 b1)"
                                  "(part :instrument u :name p (1 2) _ 2)"))
                       0 0 0)))
  (test-equal "a chord written high-to-low is still sorted by lane"
    '((0 1 0 #f) (0 1 1 #f) (0 1 2 #f))
    (timing (events-of (layout
                        (piece-of "(piece \"P\")"
                                  "(scale s a b c)"
                                  "(instrument u s a1 b1 c1)"
                                  "(part :instrument u :name p (c1 a1 b1))"))
                       0 0 0)))
  (test-equal "a stroke chord: lanes in instrument order"
    '((0 1 0 #f) (0 1 1 #f) (1 1 2 #f))
    (timing (events-of (layout
                        (piece-of "(piece \"P\")"
                                  "(strokes k dag dug du)"
                                  "(instrument kendang k dag dug du)"
                                  "(part :instrument kendang :name p (dug dag) du)"))
                       0 0 0)))

  (test-equal "the default score shows no names: text null, colours kept"
    (list (ev 0 1 0 'null dung-fill dark #f)
          (ev 1 1 1 'null dang-fill dark #f))
    (events-of (layout (selisir-piece "(instrument u selisir a1 u2)"
                                      "(part :instrument u :name p u2 a1)"))
               0 0 0))
  (test-equal "strokes show no name by default either: grey boxes, text null"
    (list (ev 0 1 0 'null grey dark #f))
    (events-of (layout
                (piece-of "(piece \"P\")"
                          "(strokes k dag)"
                          "(instrument kendang k dag)"
                          "(part :instrument kendang :name p dag)"))
               0 0 0))
  (test-equal "default colours, hard-coded: selisir degrees in pastel1"
    (list (ev 0 1 0 'null dung-fill dark #f)
          (ev 1 1 1 'null deng-fill dark #f)
          (ev 2 1 2 'null dong-fill dark #f)
          (ev 3 1 3 'null ding-fill dark #f)
          (ev 4 1 4 'null dang-fill dark #f))
    (events-of (layout (selisir-piece "(instrument u selisir a1 i2 o2 e2 u2)"
                                      "(part :instrument u :name p u2 e2 o2 i2 a1)"))
               0 0 0))
  (test-equal "degree without :display: the lane label is the degree name"
    #("dong1")
    (lanes-of (layout (piece-of "(piece \"P\")"
                                "(scale s ding dong)"
                                "(instrument u s ding1 dong1)"
                                "(part :instrument u :name p 2)"))
              0 0))
  (test-equal "a selisir with :display \"i\" labels its lane \"i1\", not \"ding1\""
    #("i1")
    (lanes-of (layout
               (piece-of "(piece \"P\")"
                         "(scale selisir (ding :display \"i\") dong)"
                         "(instrument u selisir ding1 dong1)"
                         "(part :instrument u :name p ding1)"))
              0 0))
  (test-equal "strokes: grey, text null, text colour #222222 (ADR 0019)"
    (list (ev 0 1 0 'null grey dark #f)
          (ev 1 1 1 'null grey dark #f))
    (events-of (layout
                (piece-of "(piece \"P\")"
                          "(strokes k (dag :display \"D\") dug du)"
                          "(instrument kendang k dag dug du)"
                          "(part :instrument kendang :name p dag dug)"))
               0 0 0))
  (test-equal "strokes: lanes show the display form"
    #("D" "dug")
    (lanes-of (layout
               (piece-of "(piece \"P\")"
                         "(strokes k (dag :display \"D\") dug du)"
                         "(instrument kendang k dag dug du)"
                         "(part :instrument kendang :name p dag dug)"))
              0 0))

  (test-equal "tenzer1: one default group per part, in part order"
    '("ugal" "gong" "kempli")
    (group-labels (layout tenzer) 0))
  (test-equal "tenzer1: lanes of the three groups"
    ;; The gongs from the gilak colotomy: G GL P (no T).
    (list #("e2" "o2" "i2" "a1") #("G" "GL" "P") #("K"))
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
          (ev 4 1 1 'null grey dark #f)
          (ev 5 1 2 'null grey dark #f)
          (ev 7 1 2 'null grey dark #f)
          (ev 8 1 0 'null grey dark #f))
    (events-of (layout tenzer) 0 1 0)))

;;; ------------------------------------------------------------------
;;; :note-names (04, "Note text, fill and holds"; ADR 0031)

(define names-lines
  '("(instrument u selisir a1 i2 o2 e2 u2)"
    "(strokes k (dag :display \"D\") dug du)"
    "(instrument kendang k dag dug du)"
    "(part :instrument u :name p u2 e2 o2 i2 a1)"
    "(part :instrument kendang :name d dag dug - - -)"))

(define (names-piece . score-lines)
  (apply selisir-piece (append names-lines score-lines)))

(define (texts fig s g v)
  (map (lambda (e) (field e 'text)) (events-of fig s g v)))

(test-group ":note-names"
  (test-equal "score :note-label pitch-display-name :note-label-octave no: pitched notes show their degree's display form"
    (list (ev 0 1 0 "u" dung-fill dark #f)
          (ev 1 1 1 "e" deng-fill dark #f)
          (ev 2 1 2 "o" dong-fill dark #f)
          (ev 3 1 3 "i" ding-fill dark #f)
          (ev 4 1 4 "a" dang-fill dark #f))
    (events-of (layout (names-piece "(score s :note-label pitch-display-name :note-label-octave no"
                                    "  (group \"U\" p) (group \"K\" d))"))
               0 0 0))
  (test-equal "score :note-label pitch-display-name :note-label-octave no: strokes show their display form, still grey"
    (list (ev 0 1 0 "D" grey dark #f)
          (ev 1 1 1 "dug" grey dark #f))
    (events-of (layout (names-piece "(score s :note-label pitch-display-name :note-label-octave no"
                                    "  (group \"U\" p) (group \"K\" d))"))
               0 1 0))
  (test-equal ":note-label none on the score: null everywhere"
    '((null null null null null) (null null))
    (let ((fig (layout (names-piece "(score s :note-label none"
                                    "  (group \"U\" p) (group \"K\" d))"))))
      (list (texts fig 0 0 0) (texts fig 0 1 0))))
  (test-equal "a score without :note-names: null (the default is no)"
    '((null null null null null) (null null))
    (let ((fig (layout (names-piece "(score s (group \"U\" p) (group \"K\" d))"))))
      (list (texts fig 0 0 0) (texts fig 0 1 0))))
  (test-equal "on one group only: that group shows names"
    '((null null null null null) ("D" "dug"))
    (let ((fig (layout (names-piece "(score s (group \"U\" p)"
                                    "  (group \"K\" :note-label pitch-display-name :note-label-octave no d))"))))
      (list (texts fig 0 0 0) (texts fig 0 1 0))))
  (test-equal "a group's no overrides the score's yes"
    '(("u" "e" "o" "i" "a") (null null))
    (let ((fig (layout (names-piece "(score s :note-label pitch-display-name :note-label-octave no (group \"U\" p)"
                                    "  (group \"K\" :note-label none d))"))))
      (list (texts fig 0 0 0) (texts fig 0 1 0))))
  (test-equal "names do not change the colours"
    (map (lambda (e) (list (field e 'fill) (field e 'text_color)))
         (events-of (layout (names-piece "(score s (group \"U\" p) (group \"K\" d))"))
                    0 0 0))
    (map (lambda (e) (list (field e 'fill) (field e 'text_color)))
         (events-of (layout (names-piece "(score s :note-label pitch-display-name :note-label-octave no"
                                         "  (group \"U\" p) (group \"K\" d))"))
                    0 0 0)))
  (test-equal "a degree without :display shows its name"
    '("ding" "dong")
    (texts (layout (piece-of "(piece \"P\")" "(scale s ding dong)"
                             "(instrument u s ding1 dong2)"
                             "(part :instrument u :name p 1 2)"
                             "(score s :note-label pitch-display-name :note-label-octave no (group \"p\" p))"))
           0 0 0))
  (test-equal "a held note shows its name once, on its one event"
    '((0 3 0 #f "u"))
    (map (lambda (e) (list (field e 'start) (field e 'dur) (field e 'row)
                           (field e 'continued) (field e 'text)))
         (events-of (layout (selisir-piece "(instrument u selisir u2)"
                                           "(part :instrument u :name p u2 _ _)"
                                           "(score s :note-label pitch-display-name :note-label-octave no (group \"p\" p))"))
                    0 0 0)))
  (test-equal "a cut note shows its name again in the next system"
    '(("u") ("u"))
    (let ((fig (layout (selisir-piece "(instrument u selisir u2)"
                                      "(part :instrument u :name p - u2 _ -)"
                                      "(score s :note-label pitch-display-name :note-label-octave no :system-length 2"
                                      "  (group \"p\" p))"))))
      (list (texts fig 0 0 0) (texts fig 1 0 0))))
  (test-equal "a chord: each note shows its own name"
    '("o" "i")
    (texts (layout (selisir-piece "(instrument u selisir i2 o2)"
                                  "(part :instrument u :name p (i2 o2))"
                                  "(score s :note-label pitch-display-name :note-label-octave no (group \"p\" p))"))
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
                                                   #:note-label 'pitch-display-name
                                                   #:note-label-octave? #f))))
                    0 0 0))))

;;; ------------------------------------------------------------------
;;; One style per group, from its scheme, palette and colors (04, "Note
;;; style"; ADR 0032)

(define colour-lines
  '("(instrument u selisir i2 o2)"
    "(part :instrument u :name a i2 o2)"
    "(part :instrument u :name b i2 o2)"
    "(part :instrument u :name c i2 o2)"
    "(part :instrument u :name d i2 o2)"))

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
    (list (list 'null "#e41a1c" white) (list 'null "#377eb8" dark))
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
  (test-equal ":scheme by-pitch is the default"
    (looks-of (layout (colour-piece "(score s (group \"a\" a))")) 0)
    (looks-of (layout (colour-piece "(score s :scheme by-pitch"
                                    "  (group \"a\" :scheme by-pitch a))"))
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
      (style-looks pc #:palette 'set1 #:pitch-colors '((dong . "#000000")))
      (looks-of fig 0))
    (test-equal "a group's :palette overrides the score's; the score's :colors stay"
      (style-looks pc #:palette 'dark2 #:pitch-colors '((dong . "#000000")))
      (looks-of fig 1))
    (test-equal "a group's :colors replace the score's; the score's palette stays"
      (style-looks pc #:palette 'set1 #:pitch-colors '((ding . "#ffffff")))
      (looks-of fig 2))
    (test-equal "a group's :colors, hard-coded: ding white with dark text, dong set1"
      (list (list 'null "#ffffff" dark) (list 'null "#377eb8" dark))
      (looks-of fig 2))
    (test-equal "a group's list palette"
      (style-looks pc #:palette '("#111111" "#eeeeee")
                   #:pitch-colors '((dong . "#000000")))
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
    (list (list "i" "#e41a1c" white) (list "o" "#377eb8" dark))
    (looks-of (layout (colour-piece "(score s :note-label pitch-display-name :note-label-octave no"
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
          (let ((style (make-style #:pitch-colors '((dang . "#123456")))))
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
                               " (part :instrument gong -:" (number->string (- cycle 1))
                               " G:1))")
                (string-append "(part :instrument u :name m " tokens ")"))
          (if score?
              (list (string-append "(score s " options " (group \"m\" m))"))
              '()))))

(define (notes n)
  "N one-pulse notes, as part tokens."
  (string-join (map (lambda (i) (if (even? i) "1" "2")) (iota n)) " "))

(define (header-of fig s) (field (system-ref fig s) 'header))
(define (pulses-of fig s) (field (header-of fig s) 'pulses))
(define (cycles-of fig s) (field (header-of fig s) 'cycles))
(define (label-of fig s) (field (header-of fig s) 'pulse_label))
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
    (let ((s (tiny-sizes ":font-size \"12pt\"" ":pulse-label \"\"")))
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
  (test-equal "tenzer1: 8, then 1 to 8 (gilak, a one-pulse pickup)"
    (list->vector (map number->string (cons 8 (iota 8 1))))
    (pulses-of (layout tenzer) 0))
  (test-equal "half pulses (tiny)"
    #("1" null "2" null "3")
    (pulses-of (layout tiny) 0)))

(test-group "header: cycle numbers"
  (test-equal "no pickup: cycle 1 on the first column, cycle 2 on the fifth"
    (marks '(0 "1") '(4 "2"))
    (cycles-of (layout (colo-piece (notes 8))) 0))
  (test-equal "a pickup of 1: the pickup is cycle 0; cycle 1 after it"
    (marks '(0 "0") '(1 "1") '(5 "2"))
    (cycles-of (layout (colo-piece (notes 9) #:pickup 1)) 0))
  (test-equal "quarter pulses: the mark is at the cycle's first column"
    (marks '(0 "0") '(4 "1"))
    (cycles-of (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2" #:pickup 1)) 0))
  (test-equal "the default score with a colotomy shows them"
    (marks '(0 "0") '(1 "1"))
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
    ;; tenzer1 has a colotomy now; ten-steps has none.
    (let ((pc (ten-steps)))
      (cycles-of (layout-score
                  pc
                  (hand-score pc
                              (list (hand-group "m"
                                                (list (part-named pc 'melody))))
                              #:cycle-numbers? #t))
                 0)))
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
  (test-equal "no :pulse-label: \"Pulse\" (ADR 0039)" "Pulse" (label-of (layout (ten-steps)) 0))
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
      (list (marks '(0 "0") '(1 "1")) (marks '(2 "2")) #())
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
  (test-equal "every group's annotation is null without an annotation row"
    '(null null null null)
    (map (lambda (g) (field g 'annotation))
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
    "(part :instrument u :name p i2:2 o2:1 e2 -)"
    "(part :instrument u :name q - a1 _ (i2 o2) -)"
    "(part :instrument u :name r - - - - -)"
    "(part :instrument u :name s - - - - u2)"
    "(part :instrument kendang :name d dag dug _ - -)"))

(define (rows-piece . score-lines)
  (apply piece-of (append rows-lines score-lines)))

(define (rows-fig . score-lines)
  "The figure of rows-piece with SCORE-LINES, or #f if it raises."
  (layout-or-false (layout (apply rows-piece score-lines))))

(define (shape e)
  "An event as (start dur lane text fill continued): its text_color
left out, for the \"-\" events of :holds dash, whose colour 04 doesn't
give."
  (map (lambda (k) (field e k)) '(start dur row text fill continued)))

(define (shapes fig s g v) (map shape (events-of fig s g v)))

(define (dash start lane) (list start 1 lane "-" 'null #f))

(test-group ":rows parts"
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
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
  (let ((fig (rows-fig "(score s :rows parts :note-label pitch-display-name :note-label-octave no"
                       "  (group \"K\" (q :label \"Q\") (p :label \"P\")))")))
    (test-equal "the score's :rows parts; rows follow the members' order"
      (list #("Q" "P") '(0 0) '(1 1 1))
      (and fig (list (lanes-of fig 0 0)
                     (map (lambda (e) (field e 'row)) (events-of fig 0 0 0))
                     (map (lambda (e) (field e 'row)) (events-of fig 0 0 1))))))
  (let ((fig (rows-fig "(score s :rows parts :note-label pitch-display-name :note-label-octave no"
                       "  (group \"U\" :rows notes p) (group \"K\" d))")))
    (test-equal "a group's :rows notes over the score's parts: note lanes"
      #("e2" "o2" "i2")
      (and fig (lanes-of fig 0 0)))
    (test-equal "strokes on a parts row: one row, damped names"
      ;; A stroke is one column wide (ADR 0042); "dug" still lasts 2.
      (list #("d") (list (ev 0 1 0 "d" grey dark #f) (ev 1 1 0 "dug" grey dark #f)))
      (and fig (list (lanes-of fig 0 1) (events-of fig 0 1 0))))))

(test-group ":rows compact"
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"U\" :rows compact p s))")))
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
  (let ((fig (rows-fig "(score s :rows compact :note-label pitch-display-name :note-label-octave no (group \"Q\" q))")))
    (test-equal "the score's :rows compact; a chord is one event"
      (list #("") (list (ev 1 2 0 "nang" dang-fill dark #f)
                        (ev 3 1 0 "i' o'" ding-fill dark #f)))
      (and fig (list (lanes-of fig 0 0) (events-of fig 0 0 0))))))

(test-group "damped and open names"
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no (group \"U\" p) (group \"K\" d))")))
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
                                       '("(part :instrument u :name f o2:1/2 i2 _ - -:1 - -)"
                                         "(score s :note-label pitch-display-name :note-label-octave no (group \"f\" f))")))))))
      (and fig (map (lambda (e) (list (field e 'text) (field e 'dur)))
                    (events-of fig 0 0 0)))))
  (test-equal "a note cut by a system break counts its whole length"
    '((("i" #f)) (("i" #t)))
    (let ((fig (layout-or-false
                (layout (apply piece-of
                               (append (list-head rows-lines 6)
                                       '("(part :instrument u :name h i2:2 - - -)"
                                         "(score s :note-label pitch-display-name :note-label-octave no :system-length 1"
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
                                       '("(part :instrument u :name h - o2 - - -)"
                                         "(score s :note-label pitch-display-name :note-label-octave no :system-length 2"
                                         "  (group \"h\" h))")))))))
      (and fig (texts fig 0 0 0)))))

(test-group ":fill none"
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :fill none"
                       "  (group \"U\" p) (group \"K\" d))")))
    (test-equal "pitched notes: fill null, text as before"
      (list (ev 0 2 2 "i" 'null dark #f)
            (ev 2 1 1 "o'" 'null dark #f)
            (ev 3 1 0 "e" 'null dark #f))
      (and fig (events-of fig 0 0 0)))
    (test-equal "strokes: fill null too"
      '((0 1 0 "d" null #f) (1 1 1 "dug" null #f))   ; one column (ADR 0042)
      (and fig (shapes fig 0 1 0)))
    (test-assert "well-formed" (and fig (well-formed? fig))))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"U\" :fill none p) (group \"K\" d))")))
    (test-equal "on one group only: the other keeps its colours"
      (list '(null null null) (list grey grey))
      (and fig (list (map (lambda (e) (field e 'fill)) (events-of fig 0 0 0))
                     (map (lambda (e) (field e 'fill)) (events-of fig 0 1 0))))))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :fill none"
                       "  (group \"U\" :rows compact q))")))
    (test-equal "with :rows compact: a chord with fill null"
      (list (ev 1 2 0 "nang" 'null dark #f) (ev 3 1 0 "i' o'" 'null dark #f))
      (and fig (events-of fig 0 0 0)))))

(test-group ":holds dash"
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :holds dash"
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
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :holds dash (group \"U\" p))")))
    (test-equal "notes rows: the dash in the note's lane"
      (list (list 0 1 2 "i" ding-fill #f) (dash 1 2)
            (list 2 1 1 "o'" dong-fill #f) (list 3 1 0 "e" deng-fill #f))
      (and fig (shapes fig 0 0 0))))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :holds dash"
                       "  (group \"K\" :rows compact d))")))
    (test-equal "strokes on a single row"
      ;; Strokes are not held: no dash (ADR 0042).
      (list (list 0 1 0 "d" grey #f) (list 1 1 0 "dug" grey #f))
      (and fig (shapes fig 0 0 0))))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :holds dash :fill none"
                       "  (group \"U\" :rows compact q))")))
    (test-equal "with :fill none: the note and its dashes all fill null"
      (list (list 1 1 0 "nang" 'null #f) (dash 2 0) (list 3 1 0 "i' o'" 'null #f))
      (and fig (shapes fig 0 0 0))))
  (let ((fig (layout-or-false
              (layout (apply piece-of
                             (append (list-head rows-lines 6)
                                     '("(part :instrument u :name h u2:3 - -:1)"
                                       "(score s :note-label pitch-display-name :note-label-octave no :holds dash"
                                       "  :system-length 2 (group \"h\" :rows parts h))")))))))
    (test-equal "across a system break: dashes in each system, one column each"
      (list (list (list 0 1 0 "u" dung-fill #f) (dash 1 0))
            (list (dash 0 0))
            '())
      (and fig (map (lambda (s) (shapes fig s 0 0)) '(0 1 2)))))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no (group \"U\" :rows parts p))")))
    (test-equal ":holds none (the default): no dashes, one event per note"
      '((0 2) (2 1) (3 1))
      (and fig (map (lambda (e) (list (field e 'start) (field e 'dur)))
                    (events-of fig 0 0 0))))))

(test-group "sizes: row_label_width from row labels"
  (test-equal "parts rows: the row labels count, not the notes' labels"
    "1.5em"                         ; "P": 0.52 + 1; "nang1" would be 3.6em
    (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                         "  (group \"U\" :rows parts (q :label \"P\") (r :label \"S\")))")))
      (and fig (field (field fig 'sizes) 'row_label_width))))
  (test-equal "parts rows: the longest row label"
    "9.3em"                         ; "sangsih kantilan": 16 chars
    (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                         "  (group \"U\" :rows parts (p :label \"sangsih kantilan\") q))")))
      (and fig (field (field fig 'sizes) 'row_label_width))))
  (test-equal "a single row only: its label \"\" counts 0"
    "1.0em"
    (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no (group \"U\" :rows compact q))")))
      (and fig (field (field fig 'sizes) 'row_label_width))))
  (test-equal "parts rows and notes rows: the longest of all"
    "3.6em"                         ; "nang1" in the notes group
    (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                         "  (group \"U\" :rows parts (p :label \"P\"))"
                         "  (group \"Q\" q))")))
      (and fig (field (field fig 'sizes) 'row_label_width)))))

(test-group "rows: a complete system"
  (test-equal "parts rows with :fill none, written out"
    (sys 0 5
         (hdr "Pulse" 'null #("1" "2" "3" "4" "5"))
         #("none" "pulse" "pulse" "pulse" "pulse")
         (grp "Sung" 'null #("polos" "s")
              (voice "p"
                     (ev 0 2 0 "i" 'null dark #f)
                     (ev 2 1 0 "o'" 'null dark #f)
                     (ev 3 1 0 "e" 'null dark #f))
              (voice "s"
                     (ev 4 1 1 "u" 'null dark #f))))
    (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :fill none"
                         "  (group \"Sung\" :rows parts (p :label \"polos\") s))")))
      (and fig (system-ref fig 0))))
  (test-assert "json-string accepts a figure with dashes and fill null"
    (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :fill none :holds dash"
                         "  (group \"U\" :rows compact q) (group \"P\" :rows parts p s))")))
      (and fig (string? (json-string fig))))))

;;; ------------------------------------------------------------------
;;; Pattern names over the notes (overlays) were removed in
;;; feat/collapsed-annotation (ADR 0057); the annotation row's tests,
;;; below, replace them. The piece and the step test remain.

(define overlay-lines
  '("(piece \"O\")"
    "(scale sel (ding :alias i :display \"i\") (dong :alias o :display \"o\")"
    "  (deng :alias e :display \"e\") (dung :alias u :display \"u\")"
    "  (dang :alias a :display \"a\"))"
    "(instrument u sel a1 i2 o2 e2 u2)"
    "(pattern up :instrument u :short \"U\" :long \"Up\" i2 o2)"
    "(pattern down :instrument u :short \"D\" :long \"Down\" o2 i2)"
    "(pattern pair :instrument u :short \"P\" :long \"Pair\" @up @down)"
    "(part :instrument u :name p @pair @up @down)"
    "(part :instrument u :name q @pair @up e2 e2)"
    "(part :instrument u :name r - - - - - - - -)"
    "(part :instrument u :name t1 e2 e2 e2 e2 @up e2 e2)"
    "(part :instrument u :name t2 @down e2 e2 e2 e2 e2 e2)"
    "(part :instrument u :name t3 @pair (@ up :long \"Rise\") @down)"
    "(part :instrument u :name t4 e2 e2 e2 e2 (@ up :short \"U'\") e2 e2)"))

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
                            "(part :instrument u :name h @outer o2:1)")
                          score-lines)))))

(test-group "the step: the annotation row's pattern-span edges"
  (test-equal "without an annotation row, the spans don't count: 1" 1
    (let ((fig (span-step-fig "(score s (group \"H\" h))")))
      (and fig (field fig 'steps_per_pulse))))
  (test-equal "level 0: outer's edges are whole pulses: 1" 1
    (let ((fig (span-step-fig "(score s (group \"H\" :annotation-part h h))")))
      (and fig (field fig 'steps_per_pulse))))
  (let ((fig (span-step-fig "(score s (group \"H\" :annotation-part h"
                            "  :annotation-level 1 h))")))
    (test-equal "level 1: rh ends on a half pulse: 2" 2
      (and fig (field fig 'steps_per_pulse)))
    (test-equal "level 1: the notes in half-pulse columns"
      '((0 2 1 #f) (4 2 0 #f))
      (and fig (timing (events-of fig 0 0 0))))
    (test-equal "level 1: the system is 6 columns" '((0 6))
      (and fig (starts+steps fig)))))

;;; ------------------------------------------------------------------
;;; The range, breaks and labels (slice feat/scores-range; 04, "The
;;; range and systems", "The step", "Groups and rows", "Sizes")

(define (labels-by-system fig)
  "Each system's group labels, as a list of lists."
  (map (lambda (s) (map (lambda (g) (field g 'label))
                        (vector->list (field s 'groups))))
       (systems fig)))

(define (label-width fig) (field (field fig 'sizes) 'label_width))

;;; held-piece's note (3 to 9, 16 pulses) under different ranges.
(define range-held
  (piece-of "(piece \"P\")"
            "(scale s a b)"
            "(instrument u s a1 b1)"
            "(part :instrument u :name p - - - 1 _ _ _ _ _ - - - - - - -)"
            "(score inside :from 5 :to 8 (group \"p\" p))"
            "(score tail :from 1 :to 6 (group \"p\" p))"
            "(score both :from 5 :to 6 (group \"p\" p))"
            "(score split :from 5 :to 12 :system-length 2 (group \"p\" p))"
            "(score before :from 11 (group \"p\" p))"))

(test-group "range: systems and events"
  (let ((fig (layout-or-false (layout (ten-score ":from 3 :to 6")))))
    (test-equal "one system, at its absolute start column" '((2 4))
      (starts+steps fig))
    (test-equal "pulse numbers keep the piece's numbering" #("3" "4" "5" "6")
      (and fig (pulses-of fig 0)))
    (test-equal "lines: none at the first column, pulse after"
      #("none" "pulse" "pulse" "pulse")
      (and fig (lines-of fig 0)))
    (test-equal "events in the range, relative to the system"
      '((0 1 1 #f) (1 1 0 #f) (2 1 1 #f) (3 1 0 #f))
      (and fig (timing (events-of fig 0 0 0))))
    (test-equal "kajar: only its strokes in the range" '((0 1 0 #f) (2 1 0 #f))
      (and fig (timing (events-of fig 0 2 0))))
    (test-equal "a part with no event in the range: its voice, no events" '()
      (and fig (timing (events-of fig 0 1 0))))
    (test-equal "every group, in the score's order" '(("melody" "rests" "kajar"))
      (and fig (labels-by-system fig)))
    (test-assert "well-formed" (and fig (well-formed? fig))))
  (test-equal "a note that started before :from arrives cut, continued"
    '((0 4 0 #t))
    (timing (events-of (layout-named range-held 'inside) 0 0 0)))
  (test-equal "a note running past :to is cut there"
    '((3 3 0 #f))
    (timing (events-of (layout-named range-held 'tail) 0 0 0)))
  (test-equal "cut at both ends" '((0 2 0 #t))
    (timing (events-of (layout-named range-held 'both) 0 0 0)))
  (test-equal "a note ending before :from is not printed" '()
    (timing (events-of (layout-named range-held 'before) 0 0 0)))
  (test-equal "range and :system-length: systems from :from"
    '((4 2) (6 2) (8 2) (10 2))
    (starts+steps (layout-named range-held 'split)))
  (test-equal "range and :system-length: the note cut at :from and each boundary"
    '(((0 2 0 #t)) ((0 2 0 #t)) ((0 1 0 #t)) ())
    (let ((fig (layout-named range-held 'split)))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1 2 3))))
  (test-equal ":system-length counts from :from; the last system shorter"
    '((2 3) (5 3) (8 2))
    (starts+steps (layout (ten-score ":from 3 :to 10 :system-length 3"))))
  (test-equal ":from alone: to the end" '((2 4) (6 4))
    (starts+steps (layout (ten-score ":from 3 :system-length 4"))))
  (test-equal "a score built by hand: its from and to (times)" '((2 3))
    (starts+steps
     (let ((piece (ten-steps)))
       (layout-score piece
                     (hand-score piece
                                 (list (hand-group "m" (list (part-named piece 'melody))))
                                 #:from 2 #:to 5))))))

(test-group "breaks"
  (let ((fig (layout-or-false (layout (ten-score ":breaks (4 7)")))))
    (test-equal "a system starts at each break" '((0 3) (3 3) (6 4))
      (starts+steps fig))
    (test-equal "pulse numbers continue across them"
      '(#("1" "2" "3") #("4" "5" "6") #("7" "8" "9" "10"))
      (and fig (map (lambda (s) (pulses-of fig s)) '(0 1 2))))
    (test-equal "events relative to their system"
      '(((0 1 0 #f) (2 1 0 #f)) ((1 1 0 #f)) ((0 1 0 #f) (2 1 0 #f)))
      (and fig (map (lambda (s) (timing (events-of fig s 2 0))) '(0 1 2)))))
  (test-equal "breaks and :system-length both apply, the length counted from :from"
    '((0 2) (2 2) (4 4) (8 2))
    (starts+steps (layout (ten-score ":system-length 4 :breaks (3)"))))
  (test-equal "a break at the start of the piece changes nothing" '((0 10))
    (starts+steps (layout (ten-score ":breaks (1)"))))
  (test-equal "a break at :from changes nothing" '((2 8))
    (starts+steps (layout (ten-score ":from 3 :breaks (3)"))))
  (test-equal "breaks outside the range are ignored" '((2 4))
    (starts+steps (layout (ten-score ":from 3 :to 6 :breaks (2 8)"))))
  (test-equal "a break inside the range, with breaks outside it" '((2 2) (4 2))
    (starts+steps (layout (ten-score ":from 3 :to 6 :breaks (2 5 8)"))))
  (test-equal "a note crossing a break is cut there" '(((3 1 0 #f)) ((0 5 0 #t)))
    (let ((fig (layout (piece-of "(piece \"P\")" "(scale s a b)"
                                 "(instrument u s a1 b1)"
                                 "(part :instrument u :name p - - - 1 _ _ _ _ _ - - - - - - -)"
                                 "(score s :breaks (5) (group \"p\" p))"))))
      (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1))))
  (test-equal "a score built by hand: its breaks (times)" '((0 3) (3 7))
    (starts+steps
     (let ((piece (ten-steps)))
       (layout-score piece
                     (hand-score piece
                                 (list (hand-group "m" (list (part-named piece 'melody))))
                                 #:breaks '(3)))))))

(test-group "range and breaks with a colotomy"
  ;; A pickup of 1 and two 4-pulse cycles: cycle 1 is 1-5, cycle 2 is 5-9.
  (let ((fig (layout-or-false
              (layout (colo-piece (notes 9) #:pickup 1
                                  #:options ":from (1 3) :to (2 2)")))))
    (test-equal "(1 3) to (2 2): one system" '((3 4)) (starts+steps fig))
    (test-equal "pulse numbers as in the whole piece" #("3" "4" "1" "2")
      (and fig (pulses-of fig 0)))
    (test-equal "cycle 2's mark where it starts" (marks '(2 "2"))
      (and fig (cycles-of fig 0)))
    (test-equal "lines from the second column" '("pulse" "cycle" "pulse")
      (and fig (lines-after-first fig 0)))
    (test-assert "well-formed" (and fig (well-formed? fig))))
  (let ((fig (layout-or-false
              (layout (colo-piece (notes 9) #:pickup 1
                                  #:options ":numbering gong-first :from (2 2) :to (2 1)")))))
    (test-equal "gong-first, (2 2) to (2 1): cycle 2" '((5 4)) (starts+steps fig))
    (test-equal "gong-first: printed 2 3 4 1" #("2" "3" "4" "1")
      (and fig (pulses-of fig 0)))
    (test-equal "gong-first: cycle 2's mark at column 0" (marks '(0 "2"))
      (and fig (cycles-of fig 0))))
  (let ((fig (layout-or-false
              (layout (colo-piece (notes 9) #:pickup 1
                                  #:options ":from (0 4) :to (1 4)")))))
    (test-equal "the pickup is cycle 0: (0 4) to (1 4)" '((0 5)) (starts+steps fig))
    (test-equal "the pickup and cycle 1" #("4" "1" "2" "3" "4")
      (and fig (pulses-of fig 0))))
  (test-equal "a break at a cycle's start" '((0 5) (5 4))
    (starts+steps (layout (colo-piece (notes 9) #:pickup 1
                                      #:options ":breaks ((2 1))")))))

(test-group "the step: the range"
  (let ((fig (layout-or-false
              (layout (piece-of "(piece \"P\")" "(scale s a b)"
                                "(instrument u s a1 b1)"
                                "(part :instrument u :name p 1:1/2 2:1/2 1 2 1)"
                                "(score whole (group \"p\" p))"
                                "(score late :from 2 (group \"p\" p))")))))
    (test-equal "the whole piece: half pulses, 2" 2
      (and fig (field fig 'steps_per_pulse))))
  (let ((fig (layout-or-false
              (layout-named (piece-of "(piece \"P\")" "(scale s a b)"
                                      "(instrument u s a1 b1)"
                                      ;; Durations carry over: 1:1 ends the half pulses.
                                      "(part :instrument u :name p 1:1/2 2:1/2 1:1 2 1)"
                                      "(score whole (group \"p\" p))"
                                      "(score late :from 2 (group \"p\" p))")
                            'late))))
    (test-equal "an excerpt without the half pulses: 1" 1
      (and fig (field fig 'steps_per_pulse)))
    (test-equal "its system, in its own columns" '((1 3)) (starts+steps fig)))
  (let* ((piece (ten-steps))
         (group (lambda () (list (hand-group "m" (list (part-named piece 'melody)))))))
    (test-equal "from counts towards the step" '(2 ((1 19)))
      (let ((fig (layout-score piece (hand-score piece (group) #:from 1/2))))
        (list (field fig 'steps_per_pulse) (starts+steps fig))))
    (test-equal "to counts towards the step" '(2 ((0 19)))
      (let ((fig (layout-score piece (hand-score piece (group) #:to 19/2))))
        (list (field fig 'steps_per_pulse) (starts+steps fig))))
    (test-equal "a break counts towards the step" '(2 ((0 5) (5 15)))
      (let ((fig (layout-score piece (hand-score piece (group) #:breaks '(5/2)))))
        (list (field fig 'steps_per_pulse) (starts+steps fig))))))

(test-group "labels"
  (let ((fig (layout-or-false
              (layout (ten-steps "(score s :system-length 4"
                                 "  (group \"melody\" :short \"m.\" melody)"
                                 "  (group \"kajar\" :short \"k.\" :labels long kajar)"
                                 "  (group \"rests\" :short \"r.\" :labels short rests))")))))
    (test-equal "first-long: long on the first system, short after; long; short"
      '(("melody" "kajar" "r.") ("m." "kajar" "r.") ("m." "kajar" "r."))
      (and fig (labels-by-system fig))))
  (test-equal "the score's :labels short for every group"
    '(("m.") ("m."))
    (labels-by-system
     (layout (ten-steps "(score s :labels short :system-length 5"
                        "  (group \"melody\" :short \"m.\" melody))"))))
  (test-equal "the score's :labels long for every group"
    '(("melody") ("melody"))
    (labels-by-system
     (layout (ten-steps "(score s :labels long :system-length 5"
                        "  (group \"melody\" :short \"m.\" melody))"))))
  (test-equal "first-long with one system: the long label" '(("melody"))
    (labels-by-system
     (layout (ten-steps "(score s (group \"melody\" :short \"m.\" melody))"))))
  (test-equal "without :short, the short label is the long one"
    '(("melody") ("melody"))
    (labels-by-system
     (layout (ten-steps "(score s :system-length 5 (group \"melody\" melody))"))))
  (test-equal "a group built by hand: its short and labels"
    '(("melody") ("m.") ("m."))
    (labels-by-system
     (let ((piece (ten-steps)))
       (layout-score piece
                     (hand-score piece
                                 (list (hand-group "melody"
                                                   (list (part-named piece 'melody))
                                                   #:short "m."))
                                 #:system-length 4))))))

(test-group "sizes: label_width from the labels printed"
  ;; 0.6em per character of the longest label printed, + 1.5em.
  (test-equal ":labels short: the short label (4 chars)" "3.9em"
    (label-width (layout (ten-steps "(score s :labels short :pulse-label \"\""
                                    "  (group \"Gangsa pemade\" :short \"Pem.\" melody))"))))
  (test-equal ":labels long: the long label (13 chars)" "9.3em"
    (label-width (layout (ten-steps "(score s :labels long :system-length 4"
                                    "  (group \"Gangsa pemade\" :short \"Pem.\" melody))"))))
  (test-equal "first-long, one system: only the long label is printed" "2.1em"
    (label-width (layout (ten-steps "(score s :pulse-label \"\""
                                    "  (group \"U\" :short \"Ugal-ugal\" melody))"))))
  (test-equal "first-long, several systems: the longest in any system (9 chars)"
    "6.9em"
    (label-width (layout (ten-steps "(score s :system-length 4"
                                    "  (group \"U\" :short \"Ugal-ugal\" melody))")))))

(define gilak
  (guard (c (#t #f)) (read-piece-file "examples/demos/gilak.nts")))

(test-group "examples/demos/gilak.nts"
  (let ((fig (layout-or-false (layout-named gilak 'full))))
    (test-equal "full: the pickup, then a system per cycle"
      '((0 1) (1 8) (9 8) (17 8))
      (starts+steps fig))
    (test-equal "full: long labels on the first system, short after"
      '(("Ugal" "Gong") ("U." "G.") ("U." "G.") ("U." "G."))
      (and fig (labels-by-system fig)))
    (test-equal "full: the pickup is pulse 8, with cycle mark 0 (ADR 0043)"
      (list #("8") (marks '(0 "0")))
      (and fig (list (pulses-of fig 0) (cycles-of fig 0))))
    (test-equal "full: label_width from \"Cycle\" and \"Pulse\", wider than \"Ugal\"" "4.5em"
      (and fig (label-width fig)))
    (test-assert "full: well-formed" (and fig (well-formed? fig))))
  (let ((fig (layout-or-false (layout-named gilak 'second-cycle))))
    (test-equal "second-cycle: cycle 2 alone" '((9 8)) (starts+steps fig))
    (test-equal "second-cycle: gong-first, printed 2 to 8 then 1"
      #("2" "3" "4" "5" "6" "7" "8" "1")
      (and fig (pulses-of fig 0)))
    (test-equal "second-cycle: cycle 2's mark at column 0" (marks '(0 "2"))
      (and fig (cycles-of fig 0)))
    (test-equal "second-cycle: short labels" '(("U." "G."))
      (and fig (labels-by-system fig)))
    (test-equal "second-cycle: label_width from \"Cycle\" and \"Pulse\"" "4.5em"
      (and fig (label-width fig)))
    (test-assert "second-cycle: well-formed" (and fig (well-formed? fig)))))

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

;;; A unison on `notes' rows (milestone 3, decided while drawing Jaya
;;; Semara: 04, "Groups and rows") is drawn once, under the first part.
(test-group "a unison is drawn once"
  (let ((fig (layout-or-false
              (layout (piece-of "(piece \"P\")" "(scale s a b c)"
                                "(instrument u s a1 b1 c1)"
                                "(part :instrument u :name p 1 2 _ -)"
                                "(part :instrument u :name q 1 3 _ -)"
                                "(score s (group \"G\" p q))")))))
    (test-equal "the first part keeps it"
      '((0 1 2) (1 2 1))
      (and fig (map (lambda (e) (list (field e 'start) (field e 'dur) (field e 'row)))
                    (vector->list (field (vector-ref (field (group-ref fig 0 0) 'voices) 0)
                                         'events)))))
    (test-equal "the later part leaves it out"
      '((1 2 0))
      (and fig (map (lambda (e) (list (field e 'start) (field e 'dur) (field e 'row)))
                    (vector->list (field (vector-ref (field (group-ref fig 0 0) 'voices) 1)
                                         'events)))))))

;;; A one-row group prints its subtitle after its label (04, "Sizes";
;;; 05, decided in feat/targets for Baris), so the label column fits both.
(test-group "label_width: a one-row group's subtitle follows its label"
  (let ((width (lambda (score)
                 (let ((fig (layout-or-false
                             (layout (piece-of "(piece \"P\")" "(scale s a b)"
                                               "(instrument u s a1 b1)"
                                               "(part :instrument u :name p 1 1 1)"
                                               "(part :instrument u :name q 1 2 1)"
                                               score)))))
                   (and fig (field (field fig 'sizes) 'label_width))))))
    (test-equal "one row: \"Ugal\", two spaces, \"main\": 10 characters"
      "7.5em"
      (width "(score s (group \"Ugal\" :subtitle \"main\" p))"))
    (test-equal "two rows: the longest of \"Ugal\" and \"main\""
      "3.9em"
      (width "(score s :pulse-label \"\" (group \"Ugal\" :subtitle \"main\" q))"))))

;;; ------------------------------------------------------------------
;;; Contract version 3, the header (iteration 3, milestone 2, slice
;;; feat/drawing-header; 04, "Slices (iteration 3)" slice 1 and its
;;; decided bullet, "Header and lines", the keys table; 05, "JSON
;;; contract (version 3)"; 01, `:cycle-numbers`, `:cycle-label`,
;;; `:pulse-label`; ADRs 0039, 0043): `version` is 3; the header's keys
;;; are `cycle_label`, `pulse_label`, `cycles`, `pulses`, in that order
;;; (no `label`; `pulse_lines` is a later slice). Each label is the
;;; score's ("Cycle" and "Pulse" by default), null when it is "" or
;;; its row is not shown (`cycles` or `pulses` null). The pickup is
;;; cycle 0: a system that starts in the pickup, or with it, has a mark
;;; "0" at the first pickup column it shows.
;;; Choices made where the docs are not explicit:
;;; - "Starts in the pickup" is read literally: with a pickup of 2 cut
;;;   into systems of one pulse, both systems have the mark "0" at
;;;   column 0.
;;; - The "0" mark comes before cycle 1's in `cycles` (sorted by
;;;   column, like the other marks).
;;; - With `:cycle-numbers no` the pickup has no mark either: `cycles`
;;;   stays null.
;;; - Whether the header labels count towards `label_width` is not
;;;   tested (04's "Sizes" names only group labels and subtitles).
;;; - Fixtures are read from text, not built with `hand-score`, since
;;;   the score record's constructor gains `cycle-label` at a place 02
;;;   lists but this slice's tests don't need to pin.

(define v3-header-keys '(cycle_label pulse_label cycles pulses pulse_lines))

(define (cycle-label-of fig s) (field (header-of fig s) 'cycle_label))
(define (pulse-label-of fig s) (field (header-of fig s) 'pulse_label))

(define (labels-of fig s)
  "System S's (cycle_label pulse_label)."
  (list (cycle-label-of fig s) (pulse-label-of fig s)))

(define (v3-header-ok? fig)
  "Does every system of FIG have a version 3 header: the keys in order,
each label a string or null, `cycles` null or a vector of marks, and
`pulses` null or one string-or-null per column? A label is null when
its row is."
  (every (lambda (s)
           (let ((h (field s 'header)))
             (and (equal? (keys h) v3-header-keys)
                  (string-or-null? (field h 'cycle_label))
                  (string-or-null? (field h 'pulse_label))
                  (let ((cycles (field h 'cycles)))
                    (or (eq? cycles 'null)
                        (and (vector? cycles)
                             (every (lambda (m) (equal? (keys m) mark-keys))
                                    (vector->list cycles)))))
                  (let ((pulses (field h 'pulses)))
                    (or (eq? pulses 'null)
                        (and (vector? pulses)
                             (= (field s 'steps) (vector-length pulses)))))
                  (or (not (eq? (field h 'cycles) 'null))
                      (eq? (field h 'cycle_label) 'null))
                  (or (not (eq? (field h 'pulses) 'null))
                      (eq? (field h 'pulse_label) 'null)))))
         (systems fig)))

(test-group "contract version 3: the figure and the header's keys"
  (test-equal "version 4" 4 (field (layout tiny) 'version))
  (test-equal "version 4 with a colotomy" 4
    (field (layout (colo-piece (notes 9) #:pickup 1)) 'version))
  (test-equal "the header's keys in order: no label"
    v3-header-keys
    (keys (header-of (layout (colo-piece (notes 8))) 0)))
  (test-equal "the header's keys without a colotomy" v3-header-keys
    (keys (header-of (layout (ten-steps)) 0)))
  (test-equal "the header's keys with both rows off" v3-header-keys
    (keys (header-of (layout (colo-piece (notes 8)
                                         #:options ":cycle-numbers no :pulse-numbers no"))
                     0)))
  (test-equal "the other keys stay as in version 2"
    (list figure-keys sizes-keys system-keys)
    (let ((fig (layout (colo-piece (notes 8)))))
      (list (keys fig) (keys (field fig 'sizes)) (keys (system-ref fig 0)))))
  (test-assert "every system's header, across systems"
    (v3-header-ok? (layout (colo-piece (notes 9) #:pickup 1
                                       #:options ":system-length 2"))))
  (test-assert "every system's header, with labels and rows off"
    (v3-header-ok? (layout (colo-piece (notes 9) #:pickup 1
                                       #:options (string-append
                                                  ":cycle-label \"Gong\""
                                                  " :pulse-numbers no"
                                                  " :system-length 3")))))
  (test-assert "json-string accepts a version 3 figure"
    (string? (json-string (layout (colo-piece (notes 9) #:pickup 1
                                              #:options ":cycle-label \"G\""))))))

(test-group "header: cycle_label and pulse_label"
  (test-equal "with a colotomy, by default: \"Cycle\" and \"Pulse\""
    '("Cycle" "Pulse")
    (labels-of (layout (colo-piece (notes 8))) 0))
  (test-equal "the default score with a colotomy: the same"
    '("Cycle" "Pulse")
    (labels-of (layout (colo-piece (notes 5) #:pickup 1 #:score? #f)) 0))
  (test-equal "without a colotomy: no cycle row, so no cycle label"
    '(null "Pulse")
    (labels-of (layout (ten-steps)) 0))
  (test-equal "without a colotomy, :cycle-numbers yes: still no cycle label"
    '(null "Pulse")
    (labels-of (layout (ten-score ":cycle-numbers yes")) 0))
  (test-equal "without a colotomy, :cycle-label written: still null"
    '(null "Pulse")
    (labels-of (layout (ten-score ":cycle-label \"Gong\"")) 0))
  (test-equal "tiny (no colotomy): the pulse label" '(null "Pulse")
    (labels-of (layout tiny) 0))
  (test-equal ":cycle-label and :pulse-label as written"
    '("Gong" "Beats")
    (labels-of (layout (colo-piece (notes 8)
                                   #:options ":cycle-label \"Gong\" :pulse-label \"Beats\""))
               0))
  (test-equal "labels kept as written: spaces and non-ASCII"
    '("Gong · é" "Ketukan ke-")
    (labels-of (layout (colo-piece (notes 8)
                                   #:options ":cycle-label \"Gong · é\" :pulse-label \"Ketukan ke-\""))
               0))
  (test-equal ":cycle-label \"\": null, the pulse label stays"
    '(null "Pulse")
    (labels-of (layout (colo-piece (notes 8) #:options ":cycle-label \"\"")) 0))
  (test-equal ":pulse-label \"\": null, the cycle label stays"
    '("Cycle" null)
    (labels-of (layout (colo-piece (notes 8) #:options ":pulse-label \"\"")) 0))
  (test-equal "both \"\": both null, the rows stay"
    (list 'null 'null (marks '(0 "1") '(4 "2")) #t)
    (let ((fig (layout (colo-piece (notes 8)
                                   #:options ":cycle-label \"\" :pulse-label \"\""))))
      (list (cycle-label-of fig 0) (pulse-label-of fig 0) (cycles-of fig 0)
            (vector? (pulses-of fig 0)))))
  (test-equal ":cycle-label \"\" does not change the rest of the figure"
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1))))
      (list (cycles-of fig 0) (pulses-of fig 0) (lines-of fig 0)))
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":cycle-label \"\" :pulse-label \"\""))))
      (list (cycles-of fig 0) (pulses-of fig 0) (lines-of fig 0))))
  (test-equal ":cycle-numbers no: no cycle label, the pulse label stays"
    '(null "Pulse")
    (labels-of (layout (colo-piece (notes 8) #:options ":cycle-numbers no")) 0))
  (test-equal ":cycle-numbers no with :cycle-label written: null"
    '(null "Beats")
    (labels-of (layout (colo-piece (notes 8)
                                   #:options ":cycle-numbers no :cycle-label \"Gong\" :pulse-label \"Beats\""))
               0))
  (test-equal ":pulse-numbers no: no pulse label, the cycle label stays"
    '("Cycle" null)
    (labels-of (layout (colo-piece (notes 8) #:options ":pulse-numbers no")) 0))
  (test-equal ":pulse-numbers no with :pulse-label written: null"
    '("Gong" null)
    (labels-of (layout (colo-piece (notes 8)
                                   #:options ":pulse-numbers no :cycle-label \"Gong\" :pulse-label \"Beats\""))
               0))
  (test-equal "without a colotomy, :pulse-numbers no: both null"
    '(null null)
    (labels-of (layout (ten-score ":pulse-numbers no :pulse-label \"Beats\"")) 0))
  (test-equal "both rows off: labels, cycles and pulses all null"
    '(null null null null)
    (let ((fig (layout (colo-piece (notes 8)
                                   #:options ":cycle-numbers no :pulse-numbers no"))))
      (list (cycle-label-of fig 0) (pulse-label-of fig 0)
            (cycles-of fig 0) (pulses-of fig 0))))
  (test-equal "the labels in every system, also one with no cycle mark"
    '(("Gong" "Beats") ("Gong" "Beats") ("Gong" "Beats"))
    ;; Pickup of 1, systems of 3 pulses: the third has cycles #().
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":cycle-label \"Gong\" :pulse-label \"Beats\" :system-length 3"))))
      (map (lambda (s) (labels-of fig s)) '(0 1 2))))
  (test-equal "the default labels in every system, without a colotomy"
    '((null "Pulse") (null "Pulse") (null "Pulse"))
    (let ((fig (layout (ten-score ":system-length 4"))))
      (map (lambda (s) (labels-of fig s)) '(0 1 2))))
  (test-equal "an excerpt: the labels as for the whole piece"
    '("Cycle" "Pulse")
    (labels-of (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":from (1 3) :to (2 2)"))
               0))
  (test-equal "the second score of a file: its own labels"
    '(("Cycle" "Pulse") ("Gong" null))
    (let ((pc (piece-of "(piece \"C\" :colotomy c)"
                        "(scale s a b)"
                        "(strokes gong-strokes G)"
                        "(instrument u s a1 b1)"
                        "(instrument gong gong-strokes G)"
                        "(colotomy c 4 (part :instrument gong -:3 G:1))"
                        "(part :instrument u :name m 1 2 1 2)"
                        "(score one (group \"m\" m))"
                        "(score two :cycle-label \"Gong\" :pulse-label \"\" (group \"m\" m))")))
      (list (labels-of (layout-named pc 'one) 0)
            (labels-of (layout-named pc 'two) 0)))))

(test-group "header: the pickup's cycle mark 0"
  (test-equal "a pickup of 1: \"0\" at column 0, cycle 1 after it"
    (marks '(0 "0") '(1 "1") '(5 "2"))
    (cycles-of (layout (colo-piece (notes 9) #:pickup 1)) 0))
  (test-equal "a pickup of 2: one mark \"0\", at its first column"
    (marks '(0 "0") '(2 "1"))
    (cycles-of (layout (colo-piece (notes 6) #:pickup 2)) 0))
  (test-equal "an 8-pulse cycle with a pickup of 1"
    (marks '(0 "0") '(1 "1"))
    (cycles-of (layout (colo-piece (notes 9) #:cycle 8 #:pickup 1)) 0))
  (test-equal "quarter pulses: \"0\" at column 0, cycle 1 at column 4"
    (marks '(0 "0") '(4 "1"))
    (cycles-of (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2" #:pickup 1)) 0))
  (test-equal "the default score of a piece with a pickup"
    (marks '(0 "0") '(1 "1"))
    (cycles-of (layout (colo-piece (notes 5) #:pickup 1 #:score? #f)) 0))
  (test-equal "no pickup: no \"0\""
    (marks '(0 "1") '(4 "2"))
    (cycles-of (layout (colo-piece (notes 8))) 0))
  (test-equal "gong-first: the pickup's text is still \"0\""
    (marks '(0 "0") '(1 "1") '(5 "2"))
    (cycles-of (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":numbering gong-first"))
               0))
  (test-equal "gong-first, a pickup of 2"
    (marks '(0 "0") '(2 "1"))
    (cycles-of (layout (colo-piece (notes 6) #:pickup 2
                                   #:options ":numbering gong-first"))
               0))
  (test-eq ":cycle-numbers no: no mark, cycles null" 'null
    (cycles-of (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":cycle-numbers no"))
               0))
  (test-equal ":cycle-label \"\": the marks stay"
    (marks '(0 "0") '(1 "1") '(5 "2"))
    (cycles-of (layout (colo-piece (notes 9) #:pickup 1
                                   #:options ":cycle-label \"\""))
               0))
  (test-equal "the pickup's pulse numbers and lines do not change"
    (list #("4" "1" "2" "3" "4" "1" "2" "3" "4")
          '("cycle" "pulse" "pulse" "pulse" "cycle" "pulse" "pulse" "pulse"))
    (let ((fig (layout (colo-piece (notes 9) #:pickup 1))))
      (list (pulses-of fig 0) (lines-after-first fig 0)))))

(test-group "header: the pickup's mark across systems"
  ;; A pickup of 1, two 4-pulse cycles.
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                                  #:options ":system-length 3")))))
    ;; Systems of 3 pulses: 0-2, 3-5, 6-8.
    (test-equal "systems of 3: \"0\" only in the first system"
      (list (marks '(0 "0") '(1 "1")) (marks '(2 "2")) #())
      (and fig (map (lambda (s) (cycles-of fig s)) '(0 1 2)))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                                  #:options ":breaks ((1 1))")))))
    (test-equal "the pickup on a system of its own" '((0 1) (1 8))
      (and fig (starts+steps fig)))
    (test-equal "a one-pulse pickup alone: column 0, \"0\"; cycle 1 at column 0 after"
      (list (marks '(0 "0")) (marks '(0 "1") '(4 "2")))
      (and fig (map (lambda (s) (cycles-of fig s)) '(0 1)))))
  (let ((fig (layout-or-false (layout (colo-piece "1:1/4 2 1 2 1:1 2 1 2"
                                                  #:pickup 1
                                                  #:options ":breaks ((1 1))")))))
    (test-equal "quarter pulses, the pickup alone: \"0\" at column 0"
      (list (marks '(0 "0")) (marks '(0 "1")))
      (and fig (map (lambda (s) (cycles-of fig s)) '(0 1)))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 6) #:pickup 2
                                                  #:options ":system-length 1")))))
    ;; A pickup of 2 in systems of one pulse: the second system starts
    ;; in the pickup.
    (test-equal "a system starting in the pickup also has \"0\""
      (list (marks '(0 "0")) (marks '(0 "0")) (marks '(0 "1")) #() #() #())
      (and fig (map (lambda (s) (cycles-of fig s)) '(0 1 2 3 4 5)))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 6) #:pickup 2
                                                  #:options ":breaks ((0 4))")))))
    ;; A pickup of 2 (printed 3 4), a break at its second pulse.
    (test-equal "a break inside the pickup: both systems show \"0\""
      (list (marks '(0 "0")) (marks '(0 "0") '(1 "1")))
      (and fig (map (lambda (s) (cycles-of fig s)) '(0 1)))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                                  #:options ":system-length 2 :numbering gong-first")))))
    ;; Systems of 2: 0-1, 2-3, 4-5, 6-7, 8.
    (test-equal "gong-first across systems: \"0\" in the first only"
      (list (marks '(0 "0") '(1 "1")) #() (marks '(1 "2")) #() #())
      (and fig (map (lambda (s) (cycles-of fig s)) '(0 1 2 3 4))))))

(test-group "header: the pickup's mark in an excerpt"
  ;; A pickup of 1 (printed 4) and two 4-pulse cycles.
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                                  #:options ":from (0 4) :to (1 4)")))))
    (test-equal ":from (0 4): the excerpt starts with the pickup, \"0\" at column 0"
      (marks '(0 "0") '(1 "1"))
      (and fig (cycles-of fig 0))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                                  #:options ":from (0 4) :to (0 4)")))))
    (test-equal "the pickup alone: one system of one column" '((0 1))
      (and fig (starts+steps fig)))
    (test-equal "the pickup alone: \"0\" at column 0" (marks '(0 "0"))
      (and fig (cycles-of fig 0)))
    (test-equal "the pickup alone: its labels" '("Cycle" "Pulse")
      (and fig (labels-of fig 0))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 6) #:pickup 2
                                                  #:options ":from (0 4)")))))
    ;; A pickup of 2 printed 3 4: the excerpt starts at its second pulse.
    (test-equal ":from (0 4) with a pickup of 2: starts in the pickup, \"0\" at column 0"
      (marks '(0 "0") '(1 "1"))
      (and fig (cycles-of fig 0))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                                  #:options ":numbering gong-first :from (0 1) :to (1 1)")))))
    ;; gong-first: the one-pulse pickup is printed 1, so it is (0 1).
    (test-equal "gong-first, :from (0 1): \"0\", then cycle 1"
      '((0 5))
      (and fig (starts+steps fig)))
    (test-equal "gong-first, :from (0 1): the marks"
      (marks '(0 "0") '(1 "1"))
      (and fig (cycles-of fig 0))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                                  #:options ":from (1 1)")))))
    (test-equal "an excerpt from cycle 1: no \"0\""
      (marks '(0 "1") '(4 "2"))
      (and fig (cycles-of fig 0))))
  (let ((fig (layout-or-false (layout (colo-piece (notes 9) #:pickup 1
                                                  #:options ":from (1 3) :to (2 2)")))))
    (test-equal "an excerpt inside the cycles: no \"0\"" (marks '(2 "2"))
      (and fig (cycles-of fig 0)))))

(test-group "examples/demos/gilak.nts: version 3 header"
  (let ((fig (layout-or-false (layout-named gilak 'full))))
    (test-equal "full: version 4" 4 (and fig (field fig 'version)))
    (test-equal "full: the pickup alone, pulse 8, with the mark \"0\""
      (list #("8") (marks '(0 "0")))
      (and fig (list (pulses-of fig 0) (cycles-of fig 0))))
    (test-equal "full: cycle 1 on the next system, at column 0" (marks '(0 "1"))
      (and fig (cycles-of fig 1)))
    (test-assert "full: every header is version 3"
      (and fig (v3-header-ok? fig))))
  (let ((fig (layout-or-false (layout-named gilak 'second-cycle))))
    (test-equal "second-cycle (gong-first, cycle 2 alone): no \"0\""
      (marks '(0 "2"))
      (and fig (cycles-of fig 0)))
    (test-assert "second-cycle: every header is version 3"
      (and fig (v3-header-ok? fig)))))

;;; The header labels sit in the label column, so they count towards
;;; label_width (04, "Sizes"; decided for feat/drawing-header).
(test-group "label_width: the header labels count"
  (let ((width (lambda score-lines
                 (let ((fig (layout-or-false
                             (layout (apply piece-of
                                            "(piece \"P\" :colotomy gilak :pickup 1)"
                                            "(use gong-kebyar)"
                                            "(part :instrument ugal a1 || o2 i2 e2 o2 | a1 o2 i2 a1 ||)"
                                            score-lines)))))
                   (and fig (field (field fig 'sizes) 'label_width))))))
    (test-equal "\"Cycle\", 5 characters, is wider than \"U\": 4.5em" "4.5em"
      (width "(score s (group \"U\" ugal))"))
    (test-equal "with both labels removed, \"U\" alone: 2.1em" "2.1em"
      (width "(score s :cycle-label \"\" :pulse-label \"\" (group \"U\" ugal))"))
    (test-equal "a label whose row isn't shown doesn't count" "2.1em"
      (width "(score s :cycle-numbers no :pulse-numbers no (group \"U\" ugal))"))))

;;; ==================================================================
;;; The lines behind the notes (iteration 3, milestone 2, slice
;;; feat/drawing-lines)
;;; ==================================================================
;;;
;;; 04, "Slices (iteration 3)" slice 2 and its decided bullets, "Header
;;; and lines", "Groups and rows", "Note style", the keys table; 05,
;;; "JSON contract (version 3)"; 01, `:background`; ADRs 0041, 0043.
;;; The header gains `pulse_lines` after `pulses`, from the score's
;;; background: true for `grid` and `vertical`. Each group gains
;;; `pulse_lines` and `row_lines` after `overlays`, from its own
;;; (effective) background: `grid` both true, `vertical` pulse lines
;;; only, `horizontal` row lines only, `empty` neither, for every kind
;;; of rows. The default is `grid`. A stroke's fill is `#e6e6e6`, its
;;; text near-black.
;;; Choices made where the docs are not explicit:
;;; - The flags are JSON booleans: #t and #f in the figure.
;;; - `header.pulse_lines` follows the score's own `:background` (or
;;;   grid), whatever its groups say; 02 gives the score record no
;;;   `background`, so these tests read every fixture from text.
;;; - A group of one row (one lane, or `single`) still has `row_lines`
;;;   true under `grid`: the flag is the background's, and the template
;;;   has no two rows to draw a line between.
;;; - `lines` (pulse and cycle) do not depend on the background: the
;;;   template decides where pulse lines are drawn from the flags.
;;; - Every system of a score carries the same flags.

(define lines-group-keys
  '(label subtitle rows key_numbers voices annotation pulse_lines row_lines))
(define lines-header-keys
  '(cycle_label pulse_label cycles pulses pulse_lines))
(define stroke-grey "#e6e6e6")

(define (header-pulse-lines fig s) (field (header-of fig s) 'pulse_lines))

(define (group-lines fig s g)
  "Group G of system S's (pulse_lines row_lines)."
  (let ((grp (group-ref fig s g)))
    (list (field grp 'pulse_lines) (field grp 'row_lines))))

(define (all-group-lines fig s)
  "Every group of system S's (pulse_lines row_lines), in order."
  (map (lambda (g) (group-lines fig s g))
       (iota (vector-length (field (system-ref fig s) 'groups)))))

(define (background-flags value)
  "The (pulse_lines row_lines) a group with background VALUE gets."
  (match value
    ('grid '(#t #t))
    ('vertical '(#t #f))
    ('horizontal '(#f #t))
    ('empty '(#f #f))))

(define (lines-keys-ok? fig)
  "Does every system of FIG have the header and group keys of this slice?"
  (every (lambda (s)
           (and (equal? (keys (field s 'header)) lines-header-keys)
                (every (lambda (g) (equal? (keys g) lines-group-keys))
                       (vector->list (field s 'groups)))))
         (systems fig)))

(test-group "lines: the header's and the groups' keys"
  (test-equal "the header's keys: pulse_lines after pulses" lines-header-keys
    (keys (header-of (layout (colo-piece (notes 8))) 0)))
  (test-equal "a group's keys: pulse_lines and row_lines after annotation"
    lines-group-keys
    (keys (group-ref (layout (colo-piece (notes 8))) 0 0)))
  (test-assert "every system and group, without a colotomy"
    (lines-keys-ok? (layout (ten-score ":system-length 4"))))
  (test-assert "every system and group, the default score"
    (lines-keys-ok? (layout (colo-piece (notes 9) #:pickup 1 #:score? #f))))
  (test-assert "parts and compact rows"
    (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no :background empty"
                         "  (group \"P\" :rows parts p q)"
                         "  (group \"S\" :rows compact r s)"
                         "  (group \"D\" d))")))
      (and fig (lines-keys-ok? fig))))
  (test-assert "with both header rows off"
    (lines-keys-ok? (layout (colo-piece (notes 8)
                                        #:options ":cycle-numbers no :pulse-numbers no"))))
  (test-assert "json-string accepts the figure"
    (string? (json-string (layout (ten-score ":background horizontal"))))))

(test-group "lines: the default is grid"
  (let ((fig (layout-or-false (layout (colo-piece (notes 8) #:score? #f)))))
    (test-eq "the default score: the header's pulse lines" #t
      (if fig (header-pulse-lines fig 0) 'no-figure))
    ;; Two groups: the part and the colotomy's generated gong.
    (test-equal "the default score: pulse and row lines" '((#t #t) (#t #t))
      (and fig (all-group-lines fig 0))))
  (let ((fig (layout-or-false (layout (ten-steps)))))
    (test-equal "the default score of three parts: every group both"
      '((#t #t) (#t #t) (#t #t))
      (and fig (all-group-lines fig 0))))
  (let ((fig (layout-or-false (layout (ten-score)))))
    (test-eq "a score without :background: the header's pulse lines" #t
      (if fig (header-pulse-lines fig 0) 'no-figure))
    (test-equal "a score without :background: every group both"
      '((#t #t) (#t #t) (#t #t))
      (and fig (all-group-lines fig 0)))))

(test-group "lines: :background on a score"
  (for-each
   (lambda (value)
     (let* ((name (symbol->string value))
            (fig (layout-or-false
                  (layout (ten-score (string-append ":background " name))))))
       (test-eq (string-append name ": the header's pulse lines")
         (and (memq value '(grid vertical)) #t)
         (if fig (header-pulse-lines fig 0) 'no-figure))
       (test-equal (string-append name ": every group")
         (make-list 3 (background-flags value))
         (and fig (all-group-lines fig 0)))))
   '(grid vertical horizontal empty)))

(test-group "lines: :background on a group"
  (for-each
   (lambda (value)
     (let* ((name (symbol->string value))
            (fig (layout-or-false
                  (layout (ten-steps
                           (string-append "(score s"
                                          " (group \"melody\" :background " name " melody)"
                                          " (group \"rests\" rests)"
                                          " (group \"kajar\" kajar))"))))))
       (test-equal (string-append name " on the first group: the others grid")
         (list (background-flags value) '(#t #t) '(#t #t))
         (and fig (all-group-lines fig 0)))
       (test-eq (string-append name " on a group: the header follows the score")
         #t
         (if fig (header-pulse-lines fig 0) 'no-figure))))
   '(grid vertical horizontal empty))
  (let ((fig (layout-or-false
              (layout (ten-steps
                       (string-append "(score s :background empty"
                                      " (group \"melody\" :background grid melody)"
                                      " (group \"rests\" :background horizontal rests)"
                                      " (group \"kajar\" kajar))"))))))
    (test-equal "groups override the score's empty"
      '((#t #t) (#f #t) (#f #f))
      (and fig (all-group-lines fig 0)))
    (test-eq "the score's empty: no pulse lines in the header" #f
      (if fig (header-pulse-lines fig 0) 'no-figure)))
  (let ((fig (layout-or-false
              (layout (ten-steps
                       (string-append "(score s :background vertical"
                                      " (group \"melody\" :background empty melody)"
                                      " (group \"rests\" rests)"
                                      " (group \"kajar\" :background horizontal kajar))"))))))
    (test-equal "groups override the score's vertical"
      '((#f #f) (#t #f) (#f #t))
      (and fig (all-group-lines fig 0)))
    (test-eq "the score's vertical: pulse lines in the header" #t
      (if fig (header-pulse-lines fig 0) 'no-figure)))
  (let ((fig (layout-or-false
              (layout (ten-score ":background horizontal")))))
    (test-eq "the score's horizontal: no pulse lines in the header" #f
      (if fig (header-pulse-lines fig 0) 'no-figure))))

(test-group "lines: every kind of rows"
  (for-each
   (lambda (value)
     (let* ((name (symbol->string value))
            (fig (rows-fig (string-append "(score s :note-label pitch-display-name :note-label-octave no :background " name)
                           "  (group \"N\" p)"
                           "  (group \"P\" :rows parts q r)"
                           "  (group \"S\" :rows compact s)"
                           "  (group \"D\" d))")))
       (test-equal (string-append name ": notes, parts, single and stroke rows")
         (make-list 4 (background-flags value))
         (and fig (all-group-lines fig 0)))))
   '(grid vertical horizontal empty))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"N\" :background empty p)"
                       "  (group \"P\" :rows parts :background horizontal q r)"
                       "  (group \"S\" :rows compact :background vertical s)"
                       "  (group \"D\" d))")))
    (test-equal "each kind of rows with its own background"
      '((#f #f) (#f #t) (#t #f) (#t #t))
      (and fig (all-group-lines fig 0)))))

(test-group "lines: a group of one row keeps row_lines"
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"S\" :rows compact r)"
                       "  (group \"R\" s))")))
    (test-equal "one row, grid: both true" '((#t #t) (#t #t))
      (and fig (all-group-lines fig 0)))))

(test-group "lines: across systems and ranges"
  (let ((fig (layout-or-false
              (layout (ten-steps
                       (string-append "(score s :background vertical :system-length 4"
                                      " (group \"melody\" melody)"
                                      " (group \"rests\" :background horizontal rests)"
                                      " (group \"kajar\" kajar))"))))))
    (test-equal "the same flags in every system"
      (make-list 3 (list #t '((#t #f) (#f #t) (#t #f))))
      (and fig (map (lambda (s) (list (header-pulse-lines fig s)
                                      (all-group-lines fig s)))
                    '(0 1 2)))))
  (let ((fig (layout-or-false
              (layout (colo-piece (notes 9) #:pickup 1
                                  #:options ":background empty :from (1 2) :to (2 1)")))))
    (test-equal "an excerpt: the score's flags" '(#f ((#f #f)))
      (and fig (list (header-pulse-lines fig 0) (all-group-lines fig 0)))))
  (let ((fig (layout-or-false
              (layout (colo-piece (notes 8)
                                  #:options ":background empty :cycle-numbers no :pulse-numbers no")))))
    (test-eq "with both header rows off, pulse_lines is still a boolean" #f
      (if fig (header-pulse-lines fig 0) 'no-figure))))

(test-group "lines: the second score of a file"
  (let ((pc (piece-of "(piece \"C\" :colotomy c)"
                      "(scale s a b)"
                      "(strokes gong-strokes G)"
                      "(instrument u s a1 b1)"
                      "(instrument gong gong-strokes G)"
                      "(colotomy c 4 (part :instrument gong -:3 G:1))"
                      "(part :instrument u :name m 1 2 1 2)"
                      "(score one :background empty (group \"m\" m))"
                      "(score two (group \"m\" m))")))
    (test-equal "each score its own background"
      '((#f ((#f #f))) (#t ((#t #t))))
      (and pc (map (lambda (name)
                     (let ((fig (layout-named pc name)))
                       (list (header-pulse-lines fig 0) (all-group-lines fig 0))))
                   '(one two))))))

(test-group "lines: the system's lines do not depend on the background"
  (let ((lines-with (lambda (value)
                      (lines-of (layout (colo-piece (notes 9) #:pickup 1
                                                    #:options (string-append
                                                               ":background " value)))
                                0))))
    (test-equal "grid and empty: the same lines"
      (lines-with "grid") (lines-with "empty"))
    (test-equal "vertical and horizontal: the same lines"
      (lines-with "vertical") (lines-with "horizontal"))
    (test-equal "the cycle lines stay under empty"
      '("cycle" "pulse" "pulse" "pulse" "cycle" "pulse" "pulse" "pulse")
      (cdr (vector->list (lines-with "empty"))))))

(test-group "strokes: the lighter grey"
  (let ((fig (layout-or-false (layout (ten-score)))))
    (test-equal "kajar: every stroke #e6e6e6, near-black text"
      (make-list 5 (list stroke-grey dark))
      (and fig (map (lambda (e) (list (field e 'fill) (field e 'text_color)))
                    (events-of fig 0 2 0)))))
  (let ((fig (layout-or-false (layout (ten-score ":note-label pitch-display-name :note-label-octave no :palette set1")))))
    (test-equal "with names and another palette: still #e6e6e6"
      (make-list 5 (list "K" stroke-grey dark))
      (and fig (map (lambda (e) (list (field e 'text) (field e 'fill)
                                      (field e 'text_color)))
                    (events-of fig 0 2 0)))))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no (group \"D\" d))")))
    (test-equal "kendang: dag and dug in #e6e6e6"
      (list stroke-grey stroke-grey)
      (and fig (map (lambda (e) (field e 'fill)) (events-of fig 0 0 0)))))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no (group \"D\" :rows compact d))")))
    (test-equal "on a single row too" (list stroke-grey stroke-grey)
      (and fig (map (lambda (e) (field e 'fill)) (events-of fig 0 0 0)))))
  (test-equal "the stroke grey takes near-black text" dark
    (text-color-for stroke-grey)))

;;; ==================================================================
;;; Rows, keys and strokes (iteration 3, milestone 2, slice
;;; feat/drawing-rows)
;;; ==================================================================
;;;
;;; 04, "Slices (iteration 3)" slice 3 and its decided bullets, "Groups
;;; and rows", "Note text, fill and holds", "Lane labels", "Sizes", the
;;; keys table; 05, "JSON contract (version 3)"; 01, `:keys`,
;;; `:octave-numbers`, `:key-numbers`, `:row-labels`, `:display`, "Which
;;; name a note shows"; ADRs 0042, 0047.
;;; - `:keys all`: every key of the instrument, highest at the top; for
;;;   strokes every stroke, in instrument order, a block per instrument
;;;   in the order its first part appears. A range: the instrument's
;;;   keys from LOW to HIGH, highest at the top. `used` as before.
;;; - `:row-label-octave no`: a pitched lane is labelled with its display
;;;   form alone. `:display`: a stroke shows that form in its lane label
;;;   and as its text.
;;; - `:row-labels none`: every entry of `lanes` is "". `row_label_width` is
;;;   "0.0em" when no group shows row labels.
;;; - `:key-numbers yes`: the group's `key_numbers` (after `lanes`) is
;;;   each lane's key on its instrument, from 1, as a string; else null.
;;;   `sizes.key_width` (after `label_width`) is 0.52em × the longest
;;;   number + 1em, or "0.0em" when no group shows key numbers.
;;; - A stroke is one column wide (`dur` 1) from where it starts,
;;;   whatever its written duration; its text is chosen by the written
;;;   duration (`D` for a `dag:2`, damped `d` for a one-pulse `dag`);
;;;   `:holds dash` writes no dashes after it. Pitched notes keep their
;;;   widths and dashes.
;;; Choices made where the docs are not explicit:
;;; - Group lanes hidden by `:row-labels none` do not count towards
;;;   `row_label_width` when another group shows its labels: their labels are
;;;   "" (04: the width is the longest label).
;;; - A stroke cut short by a system break leaves nothing in the next
;;;   system: it is one column, so it is never cut.
;;; - Whether a stroke's written end counts towards the step, and what
;;;   an excerpt starting inside a stroke's written duration shows, are
;;;   not tested.
;;; - `:display` is tested only on strokes whose text is their display
;;;   form (no damped form, or a written duration over one column), so
;;;   whether it also replaces a damped form is not pinned.
;;; - Existing tests that build groups or write out group and sizes keys
;;;   are left as they are: this slice changes them (the report lists
;;;   them).

(define rows3-group-keys
  '(label subtitle rows key_numbers voices annotation pulse_lines row_lines))
(define rows3-sizes-keys
  '(font_size label_width key_width row_label_width cell_width cell_height))

;;; ugal has ten keys: 1 o1  2 e1  3 u1  4 a1  5 i2  6 o2  7 e2  8 u2
;;; 9 a2  10 i3. Every note is one pulse but where written: one column
;;; is one pulse.
;;;   m: u1 (0), a1 (1-3), i2 (3)        → used: i2 a1 u1
;;;   n: i2 (0), e1 (3)
;;;   gong: P (0, written 2 pulses), G (2, written 2): GL and T unplayed
;;;   d (kendang): dag (0, written 2), dug (2), dag (3, damped "d")
(define keys-lines
  '("(piece \"K\")"
    "(scale sel (ding :alias i :display \"i\") (dong :alias o :display \"o\")"
    "  (deng :alias e :display \"e\") (dung :alias u :display \"u\")"
    "  (dang :alias a :display \"a\"))"
    "(strokes gs G GL P T)"
    "(strokes ks (dag :display \"D\" :damped \"d\") dug)"
    "(instrument ugal sel o1 e1 u1 a1 i2 o2 e2 u2 a2 i3)"
    "(instrument gong gs G GL P T)"
    "(instrument kendang ks dag dug)"
    "(part :instrument ugal :name m u1 a1:2 i2:1)"
    "(part :instrument ugal :name n i2 - - e1)"
    "(part :instrument gong P:2 G:2)"
    "(part :instrument kendang :name d dag:2 dug:1 dag)"))

(define (keys-fig . score-lines)
  "The figure of keys-lines with SCORE-LINES (its first score), or #f."
  (layout-or-false (layout (apply piece-of (append keys-lines score-lines)))))

(define (key-numbers-of fig s g) (field (group-ref fig s g) 'key_numbers))
(define (size-of fig key) (field (field fig 'sizes) key))
(define (lane-numbers fig s g v)
  (map (lambda (e) (field e 'row)) (events-of fig s g v)))
(define all-ugal-lanes #("i3" "a2" "u2" "e2" "o2" "i2" "a1" "u1" "e1" "o1"))

(define (rows3-well-formed? fig)
  "Does every group of FIG have this slice's keys, with `key_numbers`
null or one string per lane, and `sizes` this slice's keys?"
  (and (equal? (keys (field fig 'sizes)) rows3-sizes-keys)
       (every (lambda (s)
                (every (lambda (g)
                         (and (equal? (keys g) rows3-group-keys)
                              (let ((k (field g 'key_numbers)))
                                (or (eq? k 'null)
                                    (and (vector? k)
                                         (= (vector-length k)
                                            (vector-length (field g 'rows)))
                                         (every string? (vector->list k)))))))
                       (vector->list (field s 'groups))))
              (systems fig))))

(test-group "rows: the keys of version 3"
  (let ((fig (keys-fig "(score s (group \"U\" m) (group \"G\" gong))")))
    (test-equal "a group's keys: key_numbers after lanes" rows3-group-keys
      (and fig (keys (group-ref fig 0 0))))
    (test-equal "sizes: key_width after label_width" rows3-sizes-keys
      (and fig (keys (field fig 'sizes))))
    (test-assert "well-formed" (and fig (rows3-well-formed? fig))))
  (test-assert "every kind of group, numbers and all"
    (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no :system-length 2"
                         "  (group \"U\" :keys all :key-numbers yes m)"
                         "  (group \"P\" :rows parts n)"
                         "  (group \"S\" :rows compact :row-labels none d)"
                         "  (group \"G\" gong))")))
      (and fig (rows3-well-formed? fig))))
  (test-assert "the default score"
    (let ((fig (keys-fig)))
      (and fig (rows3-well-formed? fig))))
  (test-assert "json-string accepts the figure"
    (let ((fig (keys-fig "(score s (group \"U\" :key-numbers yes m))")))
      (and fig (string? (json-string fig))))))

(test-group ":keys: lanes"
  (let ((fig (keys-fig "(score s (group \"U\" m) (group \"G\" gong))")))
    (test-equal "used (the default): the keys played"
      (list #("i2" "a1" "u1") '(2 1 0))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0))))
    (test-equal "used: the strokes played" (list #("G" "P") '(1 0))
      (and fig (list (lanes-of fig 0 1) (lane-numbers fig 0 1 0)))))
  (let ((fig (keys-fig "(score s (group \"U\" :keys all m))")))
    (test-equal "all: every key of the instrument, highest at the top"
      (list all-ugal-lanes '(7 6 5))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0)))))
  (let ((fig (keys-fig "(score s (group \"U\" :keys (e1 i2) m))")))
    (test-equal "a range: LOW to HIGH, both included, highest at the top"
      (list #("i2" "a1" "u1" "e1") '(2 1 0))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0)))))
  (let ((fig (keys-fig "(score s (group \"U\" :keys (2 5) m))")))
    (test-equal "a range by key numbers" #("i2" "a1" "u1" "e1")
      (and fig (lanes-of fig 0 0))))
  (let ((fig (keys-fig "(score s (group \"U\" :keys (u1 e2) m))")))
    (test-equal "a range above the notes played"
      (list #("e2" "o2" "i2" "a1" "u1") '(4 3 2))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0)))))
  (let ((fig (keys-fig "(score s :keys (e1 i2) (group \"U\" m n) (group \"G\" gong))")))
    (test-equal "a range on the score: the pitched group takes it, strokes keep used"
      (list #("i2" "a1" "u1" "e1") #("G" "P"))
      (and fig (list (lanes-of fig 0 0) (lanes-of fig 0 1))))
    (test-equal "two parts in the range: n's lanes" '(0 3)
      (and fig (lane-numbers fig 0 0 1))))
  (let ((fig (keys-fig "(score s (group \"G\" :keys all gong))")))
    (test-equal "all on strokes: every stroke, in instrument order"
      (list #("G" "GL" "P" "T") '(2 0))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0)))))
  (let ((fig (keys-fig "(score s (group \"K\" :keys all d gong))")))
    (test-equal "all on two stroke instruments: blocks in the order of their parts"
      (list #("D" "dug" "G" "GL" "P" "T") '(0 1 0) '(4 2))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0)
                     (lane-numbers fig 0 0 1)))))
  (let ((fig (keys-fig "(score s (group \"K\" :keys all gong d))")))
    (test-equal "the other order of parts, the other order of blocks"
      (list #("G" "GL" "P" "T" "D" "dug") '(2 0) '(4 5 4))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0)
                     (lane-numbers fig 0 0 1)))))
  (let ((fig (keys-fig "(score s :keys all :system-length 2 (group \"U\" m))")))
    (test-equal "all: the same lanes in every system, played or not"
      (list all-ugal-lanes all-ugal-lanes)
      (and fig (list (lanes-of fig 0 0) (lanes-of fig 1 0)))))
  (let ((fig (keys-fig "(score s :keys all (group \"U\" m))")))
    (test-equal "row_label_width counts every lane shown" "2.0em"
      (and fig (size-of fig 'row_label_width)))))

(test-group ":row-label-octave no"
  (let ((fig (keys-fig "(score s :row-label-octave no (group \"U\" m) (group \"G\" gong))")))
    (test-equal "pitched lanes: the display form alone"
      (list #("i" "a" "u") '(2 1 0))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0))))
    (test-equal "strokes are unchanged" #("G" "P")
      (and fig (lanes-of fig 0 1))))
  (let ((fig (keys-fig "(score s (group \"U\" :keys all :row-label-octave no m))")))
    (test-equal "with all: lanes may read alike"
      #("i" "a" "u" "e" "o" "i" "a" "u" "e" "o")
      (and fig (lanes-of fig 0 0)))
    (test-equal "row_label_width from the shorter labels" "1.5em"
      (and fig (size-of fig 'row_label_width))))
  (let ((fig (keys-fig "(score s (group \"U\" :row-label-octave no m)"
                       "  (group \"N\" n))")))
    (test-equal "on one group only" (list #("i" "a" "u") #("i2" "e1"))
      (and fig (list (lanes-of fig 0 0) (lanes-of fig 0 1)))))
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"P\" :rows parts :row-label-octave no m n))")))
    (test-equal "parts rows keep their row labels" #("m" "n")
      (and fig (lanes-of fig 0 0)))))

(test-group ":display"
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"G\" :display ((P \"Kempur\")) gong))")))
    (test-equal "the lane label" #("G" "Kempur")
      (and fig (lanes-of fig 0 0)))
    (test-equal "the note text" '("Kempur" "G")
      (and fig (texts fig 0 0 0)))
    (test-equal "row_label_width counts the form shown" "4.1em"
      (and fig (size-of fig 'row_label_width))))
  (let ((fig (keys-fig "(score s :display ((G \"Gong\"))"
                       "  (group \"U\" m) (group \"G\" gong))")))
    (test-equal "on a score: the stroke group shows it, the pitched group is unchanged"
      (list #("i2" "a1" "u1") #("Gong" "P"))
      (and fig (list (lanes-of fig 0 0) (lanes-of fig 0 1))))
    (test-equal "without note names, the text stays null" '(null null)
      (and fig (texts fig 0 1 0))))
  (let ((fig (keys-fig "(score s (group \"G\" :keys all :display ((P \"Kempur\")) gong))")))
    (test-equal "with :keys all" #("G" "GL" "Kempur" "T")
      (and fig (lanes-of fig 0 0))))
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"D\" :display ((dag \"Dg\")) d))")))
    (test-equal "kendang: the lane label" #("Dg" "dug")
      (and fig (lanes-of fig 0 0)))
    (test-equal "kendang: a stroke written two pulses long shows the form"
      "Dg"
      (and fig (field (car (events-of fig 0 0 0)) 'text))))
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"G\" :rows parts :display ((P \"Kempur\")) gong))")))
    (test-equal "parts rows: the row label stays, the text changes"
      (list #("gong") '("Kempur" "G"))
      (and fig (list (lanes-of fig 0 0) (texts fig 0 0 0)))))
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"G\" :rows compact :display ((G \"Gong\")) gong))")))
    (test-equal "a single row: the text changes" '("P" "Gong")
      (and fig (texts fig 0 0 0)))))

(test-group ":row-labels none"
  (let ((fig (keys-fig "(score s (group \"U\" :row-labels none m) (group \"G\" gong))")))
    (test-equal "every lane \"\", the events in their lanes as before"
      (list #("" "" "") '(2 1 0))
      (and fig (list (lanes-of fig 0 0) (lane-numbers fig 0 0 0))))
    (test-equal "the other group keeps its labels" #("G" "P")
      (and fig (lanes-of fig 0 1)))
    (test-equal "row_label_width from the labels shown" "1.5em"
      (and fig (size-of fig 'row_label_width))))
  (let ((fig (keys-fig "(score s :row-labels none (group \"U\" m) (group \"G\" gong))")))
    (test-equal "on a score: every group" (list #("" "" "") #("" ""))
      (and fig (list (lanes-of fig 0 0) (lanes-of fig 0 1))))
    (test-equal "no group shows row labels: row_label_width 0.0em" "0.0em"
      (and fig (size-of fig 'row_label_width))))
  (let ((fig (keys-fig "(score s :row-labels none :note-label pitch-display-name :note-label-octave no"
                       "  (group \"P\" :rows parts m n)"
                       "  (group \"S\" :rows compact d))")))
    (test-equal "parts and single rows" (list #("" "") #(""))
      (and fig (list (lanes-of fig 0 0) (lanes-of fig 0 1))))
    (test-equal "parts and single rows: row_label_width 0.0em" "0.0em"
      (and fig (size-of fig 'row_label_width))))
  (let ((fig (keys-fig "(score s :row-labels none (group \"U\" :keys all m))")))
    (test-equal "with :keys all: one \"\" per key" (make-vector 10 "")
      (and fig (lanes-of fig 0 0)))))

(test-group ":key-numbers"
  (let ((fig (keys-fig "(score s (group \"U\" :key-numbers yes m) (group \"G\" gong))")))
    (test-equal "used: each lane's key, from 1, skipping the keys not shown"
      #("5" "4" "3")
      (and fig (key-numbers-of fig 0 0)))
    (test-equal "a stroke group: null" 'null
      (and fig (key-numbers-of fig 0 1)))
    (test-equal "key_width: one digit" "1.5em"
      (and fig (size-of fig 'key_width))))
  (let ((fig (keys-fig "(score s (group \"U\" :key-numbers yes m n))")))
    (test-equal "two parts" #("5" "4" "3" "2")
      (and fig (key-numbers-of fig 0 0))))
  (let ((fig (keys-fig "(score s (group \"U\" :keys all :key-numbers yes m))")))
    (test-equal "all: from 1 to the last key, highest at the top"
      #("10" "9" "8" "7" "6" "5" "4" "3" "2" "1")
      (and fig (key-numbers-of fig 0 0)))
    (test-equal "key_width: two digits" "2.0em"
      (and fig (size-of fig 'key_width))))
  (let ((fig (keys-fig "(score s (group \"U\" :keys (u1 e2) :key-numbers yes m))")))
    (test-equal "a range" #("7" "6" "5" "4" "3")
      (and fig (key-numbers-of fig 0 0))))
  (let ((fig (keys-fig "(score s (group \"U\" m) (group \"G\" gong))")))
    (test-equal "not asked: null everywhere" '(null null)
      (and fig (list (key-numbers-of fig 0 0) (key-numbers-of fig 0 1))))
    (test-equal "no group shows key numbers: key_width 0.0em" "0.0em"
      (and fig (size-of fig 'key_width))))
  (let ((fig (keys-fig "(score s :key-numbers yes :note-label pitch-display-name :note-label-octave no"
                       "  (group \"U\" m)"
                       "  (group \"P\" :rows parts n)"
                       "  (group \"S\" :rows compact d)"
                       "  (group \"G\" gong))")))
    (test-equal "on a score: only the pitched notes group" '(#("5" "4" "3") null null null)
      (and fig (map (lambda (g) (key-numbers-of fig 0 g)) '(0 1 2 3)))))
  (let ((fig (keys-fig "(score s :row-label-octave no"
                       "  (group \"U\" :key-numbers yes :row-labels none m))")))
    (test-equal "without row labels: the numbers stay"
      (list #("" "" "") #("5" "4" "3"))
      (and fig (list (lanes-of fig 0 0) (key-numbers-of fig 0 0))))
    (test-equal "without row labels: row_label_width 0.0em, key_width as before"
      '("0.0em" "1.5em")
      (and fig (list (size-of fig 'row_label_width) (size-of fig 'key_width)))))
  (let ((fig (keys-fig "(score s :system-length 2"
                       "  (group \"U\" :key-numbers yes m))")))
    (test-equal "the same numbers in every system" '(#("5" "4" "3") #("5" "4" "3"))
      (and fig (list (key-numbers-of fig 0 0) (key-numbers-of fig 1 0))))))

(test-group "strokes: one column wide"
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no (group \"U\" m)"
                       "  (group \"G\" gong) (group \"D\" d))")))
    (test-equal "pitched notes keep their widths"
      '((0 1 2 #f) (1 2 1 #f) (3 1 0 #f))
      (and fig (timing (events-of fig 0 0 0))))
    (test-equal "gong: one column each, where the stroke starts"
      '((0 1 1 #f) (2 1 0 #f))
      (and fig (timing (events-of fig 0 1 0))))
    (test-equal "the text by written duration: two pulses show the display form"
      '("P" "G")
      (and fig (texts fig 0 1 0)))
    (test-equal "kendang: D for dag:2, d for a one-pulse dag"
      (list (list 0 1 0 "D" grey #f) (list 2 1 1 "dug" grey #f)
            (list 3 1 0 "d" grey #f))
      (and fig (shapes fig 0 2 0))))
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"P\" :rows parts d)"
                       "  (group \"S\" :rows compact gong))")))
    (test-equal "on a parts row" '((0 1 0 "D" ) (2 1 0 "dug") (3 1 0 "d"))
      (and fig (map (lambda (e) (list (field e 'start) (field e 'dur)
                                      (field e 'row) (field e 'text)))
                    (events-of fig 0 0 0))))
    (test-equal "on a single row" '((0 1 0 #f) (2 1 0 #f))
      (and fig (timing (events-of fig 0 1 0)))))
  (let ((fig (keys-fig "(score s :system-length 1 (group \"G\" gong))")))
    (test-equal "across system breaks: never cut, nothing continued"
      '(((0 1 1 #f)) () ((0 1 0 #f)) ())
      (and fig (map (lambda (s) (timing (events-of fig s 0 0))) '(0 1 2 3)))))
  (let ((fig (layout-or-false
              (layout (apply piece-of
                             (append keys-lines
                                     '("(part :instrument ugal :name h i2:1/2 a1 - - - - - -)"
                                       "(score s (group \"H\" h) (group \"G\" gong))")))))))
    (test-equal "half-pulse columns: one column is half a pulse"
      (list 2 '((0 1 1 #f) (4 1 0 #f)))
      (and fig (list (field fig 'steps_per_pulse)
                     (timing (events-of fig 0 1 0)))))))

(test-group "strokes: no dashes under :holds dash"
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no :holds dash (group \"U\" m)"
                       "  (group \"G\" gong) (group \"D\" d))")))
    (test-equal "pitched notes are still held"
      (list (list 0 1 2 "u" dung-fill #f) (list 1 1 1 "a" dang-fill #f)
            (dash 2 1) (list 3 1 0 "i" ding-fill #f))
      (and fig (shapes fig 0 0 0)))
    (test-equal "gong: no dashes"
      (list (list 0 1 1 "P" grey #f) (list 2 1 0 "G" grey #f))
      (and fig (shapes fig 0 1 0)))
    (test-equal "kendang: no dashes"
      (list (list 0 1 0 "D" grey #f) (list 2 1 1 "dug" grey #f)
            (list 3 1 0 "d" grey #f))
      (and fig (shapes fig 0 2 0))))
  (let ((fig (keys-fig "(score s :note-label pitch-display-name :note-label-octave no :holds dash"
                       "  (group \"S\" :rows compact gong))")))
    (test-equal "on a single row: no dashes"
      (list (list 0 1 0 "P" grey #f) (list 2 1 0 "G" grey #f))
      (and fig (shapes fig 0 0 0)))))

;;; ------------------------------------------------------------------
;;; Slice feat/collapsed-terms (01, "piece": the piece information is
;;; never printed, and the figure doesn't change)

(test-group "[collapsed-terms] piece information is not in the figure"
  (let* ((body '("(scale s a b)"
                 "(instrument i s a1 b1)"
                 "(part :instrument i 1 2)"))
         (plain (apply piece-of "(piece \"P\")" body))
         (with-info
          (apply piece-of
                 (string-append
                  "(piece \"P\" :composer \"I Wayan Beratha\""
                  " :composition-year \"1964\" :source \"Gold\""
                  " :remarks \"two\nlines\")")
                 body)))
    (test-assert "the piece with information reads" (piece? with-info))
    (test-assert "the piece without it reads" (piece? plain))
    (test-assert "the same figure with or without it"
      (and plain with-info
           (equal? (json-string (layout plain))
                   (json-string (layout with-info)))))))

;;; ------------------------------------------------------------------
;;; Slice feat/collapsed-labels (iteration 5; 04, "Iteration 5": "The
;;; figure, version 4", "What a note shows", "The pitch column"; 04,
;;; "Public interface", version 4; ADRs 0054, 0059): the figure is
;;; version 4, with `rows`, `row` and `row_label_width` in place of
;;; `lanes`, `lane` and `lane_width`; an event's text comes from the
;;; group's `:note-label` and `:note-label-octave`, a row label from
;;; its `:row-labels` and `:row-label-octave`.
;;; Choices made where the docs are not explicit:
;;; - `annotation` and each voice's `marker` come in later slices, so
;;;   only the renamed keys, their places and `version` are tested
;;;   here, not the group's or the voice's whole key list.
;;; - The damped form keeps the octave after it (04's table: `o'2`).
;;; - A chord's labels are joined in the order the earlier slices
;;;   pinned (`i' o'`), now with their octaves (`i'2 o'2`).
;;; - `:display` is tested with `pitch-display-name` and `key-number`
;;;   only, on a stroke written longer than one column; whether it
;;;   applies to `pitch-name` is left open (01's table gives `GL`).

(define (get obj key)
  "The value of KEY in OBJ, or the symbol missing."
  (match (assq key obj)
    ((_ . value) value)
    (#f 'missing)))

(define (rows-of* fig s g) (get (group-ref fig s g) 'rows))

(define (ev4 start dur row text fill text-color continued)
  "A version 4 event object, keys in the documented order."
  `((start . ,start) (dur . ,dur) (row . ,row) (text . ,text)
    (fill . ,fill) (text_color . ,text-color) (continued . ,continued)))

(define v4-sizes-keys
  '(font_size label_width key_width row_label_width cell_width cell_height))
(define v4-event-keys '(start dur row text fill text_color continued))

(define (every-group fig pred)
  "Does PRED hold for every group of every system of FIG?"
  (every (lambda (s) (every pred (vector->list (field s 'groups))))
         (systems fig)))

(define (every-event fig pred)
  "Does PRED hold for every event of FIG?"
  (every-group fig
               (lambda (g)
                 (every (lambda (v) (every pred (vector->list (field v 'events))))
                        (vector->list (field g 'voices))))))

(test-group "[collapsed-labels] the figure, version 4"
  (let ((fig (rows-fig "(score s (group \"U\" p) (group \"K\" d))")))
    (test-equal "version 4" 4 (and fig (field fig 'version)))
    (test-equal "sizes: row_label_width in lane_width's place" v4-sizes-keys
      (and fig (keys (field fig 'sizes))))
    (test-assert "groups: rows, not lanes"
      (and fig (every-group fig (lambda (g)
                                  (and (assq 'rows g) (not (assq 'lanes g)))))))
    (test-assert "groups: rows in lanes' place, after subtitle, before key_numbers"
      (and fig (every-group fig (lambda (g)
                                  (equal? (list-head (keys g) 4)
                                          '(label subtitle rows key_numbers))))))
    (test-assert "events: row in lane's place"
      (and fig (every-event fig (lambda (e) (equal? (keys e) v4-event-keys)))))
    (test-equal "rows: the same row labels as lanes were" #("e2" "o2" "i2")
      (and fig (rows-of* fig 0 0)))
    (test-equal "row: the 0-based index of the event's row"
      (list (ev4 0 2 2 'null ding-fill dark #f)
            (ev4 2 1 1 'null dong-fill dark #f)
            (ev4 3 1 0 'null deng-fill dark #f))
      (and fig (events-of fig 0 0 0)))
    (test-equal "row_label_width as lane_width was: \"dug\", 3 chars" "2.6em"
      (and fig (get (field fig 'sizes) 'row_label_width))))
  (test-equal "the template's figure for tiny: version 4" 4
    (layout-or-false (field (layout tiny) 'version))))

(test-group "[collapsed-labels] what a note shows: pitched notes"
  (define (p-texts . score-lines)
    (let ((fig (apply rows-fig score-lines)))
      (and fig (texts fig 0 0 0))))
  ;; p: i2 (two columns), o2 (one column, damped o'), e2 (no damped form)
  (test-equal "no :note-label: null (the default is none)" '(null null null)
    (p-texts "(score s (group \"U\" p))"))
  (test-equal "none: null" '(null null null)
    (p-texts "(score s :note-label none (group \"U\" p))"))
  (test-equal "pitch-name: pitch name and octave, never damped"
    '("ding2" "dong2" "deng2")
    (p-texts "(score s :note-label pitch-name (group \"U\" p))"))
  (test-equal "pitch-display-name: display name and octave, damped on one column"
    '("i2" "o'2" "e2")
    (p-texts "(score s :note-label pitch-display-name (group \"U\" p))"))
  (test-equal "key-number: the key on the instrument, from 1 (a1 i2 o2 e2 u2)"
    '("2" "3" "4")
    (p-texts "(score s :note-label key-number (group \"U\" p))"))
  (test-equal "pitch-name, :note-label-octave no" '("ding" "dong" "deng")
    (p-texts "(score s :note-label pitch-name :note-label-octave no (group \"U\" p))"))
  (test-equal "pitch-display-name, :note-label-octave no" '("i" "o'" "e")
    (p-texts "(score s :note-label pitch-display-name :note-label-octave no"
             "  (group \"U\" p))"))
  (test-equal "key-number: :note-label-octave no changes nothing" '("2" "3" "4")
    (p-texts "(score s :note-label key-number :note-label-octave no (group \"U\" p))"))
  (test-equal "a display name unlike the pitch name (dang is nang)"
    '(("nang1" "o'2" "i'2") ("dang1" "dong2" "ding2") ("1" "3" "2"))
    (map (lambda (value)
           (let ((fig (rows-fig (string-append "(score s :note-label " value
                                               " (group \"Q\" q))"))))
             (and fig (texts fig 0 0 0))))
         '("pitch-display-name" "pitch-name" "key-number")))
  (test-equal "key-number on the ugal: keys 3, 4 and 5, then 5 and 2"
    '(("3" "4" "5") ("5" "2"))
    (let ((fig (keys-fig "(score s :note-label key-number (group \"U\" m n))")))
      (and fig (list (texts fig 0 0 0) (texts fig 0 0 1)))))
  (test-equal "key-number counts every key, whatever :keys shows"
    '("3" "4" "5")
    (let ((fig (keys-fig "(score s :note-label key-number"
                         "  (group \"U\" :keys (u1 i2) m))")))
      (and fig (texts fig 0 0 0)))))

(test-group "[collapsed-labels] what a note shows: strokes"
  (define (d-texts value . more)
    (let ((fig (rows-fig (string-append "(score s :note-label " value
                                        (apply string-append more)
                                        " (group \"K\" d))"))))
      (and fig (texts fig 0 0 0))))
  ;; d: dag (one column; display D, damped d), dug written two pulses
  (test-equal "none: null" '(null null) (d-texts "none"))
  (test-equal "pitch-name: the stroke name" '("dag" "dug") (d-texts "pitch-name"))
  (test-equal "pitch-display-name: the display name, damped on one column"
    '("d" "dug") (d-texts "pitch-display-name"))
  (test-equal "key-number: as pitch-display-name" '("d" "dug")
    (d-texts "key-number"))
  (test-equal "the octave option doesn't apply to strokes"
    '(("dag" "dug") ("d" "dug") ("d" "dug"))
    (list (d-texts "pitch-name" " :note-label-octave no")
          (d-texts "pitch-display-name" " :note-label-octave no")
          (d-texts "key-number" " :note-label-octave no")))
  (test-equal "strokes stay grey" (list grey grey)
    (let ((fig (rows-fig "(score s :note-label pitch-name (group \"K\" d))")))
      (and fig (map (lambda (e) (field e 'fill)) (events-of fig 0 0 0)))))
  (let ((fig (keys-fig "(score s :note-label pitch-display-name"
                       "  (group \"D\" :display ((dag \"Dg\")) d))")))
    (test-equal ":display with pitch-display-name: the form shown"
      "Dg" (and fig (field (car (events-of fig 0 0 0)) 'text))))
  (let ((fig (keys-fig "(score s :note-label key-number"
                       "  (group \"D\" :display ((dag \"Dg\")) d))")))
    (test-equal ":display with key-number: the form shown"
      "Dg" (and fig (field (car (events-of fig 0 0 0)) 'text))))
  (let ((fig (keys-fig "(score s :note-label key-number"
                       "  (group \"G\" :display ((P \"Kempur\")) gong))")))
    (test-equal "key-number on the gong: display names, not numbers"
      '("Kempur" "G")
      (and fig (texts fig 0 0 0)))))

(test-group "[collapsed-labels] what a note shows: score, group and look"
  (let ((fig (rows-fig "(score s :note-label pitch-name (group \"U\" p)"
                       "  (group \"K\" :note-label none d))")))
    (test-equal "a group's none overrides the score's pitch-name"
      '(("ding2" "dong2" "deng2") (null null))
      (and fig (list (texts fig 0 0 0) (texts fig 0 1 0)))))
  (let ((fig (rows-fig "(score s (group \"U\" p)"
                       "  (group \"K\" :note-label pitch-display-name d))")))
    (test-equal "on one group only"
      '((null null null) ("d" "dug"))
      (and fig (list (texts fig 0 0 0) (texts fig 0 1 0)))))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"U\" :note-label-octave yes p) (group \"Q\" q))")))
    (test-equal "a group's :note-label-octave overrides the score's"
      '(("i2" "o'2" "e2") ("nang" "o'" "i'"))
      (and fig (list (texts fig 0 0 0) (texts fig 0 1 0)))))
  (test-equal "the label doesn't change fill or text_color"
    (let ((fig (rows-fig "(score s (group \"U\" p) (group \"K\" d))")))
      (and fig (map (lambda (g)
                      (map (lambda (e) (list (field e 'fill) (field e 'text_color)))
                           (events-of fig 0 g 0)))
                    '(0 1))))
    (let ((fig (rows-fig "(score s :note-label key-number"
                         "  (group \"U\" p) (group \"K\" d))")))
      (and fig (map (lambda (g)
                      (map (lambda (e) (list (field e 'fill) (field e 'text_color)))
                           (events-of fig 0 g 0)))
                    '(0 1)))))
  (let ((fig (rows-fig "(score s :fill none :note-label pitch-display-name"
                       "  (group \"U\" p))")))
    (test-equal ":fill none: the label alone, fill null"
      (list (ev4 0 2 2 "i2" 'null dark #f)
            (ev4 2 1 1 "o'2" 'null dark #f)
            (ev4 3 1 0 "e2" 'null dark #f))
      (and fig (events-of fig 0 0 0))))
  (let ((fig (rows-fig "(score s :note-label pitch-name :system-length 1"
                       "  (group \"U\" p))")))
    (test-equal "a cut note shows its label again in the next system"
      '(("ding2") ("ding2"))
      (and fig (list (texts fig 0 0 0) (texts fig 1 0 0))))))

(test-group "[collapsed-labels] what a note shows: parts rows"
  (let ((fig (rows-fig "(score s (group \"U\" :rows parts (p :label \"Polos\") q r))")))
    (test-equal "no note label: colour only, every text null (needs no label)"
      (list (list (ev4 0 2 0 'null ding-fill dark #f)
                  (ev4 2 1 0 'null dong-fill dark #f)
                  (ev4 3 1 0 'null deng-fill dark #f))
            (list (ev4 1 2 1 'null dang-fill dark #f)
                  (ev4 3 1 1 'null ding-fill dark #f)))
      (and fig (list (events-of fig 0 0 0) (events-of fig 0 0 1)))))
  (test-equal "a chord: one event, its labels joined by a space"
    '(("nang1" "i'2 o'2") ("dang1" "ding2 dong2") ("1" "2 3")
      ("nang" "i' o'") ("dang" "ding dong"))
    (map (lambda (options)
           (let ((fig (rows-fig (string-append "(score s " options
                                               " (group \"U\" :rows parts q))"))))
             (and fig (texts fig 0 0 0))))
         '(":note-label pitch-display-name"
           ":note-label pitch-name"
           ":note-label key-number"
           ":note-label pitch-display-name :note-label-octave no"
           ":note-label pitch-name :note-label-octave no")))
  (let ((fig (rows-fig "(score s :note-label pitch-display-name"
                       "  (group \"U\" :rows parts q))")))
    (test-equal "the chord has its lowest note's look"
      (list (ev4 1 2 0 "nang1" dang-fill dark #f)
            (ev4 3 1 0 "i'2 o'2" ding-fill dark #f))
      (and fig (events-of fig 0 0 0)))))

(test-group "[collapsed-labels] the pitch column: notes rows"
  (define (rows-with options group)
    (let ((fig (rows-fig (string-append "(score s " options " " group ")"))))
      (and fig (rows-of* fig 0 0))))
  (test-equal "the default: pitch-display-name with the octave"
    '(#("e2" "o2" "i2") #("o2" "i2" "nang1"))
    (list (rows-with "" "(group \"U\" p)") (rows-with "" "(group \"Q\" q)")))
  (test-equal "pitch-display-name written"
    #("o2" "i2" "nang1")
    (rows-with ":row-labels pitch-display-name" "(group \"Q\" q)"))
  (test-equal "pitch-name" #("dong2" "ding2" "dang1")
    (rows-with ":row-labels pitch-name" "(group \"Q\" q)"))
  (test-equal "pitch-display-name, :row-label-octave no" #("o" "i" "nang")
    (rows-with ":row-label-octave no" "(group \"Q\" q)"))
  (test-equal "pitch-name, :row-label-octave no" #("dong" "ding" "dang")
    (rows-with ":row-labels pitch-name :row-label-octave no" "(group \"Q\" q)"))
  (test-equal "none: every row \"\"" #("" "" "")
    (rows-with ":row-labels none" "(group \"Q\" q)"))
  (test-equal "the row labels are never damped" #("o2" "i2" "nang1")
    (rows-with ":note-label pitch-display-name" "(group \"Q\" q)"))
  (test-equal "strokes: pitch-display-name gives the display name" #("D" "dug")
    (rows-with ":row-labels pitch-display-name" "(group \"K\" d)"))
  (test-equal "strokes: pitch-name gives the stroke name" #("dag" "dug")
    (rows-with ":row-labels pitch-name" "(group \"K\" d)"))
  (test-equal "strokes: the octave option doesn't apply" '(#("D" "dug") #("dag" "dug"))
    (list (rows-with ":row-label-octave no" "(group \"K\" d)")
          (rows-with ":row-labels pitch-name :row-label-octave no" "(group \"K\" d)")))
  (test-equal "strokes: none" #("" "")
    (rows-with ":row-labels none" "(group \"K\" d)"))
  (let ((fig (rows-fig "(score s :row-labels pitch-name (group \"U\" p)"
                       "  (group \"Q\" :row-labels none :row-label-octave no q))")))
    (test-equal "a group's own values override the score's"
      '(#("deng2" "dong2" "ding2") #("" "" ""))
      (and fig (list (rows-of* fig 0 0) (rows-of* fig 0 1)))))
  (let ((fig (rows-fig "(score s :row-labels none (group \"Q\" q))")))
    (test-equal "with none, events keep their rows"
      '(2 0 1)
      (and fig (map (lambda (e) (field e 'row)) (events-of fig 0 0 0)))))
  (let ((fig (keys-fig "(score s (group \"D\" :display ((dag \"Dg\")) d))")))
    (test-equal ":display: pitch-display-name shows the form given" #("Dg" "dug")
      (and fig (rows-of* fig 0 0))))
  (let ((fig (rows-fig "(score s :row-labels pitch-name :row-label-octave no"
                       "  :note-label pitch-name :note-label-octave yes (group \"U\" p))")))
    (test-equal "the pitch column and the notes set apart"
      (list #("deng" "dong" "ding") '("ding2" "dong2" "deng2"))
      (and fig (list (rows-of* fig 0 0) (texts fig 0 0 0))))))

(test-group "[collapsed-labels] the pitch column: parts rows"
  (define (parts-rows options)
    (let ((fig (rows-fig (string-append "(score s " options
                                        " (group \"U\" :rows parts (p :label \"Polos\") q r))"))))
      (and fig (rows-of* fig 0 0))))
  (test-equal "the default: the parts' row labels" #("Polos" "q" "r")
    (parts-rows ""))
  (test-equal "pitch-name: the parts' row labels" #("Polos" "q" "r")
    (parts-rows ":row-labels pitch-name"))
  (test-equal "pitch-display-name, :row-label-octave no: the row labels"
    #("Polos" "q" "r")
    (parts-rows ":row-labels pitch-display-name :row-label-octave no"))
  (test-equal "none: \"\" for each part" #("" "" "")
    (parts-rows ":row-labels none"))
  (let ((fig (rows-fig "(score s :key-numbers yes (group \"U\" :rows parts p q))")))
    (test-equal "key_numbers null on parts rows" 'null
      (and fig (get (group-ref fig 0 0) 'key_numbers)))))

(test-group "[collapsed-labels] sizes: row_label_width"
  (define (width . score-lines)
    (let ((fig (apply rows-fig score-lines)))
      (and fig (get (field fig 'sizes) 'row_label_width))))
  (test-equal "pitch-display-name: \"e2\", 2 chars" "2.0em"
    (width "(score s (group \"U\" p))"))
  (test-equal "pitch-name: \"deng2\", 5 chars" "3.6em"
    (width "(score s :row-labels pitch-name (group \"U\" p))"))
  (test-equal "pitch-name without the octave: \"deng\", 4 chars" "3.1em"
    (width "(score s :row-labels pitch-name :row-label-octave no (group \"U\" p))"))
  (test-equal "none on every group: 0.0em" "0.0em"
    (width "(score s :row-labels none (group \"U\" p) (group \"K\" d)"
           "  (group \"R\" :rows parts q r))"))
  (test-equal "none on one group: the others count" "2.6em"   ; "dug"
    (width "(score s (group \"U\" :row-labels none q) (group \"K\" d))"))
  (test-equal "parts rows: the row labels count" "9.3em"     ; 16 chars
    (width "(score s (group \"U\" :rows parts (p :label \"sangsih kantilan\") q))"))
  (test-equal "note labels don't count" "2.0em"
    (width "(score s :note-label pitch-name (group \"U\" p))")))

;;; ------------------------------------------------------------------
;;; Compact rows (slice feat/collapsed-compact; 04, "Compact rows",
;;; "The pitch column" and "What a note shows" under "Iteration 5"; 01,
;;; "Compact rows"; ADRs 0042, 0055, 0060)
;;;
;;; `:rows compact` merges a group's parts into one line, with a row
;;; added where different keys sound together. Rows are assigned by
;;; key, once for the whole score: the keys played in the score's range,
;;; in row order (highest pitch first; strokes as `group-row-keys`
;;; gives them), each to the first row where it never sounds with a key
;;; already there. A pitched note's box runs from its start to its end,
;;; a stroke's is one column. A chord is one event in its lowest key's
;;; row and counts as that key alone; a unison is drawn once, under the
;;; first part. Every entry of `rows` is ""; `key_numbers` is null.
;;; Choices made where the docs are not explicit:
;;; - Two boxes that only touch (one ends where the next starts) don't
;;;   sound together, as for `notes-collide`.
;;; - A chord's upper keys are not tested as keys of their own: the
;;;   fixture's chord keys could go to row 0 either way, so only the
;;;   row count and the chord's row are pinned.
;;; - The row labels "" count 0 in `row_label_width`, as `single`'s did:
;;;   a figure whose only group is compact has "1.0em".
;;; - Two stroke instruments' strokes: the kempli is the generated
;;;   timekeeper, K on every pulse.

(define compact-head
  ;; rows-lines' scale (display names i, o, e, u, nang; damped i', o',
  ;; na'), the instrument u (a1 i2 o2 e2 u2) and the kendang (dag dug).
  (list-head rows-lines 7))

(define (compact-fig . lines)
  "The figure of compact-head plus LINES (parts, then a score), or #f."
  (layout-or-false (layout (apply piece-of (append compact-head lines)))))

(define (compact-fig-named name . lines)
  "The figure of compact-head plus LINES, laid out with its score NAME."
  (layout-or-false (layout-named (apply piece-of (append compact-head lines))
                                 name)))

(define (rows-by-voice fig s g)
  "Each voice's events' rows in system S of group G."
  (map (lambda (v) (map (lambda (e) (field e 'row)) (events-of fig s g v)))
       (iota (vector-length (field (group-ref fig s g) 'voices)))))

(define colotomic-lines
  '("(piece \"C\")"
    "(strokes gong-strokes G P T)"
    "(strokes kempli-strokes K)"
    "(instrument gong gong-strokes G P T)"
    "(instrument kempli kempli-strokes K)"
    ;; kempli: the generated timekeeper, K on every pulse
    "(part :instrument gong G - T - P - T -)"))

(define (colotomic-fig . score-lines)
  (layout-or-false (layout (apply piece-of (append colotomic-lines score-lines)))))

(test-group "[compact] gong and kempli"
  (let ((fig (colotomic-fig "(score s (group \"C\" :rows compact gong kempli))")))
    (test-equal "two rows, both \"\"" #("" "") (and fig (rows-of* fig 0 0)))
    (test-equal "voices: one per member" '("gong" "kempli")
      (and fig (voice-names fig 0 0)))
    (test-equal "G, P and T on the first row, every time"
      '((0 1 0 #f) (2 1 0 #f) (4 1 0 #f) (6 1 0 #f))
      (and fig (timing (events-of fig 0 0 0))))
    (test-equal "K on the second row, every time"
      (map (lambda (i) (list i 1 1 #f)) (iota 8))
      (and fig (timing (events-of fig 0 0 1))))
    (test-equal "key_numbers null" 'null
      (and fig (get (group-ref fig 0 0) 'key_numbers)))
    (test-assert "well-formed" (and fig (well-formed? fig))))
  (let ((fig (colotomic-fig "(score s (group \"C\" :rows compact kempli gong))")))
    (test-equal "kempli first: K's block first, so K on row 0, G P T on row 1"
      '((0 0 0 0 0 0 0 0) (1 1 1 1))
      (and fig (rows-by-voice fig 0 0))))
  (let ((fig (colotomic-fig "(score s :rows compact :system-length 2"
                            "  (group \"C\" gong kempli))")))
    (test-equal "the score's :rows compact; in every system: two rows"
      '(#("" "") #("" "") #("" "") #("" ""))
      (and fig (map (lambda (s) (rows-of* fig s 0)) '(0 1 2 3))))
    (test-equal "every system: the gong on row 0, the kempli on row 1"
      '(((0) (1 1)) ((0) (1 1)) ((0) (1 1)) ((0) (1 1)))
      (and fig (map (lambda (s) (rows-by-voice fig s 0)) '(0 1 2 3)))))
  (let ((fig (colotomic-fig "(score s (group \"G\" :rows compact gong))")))
    (test-equal "the gong alone: G, P and T never together, one row"
      (list #("") '((0 0 0 0)))
      (and fig (list (rows-of* fig 0 0) (rows-by-voice fig 0 0))))))

(test-group "[compact] row assignment"
  (let ((fig (rows-fig "(score s (group \"U\" :rows compact p))")))
    (test-equal "one note at a time (a jublag): one row" #("")
      (and fig (rows-of* fig 0 0)))
    (test-equal "every event on row 0, as drawn on notes rows otherwise"
      (list (ev4 0 2 0 'null ding-fill dark #f)
            (ev4 2 1 0 'null dong-fill dark #f)
            (ev4 3 1 0 'null deng-fill dark #f))
      (and fig (events-of fig 0 0 0))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 - e2 -)"
                          "(part :instrument u :name b o2 - - -)"
                          "(score s (group \"U\" :rows compact a b))")))
    ;; Row order e2 o2 i2: e2 → 0; o2 never with e2 → 0; i2 with o2 → 1.
    (test-equal "different keys at once: two rows" #("" "")
      (and fig (rows-of* fig 0 0)))
    (test-equal "the first key in row order on row 0; i2 below, with o2"
      '((1 0) (0))
      (and fig (rows-by-voice fig 0 0))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 - - -)"
                          "(part :instrument u :name b o2 - - -)"
                          "(score s (group \"U\" :rows compact b a))")))
    (test-equal "rows by key, not by part: o2 (higher) on row 0 whatever the order"
      '((0) (1))
      (and fig (rows-by-voice fig 0 0))))
  (let ((fig (compact-fig "(part :instrument u :name a e2 o2 e2 -)"
                          "(part :instrument u :name b o2 i2 i2 -)"
                          "(score s (group \"U\" :rows compact a b))")))
    ;; e2+o2, then o2+i2, then e2+i2: never three at once, three rows.
    (test-equal "three keys pairwise together: three rows" #("" "" "")
      (and fig (rows-of* fig 0 0)))
    (test-equal "e2 on 0, o2 on 1, i2 on 2"
      '((0 1 0) (1 2 2))
      (and fig (rows-by-voice fig 0 0))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 _ - -)"
                          "(part :instrument u :name b - o2 - -)"
                          "(score s (group \"U\" :rows compact a b))")))
    (test-equal "a held note sounds with a later key: two rows"
      (list #("" "") '((1) (0)))
      (and fig (list (rows-of* fig 0 0) (rows-by-voice fig 0 0)))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 - - -)"
                          "(part :instrument u :name b - o2 - -)"
                          "(score s (group \"U\" :rows compact a b))")))
    (test-equal "notes one after the other: one row"
      (list #("") '((0) (0)))
      (and fig (list (rows-of* fig 0 0) (rows-by-voice fig 0 0)))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 _ - -)"
                          "(part :instrument u :name b - - o2 -)"
                          "(score s (group \"U\" :rows compact a b))")))
    (test-equal "a held note ending where the next starts: one row"
      (list #("") '((0) (0)))
      (and fig (list (rows-of* fig 0 0) (rows-by-voice fig 0 0)))))
  (let ((fig (compact-fig "(part :instrument u :name a i2:1/2 - - - - - - -)"
                          "(part :instrument u :name b -:1/2 o2 - - - - - -)"
                          "(score s (group \"U\" :rows compact a b))")))
    (test-equal "half pulses side by side: one row"
      (list #("") '((0) (0)))
      (and fig (list (rows-of* fig 0 0) (rows-by-voice fig 0 0)))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 - e2 i2)"
                          "(part :instrument u :name b o2 - - -)"
                          "(score s :system-length 2"
                          "  (group \"U\" :rows compact a b))")))
    (test-equal "rows are the same in every system"
      '(#("" "") #("" ""))
      (and fig (list (rows-of* fig 0 0) (rows-of* fig 1 0))))
    (test-equal "a key keeps its row in a system where it sounds alone"
      '(((1) (0)) ((0 1) ()))
      (and fig (list (rows-by-voice fig 0 0) (rows-by-voice fig 1 0))))))

(test-group "[compact] strokes"
  (let ((fig (compact-fig "(part :instrument kendang :name x dag _ - -)"
                          "(part :instrument kendang :name y - dug - -)"
                          "(score s (group \"K\" :rows compact x y))")))
    (test-equal "a stroke written long is one column: no overlap, one row"
      (list #("") '((0) (0)))
      (and fig (list (rows-of* fig 0 0) (rows-by-voice fig 0 0))))
    (test-equal "each stroke drawn one column wide"
      '(((0 1 0 #f)) ((1 1 0 #f)))
      (and fig (list (timing (events-of fig 0 0 0))
                     (timing (events-of fig 0 0 1))))))
  (let ((fig (compact-fig "(part :instrument kendang :name x dag _ - -)"
                          "(part :instrument kendang :name y dug - - -)"
                          "(score s (group \"K\" :rows compact x y))")))
    (test-equal "strokes in the same column: two rows, in instrument order"
      (list #("" "") '((0) (1)))
      (and fig (list (rows-of* fig 0 0) (rows-by-voice fig 0 0))))))

(test-group "[compact] chords and unisons"
  (let ((fig (rows-fig "(score s :note-label pitch-display-name :note-label-octave no"
                       "  (group \"Q\" :rows compact q))")))
    (test-equal "a chord is one event: labels joined, the lowest note's look"
      (list #("") (list (ev4 1 2 0 "nang" dang-fill dark #f)
                        (ev4 3 1 0 "i' o'" ding-fill dark #f)))
      (and fig (list (rows-of* fig 0 0) (events-of fig 0 0 0)))))
  (let ((fig (rows-fig "(score s :fill none :note-label pitch-name"
                       "  (group \"Q\" :rows compact q))")))
    (test-equal "a chord with :fill none and pitch names"
      (list (ev4 1 2 0 "dang1" 'null dark #f)
            (ev4 3 1 0 "ding2 dong2" 'null dark #f))
      (and fig (events-of fig 0 0 0))))
  (let ((fig (compact-fig "(part :instrument u :name a (a1 e2) -)"
                          "(part :instrument u :name b o2 -)"
                          "(score s (group \"U\" :rows compact a b))")))
    ;; As a1 alone: o2 → 0, a1 (with o2) → 1. Counting e2 would give 3.
    (test-equal "a chord counts as its lowest key: two rows, not three"
      #("" "")
      (and fig (rows-of* fig 0 0)))
    (test-equal "the chord in its lowest key's row; one event"
      '((1) (0))
      (and fig (rows-by-voice fig 0 0))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 o2 - -)"
                          "(part :instrument u :name b i2 e2 - -)"
                          "(score s (group \"U\" :rows compact a b))")))
    ;; e2 → 0; o2 (with e2) → 1; i2 never with e2 → 0.
    (test-equal "a unison is drawn once, under the first part"
      '(((0 1 0 #f) (1 1 1 #f)) ((1 1 0 #f)))
      (and fig (list (timing (events-of fig 0 0 0))
                     (timing (events-of fig 0 0 1)))))
    (test-equal "a unison adds no row of its own" #("" "")
      (and fig (rows-of* fig 0 0))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 - - -)"
                          "(part :instrument u :name b i2 - - -)"
                          "(score s (group \"U\" :rows compact b a))")))
    (test-equal "the first part in member order draws the unison"
      (list '("b" "a") '((0 1 0 #f)) '())
      (and fig (list (voice-names fig 0 0)
                     (timing (events-of fig 0 0 0))
                     (timing (events-of fig 0 0 1)))))))

(test-group "[compact] holds"
  (let ((fig (compact-fig "(part :instrument u :name a i2 _ - -)"
                          "(part :instrument u :name b - o2 - -)"
                          "(score s :note-label pitch-display-name :note-label-octave no :holds dash"
                          "  (group \"U\" :rows compact a b))")))
    (test-equal "a held note's dash in its own row"
      (list (list (list 0 1 1 "i" ding-fill #f) (dash 1 1))
            (list (list 1 1 0 "o'" dong-fill #f)))
      (and fig (list (shapes fig 0 0 0) (shapes fig 0 0 1)))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 _ - -)"
                          "(part :instrument u :name b - o2 - -)"
                          "(score s (group \"U\" :rows compact a b))")))
    (test-equal "without dashes the held note is one event two columns wide"
      '(((0 2 1 #f)) ((1 1 0 #f)))
      (and fig (list (timing (events-of fig 0 0 0))
                     (timing (events-of fig 0 0 1)))))))

(test-group "[compact] the score's range"
  (define range-parts
    '("(part :instrument u :name a i2 - e2 -)"
      "(part :instrument u :name b o2 - - o2)"))
  (let ((fig (apply compact-fig
                    (append range-parts
                            '("(score s :from 3 :to 4 (group \"U\" :rows compact a b))")))))
    (test-equal "an overlap before :from doesn't count: one row" #("")
      (and fig (rows-of* fig 0 0)))
    (test-equal "the notes in the range on row 0" '((0) (0))
      (and fig (rows-by-voice fig 0 0))))
  (let ((fig (apply compact-fig
                    (append range-parts
                            '("(score s (group \"U\" :rows compact a b))")))))
    (test-equal "the whole piece: two rows" #("" "")
      (and fig (rows-of* fig 0 0))))
  (let ((fig (apply compact-fig-named 'late
                    (append range-parts
                            '("(score whole (group \"U\" :rows compact a b))"
                              "(score late :from 3 :to 4 (group \"U\" :rows compact a b))")))))
    (test-equal "each score its own rows" #("")
      (and fig (rows-of* fig 0 0)))))

(test-group "[compact] the pitch column and sizes"
  (define (compact-rows options)
    (let ((fig (compact-fig "(part :instrument u :name a i2 - - -)"
                            "(part :instrument u :name b o2 - - -)"
                            (string-append "(score s " options
                                           " (group \"U\" :rows compact a b))"))))
      (and fig (rows-of* fig 0 0))))
  (test-equal "pitch-display-name (the default): \"\"" #("" "") (compact-rows ""))
  (test-equal "pitch-name: \"\"" #("" "") (compact-rows ":row-labels pitch-name"))
  (test-equal "none: \"\"" #("" "") (compact-rows ":row-labels none"))
  (test-equal "strokes: \"\""
    #("" "")
    (let ((fig (colotomic-fig "(score s :row-labels pitch-name"
                              "  (group \"C\" :rows compact gong kempli))")))
      (and fig (rows-of* fig 0 0))))
  (let ((fig (rows-fig "(score s :key-numbers yes (group \"U\" :rows compact p q))")))
    (test-equal "key_numbers null, even with the score's :key-numbers yes" 'null
      (and fig (get (group-ref fig 0 0) 'key_numbers))))
  (test-equal "a compact group alone: its labels \"\" count 0" "1.0em"
    (let ((fig (rows-fig "(score s (group \"U\" :rows compact q))")))
      (and fig (get (field fig 'sizes) 'row_label_width))))
  (test-equal "a compact group with :row-labels none alone: 0.0em" "0.0em"
    (let ((fig (rows-fig "(score s :row-labels none (group \"U\" :rows compact q))")))
      (and fig (get (field fig 'sizes) 'row_label_width))))
  (test-equal "compact and notes rows: the notes rows' labels count" "3.6em"
    (let ((fig (rows-fig "(score s (group \"U\" :rows compact p) (group \"Q\" q))")))
      (and fig (get (field fig 'sizes) 'row_label_width))))
  (test-assert "json-string accepts a figure with compact rows"
    (let ((fig (colotomic-fig "(score s :holds dash (group \"C\" :rows compact gong kempli))")))
      (and fig (string? (json-string fig))))))

;;; ------------------------------------------------------------------
;;; Slice feat/collapsed-markers (04, "Part markers" and the version 4
;;; keys table; 05, "JSON contract (version 4)"; ADRs 0056, 0059):
;;; each voice gets `marker`, between `name` and `events`: null for a
;;; part with no entry in its group's `part-marker`, else an object
;;; `symbol` (a string, "none" when the entry gives none),
;;; `symbol_size`, `symbol_color`, `border`, `border_width`, each null
;;; when the entry leaves it out. A unison drawn once is an event of the
;;; first part's voice only, so it carries that part's marks.
;;; Choices made where the docs are not explicit:
;;; - `symbol_size` is written as the number read (0.3), not a string.
;;; - The group's whole key list is not tested: `annotation` replaces
;;;   `overlays` in a later slice. Only the voice's and the marker's keys
;;;   are.
;;; - A voice's marker is the same in every system.

(define marker-keys '(symbol symbol_size symbol_color border border_width))

(define (marker-of fig s g v) (get (voice-ref fig s g v) 'marker))

(define (markers-of fig s g)
  "Each voice's marker in group G of system S."
  (map (lambda (v) (marker-of fig s g v))
       (iota (vector-length (field (group-ref fig s g) 'voices)))))

(define (mk symbol size symbol-color border border-width)
  "A marker object, keys in the documented order."
  `((symbol . ,symbol) (symbol_size . ,size) (symbol_color . ,symbol-color)
    (border . ,border) (border_width . ,border-width)))

(define (every-voice fig pred)
  "Does PRED hold for every voice of every group of FIG?"
  (every-group fig (lambda (g) (every pred (vector->list (field g 'voices))))))

(define (voice-keys-ok? v)
  (and (equal? (keys v) '(name marker events))
       (let ((m (get v 'marker)))
         (or (eq? m 'null)
             (and (equal? (keys m) marker-keys)
                  (member (get m 'symbol) '("none" "dot" "ring" "cross")))))))

(test-group "[markers] the voice's marker: no :part-marker"
  (let ((fig (rows-fig "(score s (group \"U\" p q) (group \"K\" d))")))
    (test-equal "every voice: marker null" '((null null) (null))
      (and fig (list (markers-of fig 0 0) (markers-of fig 0 1))))
    (test-assert "voice keys: name, marker, events"
      (and fig (every-voice fig (lambda (v) (equal? (keys v) '(name marker events))))))))

(test-group "[markers] the voice's marker: notes rows"
  (let ((fig (rows-fig "(score s (group \"U\" :part-marker ((q :symbol dot :border \"#d62728\")) p q))")))
    (test-equal "05's excerpt: null for the part with no entry, the entry's marks"
      (list 'null (mk "dot" 'null 'null "#d62728" 'null))
      (and fig (markers-of fig 0 0)))
    (test-assert "voice keys: name, marker, events; marker keys in order"
      (and fig (every-voice fig voice-keys-ok?)))
    (let ((plain (rows-fig "(score s (group \"U\" p q))")))
      (test-assert "the events are those without :part-marker"
        (and fig plain
             (equal? (list (events-of fig 0 0 0) (events-of fig 0 0 1))
                     (list (events-of plain 0 0 0) (events-of plain 0 0 1)))))))
  (let ((fig (rows-fig "(score s (group \"U\" :part-marker ((p :symbol cross :symbol-size 0.3"
                       "  :symbol-color \"#222222\" :border \"#d62728\" :border-width \"1pt\")) p q))")))
    (test-equal "every key"
      (list (mk "cross" 0.3 "#222222" "#d62728" "1pt") 'null)
      (and fig (markers-of fig 0 0))))
  (let ((fig (rows-fig "(score s (group \"U\" :part-marker ((p :border \"#00ff00\")"
                       "  (q :symbol ring)) p q))")))
    (test-equal "no :symbol: \"none\"; ring; the rest null"
      (list (mk "none" 'null 'null "#00ff00" 'null)
            (mk "ring" 'null 'null 'null 'null))
      (and fig (markers-of fig 0 0))))
  (let ((fig (rows-fig "(score s (group \"U\" :part-marker ((q :symbol none :border-width \"2pt\")) p q))")))
    (test-equal ":symbol none written: \"none\"" (list 'null (mk "none" 'null 'null 'null "2pt"))
      (and fig (markers-of fig 0 0))))
  (let ((fig (rows-fig "(score s (group \"U\" :part-marker ((q :symbol-size 1 :symbol dot)) p q))")))
    (test-equal ":symbol-size 1: a number" (list 'null (mk "dot" 1 'null 'null 'null))
      (and fig (markers-of fig 0 0))))
  (let ((fig (rows-fig "(score s (group \"U\" :part-marker ((q :symbol dot)) p q)"
                       "  (group \"S\" s))")))
    (test-equal "another group: no marks" '(null)
      (and fig (markers-of fig 0 1))))
  (let ((fig (rows-fig "(score s (group \"U\" :part-marker ((r :symbol cross)) p r))")))
    (test-equal "a voice with no events still has its marker"
      (list 'null (mk "cross" 'null 'null 'null 'null) '())
      (and fig (list (marker-of fig 0 0 0) (marker-of fig 0 0 1)
                     (events-of fig 0 0 1))))))

(test-group "[markers] the voice's marker: every kind of rows and strokes"
  (let ((fig (rows-fig "(score s (group \"U\" :rows parts :part-marker ((q :symbol dot)) p q))")))
    (test-equal "parts rows" (list 'null (mk "dot" 'null 'null 'null 'null))
      (and fig (markers-of fig 0 0))))
  (let ((fig (rows-fig "(score s (group \"U\" :rows compact :part-marker ((p :symbol ring)) p q))")))
    (test-equal "compact rows" (list (mk "ring" 'null 'null 'null 'null) 'null)
      (and fig (markers-of fig 0 0))))
  (let ((fig (rows-fig "(score s (group \"K\" :part-marker ((d :symbol cross :border \"#000000\")) d))")))
    (test-equal "a stroke group" (list (mk "cross" 'null 'null "#000000" 'null))
      (and fig (markers-of fig 0 0))))
  (let ((fig (colotomic-fig "(score s (group \"C\" :rows compact"
                            "  :part-marker ((kempli :symbol dot)) gong kempli))")))
    (test-equal "the generated kempli on compact rows"
      (list 'null (mk "dot" 'null 'null 'null 'null))
      (and fig (markers-of fig 0 0)))
    (test-assert "well-formed voices" (and fig (every-voice fig voice-keys-ok?))))
  (let ((fig (rows-fig "(score s :system-length 2"
                       "  (group \"U\" :part-marker ((q :symbol dot)) p q))")))
    (test-equal "in every system"
      (list (list 'null (mk "dot" 'null 'null 'null 'null))
            (list 'null (mk "dot" 'null 'null 'null 'null))
            (list 'null (mk "dot" 'null 'null 'null 'null)))
      (and fig (map (lambda (s) (markers-of fig s 0)) '(0 1 2))))))

(test-group "[markers] a unison drawn once carries the first part's marks"
  (let ((fig (compact-fig "(part :instrument u :name a i2 - - -)"
                          "(part :instrument u :name b i2 - - -)"
                          "(score s (group \"U\" :part-marker ((b :symbol dot)) a b))")))
    (test-equal "notes rows: the event under a, whose marker is null"
      (list 'null '((0 1 0 #f)) (mk "dot" 'null 'null 'null 'null) '())
      (and fig (list (marker-of fig 0 0 0) (timing (events-of fig 0 0 0))
                     (marker-of fig 0 0 1) (timing (events-of fig 0 0 1))))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 - - -)"
                          "(part :instrument u :name b i2 - - -)"
                          "(score s (group \"U\" :rows compact :part-marker ((a :symbol cross)) a b))")))
    (test-equal "compact rows: the event under a, with a's marks"
      (list (mk "cross" 'null 'null 'null 'null) '((0 1 0 #f)) 'null '())
      (and fig (list (marker-of fig 0 0 0) (timing (events-of fig 0 0 0))
                     (marker-of fig 0 0 1) (timing (events-of fig 0 0 1))))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 - - -)"
                          "(part :instrument u :name b i2 - - -)"
                          "(score s (group \"U\" :part-marker ((a :symbol dot)) b a))")))
    (test-equal "the first part in member order draws it, b, unmarked"
      (list '("b" "a") 'null '((0 1 0 #f)) (mk "dot" 'null 'null 'null 'null) '())
      (and fig (list (voice-names fig 0 0)
                     (marker-of fig 0 0 0) (timing (events-of fig 0 0 0))
                     (marker-of fig 0 0 1) (timing (events-of fig 0 0 1))))))
  (let ((fig (compact-fig "(part :instrument u :name a i2 - - -)"
                          "(part :instrument u :name b i2 - - -)"
                          "(score s (group \"U\" :rows parts :part-marker ((b :symbol dot)) a b))")))
    (test-equal "parts rows: each part shows it, with its own marks"
      (list 'null '((0 1 0 #f)) (mk "dot" 'null 'null 'null 'null) '((0 1 1 #f)))
      (and fig (list (marker-of fig 0 0 0) (timing (events-of fig 0 0 0))
                     (marker-of fig 0 0 1) (timing (events-of fig 0 0 1)))))))

(test-group "[markers] a group built by hand"
  ;; make-group's order of this slice (02): part-marker just after
  ;; display. The marker record through make-marker, looked up when the
  ;; test runs.
  (define (piece-proc* name)
    (let ((v (module-variable (resolve-interface '(notasi piece)) name)))
      (cond ((not v) (lambda args (error "not exported by (notasi piece):" name)))
            ((macro? (variable-ref v)) (eval name (resolve-module '(notasi piece))))
            (else (variable-ref v)))))
  (let* ((piece (rows-piece))
         (fig (and piece
                   (layout-or-false
                    (let ((p (part-named piece 'p))
                          (q (part-named piece 'q)))
                      (layout-score
                       piece
                       (hand-score
                        piece
                        (list (apply make-group
                                     (list "U" "U" #f 'first-long 'notes
                                           (list (cons p "p") (cons q "q"))
                                           'none #t 'colour 'none #f
                                           'used #t #f 'pitch-display-name '()
                                           (list (cons q ((piece-proc* 'make-marker)
                                                          'cross 0.5 "#111111" #f "1.5pt")))
                                           'by-pitch 'pastel1 '() 'grid #f))))))))))
    (test-equal "the record's fields, #f as null"
      (list 'null (mk "cross" 0.5 "#111111" 'null "1.5pt"))
      (and fig (markers-of fig 0 0)))))

(test-group "[markers] the figure as JSON"
  (let ((fig (rows-fig "(score s (group \"U\" :part-marker ((p :symbol dot :symbol-size 0.4"
                       "  :border \"#d62728\" :border-width \"1pt\")) p q) (group \"K\" d))")))
    (test-equal "version 4" 4 (and fig (field fig 'version)))
    (test-assert "json-string accepts a figure with markers"
      (and fig (string? (json-string fig))))
    (test-assert "the marker is written between name and events"
      (and fig
           (let* ((js (json-string fig))
                  (n (string-contains js "\"name\": \"p\""))
                  (m (and n (string-contains js "\"marker\"" n)))
                  (e (and n (string-contains js "\"events\"" n))))
             (and m e (< n m e)))))))

;;; ------------------------------------------------------------------
;;; Slice feat/collapsed-annotation (04, "The annotation row", "The
;;; step", "Sizes" and the version 4 keys table; 05, "JSON contract
;;; (version 4)"; ADRs 0057, 0059): each group's `annotation`, in place
;;; of `overlays`: null, or {position, label, items}, each item {start,
;;; dur, text, align, continued} in the system's columns.
;;; Choices made where the docs are not explicit:
;;; - "The next text in the row", where a point ends, is the first text
;;;   (free text or a pattern's) starting strictly after the point.
;;; - A point never runs past the end of its system: it ends at the
;;;   next text's start or at its system's end, whichever comes first,
;;;   so it has no continued piece. With a range, a system ends at `to`
;;;   at the latest.
;;; - A pattern item cut by a free text starting inside it ends there,
;;;   and doesn't start again after the free text (04: "ends where a
;;;   free text starts inside it").
;;; - A pattern item whose whole span is covered by free text is
;;;   dropped.
;;; - `align` is the row's for every pattern piece, continued pieces
;;;   included; "left" for free text.
;;; - An annotation row's label counts in `row_label_width` like a row
;;;   label (04, "Sizes": "an annotation row's label counts"); a null
;;;   label counts 0.
;;; - The annotation (position and label) is the same in every system;
;;;   a system with nothing in the row has items #().

(define annotation-keys '(position label items))
(define annotation-item-keys '(start dur text align continued))
(define annotation-group-keys
  '(label subtitle rows key_numbers voices annotation pulse_lines row_lines))

(define (it start dur text align continued)
  "An annotation item, keys in the documented order."
  `((start . ,start) (dur . ,dur) (text . ,text) (align . ,align)
    (continued . ,continued)))

(define (annotation-of fig s g) (get (group-ref fig s g) 'annotation))

(define (items-of fig s g)
  "The items of group G's annotation in system S, or the annotation
itself when it isn't an object (null, or missing)."
  (let ((a (annotation-of fig s g)))
    (if (pair? a) (get a 'items) a)))

;;; One-pulse notes: one column is one pulse. Every part is 8 pulses.
;;;   p: pair (0-4; inside it up 0-2, down 2-4), up (4-6), down (6-8)
;;;   q: pair (0-4), then notes
;;;   r: silent
;;;   t: up 0-2 with the use's annotation "rise", down 2-4 with "fall"
;;;      and the long name "Fall", then notes
;;;   f: pair (0-4), a point "angsel" at 4, up (4-6), down (6-8)
;;;   g: marked twice (0-4, 4-8), each with a point "hit" 1 pulse in
;;;   h: "intro" over 3 pulses from 0, then up, down, up, down
;;;   w: wide (0-8), with "mid" over 2 pulses from 2
;;;   a: points "a" at 0 and "b" at 2; no patterns
;;;   b: points "one" at 1 and "two" at 5
;;;   c: "long" over 3 pulses from 3
;;;   d: a point "x" at 0, "y" over 1 pulse from 3
;;; up has the annotation "going up", pair "a pair"; down none.
;;; Every part plays i2 and o2 only: rows o2 i2.
(define annotation-lines
  '("(piece \"A\")"
    "(scale sel (ding :alias i :display \"i\") (dong :alias o :display \"o\")"
    "  (deng :alias e :display \"e\") (dung :alias u :display \"u\")"
    "  (dang :alias a :display \"a\"))"
    "(instrument u sel a1 i2 o2 e2 u2)"
    "(pattern up :instrument u :short \"U\" :long \"Up\" :annotation \"going up\" i2 o2)"
    "(pattern down :instrument u :short \"D\" :long \"Down\" o2 i2)"
    "(pattern pair :instrument u :short \"P\" :long \"Pair\" :annotation \"a pair\" @up @down)"
    "(pattern marked :instrument u :short \"M\" :long \"Marked\" i2 (text \"hit\") o2 i2 o2)"
    "(pattern wide :instrument u :short \"W\" :long \"Wide\" i2 o2 (text \"mid\" 2) i2 o2 i2 o2 i2 o2)"
    "(part :instrument u :name p @pair @up @down)"
    "(part :instrument u :name q @pair i2 i2 i2 i2)"
    "(part :instrument u :name r - - - - - - - -)"
    "(part :instrument u :name t (@ up :annotation \"rise\") (@ down :annotation \"fall\" :long \"Fall\") i2 i2 i2 i2)"
    "(part :instrument u :name f @pair (text \"angsel\") @up @down)"
    "(part :instrument u :name g @marked @marked)"
    "(part :instrument u :name h (text \"intro\" 3) @up @down @up @down)"
    "(part :instrument u :name w @wide)"
    "(part :instrument u :name a (text \"a\") i2 i2 (text \"b\") i2 i2 i2 i2 i2 i2)"
    "(part :instrument u :name b i2 (text \"one\") i2 i2 i2 i2 (text \"two\") i2 i2 i2)"
    "(part :instrument u :name c i2 i2 i2 (text \"long\" 3) i2 i2 i2 i2 i2)"
    "(part :instrument u :name d (text \"x\") i2 i2 i2 (text \"y\" 1) i2 i2 i2 i2 i2)"))

(define (annotation-fig . score-lines)
  "The figure of the annotation piece with SCORE-LINES, or #f."
  (layout-or-false
   (layout (apply piece-of (append annotation-lines score-lines)))))

(define (row-items part . options)
  "The items in system 0 of a one-group score of PART with an annotation
row from PART and OPTIONS (strings), or #f."
  (let ((fig (annotation-fig
              (string-append "(score s (group \"G\" :annotation-part " part " "
                             (string-join options " ") " " part "))"))))
    (and fig (items-of fig 0 0))))

(define (row-items-by-system part score-options . options)
  "The items of each system of a one-group score with SCORE-OPTIONS and
an annotation row from PART with OPTIONS, or #f."
  (let ((fig (annotation-fig
              (string-append "(score s " score-options
                             " (group \"G\" :annotation-part " part " "
                             (string-join options " ") " " part "))"))))
    (and fig (map (lambda (s) (items-of fig s 0))
                  (iota (length (systems fig)))))))

(test-group "[annotation] the group's annotation: null without a row"
  (let ((fig (annotation-fig "(score s (group \"P\" p) (group \"F\" f))")))
    (test-equal "null for every group" '(null null)
      (and fig (list (annotation-of fig 0 0) (annotation-of fig 0 1))))
    (test-equal "no overlays key" '(missing missing)
      (and fig (list (get (group-ref fig 0 0) 'overlays)
                     (get (group-ref fig 0 1) 'overlays)))))
  (let ((fig (annotation-fig)))
    (test-assert "the default score: null in every group"
      (and fig (every-group fig (lambda (g) (eq? 'null (get g 'annotation))))))))

(test-group "[annotation] the figure's keys"
  (let ((fig (annotation-fig "(score s :system-length 4"
                             "  (group \"P\" :annotation-part p p)"
                             "  (group \"Q\" q)"
                             "  (group \"F\" :annotation-part f :annotation-position above f))")))
    (test-assert "group keys: annotation where overlays was"
      (and fig (every-group fig (lambda (g) (equal? (keys g) annotation-group-keys)))))
    (test-assert "annotation keys: position, label, items"
      (and fig (every-group
                fig (lambda (g)
                      (let ((a (get g 'annotation)))
                        (or (eq? a 'null)
                            (and (equal? (keys a) annotation-keys)
                                 (vector? (get a 'items)))))))))
    (test-assert "item keys: start, dur, text, align, continued"
      (and fig (every-group
                fig (lambda (g)
                      (let ((a (get g 'annotation)))
                        (or (eq? a 'null)
                            (every (lambda (i) (equal? (keys i) annotation-item-keys))
                                   (vector->list (get a 'items)))))))))
    (test-assert "no overlays key anywhere"
      (and fig (every-group fig (lambda (g) (not (assq 'overlays g))))))
    (test-equal "version 4" 4 (and fig (field fig 'version)))
    (test-assert "json-string accepts it" (and fig (string? (json-string fig))))
    (test-assert "annotation is written between voices and pulse_lines"
      (and fig
           (let* ((js (json-string fig))
                  (v (string-contains js "\"voices\""))
                  (a (and v (string-contains js "\"annotation\"" v)))
                  (l (and a (string-contains js "\"pulse_lines\"" a))))
             (and v a l #t))))))

(test-group "[annotation] position and label"
  (let ((fig (annotation-fig "(score s (group \"P\" :annotation-part p p))")))
    (test-equal "the defaults: below, label null"
      '("below" null)
      (and fig (let ((a (annotation-of fig 0 0)))
                 (list (get a 'position) (get a 'label))))))
  (let ((fig (annotation-fig "(score s (group \"P\" :annotation-part p"
                             "  :annotation-position above :annotation-label \"Kotekan\" p))")))
    (test-equal "above, with a label"
      '("above" "Kotekan")
      (and fig (let ((a (annotation-of fig 0 0)))
                 (list (get a 'position) (get a 'label))))))
  (let ((fig (annotation-fig "(score s (group \"P\" :annotation-part p"
                             "  :annotation-label \"\" p))")))
    (test-equal "an empty label: null" 'null
      (and fig (get (annotation-of fig 0 0) 'label))))
  (let ((fig (annotation-fig "(score s (group \"P\" :annotation-part p :row-labels none"
                             "  :annotation-label \"Kotekan\" p))")))
    (test-equal ":row-labels none: no pitch column, label null" 'null
      (and fig (get (annotation-of fig 0 0) 'label))))
  (let ((fig (annotation-fig "(score s :row-labels none"
                             "  (group \"P\" :annotation-part p :annotation-label \"K\" p))")))
    (test-equal ":row-labels none from the score: label null" 'null
      (and fig (get (annotation-of fig 0 0) 'label))))
  (let ((fig (annotation-fig "(score s :system-length 3"
                             "  (group \"P\" :annotation-part p :annotation-position above"
                             "    :annotation-label \"K\" p))")))
    (test-equal "the same position and label in every system"
      '(("above" "K") ("above" "K") ("above" "K"))
      (and fig (map (lambda (s)
                      (let ((a (annotation-of fig s 0)))
                        (list (get a 'position) (get a 'label))))
                    '(0 1 2))))))

(test-group "[annotation] pattern text at the chosen level"
  (for-each
   (match-lambda
     ((name part options items)
      (test-equal name items (apply row-items part options))))
   (list
    (list "level 0, annotation (the default): long name where there is none"
          "p" '()
          (vector (it 0 4 "a pair" "left" #f) (it 4 2 "going up" "left" #f)
                  (it 6 2 "Down" "left" #f)))
    (list "level 0, short" "p" '(":annotation-text short")
          (vector (it 0 4 "P" "left" #f) (it 4 2 "U" "left" #f)
                  (it 6 2 "D" "left" #f)))
    (list "level 0, long" "p" '(":annotation-text long")
          (vector (it 0 4 "Pair" "left" #f) (it 4 2 "Up" "left" #f)
                  (it 6 2 "Down" "left" #f)))
    (list "level 0, annotation written out" "p" '(":annotation-text annotation")
          (vector (it 0 4 "a pair" "left" #f) (it 4 2 "going up" "left" #f)
                  (it 6 2 "Down" "left" #f)))
    (list "level 1: the spans inside pair" "p" '(":annotation-level 1")
          (vector (it 0 2 "going up" "left" #f) (it 2 2 "Down" "left" #f)))
    (list "level 1, short" "p" '(":annotation-level 1 :annotation-text short")
          (vector (it 0 2 "U" "left" #f) (it 2 2 "D" "left" #f)))
    (list "a level with no spans: no items" "p" '(":annotation-level 2") #())
    (list "where there is no pattern, the row is empty" "q"
          '(":annotation-text short") (vector (it 0 4 "P" "left" #f)))
    (list "a part with no spans and no text: no items" "r" '() #())
    (list "the use's annotation" "t" '()
          (vector (it 0 2 "rise" "left" #f) (it 2 2 "fall" "left" #f)))
    (list "the use's long name" "t" '(":annotation-text long")
          (vector (it 0 2 "Up" "left" #f) (it 2 2 "Fall" "left" #f)))
    (list "short: the pattern's, the use gave none" "t" '(":annotation-text short")
          (vector (it 0 2 "U" "left" #f) (it 2 2 "D" "left" #f)))
    (list "align center" "p" '(":annotation-text short :annotation-align center")
          (vector (it 0 4 "P" "center" #f) (it 4 2 "U" "center" #f)
                  (it 6 2 "D" "center" #f)))
    (list "align right" "p" '(":annotation-text short :annotation-align right")
          (vector (it 0 4 "P" "right" #f) (it 4 2 "U" "right" #f)
                  (it 6 2 "D" "right" #f)))
    (list "align left written out" "p" '(":annotation-text short :annotation-align left")
          (vector (it 0 4 "P" "left" #f) (it 4 2 "U" "left" #f)
                  (it 6 2 "D" "left" #f)))))
  (let ((fig (annotation-fig "(score s (group \"PQ\" :annotation-part q :annotation-text short p q))")))
    (test-equal "only the annotation part's spans, not the other members'"
      (vector (it 0 4 "P" "left" #f))
      (and fig (items-of fig 0 0))))
  (let ((fig (annotation-fig "(score s (group \"F\" :annotation-part p :annotation-text short f p))")))
    (test-equal "another member's free text isn't shown"
      (vector (it 0 4 "P" "left" #f) (it 4 2 "U" "left" #f) (it 6 2 "D" "left" #f))
      (and fig (items-of fig 0 0))))
  (let ((plain (annotation-fig "(score s (group \"P\" p q))"))
        (fig (annotation-fig "(score s (group \"P\" :annotation-part p p q))")))
    (test-assert "the voices and rows are as without the row"
      (and plain fig
           (equal? (list (get (group-ref plain 0 0) 'voices)
                         (get (group-ref plain 0 0) 'rows))
                   (list (get (group-ref fig 0 0) 'voices)
                         (get (group-ref fig 0 0) 'rows))))))
  (for-each
   (lambda (rows)
     (let ((fig (annotation-fig
                 (string-append "(score s :note-label pitch-display-name"
                                " (group \"P\" :rows " rows
                                " :annotation-part p :annotation-text short p q))"))))
       (test-equal (string-append "on " rows " rows: the same items")
         (vector (it 0 4 "P" "left" #f) (it 4 2 "U" "left" #f) (it 6 2 "D" "left" #f))
         (and fig (items-of fig 0 0)))))
   '("parts" "compact")))

(test-group "[annotation] free text"
  (for-each
   (match-lambda
     ((name part options items)
      (test-equal name items (apply row-items part options))))
   (list
    (list "points run to the next text, the last to the end of the system"
          "a" '()
          (vector (it 0 2 "a" "left" #f) (it 2 6 "b" "left" #f)))
    (list "a point, then a text with a length" "d" '()
          (vector (it 0 3 "x" "left" #f) (it 3 1 "y" "left" #f)))
    (list "a text with a length" "c" '()
          (vector (it 3 3 "long" "left" #f)))
    (list "always left, whatever the row's align" "a" '(":annotation-align right")
          (vector (it 0 2 "a" "left" #f) (it 2 6 "b" "left" #f)))
    (list "shown whatever the level" "f" '(":annotation-level 3")
          (vector (it 4 4 "angsel" "left" #f)))
    (list "a point where a pattern starts: it runs to the next text, and covers that pattern"
          "f" '(":annotation-align center")
          (vector (it 0 4 "a pair" "center" #f) (it 4 2 "angsel" "left" #f)
                  (it 6 2 "Down" "center" #f)))
    (list "a point inside a pattern: the pattern ends there; the point runs to the next pattern"
          "g" '(":annotation-text short :annotation-align center")
          (vector (it 0 1 "M" "center" #f) (it 1 3 "hit" "left" #f)
                  (it 4 1 "M" "center" #f) (it 5 3 "hit" "left" #f)))
    (list "a length over a pattern's start: it starts where the text ends"
          "h" '(":annotation-text short")
          (vector (it 0 3 "intro" "left" #f) (it 3 1 "D" "left" #f)
                  (it 4 2 "U" "left" #f) (it 6 2 "D" "left" #f)))
    (list "a length inside a pattern: the pattern ends where it starts"
          "w" '(":annotation-text short")
          (vector (it 0 2 "W" "left" #f) (it 2 2 "mid" "left" #f))))))

(test-group "[annotation] across systems"
  (test-equal "a pattern cut at each break: the later piece continued, its text again"
    (list (vector (it 0 3 "P" "left" #f))
          (vector (it 0 1 "P" "left" #t) (it 1 2 "U" "left" #f))
          (vector (it 0 2 "D" "left" #f)))
    (row-items-by-system "p" ":system-length 3" ":annotation-text short"))
  (test-equal "continued pieces keep the row's align"
    (list (vector (it 0 3 "P" "right" #f))
          (vector (it 0 1 "P" "right" #t) (it 1 2 "U" "right" #f))
          (vector (it 0 2 "D" "right" #f)))
    (row-items-by-system "p" ":system-length 3" ":annotation-text short"
                         ":annotation-align right"))
  (test-equal "cut at several breaks"
    (list (vector (it 0 2 "a pair" "left" #f)) (vector (it 0 2 "a pair" "left" #t))
          (vector (it 0 2 "going up" "left" #f)) (vector (it 0 2 "Down" "left" #f)))
    (row-items-by-system "p" ":system-length 2"))
  (test-equal "a span ending on a break is not cut"
    (list (vector (it 0 4 "P" "left" #f))
          (vector (it 0 2 "U" "left" #f) (it 2 2 "D" "left" #f)))
    (row-items-by-system "p" ":system-length 4" ":annotation-text short"))
  (test-equal "a free text with a length, cut at a break"
    (list (vector (it 3 1 "long" "left" #f)) (vector (it 0 2 "long" "left" #t)))
    (row-items-by-system "c" ":system-length 4"))
  (test-equal "a point runs to the end of its system, not into the next"
    (list (vector (it 1 3 "one" "left" #f)) (vector (it 1 3 "two" "left" #f)))
    (row-items-by-system "b" ":system-length 4"))
  (test-equal "a system with nothing in the row: no items"
    (list (vector (it 0 4 "P" "left" #f)) #())
    (row-items-by-system "q" ":system-length 4" ":annotation-text short")))

(test-group "[annotation] the range"
  (test-equal "cut at :from (continued) and at :to"
    (list (vector (it 0 3 "P" "left" #t) (it 3 1 "U" "left" #f)))
    (row-items-by-system "p" ":from 2 :to 5" ":annotation-text short"))
  (test-equal "a free text with a length that started before :from"
    (list (vector (it 0 2 "long" "left" #t)))
    (row-items-by-system "c" ":from 5"))
  (test-equal "a point runs to :to at the latest"
    (list (vector (it 0 1 "M" "left" #f) (it 1 3 "hit" "left" #f)
                  (it 4 1 "M" "left" #f) (it 5 1 "hit" "left" #f)))
    (row-items-by-system "g" ":to 6" ":annotation-text short"))
  (test-equal "spans outside the range: none"
    (list (vector (it 0 2 "D" "left" #f)))
    (row-items-by-system "p" ":from 7" ":annotation-text short")))

;;; For the step: whole-pulse notes, with a free text on a half or a
;;; quarter pulse.
;;;   h2: i2 (0-1), a point "x" at 3/2, i2 (2-3)
;;;   h4: "q" over 1/4 pulse from 0, then i2 i2 i2
;;;   k2: o2 o2 o2
(define (text-step-fig . score-lines)
  (layout-or-false
   (layout (apply piece-of
                  (append (list-head annotation-lines 5)
                          '("(part :instrument u :name h2 i2:1 -:1/2 (text \"x\") -:1/2 i2:1)"
                            "(part :instrument u :name h4 (text \"q\" 1/4) i2:1 i2 i2)"
                            "(part :instrument u :name k2 o2 o2 o2)")
                          score-lines)))))

(test-group "[annotation] the step: free text and annotation spans"
  (let ((fig (text-step-fig "(score s (group \"H\" :annotation-part h2 h2))")))
    (test-equal "a free text's start counts: 2" 2
      (and fig (field fig 'steps_per_pulse)))
    (test-equal "the point in half-pulse columns, to the system's end"
      (vector (it 3 3 "x" "left" #f))
      (and fig (items-of fig 0 0)))
    (test-equal "the notes in half-pulse columns" '((0 2 0 #f) (4 2 0 #f))
      (and fig (timing (events-of fig 0 0 0)))))
  (test-equal "without an annotation row, free text doesn't count: 1" 1
    (let ((fig (text-step-fig "(score s (group \"H\" h2))")))
      (and fig (field fig 'steps_per_pulse))))
  (test-equal "free text of a part that isn't the row's doesn't count: 1" 1
    (let ((fig (text-step-fig "(score s (group \"H\" :annotation-part k2 h2 k2))")))
      (and fig (field fig 'steps_per_pulse))))
  (let ((fig (text-step-fig "(score s (group \"H\" :annotation-part h4 h4))")))
    (test-equal "a free text's end counts: 4" 4
      (and fig (field fig 'steps_per_pulse)))
    (test-equal "its item, one quarter-pulse column"
      (vector (it 0 1 "q" "left" #f))
      (and fig (items-of fig 0 0)))))

;;; span-step-fig's part h: outer (0-2) at depth 0, rh (0-3/2) at depth 1.
(test-group "[annotation] the step: pattern-span edges of the annotation row's part"
  (let ((fig (span-step-fig "(score s (group \"H\" :annotation-part h"
                            "  :annotation-text short h))")))
    (test-equal "level 0: outer's edges are whole pulses: 1" 1
      (and fig (field fig 'steps_per_pulse)))
    (test-equal "level 0: its item" (vector (it 0 2 "O" "left" #f))
      (and fig (items-of fig 0 0))))
  (let ((fig (span-step-fig "(score s (group \"H\" :annotation-part h"
                            "  :annotation-level 1 :annotation-text short h))")))
    (test-equal "level 1: rh ends on a half pulse: 2" 2
      (and fig (field fig 'steps_per_pulse)))
    (test-equal "level 1: its item in half-pulse columns"
      (vector (it 0 3 "R" "left" #f))
      (and fig (items-of fig 0 0))))
  (test-equal "without an annotation row, the spans don't count: 1" 1
    (let ((fig (span-step-fig "(score s (group \"H\" h))")))
      (and fig (field fig 'steps_per_pulse)))))

(test-group "[annotation] sizes: row_label_width counts the row's label"
  (define (width . score-lines)
    (let ((fig (apply annotation-fig score-lines)))
      (and fig (get (field fig 'sizes) 'row_label_width))))
  (test-equal "rows \"o2\" \"i2\": 2.0em" "2.0em"
    (width "(score s (group \"P\" :annotation-part p p))"))
  (test-equal "a label of 7 characters: 0.52 × 7 + 1 = 4.6em" "4.6em"
    (width "(score s (group \"P\" :annotation-part p :annotation-label \"Kotekan\" p))"))
  (test-equal "a label shorter than the rows' doesn't change it" "2.0em"
    (width "(score s (group \"P\" :annotation-part p :annotation-label \"K\" p))"))
  (test-equal ":row-labels none: the label is null and counts 0" "0.0em"
    (width "(score s :row-labels none"
           "  (group \"P\" :annotation-part p :annotation-label \"Kotekan\" p))")))

(test-group "[annotation] a group built by hand"
  (define (ann-piece-proc name)
    (let ((v (module-variable (resolve-interface '(notasi piece)) name)))
      (cond ((not v) (lambda args (error "not exported by (notasi piece):" name)))
            ((macro? (variable-ref v)) (eval name (resolve-module '(notasi piece))))
            (else (variable-ref v)))))
  (let* ((piece (apply piece-of annotation-lines))
         (fig (and piece
                   (layout-or-false
                    (let ((p (part-named piece 'p)))
                      (layout-score
                       piece
                       (hand-score
                        piece
                        (list (apply make-group
                                     (list "U" "U" #f 'first-long 'notes
                                           (list (cons p "p"))
                                           'none #t 'colour 'none
                                           ((ann-piece-proc 'make-annotation-row)
                                            p 'above 'center 0 'long "Pola")
                                           'used #t #f 'pitch-display-name '() '()
                                           'by-pitch 'pastel1 '() 'grid #f))))))))))
    (test-equal "the record's settings, as the reader would fill them"
      `((position . "above") (label . "Pola")
        (items . ,(vector (it 0 4 "Pair" "center" #f) (it 4 2 "Up" "center" #f)
                          (it 6 2 "Down" "center" #f))))
      (and fig (annotation-of fig 0 0)))))

(test-end "layout")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
