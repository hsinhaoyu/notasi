;;; Unit tests for (notasi piece): records and derived functions.
;;;
;;; Written from doc/design/02-piece.md, not from the implementation.
;;;
;;; Slice feat/music-durations (03-reader.md, "Slices (iteration 2)"):
;;; `piece` is (make-piece title length scales instruments parts groups),
;;; times are exact rationals in pulses, `part-end` replaces `part-steps`
;;; and `events-at` takes a time.
;;;
;;; Slice feat/music-colotomy (03, slice 4's decided bullets; 02,
;;; "Records" and "Derived values"): `(make-piece title length pickup
;;; colotomies scales instruments parts groups)`, `(make-part name
;;; instrument events origin location)`, the `colotomy` record, and
;;; `time->position` / `position->time`.
;;; Choices made where the docs are not explicit:
;;; - A piece's colotomy starts at time 0: `piece-colotomies` is
;;;   ((0 . colotomy)), the pickup included.
;;; - `time->position` follows 02's formula for any time, the piece's end
;;;   included (it is the first pulse of the next cycle).
;;;
;;; Slice feat/music-patterns (03, slice 5's decided bullets; 02,
;;; "Records"): `(make-piece title length pickup colotomies scales
;;; instruments patterns parts groups)`, `(make-part name instrument
;;; events origin spans location)`, and the `pattern` and `pattern-span`
;;; records. Existing tests build records with the new arities (no
;;; patterns, no spans) and check what they checked before.
;;;
;;; Slice feat/scores-form (04, "Slices (iteration 2)", slice 1; 02,
;;; "Records"): `(make-piece title length pickup colotomies scales
;;; instruments patterns parts scores)`, `scores` in place of `groups`;
;;; the `score` record and the new `group` record, with every field of
;;; 02 (ADR 0033), and `piece-score`. Existing tests build groups with
;;; the new shape (members are (part . row-label)) and wrap them in a
;;; score where a piece needs one.
;;; Choices made where the docs are not explicit:
;;; - Accessors follow 02's field names, `?` included:
;;;   `group-note-label`, `score-cycle-numbers?`, `score-pulse-numbers?`.
;;; - `piece-score` of a name the piece has no score for is #f, and the
;;;   first of two scores with one name is returned (the reader forbids
;;;   them; this only pins down that it looks names up, not positions).
;;;
;;; Slice feat/scores-rows (04, "Slices (iteration 2)", slice 3; 02,
;;; "Derived values"): `(note-display instrument note #:damped? #t)` is
;;; the degree's damped form, or its display form when it has none;
;;; without `#:damped?`, or with #f, the display form as before.
;;; Choices made where the docs are not explicit:
;;; - Strokes take `:damped` like degrees (01, `strokes`: "the same
;;;   syntax and options as a scale degree"), so `#:damped?` works on
;;;   them too.
;;; - `note-row-label` is unchanged by a damped form.
;;;
;;; Slice feat/collapsed-terms (iteration 5; 02, "Iteration 5"): the
;;; glossary's names (ADR 0051): the record `pitch` (`make-pitch`,
;;; `pitch?`, `pitch-name`, `pitch-aliases`, `pitch-display`,
;;; `pitch-damped`, `pitch-location`) in place of `degree`,
;;; `scale-pitches` and `note-pitch`; and the piece's `info`, the last
;;; argument of `make-piece`, read with `piece-info`.
;;; Choices made where the docs are not explicit:
;;; - The old names are no longer exported: "renamed", not aliased.
;;; - `make-piece` with the nine arguments of before raises: `info` is
;;;   a field like the others, not optional.

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 match)
             (notasi piece))

;;; ------------------------------------------------------------------
;;; Fixtures

(define loc (make-source-location "test.nts" 1))

