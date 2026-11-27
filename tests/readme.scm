;;; Guards against README.md and CONTRIBUTING.md drifting from the code
;;; (doc/design/07-environment.md, "The README": "CONTRIBUTING.md" and
;;; "Tests"; doc/design/08-emacs.md, "Documentation"; ADR 0062).
;;;
;;; The README is for users; "Layout" and "Running tests" moved from it
;;; to CONTRIBUTING.md, for developers, and the checks on them moved too.
;;;
;;; CONTRIBUTING.md:
;;; - It exists, and has the sections "Layout" and "Running tests".
;;; - Every module file in notasi/ is mentioned in it.
;;; - Every notasi/*.scm path it mentions exists.
;;; - Every `make <target>' it mentions is a Makefile target.
;;; - Its layout lists editors/emacs/, and not as "(in progress)".
;;;
;;; README.md:
;;; - It no longer has the sections "Layout" and "Running tests".
;;; - Every `make <target>' it mentions is a Makefile target.
;;; - It has a section "Using notasi in Emacs" linking to the manual
;;;   (08-emacs.md, "Documentation").
;;; - It shows a gallery picture (iteration 5's acceptance test, item 4;
;;;   milestone feat/gallery: jaya-semara_collapsed.png): a Markdown
;;;   image ![...](examples/gallery/images/jaya-semara_collapsed.png),
;;;   and that file exists.
;;;
;;; Choices made where the docs are not explicit:
;;; - A missing CONTRIBUTING.md is read as the empty string, and a test
;;;   "CONTRIBUTING.md exists" fails, so the other tests still run and
;;;   report.
;;; - README's own `make <target>' mentions are still checked.  07 moves
;;;   the checks that were on the README's layout and test commands to
;;;   CONTRIBUTING.md, but the README keeps `make' commands elsewhere
;;;   (its "User manual" section names `make manual' and
;;;   `make manual-serve'), and a stale target there misleads a user as
;;;   much as one in CONTRIBUTING.md.  None of the later checks (links,
;;;   the "Drawing a score" commands) covers them.
;;; - "Moved from the README" is checked as: CONTRIBUTING.md has `## '
;;;   headings "Layout" and "Running tests", and README.md has neither.
;;;   The README is not checked for leftover module paths: a user section
;;;   may still name a file.
;;; - The editors/emacs/ layout entry is a Markdown list item starting
;;;   "- `editors/emacs/`", as it was in the README.
;;;
;;; Run from the repo root: guile --fresh-auto-compile -L . tests/readme.scm

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 ftw)
             (ice-9 regex)
             (ice-9 textual-ports))

(define (slurp file)
  (call-with-input-file file get-string-all))

(define (slurp-or-empty file)
  "Return FILE's text, or the empty string if FILE doesn't exist."
  (if (file-exists? file) (slurp file) ""))

(define (matches pattern text group)
  "Return the GROUPth submatch of every match of PATTERN in TEXT."
  (map (lambda (m) (match:substring m group))
       (list-matches pattern text)))

(define readme (slurp "README.md"))
(define contributing-file "CONTRIBUTING.md")
(define contributing (slurp-or-empty contributing-file))
(define makefile (slurp "Makefile"))

(define module-files
  (map (lambda (f) (string-append "notasi/" f))
       (scandir "notasi" (lambda (f) (string-suffix? ".scm" f)))))

(define (mentioned-modules text)
  (delete-duplicates (matches "notasi/[a-z0-9-]+\\.scm" text 0)))

(define (mentioned-targets text)
  (delete-duplicates (matches "make ([a-z0-9-]+)" text 1)))

(define (section heading text)
  "Return TEXT's section under the `## ' HEADING, up to the next `## '
heading or the end, or #f if there is no such heading."
  (let ((m (string-match (string-append "(^|\n)## " heading "[ \t]*\n")
                         text)))
    (and m
         (let* ((start (match:end m))
                (next (string-match "\n## " text start)))
           (substring text start (if next (match:start next)
                                     (string-length text)))))))

(define (makefile-has-target? target)
  (string-match (string-append "(^|\n)" target ":") makefile))

(define emacs-section (section "Using notasi in Emacs" readme))

(define emacs-layout-item
  ;; CONTRIBUTING.md's layout entry for editors/emacs/, up to the next
  ;; item or blank line.
  (let ((m (string-match "(^|\n)- `editors/emacs/`([^\n]|\n[^-\n])*"
                         contributing)))
    (and m (match:substring m 0))))

(test-begin "readme")

;;; CONTRIBUTING.md

(test-assert "CONTRIBUTING.md exists"
  (file-exists? contributing-file))

(test-assert "CONTRIBUTING.md has a section \"Layout\""
  (section "Layout" contributing))

(test-assert "CONTRIBUTING.md has a section \"Running tests\""
  (section "Running tests" contributing))

(for-each
 (lambda (f)
   (test-assert (string-append "CONTRIBUTING.md mentions " f)
     (string-contains contributing f)))
 module-files)

(for-each
 (lambda (f)
   (test-assert (string-append "CONTRIBUTING.md path exists: " f)
     (file-exists? f)))
 (mentioned-modules contributing))

(for-each
 (lambda (t)
   (test-assert (string-append "Makefile has CONTRIBUTING.md's target: " t)
     (makefile-has-target? t)))
 (mentioned-targets contributing))

(test-assert "CONTRIBUTING.md's layout lists editors/emacs/"
  emacs-layout-item)

(test-assert "CONTRIBUTING.md's layout doesn't call editors/emacs/ in progress"
  (and emacs-layout-item
       (not (string-contains emacs-layout-item "(in progress)"))))

;;; README.md

(test-assert "README has no section \"Layout\" (moved to CONTRIBUTING.md)"
  (not (section "Layout" readme)))

(test-assert "README has no section \"Running tests\" (moved to CONTRIBUTING.md)"
  (not (section "Running tests" readme)))

(for-each
 (lambda (t)
   (test-assert (string-append "Makefile has README's target: " t)
     (makefile-has-target? t)))
 (mentioned-targets readme))

(test-assert "README has a section \"Using notasi in Emacs\""
  emacs-section)

(test-assert "README's Emacs section links to the manual"
  (and emacs-section
       (string-contains emacs-section "https://hsinhaoyu.github.io/notasi/")))

(define gallery-picture "examples/gallery/images/jaya-semara_collapsed.png")

(test-assert "README shows the gallery picture jaya-semara_collapsed.png"
  (string-match (string-append "!\\[[^]]*\\]\\("
                               (regexp-quote gallery-picture) "\\)")
                readme))

(test-assert "README's gallery picture exists"
  (file-exists? gallery-picture))

(define runner (test-runner-current))
(test-end "readme")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
