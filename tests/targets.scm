;;; Acceptance test of iteration 2 (milestone feat/targets): the two
;;; targets, Gold's Jaya Semara and Tenzer's Baris, read and draw; and of
;;; iteration 3 (milestone feat/examples), Baris's colour score (below).
;;;
;;; Written from doc/iterations/02-gold-and-tenzer/README.md (the
;;; acceptance test and milestone 3's decisions), the targets in its
;;; targets/ folder (their score names), 01-notation.md (colotomy),
;;; 04-layout.md ("Golden tests") and 05-typst-backend.md (`notasi
;;; render --score`), not from the implementation.
;;;
;;; - examples/gallery/jaya-semara.nts and examples/baris.nts read, and their
;;;   scores are exactly the targets' scores, in the targets' order.
;;; - examples/demos/tenzer1.nts reads, with the colotomy gilak, a one-pulse
;;;   pickup, and a generated `gong' part (origin `colotomy').
;;; - Each of the three has its golden files in tests/golden/, named per
;;;   04: NAME.json for a piece with only the default score, else
;;;   NAME_SCORE.json for each score (ADR 0040, since feat/drawing-output;
;;;   NAME.SCORE.json before).  (tests/golden.scm compares them.)
;;; - run-notasi draws each score of the two targets to an SVG in a
;;;   temporary folder, with `render FILE --score NAME -o OUT', exiting 0.
;;;   Needs Typst on the PATH.
;;; Choices made where the docs are not explicit:
;;; - tenzer1's golden names are derived from its scores as read, since
;;;   whether it gets `score' forms is not decided.
;;; - The drawing tests read the examples where they are (no copies):
;;;   only the output goes to the temporary folder.
;;; - An SVG is a file starting with "<svg" or "<?xml", as in
;;;   tests/command.scm.
;;;
;;;
;;; Extended for the acceptance test of iteration 3 (milestone
;;; feat/examples), written from doc/iterations/03-refining-the-examples/
;;; README.md (milestone 3's decisions), 01-notation.md (score options,
;;; `:display'), 02-piece.md (the score and group records), 04-layout.md
;;; (lanes, `display', "Golden tests") and ADR 0040, not from the
;;; implementation:
;;; - Baris has a fifth score, `colour', after the four Tenzer-style
;;;   ones; it renders and has its golden file baris_colour.json.
;;; - Baris's gong instrument keeps the template's strokes: GL's own
;;;   display form is "GL".  The four Tenzer-style scores' gong group
;;;   shows GL as "G" (`:display ((GL "G"))'); `colour' does not.
;;; - `colour' has Jaya Semara's look: gong-last numbering, every group
;;;   with notes rows, colour fill, no note names, keys used and grid
;;;   background; one system (no system-length, no breaks); two kendang
;;;   groups, "Kendang lanang" and "Kendang wadon", holding the parts on
;;;   the instruments kendang-lanang and kendang-wadon.  Its figure has one
;;;   system, and the gong group's lanes include "G" and "GL".
;;;   Since 2026-11-26 Baris uses the template's `gilak-2', which strikes
;;;   G where `gilak' strikes GL, so the lanes include "G" and not "GL".
;;; - Jaya Semara and Baris each have a score `collapsed' (2026-11-26).
;;; Choices made where the docs are not explicit:
;;; - The gong group of a score is the group with a part on the instrument
;;;   `gong'; the gong group in the figure is the one at the same index.
;;; - A Tenzer-style score without a gong group (some excerpts have no
;;;   gongs, and `:display' must name a stroke of the group's instruments)
;;;   is not checked for `:display'; `full' must have one.
;;; - A kendang group's parts are compared with the instrument's parts as
;;;   sets (the order within the group is not checked).
;;;
;;; Run from the repo root: guile --fresh-auto-compile -L . tests/targets.scm

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 binary-ports)
             (ice-9 exceptions)
             (ice-9 ftw)
             (ice-9 match)
             (rnrs bytevectors)
             (notasi command)
             (notasi layout)
             (notasi piece)
             (notasi reader))

;;; ------------------------------------------------------------------
;;; Helpers

(define (example-file name)
  "Example NAME's path: examples/gallery/NAME.nts, or examples/demos/
when it isn't in the gallery (07, ADR 0052)."
  (let ((gallery (string-append "examples/gallery/" name ".nts")))
    (if (file-exists? gallery)
        gallery
        (string-append "examples/demos/" name ".nts"))))