(define (deg name alias display)
  "A degree with at most one alias."
  (make-pitch name (if alias (list alias) '()) display #f loc))

;; selisir: ding dong deng dung dang, aliases i o e u a.
(define selisir
  (make-scale 'selisir
              (list (deg 'ding 'i "i")
                    (deg 'dong 'o "o")
                    (deg 'deng 'e "e")
                    (deg 'dung 'u "u")
                    (deg 'dang 'a "a"))
              #t
              loc))

;; A scale whose degree had no (display ...) option: the reader fills in
;; the degree name, so display is always a string.
(define plain-scale
  (make-scale 'plain
              (list (deg 'ding #f "ding")
                    (deg 'dung #f "dung"))
              #t
              loc))

(define gong-strokes
  (make-scale 'gong-strokes
              (list (deg 'G #f "G") (deg 'P #f "P"))
              #f
              loc))

(define kempli-strokes
  (make-scale 'kempli-strokes (list (deg 'K #f "K")) #f loc))

;; kendang strokes: dag (display "D"), dug, du.
(define kendang-strokes
  (make-scale 'kendang-strokes
              (list (deg 'dag #f "D") (deg 'dug #f "dug") (deg 'du #f "du"))
              #f
              loc))

(define (degree-index scale name)
  (list-index (lambda (d) (eq? (pitch-name d) name)) (scale-pitches scale)))

(define (pitched-note scale name octave)
  "Note NAME+OCTAVE of SCALE, e.g. (pitched-note selisir 'ding 2) is ding2."
  (make-note (symbol-append name (string->symbol (number->string octave)))
             (degree-index scale name)
             octave))

(define (stroke-note strokes name)
  (make-note name (degree-index strokes name) #f))

;; reyong: deng1 dung1 dang1 ding2 dong2 deng2 dung2 dang2 (ascending).
;; Indices:  0     1     2     3     4     5     6     7
(define reyong
  (make-instrument
   'reyong selisir
   (list->vector
    (map (match-lambda ((name octave) (pitched-note selisir name octave)))
         '((deng 1) (dung 1) (dang 1)
           (ding 2) (dong 2) (deng 2) (dung 2) (dang 2))))
   loc))

(define plain-instrument
  (make-instrument 'plain plain-scale
                   (vector (pitched-note plain-scale 'ding 1)
                           (pitched-note plain-scale 'dung 1))
                   loc))

(define gong
  (make-instrument 'gong gong-strokes
                   (vector (stroke-note gong-strokes 'G)
                           (stroke-note gong-strokes 'P))
                   loc))

(define kempli
  (make-instrument 'kempli kempli-strokes
                   (vector (stroke-note kempli-strokes 'K))
                   loc))

;; kendang lists dag dug du.
(define kendang
  (make-instrument 'kendang kendang-strokes
                   (vector (stroke-note kendang-strokes 'dag)
                           (stroke-note kendang-strokes 'dug)
                           (stroke-note kendang-strokes 'du))
                   loc))

(define (inst-note instrument index)
  (vector-ref (instrument-notes instrument) index))

(define (ev start duration . notes)
  (make-event start duration notes))

(define (mk-part name instrument . events)
  (make-part name instrument events 'written '() loc))

(define* (mk-group* label parts
                    #:key (short label) (subtitle #f) (labels 'first-long)
                    (rows 'notes) (note-label 'none) (note-label-octave? #t)
                    (fill 'colour)
                    (holds 'none) (pattern-names 'none) (pattern-level 0)
                    (keys 'used) (row-label-octave? #t) (key-numbers? #f)
                    (row-labels 'pitch-display-name) (display '())
                    (scheme 'by-pitch) (palette 'pastel1) (colors '())
                    (background 'grid) (location #f))
  "A group of PARTS, each with its name as row label; every other
setting at its default unless given."
  (make-group label short subtitle labels rows
              (map (lambda (p) (cons p (symbol->string (part-name p)))) parts)
              note-label note-label-octave? fill holds pattern-names
              pattern-level keys row-label-octave? key-numbers? row-labels
              display
              scheme palette colors background location))

(define (mk-group label . parts)
  (mk-group* label parts))

(define* (mk-score name groups #:key (title "T") (to 0) (location #f))
  "A score called NAME holding GROUPS, every other setting at its default."
  (make-score name title #f #f 0 to #f '() #f #t 'gong-last 'grid #f #f #f
              "2em" "2em" groups location))

(define (mk-piece title length scales instruments parts groups)
  "A piece without a colotomy or patterns: pickup 0, no colotomies, and
one score holding GROUPS."
  (make-piece title length 0 '() scales instruments '() parts
              (list (mk-score 'default groups #:title title #:to length))
              '()))

(define (lane-names group)
  (map note-name (group-row-keys group)))

;;; ------------------------------------------------------------------

(test-begin "piece")

;;; Records

(test-group "source-location record"
  (let ((l (make-source-location "song.nts" 12)))
    (test-assert "predicate" (source-location? l))
    (test-equal "file" "song.nts" (source-location-file l))
    (test-equal "line" 12 (source-location-line l)))
  (let ((l (make-source-location #f 3)))
    (test-assert "file #f: predicate" (source-location? l))
    (test-eq "file #f: file" #f (source-location-file l))
    (test-equal "file #f: line" 3 (source-location-line l))))

(test-group "degree record"
  (let ((d (make-pitch 'dang '(a nang) "nang" "na'" loc)))
    (test-assert "predicate" (pitch? d))
    (test-eq "name" 'dang (pitch-name d))
    (test-equal "aliases" '(a nang) (pitch-aliases d))
    (test-equal "display" "nang" (pitch-display d))
    (test-equal "damped" "na'" (pitch-damped d))
    (test-eq "location" loc (pitch-location d)))
  (test-equal "aliases may be empty" '()
    (pitch-aliases (make-pitch 'du '() "du" #f loc)))
  (test-eq "damped may be #f" #f
    (pitch-damped (make-pitch 'du '() "du" #f loc))))

(test-group "scale record"
  (test-assert "predicate" (scale? selisir))
  (test-eq "name" 'selisir (scale-name selisir))
  (test-equal "degrees" '(ding dong deng dung dang)
    (map pitch-name (scale-pitches selisir)))
  (test-eq "pitched? #t" #t (scale-pitched? selisir))
  (test-eq "pitched? #f for a stroke set" #f (scale-pitched? gong-strokes))
  (test-eq "location" loc (scale-location selisir)))

(test-group "note record"
  (let ((n (make-note 'ding2 0 2))
        (s (make-note 'dag 0 #f)))
    (test-assert "predicate" (note? n))
    (test-eq "name" 'ding2 (note-name n))
    (test-equal "degree" 0 (note-pitch n))
    (test-equal "octave" 2 (note-octave n))
    (test-eq "stroke octave is #f" #f (note-octave s))))

(test-group "instrument record"
  (test-assert "predicate" (instrument? reyong))
  (test-eq "name" 'reyong (instrument-name reyong))
  (test-eq "scale" selisir (instrument-scale reyong))
  (test-assert "notes is a vector" (vector? (instrument-notes reyong)))
  (test-equal "notes" 8 (vector-length (instrument-notes reyong)))
  (test-eq "notes in order" 'ding2 (note-name (inst-note reyong 3)))
  (test-eq "location" loc (instrument-location reyong)))

(test-group "event record"
  (let ((e (make-event 4 2 '(0 3))))
    (test-assert "predicate" (event? e))
    (test-equal "start" 4 (event-start e))
    (test-equal "duration" 2 (event-duration e))
    (test-equal "notes" '(0 3) (event-notes e))))

(test-group "event record: times are exact rationals in pulses"
  (let ((e (make-event 3/2 1/4 '(1))))
    (test-equal "start" 3/2 (event-start e))
    (test-equal "duration" 1/4 (event-duration e))
    (test-assert "start stays exact" (exact? (event-start e)))))

(test-group "part record"
  (let* ((events (list (ev 0 1 0) (ev 1 1 1)))
         (p (make-part 'polos reyong events 'written '() loc)))
    (test-assert "predicate" (part? p))
    (test-eq "name" 'polos (part-name p))
    (test-eq "instrument" reyong (part-instrument p))
    (test-equal "events" events (part-events p))
    (test-eq "origin" 'written (part-origin p))
    (test-equal "spans: none" '() (part-spans p))
    (test-eq "location" loc (part-location p)))
  (test-equal "origin is one of written, timekeeper, colotomy"
    '(written timekeeper colotomy)
    (map (lambda (o) (part-origin (make-part 'x gong '() o '() loc)))
         '(written timekeeper colotomy)))
  (let* ((pat (make-pattern 'polos-1 reyong "1" "Norot polos on 1" loc))
         (s1 (make-pattern-span pat "1" "Norot polos on 1" 0 2 0))
         (s2 (make-pattern-span pat "6" "Norot polos on 6" 2 4 0))
         (p (make-part 'polos reyong (list (ev 0 1 3)) 'written (list s1 s2) loc)))
    (test-equal "spans, in order" (list s1 s2) (part-spans p))
    (test-eq "the location comes after the spans" loc (part-location p))))

(test-group "group record"
  (let* ((p (mk-part 'polos reyong))
         (s (mk-part 'sangsih reyong))
         (members (list (cons p "polos") (cons s "S.")))
         (g (make-group "Reyong" "Rey." "polos + sangsih" 'short 'parts
                        members 'pitch-display-name #t 'none 'dash 'long 1
                        'used #t #f 'pitch-display-name '()
                        'by-pitch '("#111111" "#eeeeee")
                        '((ding . "#000000")) 'vertical loc))
         (d (mk-group "polos" p)))
    (test-assert "predicate" (group? g))
    (test-equal "label" "Reyong" (group-label g))
    (test-equal "short" "Rey." (group-short g))
    (test-equal "subtitle" "polos + sangsih" (group-subtitle g))
    (test-eq "labels" 'short (group-labels g))
    (test-eq "rows" 'parts (group-rows g))
    (test-equal "members: (part . row-label), in order" members
      (group-members g))
    (test-assert "members hold the part records themselves"
      (and (eq? p (car (car (group-members g))))
           (eq? s (car (cadr (group-members g))))))
    (test-eq "note-label" 'pitch-display-name (group-note-label g))
    (test-eq "background" 'vertical (group-background g))
    (test-eq "fill" 'none (group-fill g))
    (test-eq "holds" 'dash (group-holds g))
    (test-eq "pattern-names" 'long (group-pattern-names g))
    (test-equal "pattern-level" 1 (group-pattern-level g))
    (test-eq "scheme" 'by-pitch (group-scheme g))
    (test-equal "palette: a list of colours" '("#111111" "#eeeeee")
      (group-palette g))
    (test-equal "colors" '((ding . "#000000")) (group-colors g))
    (test-eq "location" loc (group-location g))
    (test-equal "a default group: its settings"
      (list "polos" "polos" #f 'first-long 'notes (list (cons p "polos"))
            'none 'colour 'none 'none 0 'by-pitch 'pastel1 '() #f)
      (list (group-label d) (group-short d) (group-subtitle d)
            (group-labels d) (group-rows d) (group-members d)
            (group-note-label d) (group-fill d) (group-holds d)
            (group-pattern-names d) (group-pattern-level d)
            (group-scheme d) (group-palette d) (group-colors d)
            (group-location d)))
    (test-equal "palette: a name" 'set1
      (group-palette (mk-group* "x" (list p) #:palette 'set1)))
    (test-equal "the label may be empty" ""
      (group-label (mk-group* "" (list p) #:short "")))))

(test-group "score record"
  (let* ((p (mk-part 'polos reyong))
         (g (mk-group "Reyong" p))
         (sc (make-score 'full "Full score" "pangecet" "A caption"
                         1/2 15/2 4 '(2 6) #t #f 'gong-first 'empty "Cycle" "Beats"
                         "8pt" "3em" "1.5em" (list g) loc))
         (d (mk-score 'default (list g) #:title "Piece" #:to 8)))
    (test-assert "predicate" (score? sc))
    (test-eq "name" 'full (score-name sc))
    (test-equal "title" "Full score" (score-title sc))
    (test-eq "background" 'empty (score-background sc))
    (test-equal "subtitle" "pangecet" (score-subtitle sc))
    (test-equal "caption" "A caption" (score-caption sc))
    (test-equal "from" 1/2 (score-from sc))
    (test-equal "to" 15/2 (score-to sc))
    (test-equal "system-length" 4 (score-system-length sc))
    (test-equal "breaks" '(2 6) (score-breaks sc))
    (test-eq "cycle-numbers?" #t (score-cycle-numbers? sc))
    (test-eq "pulse-numbers?" #f (score-pulse-numbers? sc))
    (test-eq "numbering" 'gong-first (score-numbering sc))
    (test-equal "cycle-label" "Cycle" (score-cycle-label sc))
    (test-equal "pulse-label" "Beats" (score-pulse-label sc))
    (test-equal "font-size" "8pt" (score-font-size sc))
    (test-equal "cell-width" "3em" (score-cell-width sc))
    (test-equal "cell-height" "1.5em" (score-cell-height sc))
    (test-equal "groups" (list g) (score-groups sc))
    (test-eq "location" loc (score-location sc))
    (test-assert "times stay exact"
      (and (exact? (score-from sc)) (exact? (score-to sc))))
    (test-equal "a default score: its settings"
      (list 'default "Piece" #f #f 0 8 #f '() #f #t 'gong-last 'grid #f #f #f
            "2em" "2em" (list g) #f)
      (list (score-name d) (score-title d) (score-subtitle d)
            (score-caption d) (score-from d) (score-to d)
            (score-system-length d) (score-breaks d)
            (score-cycle-numbers? d) (score-pulse-numbers? d)
            (score-numbering d) (score-background d) (score-cycle-label d)
            (score-pulse-label d)
            (score-font-size d)
            (score-cell-width d) (score-cell-height d) (score-groups d)
            (score-location d)))
    (test-assert "a score is not a group, a group not a score"
      (not (or (group? sc) (score? g))))))

(test-group "piece record"
  (let* ((p (mk-part 'polos reyong (ev 0 1 0)))
         (g (mk-group "Reyong" p))
         (full (mk-score 'full (list g) #:title "Test" #:to 8))
         (other (mk-score 'other '() #:title "Test" #:to 8))
         (pat (make-pattern 'polos-1 reyong "1" "1" loc))
         (pc (make-piece "Test" 8 0 '()
                         (list selisir gong-strokes)
                         (list reyong gong)
                         (list pat)
                         (list p)
                         (list full other)
                         '())))
    (test-assert "predicate" (piece? pc))
    (test-equal "title" "Test" (piece-title pc))
    (test-equal "length" 8 (piece-length pc))
    (test-equal "pickup" 0 (piece-pickup pc))
    (test-equal "colotomies" '() (piece-colotomies pc))
    (test-equal "scales" (list selisir gong-strokes) (piece-scales pc))
    (test-equal "instruments" (list reyong gong) (piece-instruments pc))
    (test-equal "patterns" (list pat) (piece-patterns pc))
    (test-equal "parts" (list p) (piece-parts pc))
    (test-equal "scores, in order" (list full other) (piece-scores pc))
    (test-eq "piece-score: by name" full (piece-score pc 'full))
    (test-eq "piece-score: the second score" other (piece-score pc 'other))
    (test-eq "piece-score: a name with no score is #f" #f
      (piece-score pc 'nope))
    (test-equal "the score's groups" (list g)
      (score-groups (piece-score pc 'full))))
  (let* ((a (mk-score 'same '() #:title "first"))
         (b (mk-score 'same '() #:title "second"))
         (pc (make-piece "T" 0 0 '() '() '() '() '() (list a b) '())))
    (test-eq "piece-score looks the name up: the first with it" a
      (piece-score pc 'same)))
  (test-eq "piece-score: a piece with no scores" #f
    (piece-score (make-piece "T" 0 0 '() '() '() '() '() '() '()) 'default))
  (test-equal "length may be a fraction of a pulse" 9/2
    (piece-length (mk-piece "T" 9/2 '() '() '() '())))
  (test-equal "length stays exact" #t
    (exact? (piece-length (mk-piece "T" 1/3 '() '() '() '()))))
  (let* ((c (make-colotomy 'gilak 8 'kempli '() loc))
         (pc (make-piece "Gilak" 17 1 (list (cons 0 c)) '() '() '() '() '() '())))
    (test-equal "with a colotomy: pickup" 1 (piece-pickup pc))
    (test-equal "with a colotomy: colotomies are (start . colotomy)"
      (list (cons 0 c)) (piece-colotomies pc))
    (test-equal "with a colotomy: length includes the pickup" 17
      (piece-length pc))))

(test-group "colotomy record"
  (let* ((p (mk-part 'gong gong (ev 3 1 1) (ev 7 1 0)))
         (c (make-colotomy 'gilak 8 'kempli (list p) loc)))
    (test-assert "predicate" (colotomy? c))
    (test-eq "name" 'gilak (colotomy-name c))
    (test-equal "length" 8 (colotomy-length c))
    (test-eq "timekeeper" 'kempli (colotomy-timekeeper c))
    (test-equal "parts" (list p) (colotomy-parts c))
    (test-eq "location" loc (colotomy-location c))
    (test-assert "not a part or a piece"
      (not (or (part? c) (piece? c) (colotomy? p))))))

(test-group "pattern record"
  (let ((pat (make-pattern 'polos-1 reyong "1" "Norot polos on 1" loc)))
    (test-assert "predicate" (pattern? pat))
    (test-eq "name" 'polos-1 (pattern-name pat))
    (test-eq "instrument" reyong (pattern-instrument pat))
    (test-equal "short" "1" (pattern-short pat))
    (test-equal "long" "Norot polos on 1" (pattern-long pat))
    (test-eq "location" loc (pattern-location pat))))

(test-group "pattern-span record"
  (let* ((pat (make-pattern 'polos-1 reyong "1" "Norot polos on 1" loc))
         (s (make-pattern-span pat "6" "Norot polos on 6" 3/2 7/2 1)))
    (test-assert "predicate" (pattern-span? s))
    (test-eq "pattern" pat (pattern-span-pattern s))
    (test-equal "short: the names in force at the use" "6" (pattern-span-short s))
    (test-equal "long" "Norot polos on 6" (pattern-span-long s))
    (test-equal "start" 3/2 (pattern-span-start s))
    (test-equal "end" 7/2 (pattern-span-end s))
    (test-equal "depth" 1 (pattern-span-depth s))
    (test-assert "times stay exact"
      (and (exact? (pattern-span-start s)) (exact? (pattern-span-end s))))))

(test-assert "records are distinct types"
  (not (or (note? (ev 0 1 0))
           (event? (make-note 'dag 0 #f))
           (scale? reyong)
           (part? (mk-group "g"))
           (score? (mk-group "g"))
           (group? (mk-score 's '()))
           (piece? (mk-score 's '()))
           (pattern? (mk-part 'p reyong))
           (pattern-span? (make-pattern 'p reyong "p" "p" loc))
           (part? (make-pattern 'p reyong "p" "p" loc))
           (pattern? (make-pattern-span (make-pattern 'p reyong "p" "p" loc)
                                        "p" "p" 0 1 0)))))

;;; note-pitch-index

(test-group "note-pitch-index"
  (test-equal "ding2 = 2*5 + 0" 10
    (note-pitch-index reyong (pitched-note selisir 'ding 2)))
  (test-equal "dang1 = 1*5 + 4" 9
    (note-pitch-index reyong (pitched-note selisir 'dang 1)))
  (test-equal "deng1 = 1*5 + 2" 7
    (note-pitch-index reyong (inst-note reyong 0)))
  (test-equal "dang2 = 2*5 + 4" 14
    (note-pitch-index reyong (inst-note reyong 7)))
  (test-assert "dang1 is below ding2 (across octaves)"
    (< (note-pitch-index reyong (pitched-note selisir 'dang 1))
       (note-pitch-index reyong (pitched-note selisir 'ding 2))))
  (test-assert "instrument notes are strictly ascending"
    (let ((idx (map (lambda (n) (note-pitch-index reyong n))
                    (vector->list (instrument-notes reyong)))))
      (every < idx (cdr idx))))
  (test-equal "scale size comes from the instrument's scale" 3
    ;; plain scale has 2 degrees: dung1 = 1*2 + 1
    (note-pitch-index plain-instrument (inst-note plain-instrument 1)))
  ;; Check the irritants, not just that some error happened: an unbound
  ;; variable is an error too, and would pass a bare test-error.
  (test-equal "raises an error for a stroke, naming note and instrument"
    '(G gong)
    (guard (e ((error? e) (exception-irritants e)))
      (note-pitch-index gong (inst-note gong 0))))
  (test-equal "raises an error for a kendang stroke"
    '(dag kendang)
    (guard (e ((error? e) (exception-irritants e)))
      (note-pitch-index kendang (inst-note kendang 0)))))

;;; note-display

(test-group "note-display"
  (test-equal "ding2 -> \"i\"" "i" (note-display reyong (inst-note reyong 3)))
  (test-equal "dung1 -> \"u\"" "u" (note-display reyong (inst-note reyong 1)))
  (test-equal "octave does not change display" "u"
    (note-display reyong (inst-note reyong 6)))
  (test-equal "display defaulted to the degree name" "dung"
    (note-display plain-instrument (inst-note plain-instrument 1)))
  (test-equal "stroke with display option" "D"
    (note-display kendang (inst-note kendang 0)))
  (test-equal "stroke without display option" "du"
    (note-display kendang (inst-note kendang 2)))
  (test-equal "gong G" "G" (note-display gong (inst-note gong 0))))

;;; note-display #:damped? (slice feat/scores-rows)

;; baris: Tenzer's syllables, with damped forms for some degrees.
;;   ding "neng"/"ne'", dong "nong" (no damped form), dang "nang"/"na'".
(define baris
  (make-scale 'baris
              (list (make-pitch 'ding '(i) "neng" "ne'" loc)
                    (make-pitch 'dong '(o) "nong" #f loc)
                    (make-pitch 'dang '(a nang) "nang" "na'" loc))
              #t
              loc))

;; Indices: 0 ding1  1 dong1  2 dang1  3 ding2
(define suling
  (make-instrument 'suling baris
                   (vector (pitched-note baris 'ding 1)
                           (pitched-note baris 'dong 1)
                           (pitched-note baris 'dang 1)
                           (pitched-note baris 'ding 2))
                   loc))

;; kajar strokes: tak (display "T", damped "t"), tuk (no damped form).
(define kajar-strokes
  (make-scale 'kajar-strokes
              (list (make-pitch 'tak '() "T" "t" loc)
                    (make-pitch 'tuk '() "tuk" #f loc))
              #f
              loc))

(define kajar
  (make-instrument 'kajar kajar-strokes
                   (vector (stroke-note kajar-strokes 'tak)
                           (stroke-note kajar-strokes 'tuk))
                   loc))

(test-group "note-display #:damped?"
  (test-equal "#:damped? #t: the damped form" "na'"
    (note-display suling (inst-note suling 2) #:damped? #t))
  (test-equal "#:damped? #f: the display form" "nang"
    (note-display suling (inst-note suling 2) #:damped? #f))
  (test-equal "without #:damped?: the display form" "nang"
    (note-display suling (inst-note suling 2)))
  (test-equal "another degree's damped form" "ne'"
    (note-display suling (inst-note suling 0) #:damped? #t))
  (test-equal "the octave does not change the damped form" "ne'"
    (note-display suling (inst-note suling 3) #:damped? #t))
  (test-equal "no damped form: the display form" "nong"
    (note-display suling (inst-note suling 1) #:damped? #t))
  (test-equal "no damped form anywhere in the scale: the display form" "i"
    (note-display reyong (inst-note reyong 3) #:damped? #t))
  (test-equal "display defaulted to the degree name, damped? #t" "dung"
    (note-display plain-instrument (inst-note plain-instrument 1) #:damped? #t))
  (test-equal "a stroke's damped form" "t"
    (note-display kajar (inst-note kajar 0) #:damped? #t))
  (test-equal "a stroke's display form without #:damped?" "T"
    (note-display kajar (inst-note kajar 0)))
  (test-equal "a stroke without a damped form" "tuk"
    (note-display kajar (inst-note kajar 1) #:damped? #t))
  (test-equal "a stroke without either option, damped? #t" "du"
    (note-display kendang (inst-note kendang 2) #:damped? #t))
  (test-equal "note-row-label keeps the display form" "nang1"
    (note-row-label suling (inst-note suling 2))))

;;; note-row-label

(test-group "note-row-label"
  (test-equal "ding2 -> \"i2\"" "i2" (note-row-label reyong (inst-note reyong 3)))
  (test-equal "dang1 -> \"a1\"" "a1" (note-row-label reyong (inst-note reyong 2)))
  (test-equal "display defaulted to name, plus octave" "dung1"
    (note-row-label plain-instrument (inst-note plain-instrument 1)))
  (test-equal "stroke dag -> \"D\"" "D" (note-row-label kendang (inst-note kendang 0)))
  (test-equal "stroke du -> \"du\"" "du" (note-row-label kendang (inst-note kendang 2)))
  (test-equal "stroke G -> \"G\"" "G" (note-row-label gong (inst-note gong 0))))

;;; ------------------------------------------------------------------
;;; Slice feat/drawing-rows (iteration 3, milestone 2, slice 3; 04,
;;; "Slices (iteration 3)"; 02, "Records" and "Derived values"):
;;; `note-row-label` takes `#:octave?` (default #t): with #f, the display
;;; form alone. The group gains `keys` (used | all | (note . note)),
;;; `octave-numbers?`, `key-numbers?`, `row-labels?` and `display` (a
;;; list of (stroke-name . string)).
;;; Choices made where the docs are not explicit:
;;; - `make-group` takes the new fields where 02 lists them, after
;;;   `pattern-level`: (make-group label short subtitle labels rows
;;;   members note-names? fill holds pattern-names pattern-level keys
;;;   octave-numbers? key-numbers? row-labels? display scheme palette
;;;   colors background location). The fields before and after keep the
;;;   order the existing tests use (02 lists `background` before
;;;   `scheme`; the constructor has it after `colors`).
;;; - The record holds a range's notes as given; it checks nothing
;;;   (the reader does, invariant 10).
;;; - `#:octave?` does not change a stroke's label, and the label keeps
;;;   the display form, not the damped one.

(define (rows3-group . args)
  "make-group applied to ARGS, or the condition it raises, so that a
constructor of another arity fails the tests instead of the file."
  (guard (c (#t c)) (apply make-group args)))

(test-group "group record: keys, octave-numbers?, key-numbers?, row-labels?, display"
  (let* ((p (mk-part 'polos reyong))
         (members (list (cons p "polos")))
         (low (inst-note reyong 1))
         (high (inst-note reyong 5))
         (g (rows3-group "Reyong" "Rey." #f 'first-long 'notes members
                         'none #t 'colour 'none 'none 0
                         (cons low high) #f #t 'none '()
                         'by-pitch 'pastel1 '() 'grid loc))
         (k (mk-part 'gong gong))
         (s (rows3-group "Gong" "Gong" #f 'first-long 'notes
                         (list (cons k "gong"))
                         'none #t 'colour 'none 'none 0
                         'all #t #f 'pitch-display-name
                         '((G . "Gong") (P . "Kempur"))
                         'by-pitch 'pastel1 '() 'vertical loc)))
    (test-assert "predicate" (group? g))
    (test-assert "keys: a range, the note records themselves"
      (and (group? g)
           (eq? low (car (group-keys g)))
           (eq? high (cdr (group-keys g)))))
    (test-eq "row-label-octave?" #f (and (group? g) (group-row-label-octave? g)))
    (test-eq "key-numbers?" #t (and (group? g) (group-key-numbers? g)))
    (test-eq "row-labels" 'none (and (group? g) (group-row-labels g)))
    (test-equal "display: none" '() (and (group? g) (group-display g)))
    (test-eq "keys: all" 'all (and (group? s) (group-keys s)))
    (test-equal "display: strokes and their forms, in order"
      '((G . "Gong") (P . "Kempur"))
      (and (group? s) (group-display s)))
    (test-equal "the other fields keep their places"
      (list "Gong" 'notes 'none 0 'by-pitch 'pastel1 '() 'vertical loc)
      (and (group? s)
           (list (group-label s) (group-rows s) (group-note-label s)
                 (group-pattern-level s) (group-scheme s) (group-palette s)
                 (group-colors s) (group-background s) (group-location s))))
    (test-equal "keys: used"
      'used
      (let ((u (rows3-group "U" "U" #f 'first-long 'notes members
                            'none #t 'colour 'none 'none 0
                            'used #t #f 'pitch-display-name '()
                            'by-pitch 'pastel1 '() 'grid #f)))
        (and (group? u) (group-keys u))))))

;;; note-row-label #:octave? (slice feat/drawing-rows)

(test-group "note-row-label #:octave?"
  (test-equal "#:octave? #f: the display form alone" "i"
    (note-row-label reyong (inst-note reyong 3) #:octave? #f))
  (test-equal "deng1 and deng2: the same label" '("e" "e")
    (list (note-row-label reyong (inst-note reyong 0) #:octave? #f)
          (note-row-label reyong (inst-note reyong 5) #:octave? #f)))
  (test-equal "dang1 without its octave" "a"
    (note-row-label reyong (inst-note reyong 2) #:octave? #f))
  (test-equal "#:octave? #t: the octave as before" "i2"
    (note-row-label reyong (inst-note reyong 3) #:octave? #t))
  (test-equal "without #:octave?: the octave" "a1"
    (note-row-label reyong (inst-note reyong 2)))
  (test-equal "display defaulted to the degree name" "dung"
    (note-row-label plain-instrument (inst-note plain-instrument 1) #:octave? #f))
  (test-equal "the display form, not the damped one" "nang"
    (note-row-label suling (inst-note suling 2) #:octave? #f))
  (test-equal "a stroke: its display form, #:octave? #f" "D"
    (note-row-label kendang (inst-note kendang 0) #:octave? #f))
  (test-equal "a stroke: its display form, #:octave? #t" "D"
    (note-row-label kendang (inst-note kendang 0) #:octave? #t))
  (test-equal "a stroke without a display option" "du"
    (note-row-label kendang (inst-note kendang 2) #:octave? #f)))


;;; group-row-keys

(test-group "group-row-keys"
  (let* ((p (mk-part 'polos reyong
                     (ev 0 1 3) (ev 1 1 1) (ev 2 1 3) (ev 3 1 5)))
         (lanes (group-row-keys (mk-group "R" p))))
    (test-assert "returns note records" (every note? lanes))
    (test-assert "the instrument's own note records"
      (every (lambda (n) (any (lambda (m) (eq? n m))
                              (vector->list (instrument-notes reyong))))
             lanes))
    (test-equal "pitched: only used notes, each once, highest first"
      '(deng2 ding2 dung1)
      (map note-name lanes)))

  (test-equal "notes from chords are included and sorted"
    '(dang2 dong2 ding2 deng1)
    (lane-names (mk-group "R" (mk-part 'polos reyong
                                       (ev 0 1 3)
                                       (ev 1 2 0 7)
                                       (ev 3 1 4 3)))))

  (test-equal "polos + sangsih on one instrument are merged"
    '(dung2 deng2 dong2 ding2 dang1)
    (lane-names
     (mk-group "Reyong"
               (mk-part 'polos reyong (ev 0 1 3) (ev 1 1 4) (ev 3 1 3))
               (mk-part 'sangsih reyong (ev 0 1 6) (ev 2 1 5) (ev 3 1 2 4)))))

  (test-equal "a note used by both parts appears once"
    '(ding2)
    (lane-names
     (mk-group "Reyong"
               (mk-part 'polos reyong (ev 0 1 3))
               (mk-part 'sangsih reyong (ev 1 1 3)))))

  (test-equal "no events: no lanes" '()
    (lane-names (mk-group "R" (mk-part 'polos reyong))))

  (test-equal "strokes follow the instrument's order, not play order"
    '(dag du)
    (lane-names (mk-group "Kendang"
                          (mk-part 'kendang kendang
                                   (ev 0 1 2) (ev 1 1 2) (ev 2 1 0)))))

  (test-equal "strokes: every listed stroke used"
    '(dag dug du)
    (lane-names (mk-group "Kendang"
                          (mk-part 'kendang kendang
                                   (ev 0 1 1) (ev 1 1 2) (ev 2 1 0)))))

  (test-equal "two stroke instruments: kempli then gong"
    '(K G P)
    (lane-names (mk-group "Pulse"
                          (mk-part 'kempli kempli (ev 0 1 0) (ev 4 1 0))
                          (mk-part 'gong gong (ev 0 1 1) (ev 7 1 0)))))

  (test-equal "two stroke instruments: gong then kempli"
    '(G P K)
    (lane-names (mk-group "Pulse"
                          (mk-part 'gong gong (ev 0 1 1) (ev 7 1 0))
                          (mk-part 'kempli kempli (ev 0 1 0) (ev 4 1 0)))))

  (test-equal "two stroke instruments: unused strokes left out"
    '(P K)
    (lane-names (mk-group "Pulse"
                          (mk-part 'gong gong (ev 0 1 1))
                          (mk-part 'kempli kempli (ev 0 1 0))))))

;;; part-end

(test-group "part-end"
  (test-equal "end of last event" 8
    (part-end (mk-part 'p reyong (ev 0 1 0) (ev 4 4 1))))
  (test-equal "single held note" 3
    (part-end (mk-part 'p reyong (ev 0 3 0))))
  (test-equal "no events" 0
    (part-end (mk-part 'p reyong)))
  (test-equal "trailing rests are not counted" 3
    ;; e.g. "1 - 2 - - -": events at 0 and 2, part ends at 3
    (part-end (mk-part 'p reyong (ev 0 1 0) (ev 2 1 1))))
  (test-equal "leading rests" 6
    (part-end (mk-part 'p kempli (ev 5 1 0))))
  (test-equal "fractions of a pulse: exact" 7/4
    (part-end (mk-part 'p reyong (ev 0 1/4 0) (ev 3/2 1/4 1))))
  (test-assert "the end stays exact"
    (exact? (part-end (mk-part 'p reyong (ev 1/3 1/3 0))))))

;;; events-at

(let* ((e-p0 (ev 0 1 3))
       (e-p1 (ev 1 3 4))                ; held over pulses 1, 2, 3
       (e-p6 (ev 6 1 3 5))              ; chord
       (polos (mk-part 'polos reyong e-p0 e-p1 e-p6))
       (e-s0 (ev 0 2 6))                ; held over pulses 0, 1
       (e-s3 (ev 3 1 5))
       (e-s6 (ev 6 1 2))
       (sangsih (mk-part 'sangsih reyong e-s0 e-s3 e-s6))
       (e-k0 (ev 0 1 0))
       (e-k6 (ev 6 1 0))
       (kp (mk-part 'kempli kempli e-k0 e-k6))
       (pc (mk-piece "Test" 8
                       (list selisir kempli-strokes)
                       (list reyong kempli)
                       (list polos sangsih kp)
                       (list (mk-group "Reyong" polos sangsih)
                             (mk-group "kempli" kp)))))

  (define (names+events pairs)
    (map (match-lambda ((part . event) (cons (part-name part) event)))
         pairs))

  (test-group "events-at"
    (test-assert "returns pairs of part and event"
      (every (match-lambda ((p . e) (and (part? p) (event? e))))
             (events-at pc 0)))
    (test-equal "time 0: all three parts, in piece part order"
      (list (cons 'polos e-p0) (cons 'sangsih e-s0) (cons 'kempli e-k0))
      (names+events (events-at pc 0)))
    (test-assert "the pair holds the part record itself"
      (eq? polos (car (car (events-at pc 0)))))
    (test-assert "the pair holds the event record itself"
      (eq? e-p0 (cdr (car (events-at pc 0)))))
    (test-equal "time 1: event start and a hold from time 0"
      (list (cons 'polos e-p1) (cons 'sangsih e-s0))
      (names+events (events-at pc 1)))
    (test-equal "time 2: hold covers the time; time = start+duration excluded"
      (list (cons 'polos e-p1))
      (names+events (events-at pc 2)))
    (test-equal "time 3: last held pulse of polos plus a sangsih start"
      (list (cons 'polos e-p1) (cons 'sangsih e-s3))
      (names+events (events-at pc 3)))
    (test-equal "time 4: polos event ended (start + duration = 4)"
      '()
      (events-at pc 4))
    (test-equal "time 5: everything rests" '() (events-at pc 5))
    (test-equal "time 6: a chord appears as one event"
      (list (cons 'polos e-p6) (cons 'sangsih e-s6) (cons 'kempli e-k6))
      (names+events (events-at pc 6)))
    (test-equal "time 6: chord keeps all its notes" '(3 5)
      (event-notes (cdr (car (events-at pc 6)))))
    (test-equal "time 7: last pulse, nothing sounding" '() (events-at pc 7))
    (test-equal "time 1/2: between pulses, the events sounding then"
      (list (cons 'polos e-p0) (cons 'sangsih e-s0) (cons 'kempli e-k0))
      (names+events (events-at pc 1/2)))
    (test-equal "time 7/2: inside a held note"
      (list (cons 'polos e-p1) (cons 'sangsih e-s3))
      (names+events (events-at pc 7/2)))
    (test-equal "time 11/2: a rest" '() (events-at pc 11/2))))

(let* ((e1 (ev 0 1/4 0))
       (e2 (ev 1/4 1/4 1))
       (e3 (ev 3/4 1/4 2))
       (p (mk-part 'polos reyong e1 e2 e3))
       (pc (mk-piece "Quarters" 1 (list selisir) (list reyong) (list p)
                       (list (mk-group "R" p)))))
  (define (events-at* time) (map cdr (events-at pc time)))
  (test-group "events-at: fractions of a pulse"
    (test-equal "time 0" (list e1) (events-at* 0))
    (test-equal "time 1/8: inside the first quarter" (list e1)
      (events-at* 1/8))
    (test-equal "time 1/4: end of the first excluded, the second starts"
      (list e2) (events-at* 1/4))
    (test-equal "time 1/2: a rest" '() (events-at* 1/2))
    (test-equal "time 3/4" (list e3) (events-at* 3/4))
    (test-equal "time 1: after the last" '() (events-at* 1))))

(let* ((a (mk-part 'a kempli (ev 0 1 0)))
       (b (mk-part 'b kempli (ev 0 1 0)))
       (pc (mk-piece "Order" 4 '() (list kempli) (list b a)
                       (list (mk-group "x" b a)))))
  (test-equal "events-at follows piece-parts order, not part names"
    '(b a)
    (map (lambda (pr) (part-name (car pr))) (events-at pc 0))))

;;; time->position and position->time (02, "Derived values"): with a
;;; pickup P and a cycle of N pulses, TIME is cycle floor((TIME-P)/N)+1,
;;; pulse (TIME-P) mod N + 1; the pickup is cycle 0. Without a colotomy,
;;; the pulse number TIME + 1.

(define gilak (make-colotomy 'gilak 8 'kempli '() loc))

(define (colotomy-piece length pickup)
  (make-piece "Gilak" length pickup (list (cons 0 gilak))
              (list gong-strokes) (list gong) '() '() '() '()))

(define no-pickup (colotomy-piece 16 0))
(define pickup-1 (colotomy-piece 17 1))
(define pickup-8 (colotomy-piece 16 8))
(define plain (mk-piece "Plain" 10 '() '() '() '()))

(test-group "time->position: a colotomy, no pickup"
  (for-each
   (match-lambda
     ((time position)
      (test-equal (format #f "time ~a" time) position
        (time->position no-pickup time))))
   '((0 (1 1)) (1 (1 2)) (7 (1 8)) (8 (2 1)) (15 (2 8))
     (16 (3 1))
     (1/2 (1 3/2)) (7/2 (1 9/2)) (31/4 (1 35/4)) (17/2 (2 3/2))))
  (test-assert "the pulse stays exact"
    (exact? (cadr (time->position no-pickup 7/2)))))

(test-group "time->position: a pickup of one pulse is cycle 0"
  (for-each
   (match-lambda
     ((time position)
      (test-equal (format #f "time ~a" time) position
        (time->position pickup-1 time))))
   '((0 (0 8)) (1/2 (0 17/2)) (1 (1 1)) (2 (1 2)) (8 (1 8))
     (9 (2 1)) (16 (2 8)) (33/2 (2 17/2)))))

(test-group "time->position: a pickup of a whole cycle"
  (for-each
   (match-lambda
     ((time position)
      (test-equal (format #f "time ~a" time) position
        (time->position pickup-8 time))))
   '((0 (0 1)) (7 (0 8)) (8 (1 1)) (15 (1 8)) (3/2 (0 5/2)))))

(test-group "time->position: no colotomy, a pulse number"
  (for-each
   (match-lambda
     ((time pulse)
      (test-equal (format #f "time ~a" time) pulse
        (time->position plain time))))
   '((0 1) (1 2) (9 10) (3/2 5/2) (1/4 5/4)))
  (test-assert "a number, not a list" (number? (time->position plain 3))))

(test-group "position->time"
  (for-each
   (match-lambda
     ((name pc cycle pulse time)
      (test-equal name time (position->time pc cycle pulse))))
   (list (list "no pickup: cycle 1, pulse 1" no-pickup 1 1 0)
         (list "no pickup: cycle 1, pulse 8" no-pickup 1 8 7)
         (list "no pickup: cycle 2, pulse 1" no-pickup 2 1 8)
         (list "no pickup: cycle 2, pulse 4 1/2" no-pickup 2 9/2 23/2)
         (list "pickup 1: cycle 0, pulse 8" pickup-1 0 8 0)
         (list "pickup 1: cycle 0, pulse 8 1/2" pickup-1 0 17/2 1/2)
         (list "pickup 1: cycle 1, pulse 1" pickup-1 1 1 1)
         (list "pickup 1: cycle 2, pulse 8" pickup-1 2 8 16)
         (list "pickup 8: cycle 0, pulse 1" pickup-8 0 1 0)
         (list "pickup 8: cycle 1, pulse 1" pickup-8 1 1 8)))
  (for-each
   (match-lambda
     ((pulse time)
      (test-equal (format #f "no colotomy: pulse ~a" pulse) time
        (position->time plain pulse))))
   '((1 0) (2 1) (10 9) (5/2 3/2)))
  (test-assert "the time stays exact"
    (exact? (position->time pickup-1 0 17/2))))

(test-group "position->time inverts time->position"
  (for-each
   (lambda (pc)
     (for-each
      (lambda (time)
        (test-equal (format #f "~a, time ~a" (piece-pickup pc) time) time
          (apply position->time pc (time->position pc time))))
      '(0 1/2 1 7 15/2 8 9 13/4 16)))
   (list no-pickup pickup-1 pickup-8))
  (for-each
   (lambda (time)
     (test-equal (format #f "no colotomy, time ~a" time) time
       (position->time plain (time->position plain time))))
   '(0 1/3 1 9)))

;;; ------------------------------------------------------------------
;;; Slice feat/collapsed-terms: the glossary's names, the piece's info

(define (exported-by-piece? name)
  "Does (notasi piece) export NAME?"
  (and (module-variable (resolve-interface '(notasi piece)) name) #t))

(define (a-pitch)
  (make-pitch 'dang '(a nang) "nang" "na'" loc))

(define (a-plain-pitch)
  (make-pitch 'du '() "du" #f loc))

(define (pitch-scale)
  "selisir built from pitch records: ding dong deng, aliases i o e."
  (make-scale 'selisir
              (list (make-pitch 'ding '(i) "i" #f loc)
                    (make-pitch 'dong '(o) "o" #f loc)
                    (make-pitch 'deng '(e) "e" "e'" loc))
              #t
              loc))

(define (raises? thunk)
  "Does THUNK raise anything?"
  (guard (c (#t #t))
    (thunk)
    #f))

(test-group "[collapsed-terms] pitch record"
  (test-assert "predicate" (pitch? (a-pitch)))
  (test-eq "name" 'dang (pitch-name (a-pitch)))
  (test-equal "aliases" '(a nang) (pitch-aliases (a-pitch)))
  (test-equal "display" "nang" (pitch-display (a-pitch)))
  (test-equal "damped" "na'" (pitch-damped (a-pitch)))
  (test-eq "location" loc (pitch-location (a-pitch)))
  (test-equal "aliases may be empty" '() (pitch-aliases (a-plain-pitch)))
  (test-eq "damped may be #f" #f (pitch-damped (a-plain-pitch)))
  (test-assert "a pitch is not a scale, a scale not a pitch"
    (not (or (scale? (a-pitch)) (pitch? (pitch-scale))))))

(test-group "[collapsed-terms] scale-pitches and note-pitch"
  (test-equal "scale-pitches: the pitches in order" '(ding dong deng)
    (map pitch-name (scale-pitches (pitch-scale))))
  (test-assert "scale-pitches: pitch records"
    (every pitch? (scale-pitches (pitch-scale))))
  (test-equal "note-pitch: the index into the scale" 2
    (note-pitch (make-note 'deng1 2 1)))
  (test-equal "note-pitch of a stroke: the index into the stroke set" 0
    (note-pitch (make-note 'dag 0 #f)))
  (test-equal "note-display uses the pitch's display form" "e"
    (let* ((s (pitch-scale))
           (n (make-note 'deng1 2 1))
           (i (make-instrument 'x s (vector n) loc)))
      (note-display i n)))
  (test-equal "note-display #:damped? uses the pitch's damped form" "e'"
    (let* ((s (pitch-scale))
           (n (make-note 'deng1 2 1))
           (i (make-instrument 'x s (vector n) loc)))
      (note-display i n #:damped? #t))))

(test-group "[collapsed-terms] the old names are gone"
  (for-each
   (lambda (name)
     (test-assert (format #f "~a is not exported" name)
       (not (exported-by-piece? name))))
   '(make-degree degree? degree-name degree-aliases degree-display
     degree-damped degree-location scale-degrees note-degree))
  (for-each
   (lambda (name)
     (test-assert (format #f "~a is exported" name)
       (exported-by-piece? name)))
   '(make-pitch pitch? pitch-name pitch-aliases pitch-display
     pitch-damped pitch-location scale-pitches note-pitch piece-info)))

(define (make-piece* . args)
  "make-piece called through apply: Guile checks a record constructor's
argument count when the call is compiled, so a direct call with the
wrong count would stop the whole file instead of failing one test."
  (apply make-piece args))

(define (piece-with-info info)
  "A piece with nothing in it but INFO, its last argument."
  (make-piece* "T" 0 0 '() '() '() '() '() '() info))

(test-group "[collapsed-terms] piece info"
  (test-equal "piece-info: the last argument of make-piece"
    '((composer . "I Wayan Beratha") (composition-year . "1964"))
    (piece-info (piece-with-info
                 '((composer . "I Wayan Beratha") (composition-year . "1964")))))
  (test-equal "piece-info: '() for none" '()
    (piece-info (piece-with-info '())))
  (test-equal "piece-info keeps its order and line breaks"
    '((remarks . "line one\nline two") (source . "Gold"))
    (piece-info (piece-with-info
                 '((remarks . "line one\nline two") (source . "Gold")))))
  (test-equal "the other fields are where they were"
    (list "Full" 8 1 '() '() '() '() '() '())
    (let ((pc (make-piece* "Full" 8 1 '() '() '() '() '() '()
                          '((composer . "X")))))
      (list (piece-title pc) (piece-length pc) (piece-pickup pc)
            (piece-colotomies pc) (piece-scales pc) (piece-instruments pc)
            (piece-patterns pc) (piece-parts pc) (piece-scores pc))))
  (test-assert "make-piece without info raises"
    (raises? (lambda () (make-piece* "T" 0 0 '() '() '() '() '() '())))))

;;; ------------------------------------------------------------------
;;; Slice feat/collapsed-labels (iteration 5; 02, "Iteration 5", ADR
;;; 0054): the group's `note-label`, `note-label-octave?`, `row-labels`
;;; and `row-label-octave?` in place of `note-names?`,
;;; `octave-numbers?` and `row-labels?`; `group-lanes` renamed
;;; `group-row-keys` and the procedure `note-label` (the row label)
;;; renamed `note-row-label`.
;;; Choices made where the docs are not explicit:
;;; - make-group's order follows 02's paragraph: (make-group label short
;;;   subtitle labels rows members note-label note-label-octave? fill
;;;   holds pattern-names pattern-level keys row-label-octave?
;;;   key-numbers? row-labels display scheme palette colors background
;;;   location), 22 arguments; the old 21 raise.
;;; - The new names are looked up in (notasi piece)'s interface when a
;;;   test runs, and make-group is called through apply, so the file
;;;   compiles before the code exists.
;;; - The record holds the symbols as given; it checks nothing (the
;;;   reader does).

(define (piece-proc name)
  "The procedure (notasi piece) exports as NAME, or one that raises when
called, so that a missing export fails one test, not the file."
  (let* ((interface (resolve-interface '(notasi piece)))
         (v (module-variable interface name)))
    (cond ((not v)
           (lambda args (error "not exported by (notasi piece):" name)))
          ;; A record accessor is a macro that names its procedure when
          ;; used as a value; evaluating the name gives the procedure.
          ((macro? (variable-ref v)) (eval name (resolve-module '(notasi piece))))
          (else (variable-ref v)))))

(define (labels-make-group . args)
  "make-group applied to ARGS, or the condition it raises."
  (guard (c (#t c)) (apply make-group args)))

(define* (labels-group label parts
                       #:key (rows 'notes) (note-label 'none)
                       (note-label-octave? #t) (fill 'colour) (keys 'used)
                       (row-label-octave? #t) (key-numbers? #f)
                       (row-labels 'pitch-display-name) (display '())
                       (location #f))
  "A group of PARTS with this slice's fields, through make-group's new
order (02), every other setting at its default; or the condition
make-group raises."
  (labels-make-group
   label label #f 'first-long rows
   (map (lambda (p) (cons p (symbol->string (part-name p)))) parts)
   note-label note-label-octave? fill 'none 'none 0
   keys row-label-octave? key-numbers? row-labels display
   'by-pitch 'pastel1 '() 'grid location))

(define (group-field name g)
  "The value of the accessor NAME on G, or #f when G is not a group."
  (and (group? g) ((piece-proc name) g)))

(test-group "[collapsed-labels] group record: the label fields"
  (let* ((p (mk-part 'polos reyong))
         (members (list (cons p "Polos")))
         (low (inst-note reyong 1))
         (high (inst-note reyong 5))
         (g (labels-make-group "Reyong" "Rey." "sub" 'short 'parts members
                               'key-number #f 'none 'dash 'long 2
                               (cons low high) #f #t 'pitch-name
                               '((G . "Gong"))
                               'by-pitch '("#111111") '((ding . "#000000"))
                               'vertical loc)))
    (test-assert "make-group takes 22 arguments" (group? g))
    (test-eq "note-label" 'key-number (group-field 'group-note-label g))
    (test-eq "note-label-octave?" #f (group-field 'group-note-label-octave? g))
    (test-eq "row-label-octave?" #f (group-field 'group-row-label-octave? g))
    (test-eq "row-labels: a symbol" 'pitch-name (group-field 'group-row-labels g))
    (test-equal "the other fields keep their places"
      (list "Reyong" "Rey." "sub" 'short 'parts members 'none 'dash 'long 2
            #t '((G . "Gong")) 'by-pitch '("#111111") '((ding . "#000000"))
            'vertical loc)
      (and (group? g)
           (list (group-label g) (group-short g) (group-subtitle g)
                 (group-labels g) (group-rows g) (group-members g)
                 (group-fill g) (group-holds g) (group-pattern-names g)
                 (group-pattern-level g) (group-key-numbers? g)
                 (group-display g) (group-scheme g) (group-palette g)
                 (group-colors g) (group-background g) (group-location g))))
    (test-assert "keys: the range's note records, in its place"
      (and (group? g)
           (eq? low (car (group-keys g)))
           (eq? high (cdr (group-keys g))))))
  (let ((g (labels-group "U" (list (mk-part 'polos reyong)))))
    (test-equal "the defaults as the reader fills them: none, yes, pitch-display-name, yes"
      '(none #t pitch-display-name #t)
      (map (lambda (name) (group-field name g))
           '(group-note-label group-note-label-octave?
             group-row-labels group-row-label-octave?))))
  (for-each
   (lambda (value)
     (test-eq (format #f "note-label ~a" value) value
       (group-field 'group-note-label
                    (labels-group "U" (list (mk-part 'polos reyong))
                                  #:note-label value))))
   '(none pitch-name pitch-display-name key-number))
  (for-each
   (lambda (value)
     (test-eq (format #f "row-labels ~a" value) value
       (group-field 'group-row-labels
                    (labels-group "U" (list (mk-part 'polos reyong))
                                  #:row-labels value))))
   '(none pitch-name pitch-display-name))
  (test-assert "make-group with the old 21 arguments raises"
    (raises? (lambda ()
               (apply make-group
                      (list "U" "U" #f 'first-long 'notes '()
                            #f 'colour 'none 'none 0
                            'used #t #f #t '()
                            'by-pitch 'pastel1 '() 'grid #f))))))

(test-group "[collapsed-labels] the new names are exported, the old ones gone"
  (for-each
   (lambda (name)
     (test-assert (format #f "~a is exported" name) (exported-by-piece? name)))
   '(group-note-label group-note-label-octave? group-row-labels
     group-row-label-octave? group-row-keys note-row-label))
  (for-each
   (lambda (name)
     (test-assert (format #f "~a is not exported" name)
       (not (exported-by-piece? name))))
   '(group-note-names? group-octave-numbers? group-row-labels?
     group-lanes note-label)))

(test-group "[collapsed-labels] note-row-label: note-label renamed"
  (let ((row-label (lambda args (apply (piece-proc 'note-row-label) args))))
    (test-equal "ding2 -> \"i2\"" "i2" (row-label reyong (inst-note reyong 3)))
    (test-equal "dang1 -> \"a1\"" "a1" (row-label reyong (inst-note reyong 2)))
    (test-equal "#:octave? #f: the pitch display name alone" "i"
      (row-label reyong (inst-note reyong 3) #:octave? #f))
    (test-equal "#:octave? #t: with the octave" "i2"
      (row-label reyong (inst-note reyong 3) #:octave? #t))
    (test-equal "display defaulted to the pitch name" "dung1"
      (row-label plain-instrument (inst-note plain-instrument 1)))
    (test-equal "the display form, not the damped one" "nang"
      (row-label suling (inst-note suling 2) #:octave? #f))
    (test-equal "a stroke: its display name" "D"
      (row-label kendang (inst-note kendang 0)))
    (test-equal "a stroke: #:octave? changes nothing" "D"
      (row-label kendang (inst-note kendang 0) #:octave? #f))
    (test-equal "a stroke without a display option" "du"
      (row-label kendang (inst-note kendang 2)))))

(test-group "[collapsed-labels] group-row-keys: group-lanes renamed"
  (let ((row-keys (lambda (g)
                    (and (group? g)
                         (map note-name ((piece-proc 'group-row-keys) g))))))
    (test-equal "pitched: only used notes, each once, highest first"
      '(deng2 ding2 dung1)
      (row-keys (labels-group "R" (list (mk-part 'polos reyong
                                                 (ev 0 1 3) (ev 1 1 1)
                                                 (ev 2 1 3) (ev 3 1 5))))))
    (test-assert "the instrument's own note records"
      (let ((g (labels-group "R" (list (mk-part 'polos reyong (ev 0 1 3))))))
        (and (group? g)
             (eq? (inst-note reyong 3)
                  (car ((piece-proc 'group-row-keys) g))))))
    (test-equal "chords and two parts merged, highest first"
      '(dung2 deng2 dong2 ding2 dang1)
      (row-keys (labels-group
                 "Reyong"
                 (list (mk-part 'polos reyong (ev 0 1 3) (ev 1 1 4) (ev 3 1 3))
                       (mk-part 'sangsih reyong (ev 0 1 6) (ev 2 1 5)
                                (ev 3 1 2 4))))))
    (test-equal "no events: no rows" '()
      (row-keys (labels-group "R" (list (mk-part 'polos reyong)))))
    (test-equal "strokes follow the instrument's order" '(dag du)
      (row-keys (labels-group "Kendang"
                              (list (mk-part 'kendang kendang
                                             (ev 0 1 2) (ev 1 1 2) (ev 2 1 0))))))
    (test-equal "two stroke instruments: a block each, in part order" '(K G P)
      (row-keys (labels-group "Pulse"
                              (list (mk-part 'kempli kempli (ev 0 1 0) (ev 4 1 0))
                                    (mk-part 'gong gong (ev 0 1 1) (ev 7 1 0))))))))

(define runner (test-runner-current))
(test-end "piece")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
