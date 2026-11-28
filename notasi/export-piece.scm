;;; (notasi export-piece) -- Save a piece, as notasi read it, as JSON or as an
;;; s-expression (ADR 0058).  See doc/design/02-piece.md, "Saving the
;;; piece".
;;;
;;; The piece is described once, as records of named fields in 02's
;;; order; the two writers turn that description into JSON (with `_' in
;;; field names) or into tagged lists (with `-').  Records refer to one
;;; another by name, and a note is its key's name.  The format has a
;;; version, but is not yet promised.

(define-module (notasi export-piece)
  #:use-module (notasi json-writer)
  #:use-module (notasi piece)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (piece->json piece->sexp save-piece))

(define format-version 1)

;;; ------------------------------------------------------------------
;;; The description: (record TAG (FIELD . VALUE) ...)
;;;
;;; A VALUE is a string, a number, a symbol, `(time . Q)' (an exact time
;;; or duration), `(bool . B)', `(list . VALUES)', `(object (KEY . STRING)
;;; ...)', a record, or `missing' for a field with no value.

(define (record tag . fields) (cons* 'record tag fields))
(define (time q) (cons 'time q))
(define (bool b) (cons 'bool (and b #t)))
(define (items . vs) (cons 'list vs))
(define (items-of f xs) (cons 'list (map f xs)))
(define (maybe x) (or x 'missing))

(define (source location)
  (match location
    (#f 'missing)
    (loc (record 'source
                 (cons 'file (maybe (source-location-file loc)))
                 (cons 'line (source-location-line loc))))))

(define (key-name instrument index)
  "The name of key INDEX of INSTRUMENT: its note's canonical name."
  (note-name (vector-ref (instrument-notes instrument) index)))

(define (describe-pitch pitch)
  (record 'pitch
          (cons 'name (pitch-name pitch))
          (cons 'aliases (items-of identity (pitch-aliases pitch)))
          (cons 'display (pitch-display pitch))
          (cons 'damped (maybe (pitch-damped pitch)))))

(define (describe-scale scale)
  (record 'scale
          (cons 'name (scale-name scale))
          (cons 'pitched (bool (scale-pitched? scale)))
          (cons 'pitches (items-of describe-pitch (scale-pitches scale)))
          (cons 'source (source (scale-location scale)))))

(define (describe-instrument instrument)
  (record 'instrument
          (cons 'name (instrument-name instrument))
          (cons 'scale (scale-name (instrument-scale instrument)))
          (cons 'keys (items-of note-name
                                (vector->list (instrument-notes instrument))))
          (cons 'source (source (instrument-location instrument)))))

(define (describe-colotomy entry)
  (match entry
    ((start . colotomy)
     (record 'colotomy
             (cons 'start (time start))
             (cons 'name (colotomy-name colotomy))
             (cons 'length (time (colotomy-length colotomy)))
             (cons 'timekeeper (colotomy-timekeeper colotomy))
             (cons 'parts (items-of part-name (colotomy-parts colotomy)))
             (cons 'source (source (colotomy-location colotomy)))))))

(define (describe-pattern pattern)
  (record 'pattern
          (cons 'name (pattern-name pattern))
          (cons 'instrument (instrument-name (pattern-instrument pattern)))
          (cons 'short (pattern-short pattern))
          (cons 'long (pattern-long pattern))
          (cons 'annotation (maybe (pattern-annotation pattern)))
          (cons 'source (source (pattern-location pattern)))))

(define (describe-part part)
  (let ((instrument (part-instrument part)))
    (record 'part
            (cons 'name (part-name part))
            (cons 'instrument (instrument-name instrument))
            (cons 'origin (part-origin part))
            (cons 'events
                  (items-of (lambda (e)
                              (record 'event
                                      (cons 'start (time (event-start e)))
                                      (cons 'dur (time (event-duration e)))
                                      (cons 'notes
                                            (items-of (lambda (i)
                                                        (key-name instrument i))
                                                      (event-notes e)))))
                            (part-events part)))
            (cons 'spans
                  (items-of (lambda (s)
                              (record 'span
                                      (cons 'pattern
                                            (pattern-name (pattern-span-pattern s)))
                                      (cons 'short (pattern-span-short s))
                                      (cons 'long (pattern-span-long s))
                                      (cons 'annotation
                                            (maybe (pattern-span-annotation s)))
                                      (cons 'start (time (pattern-span-start s)))
                                      (cons 'end (time (pattern-span-end s)))
                                      (cons 'depth (pattern-span-depth s))))
                            (part-spans part)))
            (cons 'texts
                  (items-of (lambda (t)
                              (record 'text
                                      (cons 'start (time (free-text-start t)))
                                      (cons 'length
                                            (match (free-text-length t)
                                              (#f 'missing)
                                              (q (time q))))
                                      (cons 'text (free-text-text t))))
                            (part-texts part)))
            (cons 'source (source (part-location part))))))

(define (describe-group group)
  (record 'group
          (cons 'label (group-label group))
          (cons 'short (group-short group))
          (cons 'subtitle (maybe (group-subtitle group)))
          (cons 'labels (group-labels group))
          (cons 'rows (group-rows group))
          (cons 'members
                (items-of (match-lambda
                            ((part . label)
                             (record 'member
                                     (cons 'part (part-name part))
                                     (cons 'label label))))
                          (group-members group)))
          (cons 'note_label (group-note-label group))
          (cons 'note_label_octave (bool (group-note-label-octave? group)))
          (cons 'fill (group-fill group))
          (cons 'holds (group-holds group))
          (cons 'annotation
                (match (group-annotation group)
                  (#f 'missing)
                  (row (record 'annotation
                               (cons 'part (part-name (annotation-row-part row)))
                               (cons 'position (annotation-row-position row))
                               (cons 'align (annotation-row-align row))
                               (cons 'level (annotation-row-level row))
                               (cons 'text (annotation-row-text row))
                               (cons 'label (maybe (annotation-row-label row)))))))
          (cons 'keys
                (match (group-keys group)
                  ((low . high) (items (note-name low) (note-name high)))
                  (keys keys)))
          (cons 'row_label_octave (bool (group-row-label-octave? group)))
          (cons 'key_numbers (bool (group-key-numbers? group)))
          (cons 'row_labels (group-row-labels group))
          (cons 'display
                (items-of (match-lambda
                            ((stroke . text)
                             (record 'display
                                     (cons 'stroke stroke) (cons 'text text))))
                          (group-display group)))
          (cons 'part_marker
                (items-of (match-lambda
                            ((part . marker)
                             (record 'marker
                                     (cons 'part (part-name part))
                                     (cons 'symbol (marker-symbol marker))
                                     (cons 'symbol_size
                                           (maybe (marker-symbol-size marker)))
                                     (cons 'symbol_color
                                           (maybe (marker-symbol-color marker)))
                                     (cons 'border (maybe (marker-border marker)))
                                     (cons 'border_width
                                           (maybe (marker-border-width marker))))))
                          (group-part-marker group)))
          (cons 'scheme (group-scheme group))
          (cons 'palette
                (match (group-palette group)
                  ((? symbol? name) name)
                  (colours (items-of identity colours))))
          (cons 'colors
                (items-of (match-lambda
                            ((pitch . colour)
                             (record 'color
                                     (cons 'pitch pitch) (cons 'color colour))))
                          (group-colors group)))
          (cons 'background (group-background group))
          (cons 'source (source (group-location group)))))

(define (describe-score score)
  (record 'score
          (cons 'name (score-name score))
          (cons 'title (score-title score))
          (cons 'subtitle (maybe (score-subtitle score)))
          (cons 'caption (maybe (score-caption score)))
          (cons 'from (time (score-from score)))
          (cons 'to (time (score-to score)))
          (cons 'system_length (match (score-system-length score)
                                 (#f 'missing)
                                 (q (time q))))
          (cons 'breaks (items-of time (score-breaks score)))
          (cons 'cycle_numbers (bool (score-cycle-numbers? score)))
          (cons 'pulse_numbers (bool (score-pulse-numbers? score)))
          (cons 'numbering (score-numbering score))
          (cons 'background (score-background score))
          (cons 'cycle_label (maybe (score-cycle-label score)))
          (cons 'pulse_label (maybe (score-pulse-label score)))
          (cons 'font_size (maybe (score-font-size score)))
          (cons 'cell_width (score-cell-width score))
          (cons 'cell_height (score-cell-height score))
          (cons 'groups (items-of describe-group (score-groups score)))
          (cons 'source (source (score-location score)))))

(define (describe-piece piece)
  (record 'piece
          (cons 'version format-version)
          (cons 'title (piece-title piece))
          (cons 'length (time (piece-length piece)))
          (cons 'pickup (time (piece-pickup piece)))
          (cons 'info (cons 'object (piece-info piece)))
          (cons 'colotomies (items-of describe-colotomy (piece-colotomies piece)))
          (cons 'scales (items-of describe-scale (piece-scales piece)))
          (cons 'instruments (items-of describe-instrument
                                       (piece-instruments piece)))
          (cons 'patterns (items-of describe-pattern (piece-patterns piece)))
          (cons 'parts (items-of describe-part (piece-parts piece)))
          (cons 'scores (items-of describe-score (piece-scores piece)))))

;;; ------------------------------------------------------------------
;;; JSON

(define (json-time q)
  "A whole time as a number, any other as \"N/D\" in lowest terms."
  (if (integer? q) q (number->string q)))

(define (json-number x)
  ;; JSON has no fractions: a fraction that isn't a time is written as a
  ;; decimal (a symbol size of 1/2 is 0.5).
  (if (and (exact? x) (not (integer? x))) (exact->inexact x) x))

(define (->json value)
  (match value
    ('missing 'null)
    (('record _ . fields)
     (map (match-lambda ((name . v) (cons name (->json v)))) fields))
    (('time . q) (json-time q))
    (('bool . b) b)
    (('list . vs) (list->vector (map ->json vs)))
    (('object . pairs) pairs)
    ((? symbol? s) (symbol->string s))
    ((? number? n) (json-number n))
    (other other)))

(define (piece->json piece)
  "PIECE as the JSON value of a saved piece (02, \"Saving the piece\"),
as (notasi json-writer) writes it: alists, vectors and `null'."
  (->json (describe-piece piece)))

;;; ------------------------------------------------------------------
;;; s-expression

(define (sexp-name name)
  (string->symbol (string-map (lambda (c) (if (char=? c #\_) #\- c))
                              (symbol->string name))))

(define (sexp-field name value)
  "(NAME VALUE) for one field: a list of records or of values is spread,
(parts (part ...) ...); a record is (NAME (FIELD VALUE) ...)."
  (let ((name (sexp-name name)))
    (match value
      ('missing (list name #f))
      (('record _ . fields)
       (cons name (map (match-lambda ((n . v) (sexp-field n v))) fields)))
      (('list . vs) (cons name (map ->sexp vs)))
      (('object . pairs)
       (cons name (map (match-lambda ((k . v) (list k v))) pairs)))
      (_ (list name (->sexp value))))))

(define (->sexp value)
  (match value
    ('missing #f)
    (('record tag . fields)
     (cons tag (map (match-lambda ((n . v) (sexp-field n v))) fields)))
    (('time . q) q)
    (('bool . b) b)
    (('list . vs) (map ->sexp vs))
    (('object . pairs) (map (match-lambda ((k . v) (list k v))) pairs))
    (other other)))

(define (piece->sexp piece)
  "PIECE as a saved piece in tagged lists: (piece (version 1) (title
\"...\") ... (parts (part (name polos) ...) ...) ...), times exact,
readable with `read' (02, \"Saving the piece\")."
  (->sexp (describe-piece piece)))

;;; ------------------------------------------------------------------
;;; Writing

(define (save-error message . irritants)
  (raise-exception
   (make-exception (make-error)
                   (make-exception-with-message message)
                   (make-exception-with-irritants irritants))))

(define* (save-piece piece path)
  "Save PIECE to PATH: JSON for a .json file, an s-expression for .scm,
JSON on the current output port for \"-\"; any other name is an &error.
The text is built before the file is opened."
  (cond
   ((string=? path "-")
    (display (json-string (piece->json piece)))
    (newline))
   ((string-suffix? ".json" path)
    (let ((text (string-append (json-string (piece->json piece)) "\n")))
      (call-with-output-file path (lambda (port) (display text port))
        #:encoding "UTF-8")))
   ((string-suffix? ".scm" path)
    (let ((datum (piece->sexp piece)))
      (call-with-output-file path
        (lambda (port) (write datum port) (newline port))
        #:encoding "UTF-8")))
   (else
    (save-error "a saved piece is a .json or .scm file, or - for standard output"
                path))))
