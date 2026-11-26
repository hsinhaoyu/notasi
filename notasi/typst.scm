;;; (notasi typst) -- The Guile side of the Typst backend.  See
;;; doc/design/05-typst-backend.md.
;;;
;;; Writes a figure as JSON, writes the entry file Typst compiles, runs
;;; `typst compile', and goes from a .nts file to a picture in one step.
;;; It comes after the reader and layout in the pipeline, so it may use
;;; both; they never use it.

(define-module (notasi typst)
  #:use-module (notasi json)
  #:use-module (notasi layout)
  #:use-module (notasi piece)
  #:use-module (notasi reader)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 match)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 textual-ports)
  #:use-module (srfi srfi-1)
  #:export (write-figure
            write-entry-file
            choose-font
            installed-fonts
            compile-typst
            render-piece
            render-score
            render-one-file))

(define (typst-error message . irritants)
  (raise-exception
   (make-exception (make-error)
                   (make-exception-with-message message)
                   (make-exception-with-irritants irritants))))

(define (write-text path text)
  (call-with-output-file path
    (lambda (port) (display text port))
    #:encoding "UTF-8"))

;;; ------------------------------------------------------------------
;;; Files

(define (write-figure figure path)
  "Write FIGURE (from `layout-score') to the file PATH as pretty JSON in
UTF-8, ending with a newline, replacing any file already there.  The
JSON is built first, so a figure that can't be written raises an &error
and leaves PATH as it was."
  (let ((text (json-string figure)))
    (write-text path (string-append text "\n"))))

