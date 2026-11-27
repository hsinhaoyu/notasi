;;; Guards against README.md and CONTRIBUTING.md drifting from the code
;;; (doc/design/07-environment.md, "The README": "Sections and owners",
;;; "CONTRIBUTING.md" and "Tests"; doc/design/08-emacs.md,
;;; "Documentation"; ADR 0062).
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
;;; - Markers: the part before the first `## ' heading has a `# ' title,
;;;   and the line right after it is an owner marker,
;;;   <!-- owner: user --> or <!-- owner: claude -->; so is the line
;;;   right after every `## ' heading.  Each of these parts has exactly
;;;   one owner marker.  Headings aren't checked: not their names, their
;;;   order, nor which owner each section has (07, "Headings aren't
;;;   checked").
;;; - Links: every relative link and image path points to a file or
;;;   folder that exists, relative to the repository root.
;;; - The commands run: the first code block under "Drawing a score"
;;;   has at least one command, and every command line ends with a
;;;   comment `# writes FILE, ...' or `# prints ...'.  Each command is
;;;   run with sh in a fresh temporary folder holding a copy of
;;;   examples/gallery/jaya-semara.nts at that same path, with a leading
;;;   `scripts/notasi' meaning the repository's.  It must exit 0, and
;;;   each FILE after "writes" (relative to the folder) must appear.
;;;   Nothing may be written into the repository's examples/.  If
;;;   `typst' isn't installed, one test says so and fails, as in
;;;   tests/template.scm.
;;; - It no longer has the sections "Layout" and "Running tests".
;;; - Every `make <target>' it mentions is a Makefile target.
;;; - It has a section "Using notasi in Emacs" linking to the manual
;;;   (08-emacs.md, "Documentation").
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
;;; - Markers and links ignore fenced code blocks (``` or ~~~), so a
;;;   shell comment `# ...' in one isn't a title.  A marker may have
;;;   extra spaces inside the comment (<!--owner: user-->) but nothing
;;;   else on its line.  "Exactly one" counts every <!-- owner: comment
;;;   in the part, whatever its value or place.
;;; - Only `## ' headings start sections; `### ' subsections belong to
;;;   their `## ' section and need no marker.
;;; - Links checked: Markdown inline links and images ](path), reference
;;;   definitions [name]: path, and HTML src="..." and href="..."
;;;   attributes (a user may size the picture with <img>).  Skipped: any
;;;   target with a scheme (https:, mailto:, ...) and pure #anchors;
;;;   a #fragment, a "title" and <angle brackets> are removed.  Paths
;;;   aren't URL-decoded.
;;; - The code block is the first fenced or indented one in the section.
;;;   Blank lines and lines starting with `#' are skipped; every other
;;;   line is a command.  The comment starts at the first `#' at the
;;;   start of the line or after a space or tab, as in sh.  FILEs are
;;;   split at commas, trimmed, and stripped of backticks.  A line with
;;;   neither comment fails its test and isn't run (there is nothing to
;;;   expect of it).  `# prints' checks only the exit status.
;;; - A fresh temporary folder per command, so each command works on its
;;;   own right after installing, and a file one command wrote can't
;;;   make another's check pass.
;;; - The command runs as `cd TMP && eval "$CMD"', so pipes and
;;;   redirections work as typed.  Its output is shown when it fails.
;;; - "Nothing is written into examples/" is checked both ways: the
;;;   commands run in the temporary folder, and `git status --porcelain
;;;   --untracked-files=all examples' is the same before and after them.
;;;
;;; Run from the repo root: guile --fresh-auto-compile -L . tests/readme.scm

