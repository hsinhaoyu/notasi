;;; Keeps the user manual's examples honest.  See doc/manual/STYLE.md.
;;; - Every example in examples/manual/ reads without errors.
;;; - Every {{#include ...}} in a manual page points to a file that exists.
;;; - Every example is included by at least one page.
;;; - Every mistake in examples/manual/mistakes/ (NAME.nts) fails to read,
;;;   with exactly the message in NAME.txt, and a page includes both.
;;; - Every figure a page shows (figures/NAME.png, drawn by `make images', copied by `make manual')
;;;   has an example, examples/NAME.nts, to draw it from.  A figure of
;;;   another score, figures/NAME_SCORE.png (drawn with --score SCORE),
;;;   needs examples/NAME.nts and a score SCORE in it (slice
;;;   feat/scores-range; 05, "The `notasi' command"; named NAME_SCORE
;;;   since feat/drawing-output, ADR 0040).  A page showing a figure
;;;   by the old name, figures/NAME.SCORE.png, fails: make manual no
;;;   longer draws it.
;;; - Files in a templates/ folder under examples/ or mistakes/ are
;;;   templates, not pieces: they are read through the pieces that use
;;;   them, and each must be included by a page.

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 ftw)
             (ice-9 regex)
             (ice-9 textual-ports)
             (notasi piece)
             (notasi reader))

(define src "doc/manual/src")

;;; Mistakes are read from inside their folder, so find the repo's
;;; templates/ by an absolute path rather than through ".".
(add-to-load-path (getcwd))
(define examples-dir "examples/manual")
(define mistakes-dir "examples/manual/mistakes")

(define (slurp file)
  (call-with-input-file file get-string-all))

(define (files-under dir suffix)
  "Return every file below DIR whose name ends in SUFFIX, as paths."
  (let walk ((dir dir))
    (append-map
     (lambda (name)
       (let ((path (string-append dir "/" name)))
         (cond ((eq? 'directory (stat:type (stat path))) (walk path))
               ((string-suffix? suffix name) (list path))
               (else '()))))
     (or (scandir dir (lambda (f) (not (member f '("." ".."))))) '()))))

(define (canonical path)
  "Resolve . and .. in PATH without touching the file system."
  (string-join
   (reverse
    (fold (lambda (part acc)
            (cond ((member part '("" ".")) acc)
                  ((string=? part "..") (if (null? acc) acc (cdr acc)))
                  (else (cons part acc))))
          '()
          (string-split path #\/)))
   "/"))

(define (includes page)
  "Return the files PAGE includes, as paths relative to the repo root."
  (map (lambda (m)
         (canonical (string-append (dirname page) "/" (match:substring m 1))))
       (list-matches "\\{\\{#include ([^}:[:space:]]+)" (slurp page))))

(define (message-of-reading dir name)
  "Read the file NAME in DIR, from inside DIR so that the message names
the file as a reader would see it.  Return the error message, or #f if
the file reads without a notasi error."
  (let ((here (getcwd)))
    (dynamic-wind
      (lambda () (chdir dir))
      (lambda ()
        (guard (e ((notasi-syntax-error? e) (exception-message e)))
          (read-piece-file name)
          #f))
      (lambda () (chdir here)))))

(define (expected-message nts)
  (string-trim-right (slurp (string-append (string-drop-right nts 4) ".txt"))))

(define (template-file? f)
  (string-contains f "/templates/"))

(define (mistake-file? f)
  (string-prefix? (string-append mistakes-dir "/") f))

(define examples
  (remove (lambda (f) (or (template-file? f) (mistake-file? f)))
          (files-under examples-dir ".nts")))
(define mistakes (remove template-file? (files-under mistakes-dir ".nts")))
(define templates
  ;; files-under examples-dir already walks into mistakes/.
  (filter template-file? (files-under examples-dir ".nts")))
(define pages (files-under src ".md"))
(define figure-pattern "figures/([a-z0-9-]+)(_([a-z0-9-]+))?\\.png")
(define old-figure-pattern "figures/[a-z0-9-]+\\.[a-z0-9-]+\\.png")

(define (old-figures page)
  "The figures/NAME.SCORE.png images PAGE shows, by the name used
before ADR 0040."
  (map match:substring (list-matches old-figure-pattern (slurp page))))

(define (figures page)
  "The examples/NAME.nts files PAGE's figures/NAME.png and
figures/NAME_SCORE.png images need."
  (map (lambda (m)
         (string-append examples-dir "/" (match:substring m 1) ".nts"))
       (list-matches figure-pattern (slurp page))))

(define (score-figures page)
  "(EXAMPLE . SCORE) for each figures/NAME_SCORE.png image PAGE shows,
SCORE a symbol."
  (filter-map (lambda (m)
                (and (match:substring m 3)
                     (cons (string-append examples-dir "/"
                                          (match:substring m 1) ".nts")
                           (string->symbol (match:substring m 3)))))
              (list-matches figure-pattern (slurp page))))

(define (has-score? example score)
  "Does EXAMPLE read, with a score SCORE?"
  (guard (e (#t #f))
    (and (piece-score (read-piece-file example) score) #t)))

;; A page uses a file by {{#include}}, or an example as a drawn figure.
(define included (append (append-map includes pages) (append-map figures pages)))

(test-begin "manual")

(for-each
 (lambda (f)
   (test-assert (string-append "example reads: " f)
     (piece? (read-piece-file f))))
 examples)

(for-each
 (lambda (f)
   (test-equal (string-append "mistake gives its message: " f)
     (expected-message f)
     (message-of-reading (dirname f) (basename f)))
   (for-each
    (lambda (shown)
      (test-assert (string-append "mistake is used by a page: " shown)
        (member shown included)))
    (list f (string-append (string-drop-right f 4) ".txt"))))
 mistakes)

(for-each
 (lambda (page)
   (for-each
    (lambda (f)
      (test-assert (string-append page " includes a file that exists: " f)
        (file-exists? f)))
    (includes page)))
 pages)

(for-each
 (lambda (f)
   (test-assert (string-append "example is used by a page: " f)
     (member f included)))
 (append examples templates))

(for-each
 (lambda (page)
   (for-each
    (lambda (f)
      (test-assert (string-append page " shows a figure drawn from " f)
        (file-exists? f)))
    (figures page)))
 pages)

(for-each
 (lambda (page)
   (for-each
    (lambda (f)
      (test-assert (string-append page " shows score " (symbol->string (cdr f))
                                  " of " (car f) ", which has it")
        (has-score? (car f) (cdr f))))
    (score-figures page)))
 pages)

(for-each
 (lambda (page)
   (for-each
    (lambda (f)
      (test-assert (string-append page " shows " f
                                  ", named NAME_SCORE.png since ADR 0040")
        #f))
    (old-figures page)))
 pages)

(define runner (test-runner-current))
(test-end "manual")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
