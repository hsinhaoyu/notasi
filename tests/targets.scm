;;; Acceptance test of iteration 2 (milestone feat/targets): the two
;;; targets, Gold's Jaya Semara and Tenzer's Baris, read and draw.
;;;
;;; Written from doc/iterations/02-gold-and-tenzer/README.md (the
;;; acceptance test and milestone 3's decisions), the targets in its
;;; targets/ folder (their score names), 01-notation.md (colotomy),
;;; 04-layout.md ("Golden tests") and 05-typst-backend.md (`notasi
;;; render --score`), not from the implementation.
;;;
;;; - examples/jaya-semara.nts and examples/baris.nts read, and their
;;;   scores are exactly the targets' scores, in the targets' order.
;;; - examples/tenzer1.nts reads, with the colotomy gilak, a one-pulse
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
;;; Run from the repo root: guile --fresh-auto-compile -L . tests/targets.scm

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 binary-ports)
             (ice-9 exceptions)
             (ice-9 ftw)
             (ice-9 match)
             (rnrs bytevectors)
             (notasi command)
             (notasi piece)
             (notasi reader))

;;; ------------------------------------------------------------------
;;; Helpers

(define (read-example name)
  "examples/NAME.nts as a piece, or #f if reading it raises."
  (guard (e (#t #f))
    (read-piece-file (string-append "examples/" name ".nts"))))

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
  '(("jaya-semara" (full kotekan))
    ("baris" (full polos-alone sangsih-alone kendang-composite))))

(test-begin "targets")

;;; ------------------------------------------------------------------
;;; The two targets read, with the targets' scores

(for-each
 (match-lambda
   ((name scores)
    (let ((pc (read-example name)))
      (test-group name
        (test-assert (string-append "examples/" name ".nts reads") (piece? pc))
        (test-equal "its scores are the target's" scores
          (and pc (score-names pc)))))))
 targets)

;;; ------------------------------------------------------------------
;;; examples/tenzer1.nts: the gongs come from the colotomy gilak

(test-group "tenzer1"
  (let ((pc (read-example "tenzer1")))
    (test-assert "examples/tenzer1.nts reads" (piece? pc))
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
                (r (run "render" (string-append "examples/" name ".nts")
                        "--score" (symbol->string score) "-o" out)))
           (test-equal (string-append label ": exits with status 0")
             0 (car r))
           (test-equal (string-append label ": prints nothing to stderr")
             "" (caddr r))
           (test-assert (string-append label ": writes an SVG")
             (svg-file? out))))
       scores)))
   targets))

(remove-tree tmp-dir)

(define runner (test-runner-current))
(test-end "targets")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
