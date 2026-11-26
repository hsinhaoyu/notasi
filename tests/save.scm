;;; Tests for (notasi save): saving the piece (ADR 0058).
;;;
;;; Written from doc/design/02-piece.md ("Saving the piece", with "The
;;; format, decided for `feat/save-piece`", and the records above it)
;;; and ADR 0058, not from the implementation.
;;;
;;; Choices where the spec leaves room (also noted at the tests):
;;; - (notasi save) is looked up at run time (resolve-interface), so
;;;   while it doesn't exist every test fails instead of the file
;;;   stopping.
;;; - A JSON value is as (notasi json) takes it: an object is an alist
;;;   (its keys symbols or strings, both accepted here), an array a
;;;   vector, null the symbol `null'.  An empty object (`info' with no
;;;   information) is '(), which (notasi json) writes as {}.
;;; - Lists of records and of values (keys, aliases, breaks, notes, ...)
;;;   are JSON arrays (vectors), empty ones included.
;;; - The default score has no source location, so its `source' is
;;;   null (a missing value is null).  Pitches have no `source': 02's
;;;   field list for them has none.
;;; - A key's name is its note name, never an alias (`ding1', not
;;;   `i1').  A group's `keys' range is [LOW, HIGH], key names.
;;; - In the s-expression, field names are the JSON names with `-' for
;;;   `_' (so an event's duration is `dur', as in JSON); a name (a
;;;   symbol in the records) stays a symbol; `#f' for a missing value.
;;;   Only the shape 02 gives is checked: (piece (version 1) ...),
;;;   (TAG (FIELD VALUE) ...) records, lists of records as (parts (part
;;;   ...) ...).  How a list of plain values or `source' is written in
;;;   the s-expression isn't checked.
;;; - save-piece writes JSON as write-json does when pretty: exactly
;;;   (json-string (piece->json PIECE)) and one newline, to the file or
;;;   to the current output port for "-".  The .scm file holds one datum,
;;;   (piece->sexp PIECE), and nothing but whitespace after it.
;;; - An unsupported extension raises an &error and writes no file.
;;;
;;; Run from the repo root: guile --fresh-auto-compile -L . tests/save.scm

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 match)
             (ice-9 textual-ports)
             (notasi json)
             (notasi piece)
             (notasi reader))

;;; ------------------------------------------------------------------
;;; Helpers

(define save-iface (false-if-exception (resolve-interface '(notasi save))))

(define (save-proc name)
  "The procedure NAME of (notasi save), or one that raises while the
module or the procedure doesn't exist."
  (or (and save-iface
           (module-variable save-iface name)
           (module-ref save-iface name))
      (lambda args
        (raise-exception
         (make-exception (make-error)
                         (make-exception-with-message
                          (format #f "(notasi save) has no ~a" name)))))))

(define piece->json (save-proc 'piece->json))
(define piece->sexp (save-proc 'piece->sexp))
(define save-piece (save-proc 'save-piece))

(define (try thunk)
  "THUNK's value, or the symbol failed if it raises."
  (guard (e (#t 'failed)) (thunk)))

(define (key-string k)
  (if (symbol? k) (symbol->string k) k))

(define (object? v)
  (and (list? v) (every pair? v)))

(define (keys obj)
  "The keys of the JSON object OBJ, as strings, in order; #f if OBJ
isn't an object."
  (and (object? obj) (map (lambda (m) (key-string (car m))) obj)))

(define (ref obj . path)
  "Follow PATH (key strings and vector indices) into the JSON value OBJ;
the symbol absent if a step doesn't exist."
  (let loop ((v obj) (path path))
    (match path
      (() v)
      (((? string? k) . rest)
       (let ((m (and (object? v)
                     (find (lambda (m) (equal? (key-string (car m)) k)) v))))
         (if m (loop (cdr m) rest) 'absent)))
      (((? integer? i) . rest)
       (if (and (vector? v) (< i (vector-length v)))
           (loop (vector-ref v i) rest)
           'absent)))))

(define (find-named vec name)
  "The object in the JSON array VEC whose \"name\" is NAME, or 'absent."
  (if (vector? vec)
      (or (find (lambda (o) (equal? (ref o "name") name)) (vector->list vec))
          'absent)
      'absent))

(define (tmp-dir)
  (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp") "/notasi-save-XXXXXX")))

(define (read-text path)
  (call-with-input-file path get-string-all #:encoding "UTF-8"))

(define (write-text path text)
  (call-with-output-file path (lambda (port) (put-string port text))
    #:encoding "UTF-8"))

;;; ------------------------------------------------------------------
;;; Fixtures

;;; A piece with no template: everything a small piece can have.
;;; Lines: scale 2, strokes 6, ugal 7, gong 8, fig 9, plain 10, melody
;;; 11, gong part 13, score full 14 (its groups 15 and 17), score
;;; second 20.
(define small-text
  "(piece \"Small\" :composer \"someone\" :remarks \"slowly\")
(scale sel
  (ding :alias (i ding-alt))
  (dong :alias o :display \"O\" :damped \"o'\")
  deng)
(strokes gs G P)
(instrument ugal sel i1 o1 i2)
(instrument gong gs G P)
(pattern fig :instrument ugal :short \"f\" :long \"Figure\" o1:1/4 i2 _ -)
(pattern plain :instrument ugal :annotation \"noted\" i1:1)
(part :instrument ugal :name melody
  (text \"here\") @fig i1:1/4 o1 (i1 i2) - (text \"two\" 2) (@ plain :short \"q\") i2:1)
(part :instrument gong G:1 - P -)
(score full :subtitle \"Sub\" :system-length 2 :breaks (3) :palette set2
  (group \"Ugal\" :short \"U\" :keys (i1 i2) :annotation-part melody
         :colors ((ding \"#000000\")) (melody :label \"Mel\"))
  (group \"Gong\" :note-label pitch-display-name
         :part-marker ((gong :symbol dot :border \"#d62728\"))
         :palette (\"#112233\" \"#445566\") gong))
(score second :keys all (group \"Ugal\" melody))
")

;;; A piece using the gong-kebyar template: a colotomy, a pickup,
;;; generated parts and the default score.
(define gilak-text
  "(piece \"Gilak\" :colotomy gilak :pickup 1)
(use gong-kebyar)
(part :instrument ugal a1 || o2 i2 e2 o2 | a1 o2 i2 a1 ||)
")

(define small (read-piece-string small-text))
(define gilak (read-piece-string gilak-text))

(define small-json (try (lambda () (piece->json small))))
(define gilak-json (try (lambda () (piece->json gilak))))

(test-begin "save")

(test-assert "(notasi save) exists" save-iface)
(for-each
 (lambda (name)
   (test-assert (string-append "(notasi save) exports " (symbol->string name))
     (and save-iface (module-variable save-iface name) #t)))
 '(piece->json piece->sexp save-piece))

;;; ------------------------------------------------------------------
;;; piece->json: the piece

(test-group "piece->json: the piece"
  (test-equal "the piece's keys, in order"
    '("version" "title" "length" "pickup" "info" "colotomies" "scales"
      "instruments" "patterns" "parts" "scores")
    (keys small-json))
  (test-equal "version is 1" 1 (ref small-json "version"))
  (test-equal "title" "Small" (ref small-json "title"))
  (test-equal "length, a whole number" 4 (ref small-json "length"))
  (test-equal "pickup 0 without a colotomy" 0 (ref small-json "pickup"))
  (test-equal "info: an object, keys in the order written"
    '("composer" "remarks") (keys (ref small-json "info")))
  (test-equal "info: the values" '("someone" "slowly")
    (list (ref small-json "info" "composer") (ref small-json "info" "remarks")))
  (test-equal "info: none is an empty object ({})"
    "{}" (try (lambda () (json-string (ref gilak-json "info") #:pretty? #f))))
  (test-equal "colotomies: none is an empty array" #() (ref small-json "colotomies"))
  (test-assert "json-string writes it"
    (string? (try (lambda () (json-string small-json)))))
  (test-assert "json-string writes the template piece"
    (string? (try (lambda () (json-string gilak-json)))))
  (test-equal "the template piece's length and pickup" '(9 1)
    (list (ref gilak-json "length") (ref gilak-json "pickup"))))

;;; ------------------------------------------------------------------
;;; Scales, stroke sets and instruments

(test-group "piece->json: scales"
  (let ((sel (find-named (ref small-json "scales") "sel"))
        (gs (find-named (ref small-json "scales") "gs")))
    (test-equal "scale keys, in order, source last"
      '("name" "pitched" "pitches" "source") (keys sel))
    (test-equal "a scale is pitched" #t (ref sel "pitched"))
    (test-equal "a stroke set is a scale, not pitched" #f (ref gs "pitched"))
    (test-equal "scales in the piece's order" '("sel" "gs")
      (map (lambda (s) (ref s "name")) (vector->list (ref small-json "scales"))))
    (test-equal "pitch keys, in order (no source)"
      '("name" "aliases" "display" "damped") (keys (ref sel "pitches" 0)))
    (test-equal "pitches in order, by name" '("ding" "dong" "deng")
      (map (lambda (p) (ref p "name")) (vector->list (ref sel "pitches"))))
    (test-equal "aliases: an array of names" #("i" "ding-alt") (ref sel "pitches" 0 "aliases"))
    (test-equal "aliases: none is an empty array" #() (ref sel "pitches" 2 "aliases"))
    (test-equal "display as written" "O" (ref sel "pitches" 1 "display"))
    (test-equal "damped as written" "o'" (ref sel "pitches" 1 "damped"))
    (test-equal "damped: none is null" 'null (ref sel "pitches" 0 "damped"))
    (test-equal "display: the default, as the record has it"
      (pitch-display (car (scale-pitches (car (piece-scales small)))))
      (ref sel "pitches" 0 "display"))
    (test-equal "a stroke set's strokes" '("G" "P")
      (map (lambda (p) (ref p "name")) (vector->list (ref gs "pitches"))))
    (test-equal "source: file null for a piece read from a string, and the line"
      '((null . 2) (null . 6))
      (list (cons (ref sel "source" "file") (ref sel "source" "line"))
            (cons (ref gs "source" "file") (ref gs "source" "line"))))
    (test-equal "source keys" '("file" "line") (keys (ref sel "source")))))

(test-group "piece->json: instruments"
  (let ((ugal (find-named (ref small-json "instruments") "ugal"))
        (gong (find-named (ref small-json "instruments") "gong")))
    (test-equal "instrument keys, in order"
      '("name" "scale" "keys" "source") (keys ugal))
    (test-equal "scale: its name" "sel" (ref ugal "scale"))
    (test-equal "keys: note names, in order (never aliases)"
      #("ding1" "dong1" "ding2") (ref ugal "keys"))
    (test-equal "a stroke instrument's keys" #("G" "P") (ref gong "keys"))
    (test-equal "source" '(null . 7)
      (cons (ref ugal "source" "file") (ref ugal "source" "line")))))

;;; ------------------------------------------------------------------
;;; Patterns

(test-group "piece->json: patterns"
  (let ((fig (find-named (ref small-json "patterns") "fig"))
        (plain (find-named (ref small-json "patterns") "plain")))
    (test-equal "pattern keys, in order"
      '("name" "instrument" "short" "long" "annotation" "source") (keys fig))
    (test-equal "instrument: its name" "ugal" (ref fig "instrument"))
    (test-equal "short and long" '("f" "Figure") (list (ref fig "short") (ref fig "long")))
    (test-equal "annotation: none is null" 'null (ref fig "annotation"))
    (test-equal "annotation: a string" "noted" (ref plain "annotation"))
    (test-equal "source" '(null . 9)
      (cons (ref fig "source" "file") (ref fig "source" "line")))))

;;; ------------------------------------------------------------------
;;; Parts: events, spans, texts; times exact

(test-group "piece->json: parts"
  (let* ((parts (ref small-json "parts"))
         (melody (find-named parts "melody"))
         (gong (find-named parts "gong")))
    (test-equal "parts in the piece's order (written, then generated)"
      (map (lambda (p) (symbol->string (part-name p))) (piece-parts small))
      (and (vector? parts) (map (lambda (p) (ref p "name")) (vector->list parts))))
    (test-equal "part keys, in order"
      '("name" "instrument" "origin" "events" "spans" "texts" "source") (keys melody))
    (test-equal "instrument: its name" "ugal" (ref melody "instrument"))
    (test-equal "origin of a written part" "written" (ref melody "origin"))
    (test-equal "source" '(null . 11)
      (cons (ref melody "source" "file") (ref melody "source" "line")))
    (test-equal "event keys, in order" '("start" "dur" "notes") (keys (ref melody "events" 0)))
    (test-equal "events: every one, in order, times exact"
      '((0 "1/4" #("dong1"))
        ("1/4" "1/2" #("ding2"))
        (1 "1/4" #("ding1"))
        ("5/4" "1/4" #("dong1"))
        ("3/2" "1/4" #("ding1" "ding2"))
        (2 1 #("ding1"))
        (3 1 #("ding2")))
      (and (vector? (ref melody "events"))
           (map (lambda (e) (list (ref e "start") (ref e "dur") (ref e "notes")))
                (vector->list (ref melody "events")))))
    (test-assert "a whole time is an exact integer"
      (exact-integer? (ref melody "events" 5 "start")))
    (test-equal "a stroke is its key's name" #("G") (ref gong "events" 0 "notes"))
    (test-equal "span keys, in order"
      '("pattern" "short" "long" "annotation" "start" "end" "depth")
      (keys (ref melody "spans" 0)))
    (test-equal "spans: pattern by name, names in force, times, depth"
      '(("fig" "f" "Figure" null 0 1 0)
        ("plain" "q" "plain" "noted" 2 3 0))
      (and (vector? (ref melody "spans"))
           (map (lambda (s)
                  (map (lambda (k) (ref s k))
                       '("pattern" "short" "long" "annotation" "start" "end" "depth")))
                (vector->list (ref melody "spans")))))
    (test-equal "text keys, in order" '("start" "length" "text") (keys (ref melody "texts" 0)))
    (test-equal "texts: a point has length null"
      '((0 null "here") (2 2 "two"))
      (and (vector? (ref melody "texts"))
           (map (lambda (t) (list (ref t "start") (ref t "length") (ref t "text")))
                (vector->list (ref melody "texts")))))
    (test-equal "no spans or texts: empty arrays" '(#() #())
      (list (ref gong "spans") (ref gong "texts")))))

(test-group "piece->json: times in the text"
  (let ((text (try (lambda () (json-string small-json)))))
    (test-assert "\"start\": \"5/4\"" (and (string? text) (string-contains text "\"start\": \"5/4\"")))
    (test-assert "\"dur\": \"1/4\"" (and (string? text) (string-contains text "\"dur\": \"1/4\"")))
    (test-assert "\"start\": 2" (and (string? text) (string-contains text "\"start\": 2,")))
    (test-assert "\"version\": 1" (and (string? text) (string-contains text "\"version\": 1,")))))

;;; ------------------------------------------------------------------
;;; Colotomies and generated parts (the template piece)

(test-group "piece->json: colotomies and generated parts"
  (let* ((entry (ref gilak-json "colotomies" 0))
         (parts (ref gilak-json "parts"))
         (ugal (find-named parts "ugal"))
         (gong (find-named parts "gong"))
         (kempli (find-named parts "kempli")))
    (test-equal "one colotomy entry" 1
      (and (vector? (ref gilak-json "colotomies")) (vector-length (ref gilak-json "colotomies"))))
    (test-equal "colotomy entry keys, in order"
      '("start" "name" "length" "timekeeper" "parts" "source") (keys entry))
    (test-equal "start, name, length, timekeeper" '(0 "gilak" 8 "kempli")
      (map (lambda (k) (ref entry k)) '("start" "name" "length" "timekeeper")))
    (test-equal "parts: their names" #("gong") (ref entry "parts"))
    (test-assert "a template's definition has its file"
      (let ((file (ref entry "source" "file")))
        (and (string? file) (string-suffix? "gong-kebyar.nts" file))))
    (test-assert "the source line is a number"
      (exact-integer? (ref entry "source" "line")))
    (test-equal "a written part's origin" "written" (ref ugal "origin"))
    (test-equal "a generated gong part's origin" "colotomy" (ref gong "origin"))
    (test-equal "a generated kempli part's origin" "timekeeper" (ref kempli "origin"))
    (test-equal "a written part in the piece: file null, its line" '(null . 3)
      (cons (ref ugal "source" "file") (ref ugal "source" "line")))
    (test-assert "a generated part has its colotomy's location (a template file)"
      (let ((file (ref gong "source" "file")))
        (and (string? file) (string-suffix? "gong-kebyar.nts" file))))
    (test-equal "a generated part's events: whole times are numbers, strokes by name"
      '((0 1 #("G")) (4 1 #("GL")))
      (map (lambda (i)
             (list (ref gong "events" i "start") (ref gong "events" i "dur")
                   (ref gong "events" i "notes")))
           '(0 1)))
    (test-assert "the template's unused instruments are kept"
      (not (eq? 'absent (find-named (ref gilak-json "instruments") "kendang"))))
    (test-assert "the template's scale is there, with its file"
      (let ((file (ref (find-named (ref gilak-json "scales") "selisir") "source" "file")))
        (and (string? file) (string-suffix? ".nts" file))))))

;;; ------------------------------------------------------------------
;;; Scores and groups

(define score-field-names
  '("name" "title" "subtitle" "caption" "from" "to" "system_length" "breaks"
    "cycle_numbers" "pulse_numbers" "numbering" "background" "cycle_label"
    "pulse_label" "font_size" "cell_width" "cell_height" "groups" "source"))

(define group-field-names
  '("label" "short" "subtitle" "labels" "rows" "members" "note_label"
    "note_label_octave" "fill" "holds" "annotation" "keys" "row_label_octave"
    "key_numbers" "row_labels" "display" "part_marker" "scheme" "palette"
    "colors" "background" "source"))

(test-group "piece->json: scores"
  (let* ((scores (ref small-json "scores"))
         (full (find-named scores "full"))
         (second (find-named scores "second")))
    (test-equal "scores in order" '("full" "second")
      (and (vector? scores) (map (lambda (s) (ref s "name")) (vector->list scores))))
    (test-equal "score keys, in order" score-field-names (keys full))
    (test-equal "title: the piece's" "Small" (ref full "title"))
    (test-equal "subtitle" "Sub" (ref full "subtitle"))
    (test-equal "subtitle: none is null" 'null (ref second "subtitle"))
    (test-equal "caption: none is null" 'null (ref full "caption"))
    (test-equal "from and to" '(0 4) (list (ref full "from") (ref full "to")))
    (test-equal "system_length" 2 (ref full "system_length"))
    (test-equal "system_length: none is null" 'null (ref second "system_length"))
    (test-equal "breaks: times (:breaks (3) is pulse 3, time 2)" #(2) (ref full "breaks"))
    (test-equal "breaks: none is an empty array" #() (ref second "breaks"))
    (test-assert "cycle_numbers and pulse_numbers are booleans"
      (and (boolean? (ref full "cycle_numbers")) (boolean? (ref full "pulse_numbers"))))
    (test-equal "numbering, a symbol, is a string" "gong-last" (ref full "numbering"))
    (test-equal "background" "grid" (ref full "background"))
    (test-equal "cycle_label" "Cycle" (ref full "cycle_label"))
    (test-equal "pulse_label" "Pulse" (ref full "pulse_label"))
    (test-equal "font_size: none is null" 'null (ref full "font_size"))
    (test-assert "cell_width and cell_height are strings"
      (and (string? (ref full "cell_width")) (string? (ref full "cell_height"))))
    (test-equal "source" '(null . 14)
      (cons (ref full "source" "file") (ref full "source" "line")))
    (test-equal "the default score: named default, source null"
      '("default" null)
      (list (ref gilak-json "scores" 0 "name") (ref gilak-json "scores" 0 "source")))))

(test-group "piece->json: groups"
  (let* ((full (find-named (ref small-json "scores") "full"))
         (ugal (ref full "groups" 0))
         (gong (ref full "groups" 1))
         (second-group (ref (find-named (ref small-json "scores") "second") "groups" 0)))
    (test-equal "group keys, in order" group-field-names (keys ugal))
    (test-equal "label, short" '("Ugal" "U") (list (ref ugal "label") (ref ugal "short")))
    (test-equal "subtitle: none is null" 'null (ref ugal "subtitle"))
    (test-equal "labels, rows: strings" '("first-long" "notes")
      (list (ref ugal "labels") (ref ugal "rows")))
    (test-equal "member keys" '("part" "label") (keys (ref ugal "members" 0)))
    (test-equal "members: part by name, row label" '("melody" "Mel")
      (list (ref ugal "members" 0 "part") (ref ugal "members" 0 "label")))
    (test-equal "a member's label is the part's name unless given" "gong"
      (ref gong "members" 0 "label"))
    (test-equal "note_label" '("none" "pitch-display-name")
      (list (ref ugal "note_label") (ref gong "note_label")))
    (test-assert "note_label_octave, a boolean" (boolean? (ref ugal "note_label_octave")))
    (test-equal "fill, holds" '("colour" "none") (list (ref ugal "fill") (ref ugal "holds")))
    (test-equal "annotation keys, in order"
      '("part" "position" "align" "level" "text" "label") (keys (ref ugal "annotation")))
    (test-equal "annotation: the part by name and its settings"
      '("melody" "below" "left" 0 "annotation" null)
      (map (lambda (k) (ref ugal "annotation" k))
           '("part" "position" "align" "level" "text" "label")))
    (test-equal "annotation: none is null" 'null (ref gong "annotation"))
    (test-equal "keys: a range, [LOW, HIGH] key names" #("ding1" "ding2") (ref ugal "keys"))
    (test-equal "keys: used" "used" (ref gong "keys"))
    (test-equal "keys: all" "all" (ref second-group "keys"))
    (test-assert "row_label_octave, key_numbers: booleans"
      (and (boolean? (ref ugal "row_label_octave")) (boolean? (ref ugal "key_numbers"))))
    (test-assert "row_labels, a string" (string? (ref ugal "row_labels")))
    (test-equal "display: none is an empty array" #() (ref ugal "display"))
    (test-equal "part_marker: none is an empty array" #() (ref ugal "part_marker"))
    (test-equal "part_marker keys, in order"
      '("part" "symbol" "symbol_size" "symbol_color" "border" "border_width")
      (keys (ref gong "part_marker" 0)))
    (test-equal "part_marker: part by name, symbol, border, defaults null"
      '("gong" "dot" null null "#d62728" null)
      (map (lambda (k) (ref gong "part_marker" 0 k))
           '("part" "symbol" "symbol_size" "symbol_color" "border" "border_width")))
    (test-equal "scheme" "by-pitch" (ref ugal "scheme"))
    (test-equal "palette: a name" "set2" (ref ugal "palette"))
    (test-equal "palette: a list of colours" #("#112233" "#445566") (ref gong "palette"))
    (test-equal "colors: each pitch and colour"
      '(("pitch" "color") "ding" "#000000")
      (list (keys (ref ugal "colors" 0))
            (ref ugal "colors" 0 "pitch") (ref ugal "colors" 0 "color")))
    (test-equal "colors: none is an empty array" #() (ref gong "colors"))
    (test-equal "background" "grid" (ref ugal "background"))
    (test-equal "source: the group's line" '(null . 15)
      (cons (ref ugal "source" "file") (ref ugal "source" "line")))))

(test-group "piece->json: display"
  (let* ((p (read-piece-string
             "(piece \"Keys\" :colotomy gilak :pickup 1)
(use gong-kebyar)
(part :instrument ugal a1 || o2 i2 e2 o2 | a1 o2 i2 a1 ||)
(score keys (group \"Gong\" :display ((GL \"G\")) gong))
"))
         (group (ref (try (lambda () (piece->json p))) "scores" 0 "groups" 0)))
    (test-equal "display keys" '("stroke" "text") (keys (ref group "display" 0)))
    (test-equal "display: the stroke and its text" '("GL" "G")
      (list (ref group "display" 0 "stroke") (ref group "display" 0 "text")))))

;;; ------------------------------------------------------------------
;;; A piece read from a file: source has the file

(test-group "piece->json: a piece read from a file"
  (let* ((dir (tmp-dir))
         (path (string-append dir "/small.nts")))
    (write-text path small-text)
    (let* ((p (read-piece-file path))
           (j (try (lambda () (piece->json p))))
           (file (source-location-file (part-location (car (piece-parts p))))))
      (test-equal "a part's source file is the piece's file, as the record has it"
        file (ref (find-named (ref j "parts") "melody") "source" "file"))
      (test-assert "(it names small.nts)" (and (string? file) (string-suffix? "small.nts" file)))
      (test-equal "a score's source file too"
        file (ref (find-named (ref j "scores") "full") "source" "file")))
    (delete-file path)
    (rmdir dir)))

;;; ------------------------------------------------------------------
;;; piece->sexp

(define small-sexp (try (lambda () (piece->sexp small))))

(define (fields rec)
  "The (FIELD VALUE ...) entries of the tagged record REC."
  (if (pair? rec) (cdr rec) '()))

(define (field rec name)
  "The entry (NAME ...) of REC, or #f."
  (assq name (fields rec)))

(define (records rec name)
  "The records listed in REC's field NAME: (NAME (TAG ...) ...)."
  (match (field rec name)
    ((_ . recs) recs)
    (_ '())))

(define (tree-any pred tree)
  "Does any leaf (or vector element) of TREE satisfy PRED?"
  (let loop ((t tree))
    (cond ((pair? t) (or (loop (car t)) (loop (cdr t))))
          ((vector? t) (any loop (vector->list t)))
          (else (pred t)))))

(define (record-named recs name)
  (find (lambda (r) (equal? (field r 'name) (list 'name name))) recs))

(test-group "piece->sexp"
  (test-assert "a tagged list: (piece ...)"
    (and (pair? small-sexp) (eq? 'piece (car small-sexp))))
  (test-equal "(version 1) first" '(version 1)
    (and (pair? small-sexp) (pair? (cdr small-sexp)) (cadr small-sexp)))
  (test-equal "the piece's fields, in order"
    '(version title length pickup info colotomies scales instruments patterns
      parts scores)
    (map (lambda (f) (and (pair? f) (car f))) (fields small-sexp)))
  (test-equal "(title \"Small\")" '(title "Small") (field small-sexp 'title))
  (test-equal "(length 4)" '(length 4) (field small-sexp 'length))
  (let* ((parts (records small-sexp 'parts))
         (melody (record-named parts 'melody))
         (scores (records small-sexp 'scores))
         (second (record-named scores 'second))
         (group (and second (match (field second 'groups)
                              ((_ g . _) g)
                              (_ #f)))))
    (test-assert "parts: (parts (part ...) ...)"
      (and (pair? parts) (every (lambda (p) (and (pair? p) (eq? 'part (car p)))) parts)))
    (test-equal "a part's fields, in order, with source last"
      '(name instrument origin events spans texts source)
      (map car (fields melody)))
    (test-equal "names are symbols" '(name melody) (field melody 'name))
    (test-equal "the instrument by name" '(instrument ugal) (field melody 'instrument))
    (test-assert "scores: (scores (score ...) ...)"
      (and (pair? scores) (every (lambda (s) (eq? 'score (car s))) scores)))
    (test-equal "a score's fields, in order, with - in names"
      (map (lambda (k) (string->symbol (string-map (lambda (c) (if (char=? c #\_) #\- c)) k)))
           score-field-names)
      (map car (fields second)))
    (test-equal "a missing value is #f" '(subtitle #f) (field second 'subtitle))
    (test-equal "a group's fields, in order, with - in names, no ?"
      (map (lambda (k) (string->symbol (string-map (lambda (c) (if (char=? c #\_) #\- c)) k)))
           group-field-names)
      (and group (map car (fields group)))))
  (test-assert "times are exact rationals: 5/4 is there"
    (tree-any (lambda (x) (eqv? x 5/4)) small-sexp))
  (test-assert "and 1/4"
    (tree-any (lambda (x) (eqv? x 1/4)) small-sexp))
  (test-assert "no time is a string"
    (and (pair? small-sexp)
         (not (tree-any (lambda (x) (equal? x "5/4")) small-sexp))))
  (test-assert "no inexact numbers"
    (and (pair? small-sexp)
         (not (tree-any (lambda (x) (and (number? x) (inexact? x))) small-sexp))))
  (test-assert "(the s-expression exists)" (pair? small-sexp))
  (test-equal "readable back with read from its written form"
    (if (pair? small-sexp) small-sexp 'no-sexp)
    (try (lambda () (call-with-input-string
                        (call-with-output-string (lambda (port) (write small-sexp port)))
                      read))))
  (test-equal "the template piece too"
    (let ((sx (try (lambda () (piece->sexp gilak)))))
      (if (pair? sx) sx 'no-sexp))
    (try (lambda () (call-with-input-string
                        (call-with-output-string
                          (lambda (port) (write (piece->sexp gilak) port)))
                      read)))))

;;; ------------------------------------------------------------------
;;; save-piece

(define expected-json-text
  (try (lambda () (string-append (json-string (piece->json small)) "\n"))))

(test-group "save-piece"
  (let* ((dir (tmp-dir))
         (json-path (string-append dir "/small.json"))
         (scm-path (string-append dir "/small.scm"))
         (txt-path (string-append dir "/small.txt"))
         (none-path (string-append dir "/small")))
    (try (lambda () (save-piece small json-path)))
    (test-equal ".json: the pretty JSON and a newline"
      expected-json-text
      (and (file-exists? json-path) (read-text json-path)))
    (try (lambda () (save-piece small scm-path)))
    (test-equal ".scm: one datum, the s-expression"
      (try (lambda () (piece->sexp small)))
      (and (file-exists? scm-path) (call-with-input-file scm-path read)))
    (test-assert ".scm: nothing after it but whitespace"
      (and (file-exists? scm-path)
           (call-with-input-file scm-path
             (lambda (port)
               (read port)
               (string-every char-whitespace? (get-string-all port))))))
    (test-assert "(the expected JSON text exists)" (string? expected-json-text))
    (test-equal "-: the JSON to the current output port"
      (if (string? expected-json-text) expected-json-text 'no-json)
      (try (lambda ()
             (call-with-output-string
               (lambda (port)
                 (parameterize ((current-output-port port))
                   (save-piece small "-")))))))
    (test-assert "another extension raises an &error"
      (and save-iface
           (guard (e ((error? e) #t) (#t #f))
             (save-piece small txt-path)
             #f)))
    (test-assert "and writes nothing" (not (file-exists? txt-path)))
    (test-assert "no extension raises an &error"
      (and save-iface
           (guard (e ((error? e) #t) (#t #f))
             (save-piece small none-path)
             #f)))
    (test-assert "and writes nothing" (not (file-exists? none-path)))
    (for-each (lambda (p) (when (file-exists? p) (delete-file p)))
              (list json-path scm-path txt-path none-path))
    (rmdir dir)))

;;; ------------------------------------------------------------------
;;; The whole piece, whatever is drawn

(test-group "the saved piece is the whole piece"
  (test-assert "every score is saved"
    (equal? '("full" "second")
            (map (lambda (s) (ref s "name"))
                 (let ((v (ref small-json "scores"))) (if (vector? v) (vector->list v) '())))))
  (test-assert "parts no score names are saved (the generated kempli)"
    (not (eq? 'absent (find-named (ref small-json "parts") "kempli"))))
  (test-assert "the same each time"
    (and (pair? small-json)
         (equal? small-json (try (lambda () (piece->json small)))))))

(define runner (test-runner-current))
(test-end "save")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
