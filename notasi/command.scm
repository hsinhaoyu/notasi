;;; (notasi command) -- The `notasi' command line.  See "The `notasi'
;;; command" in doc/design/05-typst-backend.md and ADR 0018.
;;;
;;; `run-notasi' does the work and returns the exit status; it never
;;; exits, so it can be tested.  scripts/notasi calls it.

(define-module (notasi command)
  #:use-module (notasi reader)
  #:use-module (notasi typst)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 match)
  #:export (run-notasi notasi-version))

(define notasi-version
  ;; notasi's version (05, "The command line as a contract"): the
  ;; version being built, with -dev until it is tagged.
  "0.4.0-dev")

(define usage "usage: notasi render PIECE.nts [--score NAME] [-o OUT]")

(define help
  (string-append usage "

Draw a piece of notation as a score.

  render PIECE.nts    draw PIECE.nts; by default to PIECE.pdf beside it
  --score NAME        draw the score NAME instead of the first one; by
                      default to PIECE_NAME.pdf
  -o, --output OUT    write OUT instead; its extension (.pdf, .png or
                      .svg) chooses the format
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

(define (default-output piece score)
  "PIECE's folder and name with .pdf, and the score's name when one was
chosen: songs/gilak.nts → songs/gilak.pdf, or songs/gilak_full.pdf
(ADR 0040)."
  (string-append (if (string-suffix? ".nts" piece)
                     (string-drop-right piece 4)
                     piece)
                 (if score (string-append "_" score) "")
                 ".pdf"))

(define (render piece score out)
  (guard (e ((notasi-syntax-error? e)
             (say (current-error-port) (exception-message e))
             1)
            ((exception? e)
             (say (current-error-port) (string-append "notasi: " (error-text e)))
             1))
    (render-piece piece out #:score (and score (string->symbol score)))
    (say (current-output-port) out)
    0))

(define (render-command args)
  "Parse the arguments after `render' and draw the piece."
  (let loop ((args args) (files '()) (out #f) (score #f))
    (match args
      (()
       (match files
         (() (usage-error "render needs a PIECE.nts file"))
         ((piece) (render piece score (or out (default-output piece score))))
         (_ (usage-error "render takes one PIECE.nts file"))))
      (("--help" . _) (show-help))
      (((or "-o" "--output") value . rest)
       (if (option? value)
           (usage-error (string-append (car args) " needs a file name"))
           (loop rest files value score)))
      (((or "-o" "--output"))
       (usage-error (string-append (car args) " needs a file name")))
      (("--score" value . rest)
       (if (option? value)
           (usage-error "--score needs a score's name")
           (loop rest files out value)))
      (("--score")
       (usage-error "--score needs a score's name"))
      (((? option? option) . _)
       (usage-error (string-append "unknown option `" option "'")))
      ((file . rest) (loop rest (append files (list file)) out score)))))

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
