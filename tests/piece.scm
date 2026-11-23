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
  (make-degree name (if alias (list alias) '()) display #f loc))

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
  (list-index (lambda (d) (eq? (degree-name d) name)) (scale-degrees scale)))

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
  (make-part name instrument events 'written loc))

(define (mk-piece title length scales instruments parts groups)
  "A piece without a colotomy: pickup 0, no colotomies."
  (make-piece title length 0 '() scales instruments parts groups))

(define (mk-group label . parts)
  (make-group label #f parts #f))

(define (lane-names group)
  (map note-name (group-lanes group)))

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
  (let ((d (make-degree 'dang '(a nang) "nang" "na'" loc)))
    (test-assert "predicate" (degree? d))
    (test-eq "name" 'dang (degree-name d))
    (test-equal "aliases" '(a nang) (degree-aliases d))
    (test-equal "display" "nang" (degree-display d))
    (test-equal "damped" "na'" (degree-damped d))
    (test-eq "location" loc (degree-location d)))
  (test-equal "aliases may be empty" '()
    (degree-aliases (make-degree 'du '() "du" #f loc)))
  (test-eq "damped may be #f" #f
    (degree-damped (make-degree 'du '() "du" #f loc))))

(test-group "scale record"
  (test-assert "predicate" (scale? selisir))
  (test-eq "name" 'selisir (scale-name selisir))
  (test-equal "degrees" '(ding dong deng dung dang)
    (map degree-name (scale-degrees selisir)))
  (test-eq "pitched? #t" #t (scale-pitched? selisir))
  (test-eq "pitched? #f for a stroke set" #f (scale-pitched? gong-strokes))
  (test-eq "location" loc (scale-location selisir)))

(test-group "note record"
  (let ((n (make-note 'ding2 0 2))
        (s (make-note 'dag 0 #f)))
    (test-assert "predicate" (note? n))
    (test-eq "name" 'ding2 (note-name n))
    (test-equal "degree" 0 (note-degree n))
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
         (p (make-part 'polos reyong events 'written loc)))
    (test-assert "predicate" (part? p))
    (test-eq "name" 'polos (part-name p))
    (test-eq "instrument" reyong (part-instrument p))
    (test-equal "events" events (part-events p))
    (test-eq "origin" 'written (part-origin p))
    (test-eq "location" loc (part-location p)))
  (test-equal "origin is one of written, timekeeper, colotomy"
    '(written timekeeper colotomy)
    (map (lambda (o) (part-origin (make-part 'x gong '() o loc)))
         '(written timekeeper colotomy))))

(test-group "group record"
  (let* ((p (mk-part 'polos reyong))
         (g (make-group "Reyong" "polos + sangsih" (list p) loc))
         (d (make-group "polos" #f (list p) #f)))
    (test-assert "predicate" (group? g))
    (test-equal "label" "Reyong" (group-label g))
    (test-equal "subtitle" "polos + sangsih" (group-subtitle g))
    (test-equal "parts" (list p) (group-parts g))
    (test-eq "location" loc (group-location g))
    (test-eq "default group: subtitle #f" #f (group-subtitle d))
    (test-eq "default group: location #f" #f (group-location d))))

(test-group "piece record"
  (let* ((p (mk-part 'polos reyong (ev 0 1 0)))
         (g (mk-group "Reyong" p))
         (pc (make-piece "Test" 8 0 '()
                         (list selisir gong-strokes)
                         (list reyong gong)
                         (list p)
                         (list g))))
    (test-assert "predicate" (piece? pc))
    (test-equal "title" "Test" (piece-title pc))
    (test-equal "length" 8 (piece-length pc))
    (test-equal "pickup" 0 (piece-pickup pc))
    (test-equal "colotomies" '() (piece-colotomies pc))
    (test-equal "scales" (list selisir gong-strokes) (piece-scales pc))
    (test-equal "instruments" (list reyong gong) (piece-instruments pc))
    (test-equal "parts" (list p) (piece-parts pc))
    (test-equal "groups" (list g) (piece-groups pc)))
  (test-equal "length may be a fraction of a pulse" 9/2
    (piece-length (mk-piece "T" 9/2 '() '() '() '())))
  (test-equal "length stays exact" #t
    (exact? (piece-length (mk-piece "T" 1/3 '() '() '() '()))))
  (let* ((c (make-colotomy 'gilak 8 'kempli '() loc))
         (pc (make-piece "Gilak" 17 1 (list (cons 0 c)) '() '() '() '())))
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

(test-assert "records are distinct types"
  (not (or (note? (ev 0 1 0))
           (event? (make-note 'dag 0 #f))
           (scale? reyong)
           (part? (mk-group "g")))))

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

;;; note-label

(test-group "note-label"
  (test-equal "ding2 -> \"i2\"" "i2" (note-label reyong (inst-note reyong 3)))
  (test-equal "dang1 -> \"a1\"" "a1" (note-label reyong (inst-note reyong 2)))
  (test-equal "display defaulted to name, plus octave" "dung1"
    (note-label plain-instrument (inst-note plain-instrument 1)))
  (test-equal "stroke dag -> \"D\"" "D" (note-label kendang (inst-note kendang 0)))
  (test-equal "stroke du -> \"du\"" "du" (note-label kendang (inst-note kendang 2)))
  (test-equal "stroke G -> \"G\"" "G" (note-label gong (inst-note gong 0))))

;;; group-lanes

(test-group "group-lanes"
  (let* ((p (mk-part 'polos reyong
                     (ev 0 1 3) (ev 1 1 1) (ev 2 1 3) (ev 3 1 5)))
         (lanes (group-lanes (mk-group "R" p))))
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
              (list gong-strokes) (list gong) '() '()))

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

(define runner (test-runner-current))
(test-end "piece")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