(define (read-example name)
  "Example NAME as a piece, or #f if reading it raises."
  (guard (e (#t #f))
    (read-piece-file (example-file name))))

(define (score-names pc)
  (map score-name (piece-scores pc)))

(define (part-named pc name)
  (find (lambda (p) (eq? (part-name p) name)) (piece-parts pc)))

(define (golden-names name pc)
  "The golden file names (without .json) of example NAME, per 04."
  (match (piece-scores pc)
    (((? (lambda (s) (not (score-location s))))) (list name))
    (scores (map (lambda (s)
                   (string-append name "_" (symbol->string (score-name s))))
                 scores))))

(define (golden-path name) (string-append "tests/golden/" name ".json"))

(define tmp-dir
  (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp") "/notasi-targets-XXXXXX")))

(define (tmp-path name) (string-append tmp-dir "/" name))

(define (remove-tree path)
  "Delete PATH: a file, or a folder and everything in it."
  (if (eq? 'directory (stat:type (lstat path)))
      (begin
        (for-each (lambda (name) (remove-tree (string-append path "/" name)))
                  (scandir path (lambda (f) (not (member f '("." ".."))))))
        (rmdir path))
      (delete-file path)))

(define (file-starts-with-bytes? path want)
  (and (file-exists? path)
       (let ((bytes (call-with-input-file path get-bytevector-all #:binary #t)))
         (and (bytevector? bytes)
              (>= (bytevector-length bytes) (bytevector-length want))
              (let ((head (make-bytevector (bytevector-length want))))
                (bytevector-copy! bytes 0 head 0 (bytevector-length want))
                (equal? head want))))))

(define (svg-file? path)
  (or (file-starts-with-bytes? path (string->utf8 "<svg"))
      (file-starts-with-bytes? path (string->utf8 "<?xml"))))

(define (run . args)
  "Call run-notasi with ARGS; return (STATUS STDOUT STDERR), STATUS being
(raised E) if it raises."
  (let ((out (open-output-string))
        (err (open-output-string)))
    (let ((status (guard (e (#t (list 'raised e)))
                    (parameterize ((current-output-port out)
                                   (current-error-port err))
                      (run-notasi args)))))
      (list status (get-output-string out) (get-output-string err)))))

;;; The targets: example name and its scores, as the targets name them.
(define targets
  '(("jaya-semara" (full kotekan collapsed))
    ("baris" (full polos-alone sangsih-alone kendang-composite colour
              collapsed))))

;;; Baris's scores in Tenzer's style (iteration 2's).
(define tenzer-scores '(full polos-alone sangsih-alone kendang-composite))

(define (instrument-named pc name)
  (find (lambda (i) (eq? (instrument-name i) name)) (piece-instruments pc)))

(define (group-parts group) (map car (group-members group)))

(define (group-on-instrument? group name)
  (any (lambda (p) (eq? name (instrument-name (part-instrument p))))
       (group-parts group)))

(define (gong-group-index score)
  "The index of SCORE's group holding a part on the instrument gong, or #f."
  (list-index (lambda (g) (group-on-instrument? g 'gong)) (score-groups score)))

(define (group-labelled score label)
  (find (lambda (g) (equal? label (group-label g))) (score-groups score)))

(define (part-names-on pc instrument)
  "The names of PC's parts on INSTRUMENT, sorted."
  (sort (map part-name
             (filter (lambda (p) (eq? instrument (instrument-name (part-instrument p))))
                     (piece-parts pc)))
        (lambda (a b) (string<? (symbol->string a) (symbol->string b)))))

(define (group-part-names group)
  (sort (map part-name (group-parts group))
        (lambda (a b) (string<? (symbol->string a) (symbol->string b)))))

(define (ref alist key)
  (match (assq key alist) ((_ . v) v) (#f #f)))

(test-begin "targets")

;;; ------------------------------------------------------------------
;;; The two targets read, with the targets' scores

(for-each
 (match-lambda
   ((name scores)
    (let ((pc (read-example name)))
      (test-group name
        (test-assert (string-append (example-file name) " reads") (piece? pc))
        (test-equal "its scores are the target's" scores
          (and pc (score-names pc)))))))
 targets)

;;; ------------------------------------------------------------------
;;; examples/demos/tenzer1.nts: the gongs come from the colotomy gilak

(test-group "tenzer1"
  (let ((pc (read-example "tenzer1")))
    (test-assert "examples/demos/tenzer1.nts reads" (piece? pc))
    (test-equal "one colotomy, gilak"
      '(gilak)
      (and pc (map (lambda (entry) (colotomy-name (cdr entry)))
                   (piece-colotomies pc))))
    (test-equal "a one-pulse pickup" 1
      (and pc (piece-pickup pc)))
    (test-equal "a gong part, generated from the colotomy" 'colotomy
      (and pc (let ((gong (part-named pc 'gong)))
                (and gong (part-origin gong)))))
    (test-assert "the gong part plays the gong"
      (and pc (let ((gong (part-named pc 'gong)))
                (and gong (eq? 'gong (instrument-name (part-instrument gong)))))))))

;;; ------------------------------------------------------------------
;;; Golden files, named per 04 ("Golden tests")

(test-group "golden files"
  (for-each
   (match-lambda
     ((name scores)
      (for-each
       (lambda (score)
         (let ((path (golden-path (string-append name "_" (symbol->string score)))))
           (test-assert (string-append path " exists") (file-exists? path))))
       scores)))
   targets)
  (let ((pc (read-example "tenzer1")))
    (test-assert "(tenzer1 reads, so its golden names are known)" (piece? pc))
    (when pc
      (for-each
       (lambda (golden)
         (test-assert (string-append (golden-path golden) " exists")
           (file-exists? (golden-path golden))))
       (golden-names "tenzer1" pc)))))

;;; ------------------------------------------------------------------
;;; Every score of the two targets draws: notasi render FILE --score NAME

(test-group "render --score"
  (for-each
   (match-lambda
     ((name scores)
      (for-each
       (lambda (score)
         (let* ((label (string-append name " --score " (symbol->string score)))
                (out (tmp-path (string-append name "_" (symbol->string score) ".svg")))
                (r (run "render" (example-file name)
                        "--score" (symbol->string score) "-o" out)))
           (test-equal (string-append label ": exits with status 0")
             0 (car r))
           (test-equal (string-append label ": prints nothing to stderr")
             "" (caddr r))
           (test-assert (string-append label ": writes an SVG")
             (svg-file? out))))
       scores)))
   targets))

;;; ------------------------------------------------------------------
;;; Baris's gongs: the template's GL, shown as "G" in Tenzer's scores

(test-group "baris gongs"
  (let ((pc (read-example "baris")))
    (test-assert "(baris reads)" (piece? pc))
    (when pc
      (let* ((gong (instrument-named pc 'gong))
             (gl (and gong (find (lambda (d) (eq? 'GL (degree-name d)))
                                 (scale-degrees (instrument-scale gong))))))
        (test-assert "the instrument gong has the stroke GL" gl)
        (test-equal "GL's own display form is \"GL\"" "GL"
          (and gl (degree-display gl))))
      (for-each
       (lambda (name)
         (let* ((score (piece-score pc name))
                (i (and score (gong-group-index score)))
                (group (and i (list-ref (score-groups score) i))))
           (test-assert (format #f "(baris has the score ~a)" name) score)
           (when (or group (eq? name 'full))
             (test-equal (format #f "~a: the gong group shows GL as \"G\"" name)
               "G" (and group (ref (group-display group) 'GL))))))
       tenzer-scores)
      (let* ((score (piece-score pc 'colour))
             (i (and score (gong-group-index score)))
             (group (and i (list-ref (score-groups score) i))))
        (test-assert "colour: has a gong group" group)
        (test-assert "colour: the gong group has no display for GL"
          (and group (not (assq 'GL (group-display group)))))))))

;;; ------------------------------------------------------------------
;;; Baris's colour score: Jaya Semara's look, one system, two kendang groups

(test-group "baris colour"
  (let* ((pc (read-example "baris"))
         (score (and pc (piece-score pc 'colour))))
    (test-assert "baris has the score colour" score)
    (when score
      (test-equal "numbering gong-last" 'gong-last (score-numbering score))
      (test-equal "no system-length" #f (score-system-length score))
      (test-equal "no breaks" '() (score-breaks score))
      (for-each
       (lambda (g)
         (let ((label (format #f "group ~s: " (group-label g))))
           (test-equal (string-append label "rows notes") 'notes (group-rows g))
           (test-equal (string-append label "fill colour") 'colour (group-fill g))
           (test-equal (string-append label "no note names") #f (group-note-names? g))
           (test-equal (string-append label "keys used") 'used (group-keys g))
           (test-equal (string-append label "background grid") 'grid (group-background g))))
       (score-groups score))
      (for-each
       (match-lambda
         ((label instrument)
          (let ((g (group-labelled score label)))
            (test-assert (string-append "a group labelled " label) g)
            (test-assert (format #f "(baris has parts on ~a)" instrument)
              (pair? (part-names-on pc instrument)))
            (test-equal (format #f "~a holds the parts on ~a" label instrument)
              (part-names-on pc instrument)
              (and g (group-part-names g))))))
       '(("Kendang lanang" kendang-lanang)
         ("Kendang wadon" kendang-wadon)))
      (let* ((fig (guard (e (#t #f)) (layout-score pc score)))
             (systems (and fig (ref fig 'systems)))
             (i (gong-group-index score)))
        (test-assert "layout-score lays it out" fig)
        (test-equal "its figure has one system" 1
          (and (vector? systems) (vector-length systems)))
        (test-assert "(it has a gong group)" i)
        (when (and (vector? systems) (> (vector-length systems) 0) i)
          (let* ((groups (ref (vector-ref systems 0) 'groups))
                 (lanes (and (vector? groups) (< i (vector-length groups))
                             (vector->list (ref (vector-ref groups i) 'lanes)))))
            (test-assert "the gong group's lanes include \"G\""
              (and lanes (member "G" lanes)))
            (test-assert "the gong group's lanes don't include \"GL\" (gilak-2)"
              (and lanes (not (member "GL" lanes))))))))))

(remove-tree tmp-dir)

(define runner (test-runner-current))
(test-end "targets")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
