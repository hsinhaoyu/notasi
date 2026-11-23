;;; Golden tests: each example's figure, as saved in tests/golden/.
;;; See doc/design/04-layout.md, "Slices", item 4.
;;; - Each examples/NAME.nts, laid out with the default style, must
;;;   match tests/golden/NAME.json as text, exactly as write-figure
;;;   writes it.  An example with no saved copy fails, and so does a
;;;   saved copy with no example.
;;; - With --update (make golden), rewrite every saved copy with
;;;   write-figure, delete saved copies with no example, and say what
;;;   changed.  No comparisons are run: the copies were just written.
;;;
;;;
;;; Slice feat/scores-form (04, "Slices (iteration 2)", slice 1):
;;; layout-piece is gone; each example's figure is its first score (its
;;; default score when it has none) laid out with layout-score.  One
;;; figure per example until slice 5.
;;;
;;; Run from the repo root: guile -L . tests/golden.scm [--update]

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 ftw)
             (ice-9 textual-ports)
             (notasi layout)
             (notasi piece)
             (notasi reader)
             (notasi typst))

(define examples-dir "examples")
(define golden-dir "tests/golden")

(define (names-in dir suffix)
  "The names, without SUFFIX, of the files in DIR ending in SUFFIX,
sorted.  No names if DIR doesn't exist."
  (map (lambda (f) (string-drop-right f (string-length suffix)))
       (or (scandir dir (lambda (f) (string-suffix? suffix f))) '())))

(define (example-path name) (string-append examples-dir "/" name ".nts"))
(define (golden-path name) (string-append golden-dir "/" name ".json"))

(define (read-text path)
  (call-with-input-file path get-string-all #:encoding "UTF-8"))

(define (example-figure name)
  "The figure of example NAME: its first score, laid out."
  (let ((piece (read-piece-file (example-path name))))
    (layout-score piece (car (piece-scores piece)))))

(define (figure-text name)
  "The text write-figure writes for example NAME, read back from a
temporary file so that the comparison goes through write-figure."
  (let* ((dir (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp")
                                      "/notasi-golden-XXXXXX")))
         (path (string-append dir "/" name ".json")))
    (dynamic-wind
      (const #f)
      (lambda ()
        (write-figure (example-figure name) path)
        (read-text path))
      (lambda ()
        (when (file-exists? path) (delete-file path))
        (rmdir dir)))))

(define examples (names-in examples-dir ".nts"))
(define goldens (names-in golden-dir ".json"))
(define orphans (lset-difference string=? goldens examples))

(define (update!)
  "Rewrite every saved copy and delete the orphans."
  (unless (file-exists? golden-dir) (mkdir golden-dir))
  (for-each (lambda (name)
              (write-figure (example-figure name) (golden-path name))
              (format #t "wrote ~a~%" (golden-path name)))
            examples)
  (for-each (lambda (name)
              (delete-file (golden-path name))
              (format #t "deleted ~a (no example)~%" (golden-path name)))
            orphans))

(define (check)
  "Compare each example with its saved copy; return #t if all pass."
  (test-begin "golden")
  (for-each
   (lambda (name)
     (if (member name goldens)
         (test-equal (string-append "figure matches " (golden-path name))
           (read-text (golden-path name))
           (figure-text name))
         (test-assert (string-append "example has a saved copy: "
                                     (golden-path name)
                                     " is missing (run make golden)")
           #f)))
   examples)
  (for-each
   (lambda (name)
     (test-assert (string-append "saved copy has an example: "
                                 (example-path name) " is missing")
       #f))
   orphans)
  (let ((runner (test-runner-current)))
    (test-end "golden")
    (zero? (+ (test-runner-fail-count runner)
              (test-runner-xpass-count runner)))))

(exit (if (member "--update" (command-line))
          (begin (update!) #t)
          (check)))
