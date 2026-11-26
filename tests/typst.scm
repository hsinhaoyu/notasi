;;; Unit tests for (notasi typst): writing the figure file.
;;;
;;; Written from doc/design/05-typst-backend.md ("Writing the figure
;;; file"), not from the implementation.  The rest of (notasi typst)
;;; is milestone 4.
;;;
;;; Choices where the spec leaves room (also noted at the tests):
;;; - Most tests use small hand-made figures (any value write-json
;;;   accepts), so that the expected text is easy to state; one test
;;;   uses a real figure from layout-score.
;;; - "In UTF-8" is checked at the byte level, so the file must be
;;;   UTF-8 whatever the locale's default port encoding is.
;;; - Each write-figure call happens inside a test, so a failing or
;;;   missing write-figure fails tests rather than stopping the file.
;;;
;;; Slice 2 (feat/typst-render): the entry file and running Typst,
;;; written from "The entry file and running Typst" in the same doc.
;;; Choices where the spec leaves room (also noted at the tests):
;;; - The entry file is the spec's block exactly, ending with a newline
;;;   after `#score(data)`, like every other text file written here.
;;; - compile-typst is tested on a hand-made folder (template copy,
;;;   figure JSON, entry text written here from the spec), so it doesn't
;;;   depend on write-entry-file.
;;; - "Typst fails": the message (exception-message) must contain
;;;   Typst's own output, not just the irritants.
;;; - "typst not on the PATH": PATH is set, for the call, to the current
;;;   PATH minus every folder holding a `typst`, so `sh` and the rest
;;;   are still found.
;;; - render-piece's temporary folder: the spec doesn't say where it
;;;   goes.  TMPDIR is set to a fresh empty folder during each call and
;;;   checked to be empty afterwards; this catches a folder left behind
;;;   only if the implementation makes it under $TMPDIR.
;;; - #:keep-in DIR: DIR exists beforehand, and holds exactly piece.json,
;;;   piece.typ and notasi.typ afterwards.
;;; - Relative OUT-PATH: `guile -L .` puts a relative "." on
;;;   %load-path, which stops finding templates once the test changes
;;;   folder, so that test puts the repo's absolute path on %load-path.
;;; - Calls to the procedures under test happen inside a test or inside
;;;   a guard (exception-from), so while they are unbound the tests fail
;;;   rather than the file stopping; an unbound variable never counts as
;;;   the expected &error.
;;;
;;; Slice feat/scores-form (04, "Slices (iteration 2)", slice 1):
;;; layout-piece is gone, and render-piece lays out the piece's first
;;; score (or its default score) with layout-score.  Colours come from
;;; the score (ADR 0032), so the #:style test is now a test that the
;;; first score is the one drawn: a copy of tenzer1 with two scores, the
;;; first with :palette set3.  render-piece takes no #:style any more;
;;; #:score is slice 5.
;;;
;;; Slice feat/scores-contract (04, "Slices (iteration 2)", slice 2; 05,
;;; "The entry file and running Typst", "Planned for version 2"): the
;;; entry file sets the text size from `data.sizes.font_size` (8pt when
;;; it is null), prints the subtitle under the title and the caption, in
;;; italics, under the score when they are not null.  05 no longer pins
;;; the entry file's exact text, so:
;;; - The exact-text tests are replaced by lines it must still hold (the
;;;   import, the page, the font, the figure's json(...), #score(data))
;;;   and the fields it must read (data.sizes.font_size, data.subtitle,
;;;   data.caption), plus what it draws: entry files written with
;;;   write-entry-file are compiled to PNG with tenzer1's figure, changed
;;;   by hand, and the pictures compared.  font_size null and "8pt" give
;;;   the same picture; "16pt" a wider and taller one; a subtitle or a
;;;   caption a taller one, as wide or wider.
;;; - keep-in's piece.typ is compared with what write-entry-file writes
;;;   for piece.json.
;;; - compile-typst keeps its hand-written entry file (the v1 text,
;;;   which still draws a version 2 figure: it reads no new field).
;;;
;;; Slice feat/scores-range (04, slice 5; 05, "The entry file and
;;; running Typst"): render-piece takes #:score, the name of the score
;;; to draw (a symbol); without it, the first score.  Tested on
;;; examples/gilak.nts (scores full and second-cycle) with #:keep-in,
;;; comparing piece.json with that score's figure.  A score the piece
;;; doesn't have is an &error (not a notation mistake) whose message
;;; names the score and the file; like other failures, it writes no
;;; output and leaves nothing in TMPDIR.
;;;
;;; Slice feat/drawing-output (04, "Slices (iteration 3)", slice 4; 05,
;;; "The entry file and running Typst"; ADR 0045): the sans-serif font.
;;; - (choose-font FAMILIES) returns the first of Helvetica, Arial,
;;;   DejaVu Sans and Liberation Sans (in that order, whatever FAMILIES'
;;;   order) that is in FAMILIES, else "Libertinus Serif".
;;; - (installed-fonts) is the list of families `typst fonts' prints.
;;; - write-entry-file takes #:font (default "Libertinus Serif") and
;;;   writes only that family; render-piece passes it the font chosen,
;;;   so Typst gives no font warning.
;;; Choices where the docs are silent:
;;; - choose-font matches family names exactly: "Helvetica Neue" is not
;;;   Helvetica, and "helvetica" isn't either.
;;; - installed-fonts is compared with `typst fonts' as a set (one
;;;   family per line, run here with the same PATH); order is free.
;;; - The font is checked as `#set text(font: "F",' (the size may follow
;;;   on the next line, as it does today).
;;; - "The rest of the entry file as 05 says": the text with #:font F
;;;   is the default text with "Libertinus Serif" replaced by F.
;;; - "No Typst warning about fonts": the kept piece.typ is compiled
;;;   here with `typst compile' and its standard error must hold no
;;;   "unknown font family" (and, more strictly, no "warning:").  The
;;;   check is shown to work on an entry file with a family no machine
;;;   has.

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 binary-ports)
             (ice-9 exceptions)
             (ice-9 ftw)
             (ice-9 match)
             (ice-9 popen)
             (ice-9 textual-ports)
             (rnrs bytevectors)
             (notasi json)
             (notasi layout)
             (notasi piece)
             (notasi reader)
             (notasi typst))

