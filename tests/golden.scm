;;; Golden tests: each example's figures, as saved in tests/golden/.
;;; See doc/design/04-layout.md, "Golden tests".
;;; - Each examples/gallery/NAME.nts and examples/demos/NAME.nts (07,
;;;   ADR 0052; names are unique across them) has one figure per score.  A file with only
;;;   the default score (no `score' form) has tests/golden/NAME.json; a
;;;   file with scores has tests/golden/NAME_SCORE.json for each of its
;;;   scores (ADR 0040; NAME.SCORE.json before feat/drawing-output).  Each figure, laid out with layout-score, must match its
;;;   saved copy as text, exactly as write-figure writes it.  A figure
;;;   with no saved copy fails, and so does a saved copy with no figure.
;;; - With --update (make golden), rewrite every saved copy with
;;;   write-figure, delete saved copies with no figure, and say what
;;;   changed.  No comparisons are run: the copies were just written.
;;;
;;; Slice feat/scores-form (04, "Slices (iteration 2)", slice 1):
;;; layout-piece is gone; figures are laid out with layout-score.
;;;
;;; Slice feat/scores-range (04, slice 5 and "Golden tests"): one figure
;;; per score, named as above (examples/gilak.nts has two scores, so its
;;; figures were gilak.full.json and gilak.second-cycle.json).
;;;
;;; Slice feat/drawing-output (04, "Slices (iteration 3)", slice 4, and
;;; "Golden tests"; ADR 0040): a file with scores names its figures
;;; NAME_SCORE.json (gilak_full.json, gilak_second-cycle.json); a file
;;; with only the default score keeps NAME.json.
;;; Choices made where the docs are not explicit:
;;; - "Only the default score" means the piece's only score has no
;;;   source location (03, step 12: the default score's location is #f).
;;; - An example that can't be read fails one test, and its saved
;;;   copies (NAME.json, NAME_*.json) count neither as figures nor as
;;;   orphans; --update then keeps them and exits non-zero.
;;;
;;; Milestone feat/save-piece (02, "Saving the piece"; ADR 0058): each
;;; example also has its saved piece, tests/golden/NAME.piece.json, which
;;; must match, as text, what save-piece writes to a .json file for the
;;; example's piece.  It is per example, not per score: the saved piece
;;; is the whole piece.  A saved piece with no example fails; --update
;;; writes them with save-piece and deletes the orphans, beside the
;;; figures.  Choices:
;;; - A NAME.piece.json is never a figure: the figures are the other
;;;   .json files, so a saved piece is not a figure's orphan.
;;; - (notasi export-piece) is looked up at run time, so while it doesn't exist
;;;   the figures are still compared and only the saved pieces fail.
;;; - The saved piece of an example that can't be read is neither
;;;   compared nor an orphan, as for its figures.
;;;
;;; Run from the repo root: guile -L . tests/golden.scm [--update]

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 ftw)
             (ice-9 match)
             (ice-9 textual-ports)
             (notasi layout)
             (notasi piece)
             (notasi reader)
             (notasi typst))

(define example-dirs '("examples/gallery" "examples/demos"))
(define golden-dir "tests/golden")

(define (names-in dir suffix)
  "The names, without SUFFIX, of the files in DIR ending in SUFFIX,
sorted.  No names if DIR doesn't exist."
  (map (lambda (f) (string-drop-right f (string-length suffix)))
       (or (scandir dir (lambda (f) (string-suffix? suffix f))) '())))

(define (example-path name)
  "The path of example NAME, in whichever of `example-dirs' holds it."
  (let ((dir (find (lambda (dir)
                     (file-exists? (string-append dir "/" name ".nts")))
                   example-dirs)))
    (string-append dir "/" name ".nts")))
(define (golden-path name) (string-append golden-dir "/" name ".json"))
(define piece-suffix ".piece.json")
(define (piece-golden-path name)
  (string-append golden-dir "/" name piece-suffix))

