;;; Tests for (notasi command) and scripts/notasi: the `notasi render'
;;; command.
;;;
;;; Written from doc/design/05-typst-backend.md ("The `notasi' command",
;;; and "The entry file and running Typst" for render-piece) and ADR
;;; 0018, not from the implementation.
;;;
;;; Choices where the spec leaves room (also noted at the tests):
;;; - run-notasi is looked up at run time (resolve-interface), so while
;;;   (notasi command) doesn't exist every test fails instead of the
;;;   file stopping.  Its stdout and stderr are captured with string
;;;   ports; the result of a call is (STATUS STDOUT STDERR).
;;; - "Prints the path it wrote, on one line": stdout is exactly OUT as
;;;   given (or the default) followed by one newline.
;;; - A notation mistake: stderr is exactly the reader's message (the
;;;   exception-message read-piece-file raises for the same path)
;;;   followed by one newline, like the manual's mistakes/*.txt files.
;;; - Every message is one or more whole lines: "notasi: " starts
;;;   stderr for other problems and usage errors.
;;; - A missing PIECE.nts is "a file that can't be read" (status 1,
;;;   "notasi: "), not a notation mistake; its message names the file.
;;; - Usage errors also name what is wrong where there is a name to
;;;   give (the unknown subcommand, the unknown option).
;;; - The default OUT is only tested on files in a temporary folder, so
;;;   the tests never write into examples/.
;;; - "typst not on the PATH": PATH is the current PATH minus every
;;;   folder holding a `typst', as in tests/typst.scm.
;;; - --score (slice feat/scores-range; 05, "The `notasi' command"):
;;;   tested on a copy of examples/gilak.nts.  That the right score is
;;;   drawn is checked by drawing SVGs: --score full and no --score give
;;;   the same bytes, --score second-cycle different ones.  --score may
;;;   come before or after PIECE.nts and -o.  `--score' as the last
;;;   argument is the "without a value" usage error; its message is
;;;   not checked to name --score.  An unknown score's message names it.
;;; - Default OUT with --score (slice feat/drawing-output; 05, "The
;;;   `notasi' command"; ADR 0040): PIECE_NAME.pdf in the piece's
;;;   folder; without --score, PIECE.pdf.  Tested on a copy of gilak in
;;;   its own folder, so the files there are only this test's: the old
;;;   name PIECE.NAME.pdf must not be written, and an unknown score
;;;   writes no PIECE_NAME.pdf.
;;; - scripts/notasi is run by its absolute path from inside the
;;;   temporary folder, with a relative PIECE.nts and OUT, so it must
;;;   find the project (and the gong-kebyar template) from its own
;;;   location, not from `.'.

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 binary-ports)
             (ice-9 exceptions)
             (ice-9 ftw)
             (ice-9 popen)
             (ice-9 textual-ports)
             (rnrs bytevectors)
             (notasi reader))

;;; ------------------------------------------------------------------
;;; Helpers

(define repo-dir (getcwd))
(define example-path (string-append repo-dir "/examples/tenzer1.nts"))
(define script-path (string-append repo-dir "/scripts/notasi"))
(define usage-text "notasi render PIECE.nts")

(define tmp-dir
  (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp") "/notasi-cmd-XXXXXX")))

(define (tmp-path name)
  (string-append tmp-dir "/" name))

(define (read-bytes path)
  (call-with-input-file path get-bytevector-all #:binary #t))

(define (write-text path text)
  (call-with-output-file path (lambda (port) (put-string port text))
    #:encoding "UTF-8"))

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
       (let ((bytes (read-bytes path)))
         (and (bytevector? bytes)
              (>= (bytevector-length bytes) (bytevector-length want))
              (let ((head (make-bytevector (bytevector-length want))))
                (bytevector-copy! bytes 0 head 0 (bytevector-length want))
                (equal? head want))))))

(define (pdf-file? path)
  (file-starts-with-bytes? path (string->utf8 "%PDF")))

(define (png-file? path)
  (file-starts-with-bytes? path #vu8(#x89 #x50 #x4e #x47 #x0d #x0a #x1a #x0a)))

(define (svg-file? path)
  (or (file-starts-with-bytes? path (string->utf8 "<svg"))
      (file-starts-with-bytes? path (string->utf8 "<?xml"))))

;;; run-notasi, or #f while (notasi command) doesn't exist.
(define run-notasi
  (let ((iface (false-if-exception (resolve-interface '(notasi command)))))
    (and iface
         (module-variable iface 'run-notasi)
         (module-ref iface 'run-notasi))))

(define (run . args)
  "Call run-notasi with ARGS and return (STATUS STDOUT STDERR).  STATUS
is 'missing if run-notasi doesn't exist, or (raised E) if it raises."
  (if (not run-notasi)
      (list 'missing "" "")
      (let ((out (open-output-string))
            (err (open-output-string)))
        (let ((status (guard (e (#t (list 'raised e)))
                        (parameterize ((current-output-port out)
                                       (current-error-port err))
                          (run-notasi args)))))
          (list status (get-output-string out) (get-output-string err))))))

(define (status-of r) (car r))
(define (stdout-of r) (cadr r))
(define (stderr-of r) (caddr r))

(define (call-with-env name value thunk)
  "Call THUNK with the environment variable NAME set to VALUE, then
restore it, even if THUNK raises."
  (let ((old (getenv name)))
    (dynamic-wind
      (lambda () (setenv name value))
      thunk
      (lambda () (if old (setenv name old) (unsetenv name))))))

(define (path-without-typst)
  "The current PATH without the folders that hold a `typst'."
  (string-join
   (filter (lambda (dir)
             (not (file-exists? (string-append
                                 (if (string-null? dir) "." dir)
                                 "/typst"))))
           (string-split (or (getenv "PATH") "") #\:))
   ":"))

(define (typst-on-path? path)
  (any (lambda (dir)
         (let ((file (string-append (if (string-null? dir) "." dir) "/typst")))
           (and (file-exists? file) (access? file X_OK))))
       (string-split path #\:)))

(define (starts-with-notasi? text)
  (string-prefix? "notasi: " text))

(define (usage-error-checks name r . also)
  "The checks every usage error shares: status 2, nothing on stdout,
stderr starting with \"notasi: \" and containing the usage line, and
each string in ALSO."
  (test-equal (string-append name ": exits with status 2")
    2 (status-of r))
  (test-equal (string-append name ": prints nothing to stdout")
    "" (stdout-of r))
  (test-assert (string-append name ": stderr starts with \"notasi: \"")
    (starts-with-notasi? (stderr-of r)))
  (test-assert (string-append name ": stderr has the usage line")
    (string-contains (stderr-of r) usage-text))
  (for-each
   (lambda (text)
     (test-assert (string-append name ": stderr names " text)
       (string-contains (stderr-of r) text)))
   also))

;;; The piece, copied next to its outputs (it uses gong-kebyar, which is
;;; found along %load-path, so the copy reads the same).
(define piece (tmp-path "tenzer1.nts"))
(copy-file example-path piece)

(test-begin "command")

(test-assert "(notasi command) exports run-notasi"
  (procedure? run-notasi))

;;; ------------------------------------------------------------------
;;; render: success

(test-group "render, default OUT"
  (let ((out (tmp-path "tenzer1.pdf"))
        (r (run "render" piece)))
    (test-equal "exits with status 0" 0 (status-of r))
    (test-equal "prints the default OUT (PIECE's folder and name, .pdf) and a newline"
      (string-append out "\n") (stdout-of r))
    (test-equal "prints nothing to stderr" "" (stderr-of r))
    (test-assert "writes a PDF there" (pdf-file? out))))

;;; (NAME ARGS OUT CHECK): the option's spelling and place, and the
;;; format from OUT's extension.
(for-each
 (lambda (spec)
   (let* ((name (car spec))
          (out (caddr spec))
          (ok? (cadddr spec))
          (r (apply run (cadr spec))))
     (test-group name
       (test-equal "exits with status 0" 0 (status-of r))
       (test-equal "prints OUT as given and a newline"
         (string-append out "\n") (stdout-of r))
       (test-equal "prints nothing to stderr" "" (stderr-of r))
       (test-assert "writes the file in OUT's format" (ok? out)))))
 (let ((a (tmp-path "a.png"))
       (b (tmp-path "b.svg"))
       (c (tmp-path "c.pdf"))
       (d (tmp-path "d.png")))
   `(("-o before PIECE, .png" ("render" "-o" ,a ,piece) ,a ,png-file?)
     ("--output after PIECE, .svg" ("render" ,piece "--output" ,b) ,b ,svg-file?)
     ("-o after PIECE, .pdf" ("render" ,piece "-o" ,c) ,c ,pdf-file?)
     ("--output before PIECE, .png" ("render" "--output" ,d ,piece) ,d ,png-file?))))

;;; ------------------------------------------------------------------
;;; --score NAME (slice feat/scores-range): gilak has scores full and
;;; second-cycle.

(define gilak (tmp-path "gilak.nts"))
(copy-file (string-append repo-dir "/examples/gilak.nts") gilak)

(define (same-bytes? a b)
  (and (file-exists? a) (file-exists? b)
       (equal? (read-bytes a) (read-bytes b))))

(test-group "render --score, default OUT"
  (for-each
   (lambda (args)
     (let* ((score (car args))
            (out (tmp-path (string-append "gilak_" score ".pdf")))   ; ADR 0040
            (r (apply run (cdr args))))
       (test-equal (string-append score ": exits with status 0") 0 (status-of r))
       (test-equal (string-append score ": prints PIECE_NAME.pdf and a newline")
         (string-append out "\n") (stdout-of r))
       (test-equal (string-append score ": prints nothing to stderr") "" (stderr-of r))
       (test-assert (string-append score ": writes a PDF there") (pdf-file? out))))
   `(("second-cycle" "render" ,gilak "--score" "second-cycle")
     ("full" "render" "--score" "full" ,gilak)))
  (let ((r (run "render" gilak)))
    (test-equal "without --score: PIECE.pdf" (string-append (tmp-path "gilak.pdf") "\n")
      (stdout-of r))))

(test-group "render --score with -o"
  (let ((full (tmp-path "full.svg"))
        (second (tmp-path "second.svg"))
        (first (tmp-path "first.svg")))
    (let ((r (run "render" gilak "--score" "second-cycle" "-o" second)))
      (test-equal "exits with status 0" 0 (status-of r))
      (test-equal "prints OUT as given" (string-append second "\n") (stdout-of r))
      (test-assert "writes an SVG" (svg-file? second)))
    (run "render" "-o" full "--score" "full" gilak)
    (run "render" gilak "-o" first)
    (test-assert "--score full: an SVG" (svg-file? full))
    (test-assert "the two scores draw different pictures"
      (and (svg-file? full) (svg-file? second)
           (not (same-bytes? full second))))
    (test-assert "without --score, the first score (full) is drawn"
      (same-bytes? full first))))

;;; ------------------------------------------------------------------
;;; Default OUT with --score: PIECE_NAME.pdf (slice feat/drawing-output,
;;; ADR 0040)

(define named-dir (tmp-path "named"))
(mkdir named-dir)
(define (named-path name) (string-append named-dir "/" name))
(define named-gilak (named-path "gilak.nts"))
(copy-file (string-append repo-dir "/examples/gilak.nts") named-gilak)

(test-group "render --score, default OUT PIECE_NAME.pdf"
  (for-each
   (lambda (args)
     (let* ((score (car args))
            (out (named-path (string-append "gilak_" score ".pdf")))
            (r (apply run (cdr args))))
       (test-equal (string-append score ": exits with status 0") 0 (status-of r))
       (test-equal (string-append score ": prints PIECE_NAME.pdf, in the piece's folder, and a newline")
         (string-append out "\n") (stdout-of r))
       (test-equal (string-append score ": prints nothing to stderr") "" (stderr-of r))
       (test-assert (string-append score ": writes a PDF there") (pdf-file? out))
       (test-assert (string-append score ": doesn't write PIECE.NAME.pdf")
         (not (file-exists? (named-path (string-append "gilak." score ".pdf")))))))
   `(("second-cycle" "render" ,named-gilak "--score" "second-cycle")
     ("full" "render" "--score" "full" ,named-gilak)))
  (let* ((out (named-path "gilak.pdf"))
         (r (run "render" named-gilak)))
    (test-equal "without --score: exits with status 0" 0 (status-of r))
    (test-equal "without --score: prints PIECE.pdf" (string-append out "\n")
      (stdout-of r))
    (test-assert "without --score: writes a PDF there" (pdf-file? out)))
  (let ((r (run "render" named-gilak "--score" "nope")))
    (test-equal "unknown score: exits with status 1" 1 (status-of r))
    (test-assert "unknown score: writes no PIECE_NAME.pdf"
      (not (file-exists? (named-path "gilak_nope.pdf"))))))

;;; ------------------------------------------------------------------
;;; A notation mistake: the reader's message exactly, status 1

(test-group "notation mistake"
  (let* ((nts (tmp-path "mistake.nts"))
         (out (tmp-path "mistake.pdf")))
    (write-text nts "(piece \"Gilak\")\n(pice \"Kotekan\")\n")
    (let ((message (guard (e ((notasi-syntax-error? e) (exception-message e)))
                     (read-piece-file nts)
                     #f))
          (r (run "render" nts)))
      (test-assert "(the reader rejects the test file)" (string? message))
      (test-equal "exits with status 1" 1 (status-of r))
      (test-equal "stderr is the reader's message and a newline"
        (and message (string-append message "\n"))
        (stderr-of r))
      (test-equal "prints nothing to stdout" "" (stdout-of r))
      (test-assert "writes no output file" (not (file-exists? out))))))

;;; ------------------------------------------------------------------
;;; Other problems: "notasi: " and the message, status 1

(define (other-problem-checks name r out . also)
  (test-equal (string-append name ": exits with status 1") 1 (status-of r))
  (test-assert (string-append name ": stderr starts with \"notasi: \"")
    (starts-with-notasi? (stderr-of r)))
  (test-equal (string-append name ": prints nothing to stdout") "" (stdout-of r))
  (test-assert (string-append name ": writes no output file")
    (not (file-exists? out)))
  (for-each
   (lambda (text)
     (test-assert (string-append name ": stderr mentions " text)
       (string-contains (stderr-of r) text)))
   also))

(test-group "other problems"
  ;; A missing PIECE.nts can't be read: not a notation mistake.
  (let ((nts (tmp-path "missing.nts"))
        (out (tmp-path "missing.pdf")))
    (other-problem-checks "missing PIECE.nts" (run "render" nts) out
                          "missing.nts"))

  (let ((out (tmp-path "x.jpg")))
    (other-problem-checks "unsupported extension (.jpg)"
                          (run "render" piece "-o" out) out))

  ;; A score the piece doesn't have: "notasi: " and the message.
  (let ((out (tmp-path "gilak_nope.pdf")))
    (other-problem-checks "unknown score" (run "render" gilak "--score" "nope")
                          out "nope"))

  (let* ((path (path-without-typst))
         (out (tmp-path "no-typst.pdf")))
    (test-assert "typst not on the PATH: (the test's PATH really has no typst)"
      (not (typst-on-path? path)))
    (other-problem-checks "typst not on the PATH"
                          (call-with-env "PATH" path
                            (lambda () (run "render" piece "-o" out)))
                          out
                          "0.15.1")))

;;; ------------------------------------------------------------------
;;; Using the command wrongly: status 2

(test-group "usage errors"
  (usage-error-checks "no arguments" (run))
  (usage-error-checks "unknown subcommand" (run "draw" piece) "draw")
  (usage-error-checks "unknown option" (run "render" piece "--colour") "--colour")
  (usage-error-checks "render with no PIECE.nts" (run "render"))
  (usage-error-checks "render with two PIECE.nts"
                      (run "render" piece (tmp-path "other.nts")))
  (usage-error-checks "-o without a value" (run "render" piece "-o"))
  (usage-error-checks "--score without a value" (run "render" piece "--score")))

;;; ------------------------------------------------------------------
;;; --help

(for-each
 (lambda (args)
   (let ((name (string-join args " "))
         (r (apply run args)))
     (test-group name
       (test-equal "exits with status 0" 0 (status-of r))
       (test-assert "stdout has the usage line"
         (string-contains (stdout-of r) usage-text))
       (test-equal "prints nothing to stderr" "" (stderr-of r)))))
 '(("--help") ("render" "--help")))

;;; ------------------------------------------------------------------
;;; --version (05, "The command line as a contract"; ADR 0048; slice
;;; feat/emacs-preview-draw).  Choices: stdout is exactly
;;; "notasi VERSION\n", VERSION being N.N.N or N.N.N-dev; --version is
;;; tested alone.  `notasi --help' names --version, and gives the
;;; default OUT with --score as PIECE_NAME.pdf (ADR 0040), not the old
;;; PIECE.NAME.pdf.

(define (version-line? text)
  "Is TEXT \"notasi VERSION\" and one newline, VERSION N.N.N[-dev]?"
  (and (string-prefix? "notasi " text)
       (string-suffix? "\n" text)
       (let* ((version (substring text 7 (- (string-length text) 1)))
              (parts (string-split version #\-))
              (numbers (string-split (car parts) #\.)))
         (and (or (null? (cdr parts))
                  (equal? (cdr parts) '("dev")))
              (= 3 (length numbers))
              (every (lambda (n)
                       (and (not (string-null? n))
                            (string-every char-numeric? n)))
                     numbers)))))

(test-group "--version"
  (let ((r (run "--version")))
    (test-equal "exits with status 0" 0 (status-of r))
    (test-assert "prints notasi VERSION and a newline"
      (version-line? (stdout-of r)))
    (test-equal "prints nothing to stderr" "" (stderr-of r))))

(test-group "--help and --version"
  (let ((r (run "--help")))
    (test-assert "--help mentions --version"
      (string-contains (stdout-of r) "--version"))
    (test-assert "--help gives the default OUT with --score as PIECE_NAME.pdf"
      (string-contains (stdout-of r) "PIECE_NAME.pdf"))
    (test-assert "--help doesn't give the old PIECE.NAME.pdf"
      (not (string-contains (stdout-of r) "PIECE.NAME.pdf")))))

;;; ------------------------------------------------------------------
;;; scripts/notasi

(test-group "scripts/notasi"
  (test-assert "is executable"
    (and (file-exists? script-path) (access? script-path X_OK)))
  ;; Run from the temporary folder, so `.' is not the project.
  (let* ((port (open-input-pipe
                (string-append "cd '" tmp-dir "' && '" script-path
                               "' render tenzer1.nts -o script.pdf 2>/dev/null")))
         (output (get-string-all port))
         (status (status:exit-val (close-pipe port))))
    (test-equal "run from another folder: exits with status 0" 0 status)
    (test-equal "run from another folder: prints OUT and a newline"
      "script.pdf\n" output)
    (test-assert "run from another folder: writes the PDF"
      (pdf-file? (tmp-path "script.pdf")))))

;;; ==================================================================
;;; Milestone feat/render-all (iteration 5; 05, "The `notasi' command",
;;; Planned (ADR 0061)): --all, --format, --ppi, --one-file, --list.
;;; --save-piece is a later milestone and isn't tested here.
;;;
;;; Choices where the spec leaves room:
;;; - The fixture three.nts is tenzer1 with three scores, written in the
;;;   order zeta, alpha, mid (not alphabetical, so "in score order" and
;;;   "in the order written" can't pass by sorting).  A copy of tenzer1
;;;   is the file with no score form.  Each group works in its own
;;;   folder, so "nothing written" is checked as the folder's names
;;;   being unchanged.
;;; - Paths are given absolute, so a printed path is the folder (or -o
;;;   DIR) as given, one "/" and the file's name.
;;; - --all: stdout is exactly one line per file, in score order.
;;; - --ppi: checked by a PNG's width: at 72 about half (within 2
;;;   pixels) of the width at 144, and no --ppi gives the width at 144.
;;; - --one-file: pages are counted as the PDF's /Type/Page objects;
;;;   no NAME_SCORE.pdf is written beside it.  Page order isn't checked.
;;; - A score Typst fails on: with --all -o DIR, a folder already
;;;   standing where one score's file goes (DIR/three_alpha.pdf/), so
;;;   Typst can't write that file.  The others are still drawn, the
;;;   status is 1, stderr starts "notasi: ", and no line of stdout names
;;;   the file that failed.
;;; - --list needs no Typst: tested with typst taken off the PATH.
;;; - A notation mistake with --list is reported as when drawing: the
;;;   reader's message and a newline on stderr, status 1.
;;; - "--all with -o naming a file": -o an existing regular file, a
;;;   path ending .pdf, and a missing path without a trailing "/".
;;; - "--format disagreeing with -o's extension" covers -o out.png
;;;   --format svg; --format png with -o out.png agrees (status 0).
;;; - Usage errors use usage-error-checks (status 2, nothing on
;;;   stdout, "notasi: " and the usage line), and also check that
;;;   nothing is written in the folder.

(use-modules (ice-9 iconv)
             (ice-9 regex))

(define three-scores
  (string-append
   "\n(score zeta (group \"Ugal\" ugal))\n"
   "(score alpha :palette set3 (group \"Ugal\" ugal))\n"
   "(score mid :title \"Middle\" (group \"Ugal\" ugal))\n"))

(define score-order '("zeta" "alpha" "mid"))

(define (entries dir)
  "The names in DIR, sorted, without . and .."
  (scandir dir (lambda (f) (not (member f '("." ".."))))))

(define (make-piece-dir name kind)
  "Make the folder NAME in tmp-dir holding one piece, and return the
piece's path: three.nts (three scores) when KIND is 'three, else
tenzer1.nts (no score form)."
  (let ((dir (tmp-path name)))
    (mkdir dir)
    (let ((nts (string-append dir (if (eq? kind 'three) "/three.nts" "/tenzer1.nts"))))
      (write-text nts (string-append
                       (call-with-input-file example-path get-string-all
                         #:encoding "UTF-8")
                       (if (eq? kind 'three) three-scores "")))
      nts)))

(define (lines . paths)
  "PATHS, each followed by a newline, as one string."
  (string-concatenate (map (lambda (p) (string-append p "\n")) paths)))

(define (score-files dir piece-name ext)
  "DIR/PIECE-NAME_SCORE.EXT for each score of three.nts, in order."
  (map (lambda (s) (string-append dir "/" piece-name "_" s "." ext))
       score-order))

(define (pdf-page-count path)
  "The number of pages in the PDF file PATH, from its /Type/Page objects."
  (length (list-matches "/Type[ \n\r]*/Page([^s]|$)"
                        (bytevector->string (read-bytes path) "ISO-8859-1"))))

(define (png-width path)
  (and (png-file? path)
       (bytevector-u32-ref (read-bytes path) 16 (endianness big))))

(define (success-checks name r out-lines)
  "Status 0, stdout exactly OUT-LINES, nothing on stderr."
  (test-equal (string-append name ": exits with status 0") 0 (status-of r))
  (test-equal (string-append name ": prints one line per file, in score order")
    out-lines (stdout-of r))
  (test-equal (string-append name ": prints nothing to stderr") "" (stderr-of r)))

;;; ------------------------------------------------------------------
;;; --all

(test-group "render --all"
  (let* ((nts (make-piece-dir "all" 'three))
         (dir (dirname nts))
         (outs (score-files dir "three" "pdf"))
         (r (run "render" nts "--all")))
    (success-checks "three scores" r (apply lines outs))
    (test-assert "three scores: each score to NAME_SCORE.pdf, the first included"
      (every pdf-file? outs))
    (test-equal "three scores: writes nothing else (no NAME.pdf)"
      (sort (cons "three.nts" (map basename outs)) string<?)
      (entries dir)))
  (let* ((nts (make-piece-dir "all-none" 'none))
         (dir (dirname nts))
         (out (string-append dir "/tenzer1.pdf"))
         (r (run "render" "--all" nts)))
    (success-checks "no score form" r (lines out))
    (test-assert "no score form: the default score to NAME.pdf" (pdf-file? out))
    (test-equal "no score form: writes nothing else"
      '("tenzer1.nts" "tenzer1.pdf") (entries dir))))

(test-group "render --all -o DIR"
  (let* ((nts (make-piece-dir "all-o" 'three))
         (out-dir (tmp-path "all-o/existing")))
    (mkdir out-dir)
    (let* ((outs (score-files out-dir "three" "pdf"))
           (r (run "render" nts "--all" "-o" out-dir)))
      (success-checks "existing folder" r (apply lines outs))
      (test-assert "existing folder: the files are in DIR" (every pdf-file? outs))
      (test-equal "existing folder: nothing beside the piece"
        '("existing" "three.nts") (entries (dirname nts)))))
  (let* ((nts (make-piece-dir "all-slash" 'three))
         (out-dir (tmp-path "all-slash/existing")))
    (mkdir out-dir)
    (let* ((outs (score-files out-dir "three" "pdf"))
           (r (run "render" nts "--all" "-o" (string-append out-dir "/"))))
      (success-checks "existing folder ending in /: one / in each path"
                      r (apply lines outs))
      (test-assert "existing folder ending in /: the files are in DIR"
        (every pdf-file? outs))))
  (let* ((nts (make-piece-dir "all-new2" 'three))
         (out-dir (tmp-path "all-new2/made/deeper"))
         (outs (score-files out-dir "three" "pdf"))
         (r (run "render" nts "-o" (string-append out-dir "/") "--all")))
    (success-checks "missing folder ending in /" r (apply lines outs))
    (test-assert "missing folder ending in /: made, with missing parents"
      (and (file-exists? out-dir)
           (eq? 'directory (stat:type (stat out-dir)))))
    (test-assert "missing folder ending in /: the files are in it"
      (every pdf-file? outs))))

(test-group "render --all, a score Typst fails on"
  (let* ((nts (make-piece-dir "all-fail" 'three))
         (out-dir (tmp-path "all-fail/out"))
         (outs (score-files out-dir "three" "pdf"))
         (blocked (cadr outs)))          ; three_alpha.pdf
    (mkdir out-dir)
    (mkdir blocked)
    (let ((r (run "render" nts "--all" "-o" out-dir)))
      (test-equal "exits with status 1" 1 (status-of r))
      (test-assert "stderr starts with \"notasi: \""
        (starts-with-notasi? (stderr-of r)))
      (test-assert "the other scores are still drawn"
        (and (pdf-file? (car outs)) (pdf-file? (caddr outs))))
      (test-assert "stdout has no line for the file that failed"
        (not (member blocked (string-split (stdout-of r) #\newline)))))))

(test-group "render --all, a notation mistake"
  (let* ((dir (tmp-path "all-mistake"))
         (nts (string-append dir "/mistake.nts")))
    (mkdir dir)
    (write-text nts (string-append
                     "(piece \"Gilak\")\n(pice \"Kotekan\")\n"
                     "(score a (group \"Ugal\" ugal))\n"))
    (let ((message (guard (e ((notasi-syntax-error? e) (exception-message e)))
                     (read-piece-file nts)
                     #f))
          (r (run "render" nts "--all")))
      (test-assert "(the reader rejects the test file)" (string? message))
      (test-equal "exits with status 1" 1 (status-of r))
      (test-equal "stderr is the reader's message and a newline"
        (and message (string-append message "\n")) (stderr-of r))
      (test-equal "prints nothing to stdout" "" (stdout-of r))
      (test-equal "draws nothing" '("mistake.nts") (entries dir)))))

;;; ------------------------------------------------------------------
;;; --format

(test-group "render --format"
  (let* ((nts (make-piece-dir "format" 'three))
         (dir (dirname nts)))
    (let* ((out (string-append dir "/three.png"))
           (r (run "render" nts "--format" "png")))
      (success-checks "--format png: PIECE.png" r (lines out))
      (test-assert "--format png: a PNG" (png-file? out)))
    (let* ((out (string-append dir "/three_alpha.svg"))
           (r (run "render" "--format" "svg" "--score" "alpha" nts)))
      (success-checks "--format svg --score alpha: PIECE_NAME.svg" r (lines out))
      (test-assert "--format svg --score alpha: an SVG" (svg-file? out)))
    (let* ((out (string-append dir "/three_mid.pdf"))
           (r (run "render" nts "--score" "mid" "--format" "pdf")))
      (success-checks "--format pdf --score mid" r (lines out))
      (test-assert "--format pdf: a PDF" (pdf-file? out)))
    (let* ((out (string-append dir "/named"))
           (r (run "render" nts "-o" out "--format" "png")))
      (success-checks "-o FILE without an extension: --format adds it"
                      r (lines (string-append out ".png")))
      (test-assert "-o FILE without an extension: a PNG at FILE.png"
        (png-file? (string-append out ".png")))
      (test-assert "-o FILE without an extension: nothing at FILE"
        (not (file-exists? out))))
    (let* ((out (string-append dir "/agrees.png"))
           (r (run "render" nts "-o" out "--format" "png")))
      (success-checks "--format agreeing with -o's extension" r (lines out))
      (test-assert "--format agreeing with -o's extension: a PNG" (png-file? out))))
  (let* ((nts (make-piece-dir "format-all" 'three))
         (dir (dirname nts)))
    (let* ((outs (score-files dir "three" "svg"))
           (r (run "render" nts "--all" "--format" "svg")))
      (success-checks "--all --format svg" r (apply lines outs))
      (test-assert "--all --format svg: each an SVG" (every svg-file? outs)))
    (let* ((out-dir (string-append dir "/png/"))
           (outs (score-files (string-append dir "/png") "three" "png"))
           (r (run "render" nts "--all" "--format" "png" "-o" out-dir)))
      (success-checks "--all --format png -o DIR/" r (apply lines outs))
      (test-assert "--all --format png -o DIR/: each a PNG" (every png-file? outs)))))

;;; ------------------------------------------------------------------
;;; --ppi

(test-group "render --ppi"
  (let* ((nts (make-piece-dir "ppi" 'none))
         (dir (dirname nts))
         (at-72 (string-append dir "/at72.png"))
         (at-144 (string-append dir "/at144.png"))
         (plain (string-append dir "/plain.png")))
    (success-checks "--ppi 72 -o FILE.png" (run "render" nts "--ppi" "72" "-o" at-72)
                    (lines at-72))
    (run "render" nts "-o" at-144 "--ppi" "144")
    (run "render" nts "-o" plain)
    (test-assert "--ppi 72: about half as wide as at 144"
      (let ((a (png-width at-72)) (b (png-width at-144)))
        (and a b (<= (abs (- (* 2 a) b)) 2))))
    (test-assert "the default is 144 ppi"
      (let ((a (png-width plain)))
        (and a (eqv? a (png-width at-144)))))
    (let* ((out (string-append dir "/tenzer1.png"))
           (r (run "render" nts "--format" "png" "--ppi" "72")))
      (success-checks "--format png --ppi 72" r (lines out))
      (test-equal "--format png --ppi 72: the same width as -o FILE.png --ppi 72"
        (png-width at-72) (png-width out))))
  (let* ((nts (make-piece-dir "ppi-all" 'three))
         (dir (dirname nts))
         (outs (score-files dir "three" "png"))
         (r (run "render" nts "--all" "--format" "png" "--ppi" "72")))
    (success-checks "--all --format png --ppi 72" r (apply lines outs))
    (test-assert "--all --format png --ppi 72: each a PNG" (every png-file? outs))))

;;; ------------------------------------------------------------------
;;; --one-file

(test-group "render --all --one-file"
  (let* ((nts (make-piece-dir "one-file" 'three))
         (dir (dirname nts))
         (out (string-append dir "/three.pdf"))
         (r (run "render" nts "--all" "--one-file")))
    (success-checks "default OUT" r (lines out))
    (test-assert "default OUT: NAME.pdf beside the piece" (pdf-file? out))
    (test-equal "default OUT: one page per score"
      3 (and (pdf-file? out) (pdf-page-count out)))
    (test-equal "default OUT: writes no NAME_SCORE.pdf"
      '("three.nts" "three.pdf") (entries dir)))
  (let* ((nts (make-piece-dir "one-file-o" 'three))
         (dir (dirname nts))
         (out (string-append dir "/book.pdf"))
         (r (run "render" "--one-file" "-o" out nts "--all")))
    (success-checks "-o FILE.pdf" r (lines out))
    (test-equal "-o FILE.pdf: one page per score"
      3 (and (pdf-file? out) (pdf-page-count out))))
  (let* ((nts (make-piece-dir "one-file-none" 'none))
         (out (string-append (dirname nts) "/tenzer1.pdf"))
         (r (run "render" nts "--all" "--one-file" "--format" "pdf")))
    (success-checks "no score form, --format pdf" r (lines out))
    (test-equal "no score form: one page"
      1 (and (pdf-file? out) (pdf-page-count out)))))

;;; ------------------------------------------------------------------
;;; --list

(test-group "render --list"
  (let* ((nts (make-piece-dir "list" 'three))
         (dir (dirname nts))
         (r (run "render" nts "--list")))
    (success-checks "three scores: the names, in the order written"
                    r (apply lines score-order))
    (test-equal "three scores: draws nothing" '("three.nts") (entries dir)))
  (let* ((nts (make-piece-dir "list-none" 'none))
         (dir (dirname nts))
         (r (run "render" "--list" nts)))
    (success-checks "no score form: prints nothing" r "")
    (test-equal "no score form: draws nothing" '("tenzer1.nts") (entries dir)))
  (let* ((nts (make-piece-dir "list-no-typst" 'three))
         (path (path-without-typst))
         (r (call-with-env "PATH" path (lambda () (run "render" nts "--list")))))
    (test-assert "without Typst: (the test's PATH really has no typst)"
      (not (typst-on-path? path)))
    (success-checks "without Typst: lists all the same" r (apply lines score-order)))
  (let* ((dir (tmp-path "list-mistake"))
         (nts (string-append dir "/mistake.nts")))
    (mkdir dir)
    (write-text nts "(piece \"Gilak\")\n(pice \"Kotekan\")\n")
    (let ((message (guard (e ((notasi-syntax-error? e) (exception-message e)))
                     (read-piece-file nts)
                     #f))
          (r (run "render" nts "--list")))
      (test-equal "notation mistake: exits with status 1" 1 (status-of r))
      (test-equal "notation mistake: stderr is the reader's message (FILE:LINE: ...)"
        (and message (string-append message "\n")) (stderr-of r))
      (test-equal "notation mistake: prints nothing to stdout" "" (stdout-of r))
      (test-equal "notation mistake: draws nothing" '("mistake.nts") (entries dir)))))

;;; ------------------------------------------------------------------
;;; Usage errors of the new options: status 2, nothing written

(define usage-dir (tmp-path "usage-new"))
(mkdir usage-dir)
(define usage-piece (string-append usage-dir "/three.nts"))
(write-text usage-piece
            (string-append (call-with-input-file example-path get-string-all
                             #:encoding "UTF-8")
                           three-scores))
(define usage-file (string-append usage-dir "/existing.txt"))
(write-text usage-file "not a folder\n")
(define (usage-path name) (string-append usage-dir "/" name))

(test-group "usage errors of --all, --format, --ppi, --one-file, --list"
  (for-each
   (lambda (spec)
     (let* ((name (car spec))
            (before (entries usage-dir))
            (r (apply run "render" usage-piece (cdr spec))))
       (usage-error-checks name r)
       (test-equal (string-append name ": writes nothing")
         before (entries usage-dir))))
   `(("--all with --score" "--all" "--score" "alpha")
     ("--all with -o an existing file" "--all" "-o" ,usage-file)
     ("--all with -o FILE.pdf" "--all" "-o" ,(usage-path "out.pdf"))
     ("--all with -o a missing path without a trailing /"
      "--all" "-o" ,(usage-path "nowhere"))
     ("--one-file without --all" "--one-file")
     ("--one-file without --all, with --score" "--one-file" "--score" "alpha")
     ("--one-file with --format png" "--all" "--one-file" "--format" "png")
     ("--one-file with --format svg" "--all" "--one-file" "--format" "svg")
     ("--one-file with -o not .pdf" "--all" "--one-file" "-o" ,(usage-path "book.svg"))
     ("--format disagreeing with -o's extension"
      "-o" ,(usage-path "out.png") "--format" "svg")
     ("--format disagreeing with -o's extension (.pdf, png)"
      "-o" ,(usage-path "out.pdf") "--format" "png")
     ("--format with an unknown value" "--format" "jpg")
     ("--format without a value" "--format")
     ("--ppi without a value" "--format" "png" "--ppi")
     ("--ppi with the default format (pdf)" "--ppi" "72")
     ("--ppi with --format pdf" "--format" "pdf" "--ppi" "72")
     ("--ppi with --format svg" "--format" "svg" "--ppi" "72")
     ("--ppi with -o FILE.svg" "-o" ,(usage-path "out.svg") "--ppi" "72")
     ("--ppi with -o FILE.pdf" "-o" ,(usage-path "out.pdf") "--ppi" "72")
     ("--ppi with --all and the default format" "--all" "--ppi" "72")
     ("--ppi 0" "--format" "png" "--ppi" "0")
     ("--ppi -1" "--format" "png" "--ppi" "-1")
     ("--ppi 1.5" "--format" "png" "--ppi" "1.5")
     ("--ppi x" "--format" "png" "--ppi" "x")
     ("--list with --all" "--list" "--all")
     ("--list with --score" "--list" "--score" "alpha")
     ("--list with -o" "--list" "-o" ,(usage-path "list.pdf"))
     ("--list with --format" "--list" "--format" "pdf")
     ("--list with --ppi" "--list" "--ppi" "72")
     ("--list with --one-file" "--list" "--one-file"))))

;;; ------------------------------------------------------------------
;;; --help describes the new options

(for-each
 (lambda (args)
   (let ((r (apply run args)))
     (test-group (string-append (string-join args " ") ": the new options")
       (for-each
        (lambda (option)
          (test-assert (string-append "mentions " option)
            (string-contains (stdout-of r) option)))
        '("--all" "--one-file" "--list" "--format" "--ppi")))))
 '(("--help") ("render" "--help")))

(remove-tree tmp-dir)

(define runner (test-runner-current))
(test-end "command")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
