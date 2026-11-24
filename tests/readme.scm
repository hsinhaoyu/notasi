;;; Guards against README.md drifting from the code.
;;; - Every module file in notasi/ must be mentioned in README.md.
;;; - Every notasi/*.scm path README.md mentions must exist.
;;; - Every `make <target>` README.md mentions must be a Makefile target.
;;; - README.md has a section "Using notasi in Emacs" linking to the
;;;   manual, and its layout list no longer calls editors/emacs/ in
;;;   progress (doc/design/08-emacs.md, "Documentation").

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 ftw)
             (ice-9 regex)
             (ice-9 textual-ports))

(define (slurp file)
  (call-with-input-file file get-string-all))

(define (matches pattern text group)
  "Return the GROUPth submatch of every match of PATTERN in TEXT."
  (map (lambda (m) (match:substring m group))
       (list-matches pattern text)))

(define readme (slurp "README.md"))
(define makefile (slurp "Makefile"))

(define module-files
  (map (lambda (f) (string-append "notasi/" f))
       (scandir "notasi" (lambda (f) (string-suffix? ".scm" f)))))

(define readme-modules
  (delete-duplicates (matches "notasi/[a-z0-9-]+\\.scm" readme 0)))

(define readme-targets
  (delete-duplicates (matches "make ([a-z0-9-]+)" readme 1)))

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

(define emacs-section (section "Using notasi in Emacs" readme))

(define emacs-layout-item
  ;; README's layout entry for editors/emacs/, up to the next item or
  ;; blank line.
  (let ((m (string-match "\n- `editors/emacs/`([^\n]|\n[^-\n])*" readme)))
    (and m (match:substring m 0))))

(test-begin "readme")

(for-each
 (lambda (f)
   (test-assert (string-append "README mentions " f)
     (string-contains readme f)))
 module-files)

(for-each
 (lambda (f)
   (test-assert (string-append "README path exists: " f)
     (file-exists? f)))
 readme-modules)

(for-each
 (lambda (t)
   (test-assert (string-append "Makefile has target: " t)
     (string-match (string-append "(^|\n)" t ":") makefile)))
 readme-targets)

(test-assert "README has a section \"Using notasi in Emacs\""
  emacs-section)

(test-assert "README's Emacs section links to the manual"
  (and emacs-section
       (string-contains emacs-section "https://hsinhaoyu.github.io/notasi/")))

(test-assert "README's layout lists editors/emacs/"
  emacs-layout-item)

(test-assert "README's layout no longer calls editors/emacs/ in progress"
  (and emacs-layout-item
       (not (string-contains emacs-layout-item "(in progress)"))))

(define runner (test-runner-current))
(test-end "readme")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