;;; save-piece from (notasi export-piece), or #f while it doesn't exist.
(define save-piece
  (let ((iface (false-if-exception (resolve-interface '(notasi export-piece)))))
    (and iface
         (module-variable iface 'save-piece)
         (module-ref iface 'save-piece))))

(define (read-text path)
  (call-with-input-file path get-string-all #:encoding "UTF-8"))

(define (read-example name)
  "Example NAME's piece, or the exception reading it raised."
  (guard (e (#t e))
    (read-piece-file (example-path name))))

(define (default-score-only? piece)
  (match (piece-scores piece)
    ((score) (not (score-location score)))
    (_ #f)))

;;; A figure: (GOLDEN-NAME PIECE SCORE).
(define (figures-of name piece)
  "The figures of example NAME, whose piece is PIECE."
  (if (default-score-only? piece)
      (list (list name piece (car (piece-scores piece))))
      (map (lambda (score)
             (list (string-append name "_" (symbol->string (score-name score)))
                   piece score))
           (piece-scores piece))))

(define (figure-name f) (car f))

(define (figure-value f)
  (match f
    ((_ piece score) (layout-score piece score))))

(define (figure-text f)
  "The text write-figure writes for figure F, read back from a temporary
file so that the comparison goes through write-figure."
  (let* ((dir (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp")
                                      "/notasi-golden-XXXXXX")))
         (path (string-append dir "/figure.json")))
    (dynamic-wind
      (const #f)
      (lambda ()
        (write-figure (figure-value f) path)
        (read-text path))
      (lambda ()
        (when (file-exists? path) (delete-file path))
        (rmdir dir)))))

(define (piece-text piece)
  "The text save-piece writes for PIECE to a .json file, read back from a
temporary file; the exception if it raises."
  (let* ((dir (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp")
                                      "/notasi-golden-XXXXXX")))
         (path (string-append dir "/piece.json")))
    (dynamic-wind
      (const #f)
      (lambda ()
        (guard (e (#t e))
          (unless save-piece (error "(notasi export-piece) has no save-piece"))
          (save-piece piece path)
          (read-text path)))
      (lambda ()
        (when (file-exists? path) (delete-file path))
        (rmdir dir)))))

(define examples
  (sort (append-map (lambda (dir) (names-in dir ".nts")) example-dirs)
        string<?))
(define pieces (map (lambda (name) (cons name (read-example name))) examples))
(define unreadable
  (filter-map (match-lambda
                ((name . p) (and (not (piece? p)) name)))
              pieces))
(define figures
  (append-map (match-lambda
                ((name . p) (if (piece? p) (figures-of name p) '())))
              pieces))
(define figure-names (map figure-name figures))
(define goldens
  ;; The figures' saved copies: every .json except the saved pieces.
  (remove (lambda (name) (string-suffix? ".piece" name))
          (names-in golden-dir ".json")))
(define piece-goldens (names-in golden-dir piece-suffix))
(define readable
  (filter-map (match-lambda
                ((name . p) (and (piece? p) (cons name p))))
              pieces))
(define piece-orphans
  (lset-difference string=? piece-goldens examples))

(define (of-unreadable? golden)
  "Is GOLDEN a saved copy of an example that can't be read?"
  (any (lambda (name)
         (or (string=? golden name)
             (string-prefix? (string-append name "_") golden)))
       unreadable))

(define orphans
  (remove of-unreadable? (lset-difference string=? goldens figure-names)))

(define (update!)
  "Rewrite every saved copy and delete the orphans; #f if an example
can't be read."
  (unless (file-exists? golden-dir) (mkdir golden-dir))
  (for-each (lambda (f)
              (write-figure (figure-value f) (golden-path (figure-name f)))
              (format #t "wrote ~a~%" (golden-path (figure-name f))))
            figures)
  (for-each (lambda (name)
              (delete-file (golden-path name))
              (format #t "deleted ~a (no figure)~%" (golden-path name)))
            orphans)
  (for-each (match-lambda
              ((name . piece)
               (save-piece piece (piece-golden-path name))
               (format #t "wrote ~a~%" (piece-golden-path name))))
            readable)
  (for-each (lambda (name)
              (delete-file (piece-golden-path name))
              (format #t "deleted ~a (no example)~%" (piece-golden-path name)))
            piece-orphans)
  (for-each (lambda (name)
              (format (current-error-port) "can't read ~a: ~a~%"
                      (example-path name) (assoc-ref pieces name)))
            unreadable)
  (null? unreadable))

(define (check)
  "Compare each figure with its saved copy; return #t if all pass."
  (test-begin "golden")
  (for-each
   (lambda (name)
     (test-assert (string-append "example reads: " (example-path name)) #f))
   unreadable)
  (for-each
   (lambda (f)
     (let ((name (figure-name f)))
       (if (member name goldens)
           (test-equal (string-append "figure matches " (golden-path name))
             (read-text (golden-path name))
             (figure-text f))
           (test-assert (string-append "figure has a saved copy: "
                                       (golden-path name)
                                       " is missing (run make golden)")
             #f))))
   figures)
  (for-each
   (lambda (name)
     (test-assert (string-append "saved copy has a figure: "
                                 (golden-path name)
                                 " is no example's figure")
       #f))
   orphans)
  (for-each
   (match-lambda
     ((name . piece)
      (if (member name piece-goldens)
          (test-equal (string-append "saved piece matches " (piece-golden-path name))
            (read-text (piece-golden-path name))
            (piece-text piece))
          (test-assert (string-append "example has a saved piece: "
                                      (piece-golden-path name)
                                      " is missing (run make golden)")
            #f))))
   readable)
  (for-each
   (lambda (name)
     (test-assert (string-append "saved piece has an example: "
                                 (piece-golden-path name)
                                 " is no example's piece")
       #f))
   piece-orphans)
  (let ((runner (test-runner-current)))
    (test-end "golden")
    (zero? (+ (test-runner-fail-count runner)
              (test-runner-xpass-count runner)))))

(exit (if (member "--update" (command-line))
          (update!)
          (check)))
