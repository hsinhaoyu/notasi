;;; (notasi piece) -- Records for a gamelan piece: scales, instruments,
;;; notes, parts, events and groups.  See doc/design/02-piece.md.
;;;
;;; The records are immutable.  Constructors do not validate: the reader
;;; checks the invariants, and everything downstream assumes them.

(define-module (notasi piece)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 match)
  #:export (note-pitch-index note-display note-label
            group-lanes part-end events-at

make-source-location source-location?
            source-location-file source-location-line

            make-piece piece?
            piece-title
            piece-length piece-scales piece-instruments piece-parts
            piece-groups

            make-scale scale?
            scale-name scale-degrees scale-pitched? scale-location

            make-degree degree?
            degree-name degree-aliases degree-display degree-damped
            degree-location

            make-instrument instrument?
            instrument-name instrument-scale instrument-notes
            instrument-location

            make-note note?
            note-name note-degree note-octave

            make-part part?
            part-name part-instrument part-events part-location

            make-event event?
            event-start event-duration event-notes

            make-group group?
            group-label group-subtitle group-parts group-location))

;;; Where a record came from, for error messages.  FILE is #f when the
;;; source was a string or port; LINE is 1-based.
(define-record-type <source-location>
  (make-source-location file line)
  source-location?
  (file source-location-file)
  (line source-location-line))

;;; A whole piece after reading, with templates merged.
(define-record-type <piece>
  (make-piece title length scales instruments parts groups)
  piece?
  (title            piece-title)
  (length           piece-length)           ; pulses, an exact rational
  (scales           piece-scales)           ; includes stroke sets
  (instruments      piece-instruments)
  (parts            piece-parts)
  (groups           piece-groups))

;;; A scale (pitched? #t, degrees ascending within one octave) or a
;;; stroke set (pitched? #f, strokes unordered).
(define-record-type <scale>
  (make-scale name degrees pitched? location)
  scale?
  (name     scale-name)
  (degrees  scale-degrees)
  (pitched? scale-pitched?)
  (location scale-location))

;;; A scale degree or a stroke.  DISPLAY is always a string; the reader
;;; fills in the name when the source gives none.  DAMPED is the form
;;; for a note cut short, or #f to use DISPLAY.
(define-record-type <degree>
  (make-degree name aliases display damped location)
  degree?
  (name     degree-name)
  (aliases  degree-aliases)
  (display  degree-display)
  (damped   degree-damped)
  (location degree-location))

;;; NOTES is a vector: ascending pitch for a pitched instrument, the
;;; listed order for a stroke instrument.
(define-record-type <instrument>
  (make-instrument name scale notes location)
  instrument?
  (name     instrument-name)
  (scale    instrument-scale)
  (notes    instrument-notes)
  (location instrument-location))

;;; DEGREE indexes the scale's degrees; OCTAVE is #f for a stroke.
(define-record-type <note>
  (make-note name degree octave)
  note?
  (name   note-name)
  (degree note-degree)
  (octave note-octave))

;;; EVENTS are sorted by start.
(define-record-type <part>
  (make-part name instrument events location)
  part?
  (name       part-name)
  (instrument part-instrument)
  (events     part-events)
  (location   part-location))

;;; NOTES are 0-based indices into the instrument's notes; more than one
;;; is a chord.
(define-record-type <event>
  (make-event start duration notes)
  event?
  (start    event-start)
  (duration event-duration)
  (notes    event-notes))

;;; LOCATION is #f for a default group (a part with no `group` form).
(define-record-type <group>
  (make-group label subtitle parts location)
  group?
  (label    group-label)
  (subtitle group-subtitle)
  (parts    group-parts)
  (location group-location))

;;; ------------------------------------------------------------------
;;; Derived values

(define (note-degree-record instrument note)
  "Return the degree (or stroke) record of NOTE on INSTRUMENT."
  (list-ref (scale-degrees (instrument-scale instrument))
            (note-degree note)))

(define (note-pitch-index instrument note)
  "Return NOTE's pitch on INSTRUMENT as octave × scale size + degree: a
total order across pitched instruments sharing a scale.  Raise an error
for a stroke, which has no pitch."
  (let ((scale (instrument-scale instrument)))
    (unless (scale-pitched? scale)
      (raise-exception
       (make-exception
        (make-error)
        (make-exception-with-origin 'note-pitch-index)
        (make-exception-with-message "a stroke has no pitch")
        (make-exception-with-irritants
         (list (note-name note) (instrument-name instrument))))))
    (+ (* (note-octave note) (length (scale-degrees scale)))
       (note-degree note))))

(define (note-display instrument note)
  "Return the short form of NOTE drawn in grid cells, e.g. \"i\" for ding2."
  (degree-display (note-degree-record instrument note)))

(define (note-label instrument note)
  "Return NOTE's lane label: the display form plus the octave (\"i2\"),
or just the display form for a stroke."
  (let ((shown (note-display instrument note)))
    (match (note-octave note)
      (#f shown)
      (octave (string-append shown (number->string octave))))))

(define (group-lanes group)
  "Return the notes the parts of GROUP play, each once, as note records:
one lane per note.  Pitched notes come highest first; strokes in their
instrument's order.  With several instruments, each instrument's lanes
follow in the order its first part appears in GROUP."
  (define (instrument-lanes instrument)
    (let* ((used (append-map
                  (lambda (part)
                    (if (eq? (part-instrument part) instrument)
                        (append-map event-notes (part-events part))
                        '()))
                  (group-parts group)))
           (notes (map (lambda (i) (vector-ref (instrument-notes instrument) i))
                       (sort (delete-duplicates used) <))))
      ;; Notes of a pitched instrument are in ascending pitch order
      ;; (invariant 5), so reversing puts the highest first.
      (if (scale-pitched? (instrument-scale instrument))
          (reverse notes)
          notes)))
  (append-map instrument-lanes
              (delete-duplicates (map part-instrument (group-parts group))
                                 eq?)))

(define (part-end part)
  "Return the time (in pulses) when PART's last event ends, or 0 if it
has none."
  (match (part-events part)
    (() 0)
    (events (let ((e (last events)))
              (+ (event-start e) (event-duration e))))))

(define (events-at piece time)
  "Return everything sounding at TIME (in pulses) in PIECE, as
(part . event) pairs in the piece's part order.  An event sounds from its
start through its holds."
  (append-map
   (lambda (part)
     (filter-map (lambda (e)
                   (and (<= (event-start e) time)
                        (< time (+ (event-start e) (event-duration e)))
                        (cons part e)))
                 (part-events part)))
   (piece-parts piece)))