(use-modules (srfi srfi-1)
             (srfi srfi-9)
             (srfi srfi-11)
             (srfi srfi-64)
             (ice-9 ftw)
             (ice-9 match)
             (ice-9 popen)
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

;;; README.md: the owner markers

(define (lines text)
  (string-split text #\newline))

(define (fence? line)
  "Whether LINE opens or closes a fenced code block (``` or ~~~,
indented at most three spaces)."
  (string-match "^ {0,3}(```|~~~)" line))

(define (outside-fences text-lines)
  "TEXT-LINES with the lines of fenced code blocks (fences included)
replaced by empty strings, so a `# ' comment in a block isn't read as a
heading.  The lines keep their positions."
  (let loop ((ls text-lines) (in-fence? #f) (acc '()))
    (match ls
      (() (reverse acc))
      ((l . rest)
       (cond ((fence? l) (loop rest (not in-fence?) (cons "" acc)))
             (in-fence? (loop rest #t (cons "" acc)))
             (else (loop rest #f (cons l acc))))))))

(define readme-lines (outside-fences (lines readme)))

(define (heading-2? line)
  (string-match "^## " line))

(define (title? line)
  (string-match "^# " line))

(define (marker-line? line)
  "Whether LINE is exactly an owner marker whose value is user or claude."
  (string-match "^<!--[ \t]*owner:[ \t]*(user|claude)[ \t]*-->[ \t]*$" line))

(define (any-marker? line)
  "Whether LINE has an owner marker, of any value or form."
  (string-match "<!--[ \t]*owner:" line))

(define (split-sections text-lines)
  "TEXT-LINES split at each `## ' heading: a list whose first element is
the lines before the first heading (the title part), then one list per
section, each starting with its heading."
  (let loop ((ls text-lines) (current '()) (acc '()))
    (match ls
      (() (reverse (cons (reverse current) acc)))
      ((l . rest)
       (if (heading-2? l)
           (loop rest (list l) (cons (reverse current) acc))
           (loop rest (cons l current) acc))))))

(define readme-parts (split-sections readme-lines))
(define title-part (car readme-parts))
(define readme-sections (cdr readme-parts))

(define (line-after pred part)
  "The line right after the first line of PART that satisfies PRED, or
#f if there is none."
  (match (drop-while (negate pred) part)
    ((_ next . _) next)
    (_ #f)))

(define (check-markers label heading? part)
  (let ((after (line-after heading? part)))
    (test-assert (string-append label
                                ": owner marker (user or claude) on the line after "
                                "its heading")
      (and after (marker-line? after)))
    (test-equal (string-append label ": exactly one owner marker")
      1
      (count any-marker? part))))

(test-assert "README has a `# ' title before its first `## ' heading"
  (find title? title-part))

(check-markers "README's title part" title? title-part)

(test-assert "README has at least one `## ' section"
  (pair? readme-sections))

(for-each
 (lambda (part)
   (check-markers (string-append "README section \"" (substring (car part) 3) "\"")
                  heading-2? part))
 readme-sections)

;;; README.md: the relative links

(define (link-targets text)
  "Every link and image target in TEXT: Markdown inline links and
images, reference definitions, and HTML src and href attributes."
  (append
   (matches "\\]\\(([^)]*)\\)" text 1)
   (matches "(^|\n) {0,3}\\[[^]\n]+\\]:[ \t]+([^ \t\n]+)" text 2)
   (matches "<[a-zA-Z][^>]*[ \t\n](src|href)=\"([^\"]*)\"" text 2)))

(define (link-path target)
  "TARGET as a path relative to the repository root: its angle brackets,
title and #fragment removed.  #f for a link that isn't a relative path:
one with a scheme (https:, mailto:, ...) or only a #fragment."
  (let* ((t (string-trim-both target))
         (t (if (string-prefix? "<" t)
                (string-trim-right (string-trim t #\<) #\>)
                (car (string-split t #\space))))
         (t (car (string-split t #\#))))
    (and (not (string-null? t))
         (not (string-match "^[a-zA-Z][a-zA-Z0-9+.-]*:" t))
         t)))

(define readme-links
  (delete-duplicates
   (filter-map link-path
               (link-targets (string-join readme-lines "\n")))))

(for-each
 (lambda (path)
   (test-assert (string-append "README's link exists: " path)
     (file-exists? path)))
 readme-links)

;;; README.md: the "Drawing a score" commands run

(define drawing-section (section "Drawing a score" readme))

(define (indented? line)
  (string-match "^(    |\t)" line))

(define (blank? line)
  (string-null? (string-trim-both line)))

(define (first-code-block text)
  "The lines of TEXT's first code block, fenced or indented (an indented
one must follow a blank line), with an indented block's indent removed;
#f if there is none."
  (let loop ((ls (lines text)) (previous-blank? #t))
    (match ls
      (() #f)
      ((l . rest)
       (cond ((fence? l)
              (take-while (negate fence?) rest))
             ((and previous-blank? (indented? l) (not (blank? l)))
              (map (lambda (b)
                     (if (indented? b)
                         (substring b (if (string-prefix? "\t" b) 1 4))
                         b))
                   (take-while (lambda (b) (or (indented? b) (blank? b)))
                               ls)))
             (else (loop rest (blank? l))))))))

(define drawing-block (and drawing-section (first-code-block drawing-section)))

(define command-lines
  (if drawing-block
      (remove (lambda (l)
                (or (blank? l) (string-prefix? "#" (string-trim l))))
              drawing-block)
      '()))

(define-record-type <command>
  (make-command line shell kind files)
  command?
  (line command-line)                   ; the line as written
  (shell command-shell)                 ; the part before the comment
  (kind command-kind)                   ; 'writes, 'prints or #f
  (files command-files))                ; the files after "writes"

(define (parse-command line)
  "LINE split at its comment: the first `#' at the start or after a space."
  (let* ((m (string-match "(^|[ \t])#" line))
         (shell (string-trim-both (if m (substring line 0 (match:start m))
                                      line)))
         (comment (if m (string-trim-both (substring line (match:end m))) ""))
         (writes (string-match "^writes[ \t]+(.+)$" comment)))
    (cond (writes
           (make-command line shell 'writes
                         (remove string-null?
                                 (map (lambda (f)
                                        (string-trim-both
                                         (string-trim-both f) #\`))
                                      (string-split (match:substring writes 1)
                                                    #\,)))))
          ((string-match "^prints([ \t]|$)" comment)
           (make-command line shell 'prints '()))
          (else (make-command line shell #f '())))))

(define commands (map parse-command command-lines))

(test-assert "README has a section \"Drawing a score\""
  drawing-section)

(test-assert "README's \"Drawing a score\" has a code block"
  drawing-block)

(test-assert "README's \"Drawing a score\" block has at least one command"
  (pair? commands))

(for-each
 (lambda (c)
   (test-assert (string-append "command ends with `# writes FILE, ...' or "
                               "`# prints ...': " (command-line c))
     (and (command-kind c)
          (not (string-null? (command-shell c)))
          (or (eq? (command-kind c) 'prints)
              (pair? (command-files c))))))
 commands)

(define notasi-script (canonicalize-path "scripts/notasi"))
(define piece "examples/gallery/jaya-semara.nts")

(define (shell-quote s)
  (string-append "'" (string-join (string-split s #\') "'\\''") "'"))

(define (with-repository-notasi shell)
  "SHELL with a leading `scripts/notasi' replaced by the repository's."
  (let ((m (string-match "^scripts/notasi([ \t]|$)" shell)))
    (if m
        (string-append (shell-quote notasi-script)
                       (substring shell (string-length "scripts/notasi")))
        shell)))

(define (typst-installed?)
  (zero? (status:exit-val
          (system* "sh" "-c" "command -v typst >/dev/null 2>&1"))))

(define (examples-status)
  "What git reports as changed or new under examples/."
  (let* ((port (open-pipe* OPEN_READ "git" "status" "--porcelain"
                           "--untracked-files=all" "examples"))
         (out (get-string-all port)))
    (close-pipe port)
    out))

(define (run-in-copy shell files)
  "Run SHELL with sh in a fresh temporary folder holding a copy of the
piece at its path, then remove the folder.  Return three values: the
exit status, the output (stdout and stderr), and the FILES (paths
relative to the folder) that didn't appear."
  (let ((dir (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp")
                                     "/notasi-readme-XXXXXX"))))
    (dynamic-wind
      (const #f)
      (lambda ()
        (mkdir (string-append dir "/examples"))
        (mkdir (string-append dir "/examples/gallery"))
        (copy-file piece (string-append dir "/" piece))
        (let* ((port (open-pipe* OPEN_READ "sh" "-c"
                                 "cd \"$1\" && eval \"$2\" 2>&1"
                                 "sh" dir shell))
               (output (get-string-all port))
               (status (status:exit-val (close-pipe port))))
          (values status output
                  (remove (lambda (f)
                            (file-exists? (string-append dir "/" f)))
                          files))))
      (lambda () (system* "rm" "-rf" dir)))))

(define (check-command c)
  "Two tests for command C: it exits 0, and the files it writes appear.
Its output is shown when either fails."
  (let-values (((status output missing)
                (run-in-copy (with-repository-notasi (command-shell c))
                             (command-files c))))
    (unless (and (eqv? status 0) (null? missing))
      (format (current-error-port) "output of ~a:~%~a~%"
              (command-shell c) output))
    (test-equal (string-append "command succeeds: " (command-shell c))
      0
      status)
    (when (eq? (command-kind c) 'writes)
      (test-equal (string-append "command writes "
                                 (string-join (command-files c) ", ")
                                 ": " (command-shell c))
        '()
        missing))))

(if (typst-installed?)
    (let ((before (examples-status)))
      (for-each check-command (filter command-kind commands))
      (test-equal "the commands write nothing into examples/"
        before
        (examples-status)))
    (test-assert "typst is installed (CI installs 0.15.1)" #f))

(define runner (test-runner-current))
(test-end "readme")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