;;; The entry file of a standalone figure (05, "The entry file and
;;; running Typst"), reading the figure from JSON-NAME.
(define entry-header
  (string-append
   "#import \"notasi.typ\": score\n"
   "#set page(width: auto, height: auto, margin: 14pt, fill: white)\n"))

(define (figure-text json-name font)
  "The part of an entry file that draws the figure in JSON-NAME: its
title, subtitle, score and caption, in the font family FONT."
  (string-append
   "#let data = json(\"" json-name "\")\n"
   "#set text(font: \"" font "\",\n"
   "  size: if data.sizes.font_size == none { 8pt } else { eval(data.sizes.font_size) })\n"
   "#if data.title != \"\" {\n"
   "  block(below: if data.subtitle == none { 1em } else { 0.4em },\n"
   "    text(weight: \"bold\", size: 1.2em, data.title))\n"
   "}\n"
   "#if data.subtitle != none {\n"
   "  block(below: 1em, text(style: \"italic\", data.subtitle))\n"
   "}\n"
   "#score(data)\n"
   "#if data.caption != none {\n"
   "  block(above: 1em, text(style: \"italic\", data.caption))\n"
   "}\n"))

(define (entry-text json-name font)
  (string-append entry-header (figure-text json-name font)))

(define (pages-entry-text json-names font)
  "An entry file drawing each figure in JSON-NAMES on its own page."
  (string-append
   entry-header
   (string-join (map (lambda (name) (figure-text name font)) json-names)
                "#pagebreak()\n")))

(define* (write-entry-file path json-name #:key (font "Libertinus Serif"))
  "Write the entry file Typst compiles to PATH: it draws the figure in
JSON-NAME (relative to PATH's folder) with the template notasi.typ, with
the piece's title above it, in the font family FONT."
  (write-text path (entry-text json-name font)))

;;; Standalone figures use a sans serif found on the machine, the first
;;; of these, and Libertinus Serif, built into Typst, when none is
;;; (ADR 0045).
(define sans-fonts '("Helvetica" "Arial" "DejaVu Sans" "Liberation Sans"))

(define (choose-font families)
  "The font family for a standalone figure: the first of `sans-fonts'
in FAMILIES (a list of strings), else \"Libertinus Serif\"."
  (or (find (lambda (font) (member font families)) sans-fonts)
      "Libertinus Serif"))

(define (installed-fonts)
  "The font families Typst can use here, as `typst fonts' lists them; '()
if Typst can't be run."
  (match (typst-program)
    (#f '())
    (program
     (guard (e (#t '()))
       (let* ((port (open-pipe* OPEN_READ program "fonts"))
              (text (get-string-all port)))
         (close-pipe port)
         (filter (lambda (line) (not (string-null? line)))
                 (map string-trim-both (string-split text #\newline))))))))

;;; ------------------------------------------------------------------
;;; Running Typst

(define (output-format path)
  "Typst's format name for the file PATH, from its extension."
  (let ((dot (string-rindex path #\.)))
    (match (and dot (string-downcase (substring path (1+ dot))))
      ((and format (or "pdf" "png" "svg")) format)
      (_ (typst-error
          "can only draw to .pdf, .png or .svg files" path)))))

(define (typst-program)
  "The `typst' program on the PATH, looked up now."
  (or (find file-exists?
            (map (lambda (dir) (in-vicinity dir "typst"))
                 (filter (lambda (dir) (not (string-null? dir)))
                         (string-split (or (getenv "PATH") "") #\:))))
      (typst-error
       "Typst 0.15.1 is needed to draw figures, but `typst' isn't on the PATH.
Install it from https://github.com/typst/typst/releases")))

(define (run-and-capture program . args)
  "Run PROGRAM with ARGS; return (EXIT-STATUS . OUTPUT), with standard
output and standard error together."
  (let* ((port (apply open-pipe* OPEN_READ
                      "/bin/sh" "-c" "exec \"$0\" \"$@\" 2>&1"
                      program args))
         (output (get-string-all port))
         (status (close-pipe port)))
    (cons (status:exit-val status) output)))

(define (check-ppi out-path ppi)
  "Check OUT-PATH's format, and that PPI is given only for a PNG (05,
ADR 0061); return the format."
  (let ((format (output-format out-path)))
    (when (and ppi (not (string=? format "png")))
      (typst-error "a resolution (ppi) can only be given for a .png file"
                   out-path ppi))
    format))

(define* (compile-typst typ-path out-path #:key ppi)
  "Compile the Typst file TYP-PATH to OUT-PATH, whose extension (.pdf,
.png or .svg) gives the format, and return OUT-PATH.  A PNG is drawn at
PPI pixels per inch (default 144); PPI for a PDF or SVG is an &error.
Everything TYP-PATH reads must be in its folder.  Raise an &error if
Typst is missing or fails; the message then includes Typst's own
output."
  (let* ((format (check-ppi out-path ppi))
         (program (typst-program))
         (args `("compile" "--root" ,(dirname typ-path)
                 ,@(if (string=? format "png")
                       (list "--ppi" (number->string (or ppi 144)))
                       '())
                 ,typ-path ,out-path)))
    (match (apply run-and-capture program args)
      ((0 . _) out-path)
      ((_ . output)
       (typst-error (string-append "typst could not compile " typ-path
                                   ":\n" output)
                    typ-path)))))

;;; ------------------------------------------------------------------
;;; From a .nts file to a picture

(define (find-template)
  (or (search-path %load-path "typst/notasi.typ")
      (typst-error "can't find the template typst/notasi.typ on Guile's load path")))

(define (remove-tree dir)
  "Delete DIR and the files in it."
  (for-each (lambda (name) (delete-file (in-vicinity dir name)))
            (scandir dir (lambda (name) (not (member name '("." ".."))))))
  (rmdir dir))

(define (temporary-folder)
  (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp") "/notasi-XXXXXX")))

(define (call-with-render-folder keep-in proc)
  "Call PROC with a folder holding a copy of the template: KEEP-IN, which
is kept, or a fresh temporary folder, deleted afterwards even on
failure."
  (let ((template (find-template))
        (dir (or keep-in (temporary-folder))))
    (dynamic-wind
      (const #t)
      (lambda ()
        (copy-file template (in-vicinity dir "notasi.typ"))
        (proc dir))
      (lambda ()
        (unless keep-in (remove-tree dir))))))

(define* (render-score piece score out-path #:key ppi keep-in)
  "Draw SCORE, one of PIECE's scores, to OUT-PATH (.pdf, .png or .svg)
and return OUT-PATH.  A PNG is drawn at PPI pixels per inch (default
144).  The figure, template and entry file are made in a temporary
folder that is deleted afterwards, or in KEEP-IN, which is kept."
  (check-ppi out-path ppi)
  (let ((figure (layout-score piece score)))
    (call-with-render-folder keep-in
      (lambda (dir)
        (write-figure figure (in-vicinity dir "piece.json"))
        (write-entry-file (in-vicinity dir "piece.typ") "piece.json"
                          #:font (choose-font (installed-fonts)))
        (compile-typst (in-vicinity dir "piece.typ") out-path #:ppi ppi)))))

(define* (render-one-file piece scores out-path #:key keep-in)
  "Draw SCORES, some of PIECE's scores, to the one PDF OUT-PATH, each on
its own page sized to it, in order, with its title, subtitle and
caption; return OUT-PATH.  The files are made as `render-score' makes
them, one figure file per score."
  (unless (string=? (output-format out-path) "pdf")
    (typst-error "several scores can only be drawn to one .pdf file"
                 out-path))
  (let ((figures (map (lambda (score) (layout-score piece score)) scores))
        (names (map (lambda (i) (format #f "piece-~a.json" (1+ i)))
                    (iota (length scores)))))
    (call-with-render-folder keep-in
      (lambda (dir)
        (for-each (lambda (figure name)
                    (write-figure figure (in-vicinity dir name)))
                  figures names)
        (write-text (in-vicinity dir "piece.typ")
                    (pages-entry-text names (choose-font (installed-fonts))))
        (compile-typst (in-vicinity dir "piece.typ") out-path)))))

(define* (render-piece nts-path out-path #:key score keep-in ppi)
  "Draw the score SCORE (a symbol) of the piece in NTS-PATH, or its first
score (its default score if it has none) without SCORE, to OUT-PATH
(.pdf, .png or .svg), and return OUT-PATH.  A PNG is drawn at PPI
pixels per inch (default 144).  The figure, template and entry file are
made in a temporary folder that is deleted afterwards, or in KEEP-IN,
which is kept.  Reader errors pass through unchanged; a score the piece
doesn't have is an &error."
  (check-ppi out-path ppi)              ; a bad extension fails first
  (let* ((piece (read-piece-file nts-path))
         (chosen (if score
                     (or (piece-score piece score)
                         (raise-exception
                          (make-exception
                           (make-error)
                           (make-exception-with-message
                            (format #f "~a has no score called `~a'"
                                    nts-path score))
                           (make-exception-with-irritants
                            (list score nts-path)))))
                     (car (piece-scores piece)))))
    (render-score piece chosen out-path #:ppi ppi #:keep-in keep-in)))