;;; ------------------------------------------------------------------
;;; Helpers

(define tmp-dir
  (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp") "/notasi-XXXXXX")))

(define (tmp-path name)
  (string-append tmp-dir "/" name))

(define (read-text path)
  (call-with-input-file path get-string-all #:encoding "UTF-8"))

(define (read-bytes path)
  (call-with-input-file path get-bytevector-all #:binary #t))

(define (write-text path text)
  (call-with-output-file path (lambda (port) (put-string port text))
    #:encoding "UTF-8"))

(define (first-score-figure nts-path)
  "The figure of NTS-PATH's first score (its default score when the file
has none), laid out with layout-score."
  (let ((piece (read-piece-file nts-path)))
    (layout-score piece (car (piece-scores piece)))))

(define (expected-text figure)
  "What write-figure should write for FIGURE: pretty JSON and a newline."
  (string-append (json-string figure) "\n"))

(define (raises-error-about? bad thunk)
  "#t if THUNK raises an &error whose irritants include BAD (the value the
JSON writer can't write), #f if it returns or raises anything else.  An
unbound write-figure is an &error too, so checking the irritant keeps
these tests from passing by accident."
  (guard (e ((and (error? e)
                  (exception-with-irritants? e)
                  (member bad (exception-irritants e)))
             #t)
            (#t #f))
    (thunk)
    #f))

(define (remove-tree path)
  "Delete PATH: a file, or a folder and everything in it."
  (if (eq? 'directory (stat:type (lstat path)))
      (begin
        (for-each (lambda (name) (remove-tree (string-append path "/" name)))
                  (scandir path (lambda (f) (not (member f '("." ".."))))))
        (rmdir path))
      (delete-file path)))

(define (cleanup)
  "Delete tmp-dir and everything in it."
  (remove-tree tmp-dir))

;;; A small figure with nested values and non-ASCII text.
(define small-figure
  `((title . "Tabuh · Pelegongan é")
    (systems . #(((label . "Gangsa") (lanes . #("dong" "dèng")))))
    (count . 3)
    (ready . #t)
    (subtitle . null)))

;;; Figures write-json can't write, by a short name used in file names.
(define bad-figures
  ;; (NAME BAD-VALUE FIGURE)
  `(("rational" 1/2 ((title . "x") (width . 1/2)))
    ("symbol" bold ((title . "x") (look . bold)))))

(test-begin "typst")

;;; ------------------------------------------------------------------
;;; Writing

(let ((path (tmp-path "small.json")))
  (test-equal "writes the figure as pretty JSON ending with a newline"
    (expected-text small-figure)
    (begin (write-figure small-figure path)
           (read-text path)))
  (test-equal "writes the file in UTF-8 (bytes)"
    (string->utf8 (expected-text small-figure))
    (read-bytes path)))

(let ((path (tmp-path "replace.json")))
  ;; The old contents are longer, so a write that doesn't truncate
  ;; would leave a tail behind.
  (write-text path (string-append "{\"old\": \"" (make-string 200 #\x) "\"}\n"))
  (test-equal "replaces an existing file's contents"
    (expected-text '((a . 1)))
    (begin (write-figure '((a . 1)) path)
           (read-text path))))

;;; ------------------------------------------------------------------
;;; A figure that can't be written

(for-each
 (match-lambda
   ((name bad figure)
    (let ((path (tmp-path (string-append "bad-new-" name ".json"))))
      (test-assert (string-append "can't be written (" name "): raises an &error")
        (raises-error-about? bad (lambda () (write-figure figure path))))
      (test-assert (string-append "can't be written (" name "): leaves no file")
        (not (file-exists? path))))
    (let ((path (tmp-path (string-append "bad-old-" name ".json")))
          (old "{\n  \"old\": true\n}\n"))
      (write-text path old)
      (test-assert (string-append "can't be written (" name "), file there: raises an &error")
        (raises-error-about? bad (lambda () (write-figure figure path))))
      (test-equal (string-append "can't be written (" name "): leaves an existing file as it was")
        old
        (read-text path)))))
 bad-figures)

;;; ------------------------------------------------------------------
;;; A real figure

(let ((figure (guard (c (#t #f)) (first-score-figure "examples/tenzer1.nts")))
      (path (tmp-path "tenzer1.json")))
  (test-equal "writes a real figure (examples/tenzer1.nts)"
    (string->utf8 (expected-text figure))
    (begin (write-figure figure path)
           (read-bytes path))))

;;; ==================================================================
;;; Slice 2: the entry file and running Typst

;;; ------------------------------------------------------------------
;;; Helpers

(define repo-dir (getcwd))
(define template-path (string-append repo-dir "/typst/notasi.typ"))
(define example-path (string-append repo-dir "/examples/tenzer1.nts"))
(define releases-url "https://github.com/typst/typst/releases")

(define (spec-entry-text json-name)
  "The entry file from the spec's code block, reading JSON-NAME."
  (string-append
   "#import \"notasi.typ\": score\n"
   "#set page(width: auto, height: auto, margin: 14pt, fill: white)\n"
   "#set text(font: \"Libertinus Serif\", size: 8pt)\n"
   "#let data = json(\"" json-name "\")\n"
   "#if data.title != \"\" {\n"
   "  block(below: 1em, text(weight: \"bold\", size: 1.2em, data.title))\n"
   "}\n"
   "#score(data)\n"))

(define (make-subdir name)
  "Make the folder NAME in tmp-dir and return its path."
  (let ((dir (tmp-path name)))
    (mkdir dir)
    dir))

(define (folder-entries dir)
  "The names in DIR, sorted, without . and .."
  (scandir dir (lambda (f) (not (member f '("." ".."))))))

(define (file-starts-with? path prefix)
  "#t if PATH is a file whose bytes start with the string PREFIX (ASCII)."
  (and (file-exists? path)
       (let ((bytes (read-bytes path))
             (want (string->utf8 prefix)))
         (and (bytevector? bytes)
              (>= (bytevector-length bytes) (bytevector-length want))
              (let ((head (make-bytevector (bytevector-length want))))
                (bytevector-copy! bytes 0 head 0 (bytevector-length want))
                (equal? head want))))))

(define (png-file? path)
  "#t if PATH starts with the PNG signature \\x89PNG\\r\\n\\x1a\\n."
  (and (file-exists? path)
       (let ((bytes (read-bytes path))
             (want #vu8(#x89 #x50 #x4e #x47 #x0d #x0a #x1a #x0a)))
         (and (bytevector? bytes)
              (>= (bytevector-length bytes) 8)
              (let ((head (make-bytevector 8)))
                (bytevector-copy! bytes 0 head 0 8)
                (equal? head want))))))

(define (png-size path)
  "The width and height in pixels of the PNG file PATH, from its IHDR."
  (let ((bytes (read-bytes path)))
    (list (bytevector-u32-ref bytes 16 (endianness big))
          (bytevector-u32-ref bytes 20 (endianness big)))))

(define (non-empty-file? path)
  (and (file-exists? path)
       (> (stat:size (stat path)) 0)))

(define (pdf-file? path)
  (and (non-empty-file? path) (file-starts-with? path "%PDF")))

(define (svg-file? path)
  (and (non-empty-file? path)
       (or (file-starts-with? path "<svg")
           (file-starts-with? path "<?xml"))))

(define (exception-from thunk)
  "The exception THUNK raises, or #f if it returns."
  (guard (e (#t e))
    (thunk)
    #f))

(define (raises? pred thunk)
  "#t if THUNK raises an exception satisfying PRED.  An unbound variable
(the procedure under test not existing yet) never counts."
  (let ((e (exception-from thunk)))
    (and e
         (not (undefined-variable-error? e))
         (pred e)
         #t)))

(define (the-error? e)
  "#t if E is an &error that isn't an unbound variable."
  (and e (error? e) (not (undefined-variable-error? e))))

(define (message-contains? e text)
  (and (the-error? e)
       (exception-with-message? e)
       (string? (exception-message e))
       (string-contains-ci (exception-message e) text)
       #t))

(define (call-with-env name value thunk)
  "Call THUNK with the environment variable NAME set to VALUE, then
restore it, even if THUNK raises."
  (let ((old (getenv name)))
    (dynamic-wind
      (lambda () (setenv name value))
      thunk
      (lambda () (if old (setenv name old) (unsetenv name))))))

(define (call-in-dir dir thunk)
  "Call THUNK with DIR as the current folder and the repo's absolute
path at the front of %load-path, then restore both."
  (let ((old-dir (getcwd))
        (old-path %load-path))
    (dynamic-wind
      (lambda ()
        (set! %load-path (cons repo-dir old-path))
        (chdir dir))
      thunk
      (lambda ()
        (chdir old-dir)
        (set! %load-path old-path)))))

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
  "#t if a `typst' is found on the search path PATH."
  (any (lambda (dir)
         (let ((file (string-append (if (string-null? dir) "." dir) "/typst")))
           (and (file-exists? file) (access? file X_OK))))
       (string-split path #\:)))

(define gilak-path (string-append repo-dir "/examples/gilak.nts"))

(define (score-figure-text nts-path name)
  "What write-figure writes for NTS-PATH's score NAME, or #f if reading
or laying it out raises."
  (guard (e (#t #f))
    (let ((piece (read-piece-file nts-path)))
      (expected-text (layout-score piece (piece-score piece name))))))

(define (expected-figure-text nts-path)
  "What write-figure writes for NTS-PATH's first score."
  (expected-text (first-score-figure nts-path)))

;;; ------------------------------------------------------------------
;;; write-entry-file

(define (entry-file-text json-name)
  "What write-entry-file writes for JSON-NAME, or #f if it raises."
  (guard (c (#t #f))
    (let ((path (tmp-path (string-append "entry-for-" json-name ".typ"))))
      (write-entry-file path json-name)
      (read-text path))))

(define (contains-all? text parts)
  (and (string? text)
       (every (lambda (part) (string-contains text part)) parts)
       #t))

(test-group "write-entry-file"
  (test-assert "holds the import, the page, the font and #score(data)"
    (contains-all? (entry-file-text "figure.json")
                   '("#import \"notasi.typ\": score\n"
                     "#set page(width: auto, height: auto, margin: 14pt, fill: white)\n"
                     "font: \"Libertinus Serif\""
                     "#let data = json(\"figure.json\")\n"
                     "#score(data)")))
  (test-assert "uses the given json-name (piece.json)"
    (contains-all? (entry-file-text "piece.json")
                   '("json(\"piece.json\")")))
  (test-assert "ends with a newline"
    (let ((text (entry-file-text "figure.json")))
      (and text (string-suffix? "\n" text))))
  (test-assert "reads the font size, the subtitle and the caption from the figure"
    (contains-all? (entry-file-text "figure.json")
                   '("data.sizes.font_size" "data.subtitle" "data.caption")))
  (test-assert "still shows the title"
    (contains-all? (entry-file-text "figure.json") '("data.title"))))

;;; What the entry file draws: tenzer1's figure with its top-level
;;; fields changed, compiled to PNG next to the template.
(define entry-dir (make-subdir "entry-draws"))

(define (set-field obj key value)
  "OBJ (an alist) with KEY's value replaced, in its place."
  (map (lambda (pair) (if (eq? (car pair) key) (cons key value) pair)) obj))

(define (with-sizes figure key value)
  (set-field figure 'sizes (set-field (assq-ref figure 'sizes) key value)))

(define base-figure
  (guard (c (#t #f)) (first-score-figure "examples/tenzer1.nts")))

(define (drawn-size name figure)
  "Write FIGURE as NAME.json and an entry file NAME.typ from
write-entry-file, compile it to NAME.png and return the PNG's
(width height), or #f if any step raises."
  (guard (c (#t (format (current-error-port) "~a not drawn: ~a~%" name
                        (if (exception-with-message? c) (exception-message c) c))
                #f))
    (let ((json (string-append entry-dir "/" name ".json"))
          (typ (string-append entry-dir "/" name ".typ"))
          (png (string-append entry-dir "/" name ".png")))
      (unless (file-exists? (string-append entry-dir "/notasi.typ"))
        (copy-file template-path (string-append entry-dir "/notasi.typ")))
      (write-figure figure json)
      (write-entry-file typ (string-append name ".json"))
      (compile-typst typ png)
      (png-size png))))

(test-group "what the entry file draws"
  (let ((plain (and base-figure
                    (drawn-size "plain"
                                (with-sizes (set-field
                                             (set-field base-figure 'subtitle 'null)
                                             'caption 'null)
                                            'font_size 'null))))
        (eight (and base-figure
                    (drawn-size "eight" (with-sizes base-figure 'font_size "8pt"))))
        (big (and base-figure
                  (drawn-size "big" (with-sizes base-figure 'font_size "16pt"))))
        (sub (and base-figure
                  (drawn-size "sub" (with-sizes (set-field base-figure 'subtitle
                                                           "A subtitle")
                                                'font_size 'null))))
        (cap (and base-figure
                  (drawn-size "cap" (with-sizes (set-field base-figure 'caption
                                                           "A caption")
                                                'font_size 'null)))))
    (test-assert "(tenzer1's figure is version 3, with every field null)"
      (and base-figure
           (eqv? 3 (assq-ref base-figure 'version))
           (eq? 'null (assq-ref base-figure 'subtitle))
           (eq? 'null (assq-ref base-figure 'caption))
           (eq? 'null (assq-ref (assq-ref base-figure 'sizes) 'font_size))))
    (test-assert "draws a figure with every field null" (and plain #t))
    (test-equal "font_size null: the same picture as \"8pt\"" plain eight)
    (test-assert "font_size \"16pt\": a wider and taller picture"
      (and plain big
           (> (car big) (car plain))
           (> (cadr big) (cadr plain))))
    (test-assert "a subtitle: a taller picture, as wide or wider"
      (and plain sub
           (>= (car sub) (car plain))
           (> (cadr sub) (cadr plain))))
    (test-assert "a caption: a taller picture, as wide or wider"
      (and plain cap
           (>= (car cap) (car plain))
           (> (cadr cap) (cadr plain))))))

;;; ------------------------------------------------------------------
;;; compile-typst

;;; A folder made by hand: the template, a real figure, the spec's entry
;;; file, an entry file with a Typst error, and a one-inch page.
(define compile-dir (make-subdir "compile"))
(define (compile-path name) (string-append compile-dir "/" name))
(copy-file template-path (compile-path "notasi.typ"))
(write-text (compile-path "figure.json")
            (expected-figure-text "examples/tenzer1.nts"))
(write-text (compile-path "entry.typ") (spec-entry-text "figure.json"))
(write-text (compile-path "broken.typ") "#nonexistent()\n")
(write-text (compile-path "inch.typ")
            "#set page(width: 1in, height: 1in, margin: 0pt)\nx\n")

(test-group "compile-typst"
  (for-each
   (match-lambda
     ((ext ok?)
      (let ((out (compile-path (string-append "out." ext))))
        (test-equal (string-append "." ext ": returns OUT-PATH")
          out
          (compile-typst (compile-path "entry.typ") out))
        (test-assert (string-append "." ext ": writes a non-empty " ext " file")
          (and (non-empty-file? out) (ok? out))))))
   `(("pdf" ,pdf-file?)
     ("png" ,png-file?)
     ("svg" ,svg-file?)))

  ;; 144 ppi: a one-inch square page is 144 pixels on each side.
  (let ((out (compile-path "inch.png")))
    (test-equal ".png is at 144 ppi"
      '(144 144)
      (begin (compile-typst (compile-path "inch.typ") out)
             (png-size out))))

  (for-each
   (lambda (name)
     (let ((out (compile-path name)))
       (test-assert (string-append "unsupported extension (" name "): raises an &error")
         (raises? error?
                  (lambda () (compile-typst (compile-path "entry.typ") out))))
       (test-assert (string-append "unsupported extension (" name "): writes no file")
         (not (file-exists? out)))))
   '("out.jpg" "out-no-extension"))

  (let* ((typ (compile-path "broken.typ"))
         (e (exception-from
             (lambda () (compile-typst typ (compile-path "broken.pdf"))))))
    (test-assert "Typst fails: raises an &error"
      (the-error? e))
    (test-assert "Typst fails: the message includes Typst's output"
      (and (message-contains? e "error")
           (message-contains? e "nonexistent")))
    (test-assert "Typst fails: the irritants include TYP-PATH"
      (and (the-error? e)
           (exception-with-irritants? e)
           (member typ (exception-irritants e))
           #t)))

  (let* ((path (path-without-typst))
         (out (compile-path "no-typst.pdf"))
         (e (call-with-env "PATH" path
              (lambda ()
                (exception-from
                 (lambda () (compile-typst (compile-path "entry.typ") out)))))))
    (test-assert "typst not on the PATH: (the test's PATH really has no typst)"
      (not (typst-on-path? path)))
    (test-assert "typst not on the PATH: raises an &error"
      (the-error? e))
    (test-assert "typst not on the PATH: the message names Typst 0.15.1"
      (and (message-contains? e "typst")
           (message-contains? e "0.15.1")))
    (test-assert "typst not on the PATH: the message says where to get it"
      (message-contains? e releases-url))
    (test-assert "typst not on the PATH: writes no file"
      (not (file-exists? out)))))

;;; ------------------------------------------------------------------
;;; render-piece

(define render-dir (make-subdir "render"))
(define (render-path name) (string-append render-dir "/" name))

;;; TMPDIR during render-piece calls; must be empty after each one.
(define render-tmp (make-subdir "render-tmp"))
(define (with-render-tmp thunk)
  (call-with-env "TMPDIR" render-tmp thunk))
(define (render-tmp-empty?)
  (null? (folder-entries render-tmp)))

(test-group "render-piece"
  (let ((out (render-path "tenzer1.pdf")))
    (test-equal "tenzer1 to .pdf: returns OUT-PATH"
      out
      (with-render-tmp (lambda () (render-piece example-path out))))
    (test-assert "tenzer1 to .pdf: writes a non-empty PDF"
      (pdf-file? out))
    (test-assert "tenzer1 to .pdf: leaves nothing in TMPDIR"
      (render-tmp-empty?)))

  (let ((out (render-path "tenzer1.png")))
    (test-equal "tenzer1 to .png: returns OUT-PATH"
      out
      (with-render-tmp (lambda () (render-piece example-path out))))
    (test-assert "tenzer1 to .png: writes a non-empty PNG"
      (and (non-empty-file? out) (png-file? out))))

  ;; #:keep-in: the three files are kept, and are what the pieces
  ;; write on their own.
  (let ((keep (make-subdir "keep"))
        (out (render-path "kept.pdf")))
    (define (kept name) (string-append keep "/" name))
    (test-equal "keep-in: returns OUT-PATH"
      out
      (with-render-tmp
       (lambda () (render-piece example-path out #:keep-in keep))))
    (test-assert "keep-in: writes the PDF"
      (pdf-file? out))
    (test-equal "keep-in: DIR holds piece.json, piece.typ and notasi.typ"
      '("notasi.typ" "piece.json" "piece.typ")
      (folder-entries keep))
    (test-equal "keep-in: piece.json is the figure, as write-figure writes it"
      (expected-figure-text example-path)
      (and (file-exists? (kept "piece.json")) (read-text (kept "piece.json"))))
    ;; In the font chosen from those installed (ADR 0045).
    (test-equal "keep-in: piece.typ is the entry file for piece.json"
      (let ((path (tmp-path "entry-with-font.typ")))
        (write-entry-file path "piece.json"
                          #:font (choose-font (installed-fonts)))
        (read-text path))
      (and (file-exists? (kept "piece.typ")) (read-text (kept "piece.typ"))))
    (test-equal "keep-in: notasi.typ is a copy of the template"
      (read-text template-path)
      (and (file-exists? (kept "notasi.typ")) (read-text (kept "notasi.typ"))))
    (test-assert "keep-in: leaves nothing in TMPDIR"
      (render-tmp-empty?)))

  ;; The first score is drawn (04, slice 1): its colours are the
  ;; score's, so a piece whose first score has :palette set3 gives
  ;; another figure than its default score would.
  (let ((keep (make-subdir "keep-score"))
        (out (render-path "scored.pdf"))
        (nts (tmp-path "scored.nts")))
    (write-text nts (string-append
                     (read-text example-path)
                     "\n(score coloured :palette set3 (group \"Ugal\" ugal))\n"
                     "(score plain (group \"Ugal\" ugal))\n"))
    (test-assert "first score: (the test's score changes the figure)"
      (not (equal? (expected-figure-text nts)
                   (expected-text
                    (let ((piece (read-piece-file nts)))
                      (layout-score piece (piece-score piece 'plain)))))))
    (test-equal "first score: piece.json is the first score's figure"
      (expected-figure-text nts)
      (begin
        (with-render-tmp
         (lambda ()
           (render-piece nts out #:keep-in keep)))
        (let ((json (string-append keep "/piece.json")))
          (and (file-exists? json) (read-text json))))))

  ;; #:score (slice feat/scores-range): the score named SCORE is drawn;
  ;; examples/gilak.nts has two, full and second-cycle.
  (for-each
   (lambda (name)
     (let ((keep (make-subdir (string-append "keep-" (symbol->string name))))
           (out (render-path (string-append "gilak." (symbol->string name) ".pdf"))))
       (test-equal (string-append "#:score " (symbol->string name) ": returns OUT-PATH")
         out
         (with-render-tmp
          (lambda () (render-piece gilak-path out #:score name #:keep-in keep))))
       (test-assert (string-append "#:score " (symbol->string name) ": writes the PDF")
         (pdf-file? out))
       (test-assert (string-append "#:score " (symbol->string name)
                                   ": piece.json is that score's figure")
         (let ((want (score-figure-text gilak-path name))
               (json (string-append keep "/piece.json")))
           (and want (file-exists? json)
                (equal? want (read-text json)))))))
   '(second-cycle full))
  (test-assert "#:score: (the two scores give different figures)"
    (not (equal? (score-figure-text gilak-path 'full)
                 (score-figure-text gilak-path 'second-cycle))))
  (let ((keep (make-subdir "keep-gilak-first"))
        (out (render-path "gilak.pdf")))
    (test-assert "without #:score: the first score, full"
      (let ((want (score-figure-text gilak-path 'full)))
        (with-render-tmp
         (lambda () (exception-from
                     (lambda () (render-piece gilak-path out #:keep-in keep)))))
        (let ((json (string-append keep "/piece.json")))
          (and want (file-exists? json) (equal? want (read-text json)))))))
  (let* ((out (render-path "gilak.nope.pdf"))
         (e (with-render-tmp
             (lambda ()
               (exception-from
                (lambda () (render-piece gilak-path out #:score 'nope)))))))
    (test-assert "unknown score: raises an &error" (the-error? e))
    (test-assert "unknown score: not a notation mistake"
      (and e (not (notasi-syntax-error? e))))
    (test-assert "unknown score: the message names the score"
      (message-contains? e "nope"))
    (test-assert "unknown score: the message names the file"
      (message-contains? e "gilak.nts"))
    (test-assert "unknown score: writes no output file"
      (not (file-exists? out)))
    (test-assert "unknown score: leaves nothing in TMPDIR"
      (render-tmp-empty?)))

  ;; A reader error passes through unchanged.
  (let ((nts (tmp-path "bad.nts"))
        (out (render-path "bad.pdf")))
    (write-text nts "(piece \"Bad\")\n(bogus 1)\n")
    (let ((direct (exception-from (lambda () (read-piece-file nts))))
          (e (with-render-tmp
              (lambda ()
                (exception-from (lambda () (render-piece nts out)))))))
      (test-assert "syntax error: raises &notasi-syntax-error"
        (and e (notasi-syntax-error? e)))
      (test-equal "syntax error: same kind, file and line as the reader's"
        (list 'unknown-form
              (notasi-syntax-error-file direct)
              (notasi-syntax-error-line direct))
        (and e (notasi-syntax-error? e)
             (list (notasi-syntax-error-kind e)
                   (notasi-syntax-error-file e)
                   (notasi-syntax-error-line e))))
      (test-assert "syntax error: writes no output file"
        (not (file-exists? out)))
      (test-assert "syntax error: leaves nothing in TMPDIR"
        (render-tmp-empty?))))

  ;; OUT-PATH relative to the current folder.
  (let ((dir (make-subdir "relative")))
    (test-equal "relative OUT-PATH: returns OUT-PATH as given"
      "rel.pdf"
      (call-in-dir dir
        (lambda ()
          (with-render-tmp (lambda () (render-piece example-path "rel.pdf"))))))
    (test-assert "relative OUT-PATH: writes the PDF in the current folder"
      (pdf-file? (string-append dir "/rel.pdf"))))

  (let ((out (render-path "tenzer1.jpg")))
    (test-assert "unsupported extension: raises an &error"
      (raises? error?
               (lambda ()
                 (with-render-tmp (lambda () (render-piece example-path out))))))
    (test-assert "unsupported extension: writes no file"
      (not (file-exists? out)))
    (test-assert "unsupported extension: leaves nothing in TMPDIR"
      (render-tmp-empty?))))

;;; ==================================================================
;;; Slice feat/drawing-output: the font (ADR 0045)

(define sans-candidates '("Helvetica" "Arial" "DejaVu Sans" "Liberation Sans"))

(define (choose-font-of families)
  "choose-font of FAMILIES, or the exception it raises."
  (guard (e (#t e)) (choose-font families)))

(define (shell-quote str)
  (string-append "'" str "'"))

(define (command-output command)
  "Run COMMAND with sh; return what it prints (standard output and
standard error together), or #f if it can't be run."
  (guard (e (#t #f))
    (let* ((port (open-input-pipe command))
           (text (get-string-all port)))
      (close-pipe port)
      text)))

(define (typst-families)
  "The families `typst fonts' prints, one per line; #f without Typst."
  (let ((text (and (typst-on-path? (or (getenv "PATH") ""))
                   (command-output "typst fonts 2>/dev/null"))))
    (and text
         (filter (lambda (l) (not (string-null? l)))
                 (map string-trim-both (string-split text #\newline))))))

(define (typst-stderr typ out)
  "Compile TYP to OUT with `typst compile', --root TYP's folder; return
what Typst prints on standard error."
  (command-output
   (string-append "typst compile --root " (shell-quote (dirname typ)) " "
                  (shell-quote typ) " " (shell-quote out)
                  " 2>&1 >/dev/null")))

(define (font-warning? text)
  (and (string? text)
       (or (string-contains-ci text "unknown font family")
           (string-contains-ci text "warning:"))
       #t))

(define (entry-file-text/font json-name font)
  "What write-entry-file writes for JSON-NAME with #:font FONT, or #f if
it raises."
  (guard (c (#t #f))
    (let ((path (tmp-path (string-append "entry-font-" font "-" json-name ".typ"))))
      (write-entry-file path json-name #:font font)
      (read-text path))))

(define (string-replace-all str from to)
  "STR with every FROM replaced by TO."
  (let loop ((start 0) (acc '()))
    (let ((i (string-contains str from start)))
      (if i
          (loop (+ i (string-length from))
                (cons* to (substring str start i) acc))
          (string-concatenate-reverse acc (substring str start))))))

(test-group "choose-font"
  (for-each
   (match-lambda
     ((name want families)
      (test-equal name want (choose-font-of families))))
   `(("no families: Libertinus Serif" "Libertinus Serif" ())
     ("none of the four: Libertinus Serif" "Libertinus Serif"
      ("Times New Roman" "Courier" "Libertinus Serif"))
     ("Helvetica alone" "Helvetica" ("Helvetica"))
     ("Arial alone" "Arial" ("Arial"))
     ("DejaVu Sans alone" "DejaVu Sans" ("DejaVu Sans"))
     ("Liberation Sans alone" "Liberation Sans" ("Liberation Sans"))
     ("all four: Helvetica" "Helvetica"
      ("Liberation Sans" "DejaVu Sans" "Arial" "Helvetica"))
     ("the list's order, not FAMILIES': Arial before DejaVu Sans" "Arial"
      ("Times" "DejaVu Sans" "Liberation Sans" "Arial"))
     ("DejaVu Sans before Liberation Sans" "DejaVu Sans"
      ("Liberation Sans" "DejaVu Sans"))
     ("among other families" "Liberation Sans"
      ("Al Bayan" "Liberation Sans" "Zapfino"))
     ("an exact name: Helvetica Neue is not Helvetica" "Libertinus Serif"
      ("Helvetica Neue" "Arial Black" "DejaVu Sans Mono"))
     ("an exact name: case counts" "Libertinus Serif"
      ("helvetica" "ARIAL")))))

(test-group "installed-fonts"
  (let ((fonts (guard (e (#t e)) (installed-fonts))))
    (test-assert "a list of strings"
      (and (list? fonts) (every string? fonts)))
    (let ((want (typst-families)))
      (when want
        (test-assert "non-empty where Typst is installed"
          (and (list? fonts) (pair? fonts)))
        (test-assert "holds Libertinus Serif, built into Typst"
          (and (list? fonts) (member "Libertinus Serif" fonts) #t))
        (test-assert "the families `typst fonts' prints"
          (and (list? fonts)
               (lset= string=? want fonts)))))))

(test-group "write-entry-file #:font"
  (for-each
   (lambda (font)
     (let ((text (entry-file-text/font "figure.json" font)))
       (test-assert (string-append font ": sets the text font to " font)
         (contains-all? text
                        (list (string-append "#set text(font: \"" font "\","))))
       (test-assert (string-append font ": names no other family")
         (and (string? text)
              (every (lambda (other)
                       (or (string=? other font)
                           (not (string-contains text other))))
                     (cons "Libertinus Serif" sans-candidates))))
       (test-equal (string-append font ": the rest as without #:font")
         (let ((plain (entry-file-text "figure.json")))
           (and plain (string-replace-all plain "Libertinus Serif" font)))
         text)))
   sans-candidates)
  (test-equal "#:font \"Libertinus Serif\" is the default text"
    (entry-file-text "figure.json")
    (entry-file-text/font "figure.json" "Libertinus Serif"))
  (let ((text (entry-file-text "figure.json")))
    (test-assert "without #:font: font \"Libertinus Serif\""
      (contains-all? text '("#set text(font: \"Libertinus Serif\",")))
    (test-assert "without #:font: no sans-serif family"
      (and (string? text)
           (not (any (lambda (f) (string-contains text f)) sans-candidates))))))

(test-group "render-piece: the font"
  (let ((keep (make-subdir "keep-font"))
        (out (render-path "font.pdf"))
        (chosen (guard (e (#t #f)) (choose-font (installed-fonts)))))
    (with-render-tmp
     (lambda ()
       (exception-from
        (lambda () (render-piece example-path out #:keep-in keep)))))
    (let ((typ (string-append keep "/piece.typ")))
      (test-assert "(the font chosen for this machine is known)" (string? chosen))
      (test-equal "piece.typ is the entry file with the font chosen"
        (and chosen (entry-file-text/font "piece.json" chosen))
        (and (file-exists? typ) (read-text typ)))
      (test-assert "(the check sees a font warning: an unknown family)"
        (let ((dir (make-subdir "font-warning")))
          (copy-file template-path (string-append dir "/notasi.typ"))
          (write-text (string-append dir "/figure.json")
                      (expected-figure-text example-path))
          (write-text (string-append dir "/entry.typ")
                      (string-replace-all (spec-entry-text "figure.json")
                                          "Libertinus Serif" "No Such Family Sans"))
          (font-warning? (typst-stderr (string-append dir "/entry.typ")
                                       (string-append dir "/entry.pdf")))))
      (test-assert "drawing piece.typ gives no font warning"
        (and (file-exists? typ)
             (let ((err (typst-stderr typ (string-append keep "/again.pdf"))))
               (and (string? err) (not (font-warning? err))))))))
  (test-assert "render-piece leaves nothing in TMPDIR"
    (render-tmp-empty?)))

;;; ==================================================================
;;; Milestone feat/render-all (iteration 5; 05, "The entry file and
;;; running Typst", ADR 0061): #:ppi, render-score, render-one-file.
;;; Choices where the spec leaves room:
;;; - "#:ppi with a .pdf or .svg is an &error": an error that is only
;;;   Guile rejecting an unknown keyword (or an unbound procedure, or
;;;   the wrong number of arguments) doesn't count, so these tests fail
;;;   until #:ppi is really handled.  No file is written.
;;; - A PNG's resolution is checked on the one-inch page (exactly N
;;;   pixels at N ppi) and, for render-piece and render-score, by
;;;   width: at 72 ppi about half (within 2 pixels) of the default 144.
;;; - render-one-file: the PDF's pages are counted as its `/Type/Page'
;;;   objects (Typst 0.15.1 writes them uncompressed).  "One figure file
;;;   per score" is checked with #:keep-in as the number of .json files
;;;   kept.  The order of the pages isn't checked.

(use-modules (ice-9 iconv)
             (ice-9 regex))

(define (new-error? e)
  "#t if E is an &error raised on purpose: not an unbound variable, an
unknown keyword or the wrong number of arguments."
  (and (the-error? e)
       (not (memq (exception-kind e)
                  '(keyword-argument-error wrong-number-of-args
                    unbound-variable)))
       #t))

(define (pdf-page-count path)
  "The number of pages in the PDF file PATH, from its /Type/Page objects."
  (let ((text (bytevector->string (read-bytes path) "ISO-8859-1")))
    (length (list-matches "/Type[ \n\r]*/Page([^s]|$)" text))))

(define (png-width path)
  (and (png-file? path) (car (png-size path))))

(define (about-half? small big)
  "#t if SMALL is about half of BIG (within 2 pixels of it doubled)."
  (and small big (<= (abs (- (* 2 small) big)) 2)))

(test-group "compile-typst #:ppi"
  (for-each
   (lambda (ppi)
     (let ((out (compile-path (string-append "inch-" (number->string ppi) ".png"))))
       (test-equal (string-append "#:ppi " (number->string ppi)
                                  ": a one-inch page is that many pixels")
         (list ppi ppi)
         (guard (e (#t #f))
           (compile-typst (compile-path "inch.typ") out #:ppi ppi)
           (png-size out)))))
   '(72 300))
  (let ((out (compile-path "inch-ret.png")))
    (test-equal "#:ppi: returns OUT-PATH"
      out
      (guard (e (#t #f))
        (compile-typst (compile-path "inch.typ") out #:ppi 72))))
  (for-each
   (lambda (name)
     (let ((out (compile-path name)))
       (test-assert (string-append "#:ppi for " name ": raises an &error")
         (new-error? (exception-from
                      (lambda ()
                        (compile-typst (compile-path "entry.typ") out #:ppi 72)))))
       (test-assert (string-append "#:ppi for " name ": writes no file")
         (not (file-exists? out)))))
   '("ppi.pdf" "ppi.svg")))

(test-group "render-piece #:ppi"
  (let ((at-72 (render-path "tenzer1-72.png"))
        (at-144 (render-path "tenzer1-144.png"))
        (plain (render-path "tenzer1-default.png")))
    (test-equal "#:ppi 72: returns OUT-PATH"
      at-72
      (guard (e (#t #f))
        (with-render-tmp (lambda () (render-piece example-path at-72 #:ppi 72)))))
    (guard (e (#t #f))
      (with-render-tmp (lambda () (render-piece example-path at-144 #:ppi 144))))
    (guard (e (#t #f))
      (with-render-tmp (lambda () (render-piece example-path plain))))
    (test-assert "#:ppi 72: a PNG about half as wide as at 144"
      (about-half? (png-width at-72) (png-width at-144)))
    (test-assert "the default is 144 ppi"
      (let ((w (png-width plain)))
        (and w (eqv? w (png-width at-144)))))
    (test-assert "#:ppi: leaves nothing in TMPDIR"
      (render-tmp-empty?)))
  (for-each
   (lambda (name)
     (let ((out (render-path name)))
       (test-assert (string-append "#:ppi for " name ": raises an &error")
         (new-error? (with-render-tmp
                      (lambda ()
                        (exception-from
                         (lambda () (render-piece example-path out #:ppi 72)))))))
       (test-assert (string-append "#:ppi for " name ": writes no file")
         (not (file-exists? out)))
       (test-assert (string-append "#:ppi for " name ": leaves nothing in TMPDIR")
         (render-tmp-empty?))))
   '("tenzer1-ppi.pdf" "tenzer1-ppi.svg")))

;;; gilak has scores full and second-cycle.
(define gilak-piece (guard (e (#t #f)) (read-piece-file gilak-path)))

(test-group "render-score"
  (test-assert "(gilak reads, with scores full and second-cycle)"
    (and gilak-piece
         (equal? '(full second-cycle)
                 (map score-name (piece-scores gilak-piece)))))
  (let ((out (render-path "score-second.pdf"))
        (keep (make-subdir "keep-render-score")))
    (test-equal "returns OUT-PATH"
      out
      (guard (e (#t #f))
        (with-render-tmp
         (lambda ()
           (render-score gilak-piece (piece-score gilak-piece 'second-cycle) out
                         #:keep-in keep)))))
    (test-assert "writes a PDF" (pdf-file? out))
    (test-assert "keep-in: piece.json is that score's figure"
      (let ((want (score-figure-text gilak-path 'second-cycle))
            (json (string-append keep "/piece.json")))
        (and want (file-exists? json) (equal? want (read-text json)))))
    (test-assert "leaves nothing in TMPDIR" (render-tmp-empty?)))
  (let ((out (render-path "score-full.svg")))
    (test-assert "the first score, to .svg: writes an SVG"
      (begin
        (guard (e (#t #f))
          (with-render-tmp
           (lambda ()
             (render-score gilak-piece (car (piece-scores gilak-piece)) out))))
        (svg-file? out))))
  (let ((at-72 (render-path "score-72.png"))
        (at-144 (render-path "score-144.png"))
        (score (and gilak-piece (piece-score gilak-piece 'full))))
    (guard (e (#t #f))
      (with-render-tmp
       (lambda () (render-score gilak-piece score at-72 #:ppi 72))))
    (guard (e (#t #f))
      (with-render-tmp
       (lambda () (render-score gilak-piece score at-144))))
    (test-assert "#:ppi 72: a PNG about half as wide as the default"
      (about-half? (png-width at-72) (png-width at-144)))
    (test-assert "#:ppi: leaves nothing in TMPDIR" (render-tmp-empty?))))

(test-group "render-one-file"
  (let ((out (render-path "gilak-all.pdf"))
        (keep (make-subdir "keep-one-file")))
    (test-equal "two scores: returns OUT-PATH"
      out
      (guard (e (#t #f))
        (with-render-tmp
         (lambda ()
           (render-one-file gilak-piece (piece-scores gilak-piece) out
                            #:keep-in keep)))))
    (test-assert "two scores: writes a PDF" (pdf-file? out))
    (test-equal "two scores: two pages"
      2
      (and (pdf-file? out) (pdf-page-count out)))
    (test-equal "keep-in: one figure file per score"
      2
      (length (filter (lambda (f) (string-suffix? ".json" f))
                      (folder-entries keep))))
    (test-assert "leaves nothing in TMPDIR" (render-tmp-empty?)))
  (let ((out (render-path "gilak-one.pdf")))
    (test-equal "one score: one page"
      1
      (begin
        (guard (e (#t #f))
          (with-render-tmp
           (lambda ()
             (render-one-file gilak-piece
                              (list (piece-score gilak-piece 'second-cycle))
                              out))))
        (and (pdf-file? out) (pdf-page-count out)))))
  ;; Three scores, to check the count isn't fixed at two.
  (let ((nts (tmp-path "three.nts"))
        (out (render-path "three.pdf")))
    (write-text nts (string-append
                     (read-text example-path)
                     "\n(score zeta (group \"Ugal\" ugal))\n"
                     "(score alpha :palette set3 (group \"Ugal\" ugal))\n"
                     "(score mid :title \"Middle\" (group \"Ugal\" ugal))\n"))
    (test-equal "three scores: three pages"
      3
      (guard (e (#t #f))
        (let ((piece (read-piece-file nts)))
          (with-render-tmp
           (lambda () (render-one-file piece (piece-scores piece) out)))
          (pdf-page-count out))))))

(cleanup)

(define runner (test-runner-current))
(test-end "typst")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
