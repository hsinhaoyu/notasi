;;; (notasi command) -- The `notasi' command line.  See "The `notasi'
;;; command" in doc/design/05-typst-backend.md and ADR 0018.
;;;
;;; `run-notasi' does the work and returns the exit status; it never
;;; exits, so it can be tested.  scripts/notasi calls it.

(define-module (notasi command)
  #:use-module (notasi piece)
  #:use-module (notasi reader)
  #:use-module (notasi typst)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (run-notasi notasi-version))

(define notasi-version
  ;; notasi's version (05, "The command line as a contract"): the
  ;; version being built, with -dev until it is tagged.
  "0.4.0-dev")

(define usage
  "usage: notasi render PIECE.nts [--score NAME | --all [--one-file]]
                    [--format pdf|png|svg] [--ppi N] [-o OUT]
       notasi render PIECE.nts --list")

(define help
  (string-append usage "

Draw a piece of notation as a score.

  render PIECE.nts    draw PIECE.nts; by default to PIECE.pdf beside it
  --score NAME        draw the score NAME instead of the first one; by
                      default to PIECE_NAME.pdf
  --all               draw every score, each to PIECE_NAME.pdf beside the
                      piece, or into the folder -o DIR
  --one-file          with --all, draw every score into one PDF, a page
                      each: PIECE.pdf, or -o FILE.pdf
  --format FORMAT     pdf (the default), png or svg
  --ppi N             a PNG's resolution in pixels per inch (default 144)
  -o, --output OUT    write OUT instead; its extension (.pdf, .png or
                      .svg) chooses the format
  --list              print the names of the piece's scores, and draw
                      nothing
  --help              show this help
  --version           show notasi's version"))

(define (say port . lines)
  (for-each (lambda (line) (display line port) (newline port)) lines))

(define (show-help)
  (say (current-output-port) help)
  0)

(define (show-version)
  (say (current-output-port) (string-append "notasi " notasi-version))
  0)

(define (usage-error what)
  (say (current-error-port) (string-append "notasi: " what) usage)
  2)

(define (option? arg)
  (and (> (string-length arg) 1) (char=? (string-ref arg 0) #\-)))

;;; ------------------------------------------------------------------
;;; Messages for errors that aren't notation mistakes

(define (error-text e)
  "A readable message for the exception E.  Guile's own errors (e.g. a
missing file) keep their details in the irritants, with a format string
as the message."
  (let ((message (if (exception-with-message? e)
                     (exception-message e)
                     "something went wrong"))
        (irritants (if (exception-with-irritants? e)
                       (exception-irritants e)
                       '())))
    (cond
     ((null? irritants) message)
     ((string-index message #\~)
      (or (false-if-exception (apply format #f message irritants))
          (string-join (cons message
                             (map (lambda (x) (format #f "~a" x)) irritants))
                       " ")))
     (else message))))

;;; ------------------------------------------------------------------
;;; notasi render

;;; A usage error found while reading or checking the options: raised as
;;; (usage . MESSAGE), and turned into status 2 by `render-command'.
(define (usage! . parts)
  (raise-exception (cons 'usage (string-concatenate parts))))

(define (usage? e)
  (and (pair? e) (eq? (car e) 'usage)))

(define formats '("pdf" "png" "svg"))

(define (strip-nts path)
  (if (string-suffix? ".nts" path) (string-drop-right path 4) path))

(define (extension path)
  "PATH's extension, lowercased, without the dot, or #f."
  (let* ((name (basename path))
         (dot (string-rindex name #\.)))
    (and dot (> dot 0) (string-downcase (substring name (1+ dot))))))

(define (folder? path)
  "Whether PATH names a folder for --all: an existing one, or a path
ending in /."
  (or (string-suffix? "/" path)
      (and (file-exists? path) (file-is-directory? path))))

(define (in-folder dir name)
  "DIR and NAME joined with one /."
  (string-append (string-trim-right dir #\/) "/" name))

(define (make-folders dir)
  "Make the folder DIR and any missing folders above it."
  (let ((dir (string-trim-right dir #\/)))
    (unless (or (string-null? dir) (file-exists? dir))
      (make-folders (dirname dir))
      (mkdir dir))))

(define (parse-render-args args)
  "The options and files of ARGS, the arguments after `render', as
(values OPTIONS FILES): OPTIONS an alist from option names (symbols) to
their values, #t for a flag.  A help request is (help . #t)."
  (define (needs-value option)
    (usage! option
            (match option
              ("--score" " needs a score's name")
              ((or "-o" "--output") " needs a file name")
              ("--format" " needs a format: pdf, png or svg")
              ("--ppi" " needs a number"))))
  (let loop ((args args) (options '()) (files '()))
    (match args
      (() (values options (reverse files)))
      (("--help" . _) (values '((help . #t)) '()))
      (((and option (or "--score" "-o" "--output" "--format" "--ppi"))
        . rest)
       (match rest
         (((? (lambda (v) (not (option? v))) value) . rest)
          (loop rest
                (acons (match option
                         ("--score" 'score)
                         ((or "-o" "--output") 'output)
                         ("--format" 'format)
                         ("--ppi" 'ppi))
                       value options)
                files))
         (_ (needs-value option))))
      (((and flag (or "--all" "--one-file" "--list")) . rest)
       (loop rest (acons (string->symbol (string-drop flag 2)) #t options)
             files))
      (((? option? option) . _)
       (usage! "unknown option `" option "'"))
      ((file . rest) (loop rest options (cons file files))))))

(define (option options name)
  (assq-ref options name))

(define (check-ppi value format)
  "The resolution VALUE (a string) as a number, checked for FORMAT."
  (let ((n (and (string-every char-set:digit value) (string->number value))))
    (unless (and n (> n 0))
      (usage! "--ppi needs a whole number greater than 0, not `" value "'"))
    (unless (string=? format "png")
      (usage! "--ppi can only be given for a PNG, not a "
              (string-upcase format)))
    n))

(define (render-plan options)
  "Check OPTIONS for drawing, and return what to do as an alist:
how (one, all or one-file), format, ppi, output, score."
  (let* ((all? (option options 'all))
         (one-file? (option options 'one-file))
         (score (option options 'score))
         (output (option options 'output))
         (format (option options 'format))
         (out-folder? (and all? (not one-file?) output (folder? output)))
         (out-ext (and output (not out-folder?) (extension output))))
    (when (option options 'list)
      (for-each (lambda (name)
                  (when (option options name)
                    (usage! "--list draws nothing, so it can't be used with --"
                            (if (eq? name 'output) "output (-o)"
                                (symbol->string name)))))
                '(all score output format ppi one-file)))
    (when (and all? score)
      (usage! "--all draws every score, so it can't be used with --score"))
    (when (and one-file? (not all?))
      (usage! "--one-file can only be used with --all"))
    (when (and format (not (member format formats)))
      (usage! "--format must be pdf, png or svg, not `" format "'"))
    (when (and format out-ext (not (string=? format out-ext)))
      (usage! "--format " format " doesn't match " output))
    (when (and all? (not one-file?) output (not out-folder?))
      (usage! "with --all, -o names a folder (an existing one, or a path "
              "ending in /), not " output))
    (let ((format (or format
                      (and out-ext (member out-ext formats) out-ext)
                      (if out-ext out-ext "pdf"))))
      (when (and one-file? (not (string=? format "pdf")))
        (usage! "--one-file draws one PDF, not a "
                (string-upcase format)))
      (let ((ppi (and=> (option options 'ppi)
                        (lambda (v) (check-ppi v format)))))
        `((how . ,(cond (one-file? 'one-file) (all? 'all) (else 'one)))
          (format . ,format)
          (ppi . ,ppi)
          (output . ,(cond
                      ((not output) #f)
                      ((and (not out-folder?) (not out-ext)
                            (option options 'format))
                       (string-append output "." format))
                      (else output)))
          (score . ,score))))))

(define (report-problems thunk)
  "Call THUNK, which returns a status.  A notation mistake prints the
reader's message; any other problem prints notasi: and its message.
Both return status 1."
  (guard (e ((notasi-syntax-error? e)
             (say (current-error-port) (exception-message e))
             1)
            ((exception? e)
             (say (current-error-port) (string-append "notasi: " (error-text e)))
             1))
    (thunk)))

(define (written-scores piece)
  "PIECE's scores written in the file, in order; '() when it has only
its default score."
  (filter score-location (piece-scores piece)))

(define (draw-one piece-path plan)
  (let* ((score (assq-ref plan 'score))
         (format (assq-ref plan 'format))
         (out (or (assq-ref plan 'output)
                  (string-append (strip-nts piece-path)
                                 (if score (string-append "_" score) "")
                                 "." format))))
    (report-problems
     (lambda ()
       (render-piece piece-path out
                     #:score (and score (string->symbol score))
                     #:ppi (assq-ref plan 'ppi))
       (say (current-output-port) out)
       0))))

(define (draw-all piece-path plan)
  "Draw every score of the piece, each to its own file; a score that
fails is reported, and the others are still drawn."
  (let ((format (assq-ref plan 'format))
        (output (assq-ref plan 'output))
        (base (strip-nts piece-path)))
    (define (out-path name)
      (let ((file (string-append (basename base)
                                 (if name (string-append "_" name) "")
                                 "." format)))
        (if output
            (in-folder output file)
            (string-append base (if name (string-append "_" name) "")
                           "." format))))
    (report-problems
     (lambda ()
       (let* ((piece (read-piece-file piece-path))
              (written (written-scores piece))
              (jobs (if (null? written)
                        (list (cons (car (piece-scores piece)) #f))
                        (map (lambda (score)
                               (cons score
                                     (symbol->string (score-name score))))
                             written))))
         (when output (make-folders output))
         (fold (lambda (job status)
                 (let* ((out (out-path (cdr job)))
                        (drawn (report-problems
                                (lambda ()
                                  (render-score piece (car job) out
                                                #:ppi (assq-ref plan 'ppi))
                                  (say (current-output-port) out)
                                  0))))
                   (max status drawn)))
               0 jobs))))))

(define (draw-one-file piece-path plan)
  (let ((out (or (assq-ref plan 'output)
                 (string-append (strip-nts piece-path) ".pdf"))))
    (report-problems
     (lambda ()
       (let ((piece (read-piece-file piece-path)))
         (render-one-file piece (piece-scores piece) out)
         (say (current-output-port) out)
         0)))))

(define (list-scores piece-path)
  "Print the names of the piece's scores, one per line, in the order
written, and draw nothing."
  (report-problems
   (lambda ()
     (for-each (lambda (score)
                 (say (current-output-port)
                      (symbol->string (score-name score))))
               (written-scores (read-piece-file piece-path)))
     0)))

(define (render-command args)
  "Parse the arguments after `render', check them, and draw the piece
(or list its scores)."
  (guard (e ((usage? e) (usage-error (cdr e))))
    (call-with-values (lambda () (parse-render-args args))
      (lambda (options files)
        (cond
         ((option options 'help) (show-help))
         (else
          (match files
            (() (usage! "render needs a PIECE.nts file"))
            ((piece-path)
             (let ((plan (render-plan options)))
               (if (option options 'list)
                   (list-scores piece-path)
                   (match (assq-ref plan 'how)
                     ('one (draw-one piece-path plan))
                     ('all (draw-all piece-path plan))
                     ('one-file (draw-one-file piece-path plan))))))
            (_ (usage! "render takes one PIECE.nts file")))))))))

;;; ------------------------------------------------------------------
;;; Entry point

(define (run-notasi args)
  "Run the notasi command with ARGS, the arguments after the program
name.  Write to the current output and error ports, and return the exit
status: 0 on success, 1 for a problem with the piece or drawing, 2 for
a mistake in using the command."
  (match args
    (() (usage-error "no subcommand"))
    (("--help" . _) (show-help))
    (("--version" . _) (show-version))
    (("render" . rest) (render-command rest))
    (((? option? option) . _)
     (usage-error (string-append "unknown option `" option "'")))
    ((other . _)
     (usage-error (string-append "unknown subcommand `" other "'")))))
