;;; The licence files: doc/design/07-environment.md, "Licences" ("The
;;; files" and "Tests"; ADRs 0063, 0065).  Written from the design doc
;;; for milestone feat/licences, before the files existed.
;;;
;;; What it checks:
;;; - LICENSE exists and names the MIT licence ("MIT").
;;; - doc/manual/LICENSE and examples/LICENSE exist and each names
;;;   "CC BY 4.0".
;;; - examples/LICENSE and CONTRIBUTING.md each contain, word for word,
;;;   the contribution sentence: "By adding a file to
;;;   `examples/contrib/`, you license it under CC BY 4.0 and confirm you
;;;   have the right to: it's your own transcription or composition, or
;;;   its source allows it."
;;; - Nothing checks the examples' published sources: each example names
;;;   its own, and examples/LICENSE names only the books (ADR 0065).
;;;
;;; Choices made where the docs are not explicit:
;;; - A missing file is read as the empty string, and its own test
;;;   "FILE exists" fails, so the other tests still run and report.
;;; - "Names its licence" is a plain substring search, case-sensitive:
;;;   "MIT" in LICENSE, "CC BY 4.0" in the two notices.  The CC BY
;;;   notices are matched after whitespace is normalised (below), so
;;;   "CC BY 4.0" broken across a line still counts.
;;; - "Word for word" compares after normalising whitespace on both
;;;   sides: every run of spaces, tabs and newlines becomes one space.
;;;   So a sentence wrapped over several lines matches, but its words,
;;;   punctuation, case and backquotes must be exactly as in 07.  A
;;;   Markdown block quote's "> " at the start of a wrapped line is not
;;;   stripped: the sentence is expected as plain running text.
;;;
;;; Run from the repo root: guile --fresh-auto-compile -L . tests/licences.scm

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 regex)
             (ice-9 textual-ports))

(define (slurp file)
  (call-with-input-file file get-string-all))

(define (slurp-or-empty file)
  "Return FILE's text, or the empty string if FILE doesn't exist."
  (if (file-exists? file) (slurp file) ""))

(define (normalise-space text)
  "TEXT with every run of whitespace turned into one space, trimmed."
  (string-trim-both
   (regexp-substitute/global #f "[ \t\r\n]+" text 'pre " " 'post)))

(define (contains? text phrase)
  "Whether PHRASE is in TEXT, whitespace normalised in both."
  (and (string-contains (normalise-space text) (normalise-space phrase))
       #t))

(define licence-file "LICENSE")
(define manual-licence-file "doc/manual/LICENSE")
(define examples-licence-file "examples/LICENSE")
(define contributing-file "CONTRIBUTING.md")

(define licence (slurp-or-empty licence-file))
(define manual-licence (slurp-or-empty manual-licence-file))
(define examples-licence (slurp-or-empty examples-licence-file))
(define contributing (slurp-or-empty contributing-file))

(define contribution-sentence
  "By adding a file to `examples/contrib/`, you license it under CC BY 4.0 and confirm you have the right to: it's your own transcription or composition, or its source allows it.")

(test-begin "licences")

;;; The three files and their licences

(test-assert "LICENSE exists"
  (file-exists? licence-file))

(test-assert "LICENSE names the MIT licence"
  (string-contains licence "MIT"))

(test-assert "doc/manual/LICENSE exists"
  (file-exists? manual-licence-file))

(test-assert "doc/manual/LICENSE names CC BY 4.0"
  (contains? manual-licence "CC BY 4.0"))

(test-assert "examples/LICENSE exists"
  (file-exists? examples-licence-file))

(test-assert "examples/LICENSE names CC BY 4.0"
  (contains? examples-licence "CC BY 4.0"))

;;; The contribution sentence

(test-assert "CONTRIBUTING.md exists"
  (file-exists? contributing-file))

(test-assert "examples/LICENSE has the contribution sentence"
  (contains? examples-licence contribution-sentence))

(test-assert "CONTRIBUTING.md has the contribution sentence"
  (contains? contributing contribution-sentence))

(define runner (test-runner-current))
(test-end "licences")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
