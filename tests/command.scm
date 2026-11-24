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

(remove-tree tmp-dir)

(define runner (test-runner-current))
(test-end "command")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
