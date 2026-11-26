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
  #:export (note-pitch-index note-display note-row-label
            group-row-keys part-end events-at
            time->position position->time

make-source-location source-location?
            source-location-file source-location-line

            make-piece piece? piece-info
            piece-title
            piece-length piece-pickup piece-colotomies
            piece-scales piece-instruments piece-patterns piece-parts
            piece-scores piece-score

            make-pattern pattern?
            pattern-name pattern-instrument pattern-short pattern-long
            pattern-annotation
            pattern-location

            make-pattern-span pattern-span?
            pattern-span-pattern pattern-span-short pattern-span-long
            pattern-span-annotation pattern-span-start pattern-span-end
            pattern-span-depth

            make-colotomy colotomy?
            colotomy-name colotomy-length colotomy-timekeeper
            colotomy-parts colotomy-location

            make-scale scale?
            scale-name scale-pitches scale-pitched? scale-location

            make-pitch pitch?
            pitch-name pitch-aliases pitch-display pitch-damped
            pitch-location

            make-instrument instrument?
            instrument-name instrument-scale instrument-notes
            instrument-location

            make-note note?
            note-name note-pitch note-octave

            make-part part?
            part-name part-instrument part-events part-origin
            part-spans part-texts part-location

            make-free-text free-text?
            free-text-start free-text-length free-text-text

            make-annotation-row annotation-row?
            annotation-row-part annotation-row-position annotation-row-align
            annotation-row-level annotation-row-text annotation-row-label

            make-event event?
            event-start event-duration event-notes

            make-score score?
            score-name score-title score-subtitle score-caption score-from
            score-to score-system-length score-breaks score-cycle-numbers?
            score-pulse-numbers? score-numbering score-background score-cycle-label
            score-pulse-label
            score-font-size score-cell-width score-cell-height score-groups
            score-location

            make-group group?
            group-label group-short group-subtitle group-labels group-rows
            group-members group-note-label group-note-label-octave?
            group-fill group-holds
            group-annotation group-scheme
            group-palette group-colors group-background group-location
            group-keys group-row-label-octave? group-key-numbers?
            group-row-labels group-display group-part-marker

            make-marker marker?
            marker-symbol marker-symbol-size marker-symbol-color
            marker-border marker-border-width
            group-parts))

;;; Where a record came from, for error messages.  FILE is #f when the
;;; source was a string or port; LINE is 1-based.
(define-record-type <source-location>
  (make-source-location file line)
  source-location?
  (file source-location-file)
  (line source-location-line))

;;; A whole piece after reading, with templates merged.
(define-record-type <piece>
  (make-piece title length pickup colotomies scales instruments patterns
              parts scores info)
  piece?
  (title            piece-title)
  (length           piece-length)           ; pulses, an exact rational
  (pickup           piece-pickup)           ; pulses; 0 without a colotomy
  (colotomies       piece-colotomies)       ; ((START . COLOTOMY)) or ()
  (scales           piece-scales)           ; includes stroke sets
  (instruments      piece-instruments)
  (patterns         piece-patterns)
  (parts            piece-parts)
  (scores           piece-scores)       ; at least one (the default score)
  (info             piece-info))        ; ((KEY . STRING) ...), as written

;;; A scale (pitched? #t, pitches ascending within one octave) or a
;;; stroke set (pitched? #f, strokes unordered).
(define-record-type <scale>
  (make-scale name pitches pitched? location)
  scale?
  (name     scale-name)
  (pitches  scale-pitches)
  (pitched? scale-pitched?)
  (location scale-location))

;;; A pitch or a stroke.  DISPLAY is always a string; the reader
;;; fills in the name when the source gives none.  DAMPED is the form
;;; for a note cut short, or #f to use DISPLAY.
(define-record-type <pitch>
  (make-pitch name aliases display damped location)
  pitch?
  (name     pitch-name)
  (aliases  pitch-aliases)
  (display  pitch-display)
  (damped   pitch-damped)
  (location pitch-location))

;;; NOTES is a vector: ascending pitch for a pitched instrument, the
;;; listed order for a stroke instrument.
(define-record-type <instrument>
  (make-instrument name scale notes location)
  instrument?
  (name     instrument-name)
  (scale    instrument-scale)
  (notes    instrument-notes)
  (location instrument-location))

;;; PITCH indexes the scale's pitches; OCTAVE is #f for a stroke.
(define-record-type <note>
  (make-note name pitch octave)
  note?
  (name   note-name)
  (pitch note-pitch)
  (octave note-octave))

;;; EVENTS are sorted by start.
(define-record-type <part>
  (make-part name instrument events origin spans texts location)
  part?
  (name       part-name)
  (instrument part-instrument)
  (events     part-events)
  (origin     part-origin)       ; written, timekeeper or colotomy
  (spans      part-spans)        ; pattern-spans, sorted by start
  (texts      part-texts)        ; free-texts, sorted by start (ADR 0057)
  (location   part-location))

;;; Free text written in a part, `(text STRING [LENGTH])' (ADR 0057):
;;; not an event, it takes no time.  LENGTH is #f for a point, which
;;; runs to the next text in an annotation row.
(define-record-type <free-text>
  (make-free-text start length text)
  free-text?
  (start  free-text-start)              ; pulses
  (length free-text-length)             ; pulses, or #f
  (text   free-text-text))

;;; A group's annotation row (ADR 0057): a text-only row ABOVE or BELOW
;;; its rows, from PART's patterns at LEVEL (their SHORT or LONG name or
;;; ANNOTATION) and its free text, aligned LEFT, CENTER or RIGHT; LABEL
;;; is #f for none.
(define-record-type <annotation-row>
  (make-annotation-row part position align level text label)
  annotation-row?
  (part     annotation-row-part)
  (position annotation-row-position)
  (align    annotation-row-align)
  (level    annotation-row-level)
  (text     annotation-row-text)
  (label    annotation-row-label))

;;; A pattern: a named figure for one INSTRUMENT (ADR 0029).  Its body
;;; is used up by expansion; the piece keeps its names for its spans.
(define-record-type <pattern>
  (make-pattern name instrument short long annotation location)
  pattern?
  (name       pattern-name)
  (instrument pattern-instrument)
  (short      pattern-short)
  (long       pattern-long)
  (annotation pattern-annotation)       ; a string, or #f
  (location   pattern-location))

;;; One use of a pattern in a part: the names in force at that use, its
;;; START and END in pulses, and its DEPTH (0 for a use in the part, 1
;;; inside such a pattern, ...).
(define-record-type <pattern-span>
  (make-pattern-span pattern short long annotation start end depth)
  pattern-span?
  (pattern pattern-span-pattern)
  (short   pattern-span-short)
  (long    pattern-span-long)
  (annotation pattern-span-annotation)  ; in force at this use, or #f
  (start   pattern-span-start)
  (end     pattern-span-end)
  (depth   pattern-span-depth))

;;; A colotomic meter: a cycle of LENGTH pulses and the colotomic PARTS
;;; that mark it, each written out over one cycle.  TIMEKEEPER is the
;;; timekeeper's instrument name (kempli).
(define-record-type <colotomy>
  (make-colotomy name length timekeeper parts location)
  colotomy?
  (name       colotomy-name)
  (length     colotomy-length)
  (timekeeper colotomy-timekeeper)
  (parts      colotomy-parts)
  (location   colotomy-location))

;;; NOTES are 0-based indices into the instrument's notes; more than one
;;; is a chord.
(define-record-type <event>
  (make-event start duration notes)
  event?
  (start    event-start)
  (duration event-duration)
  (notes    event-notes))

;;; How the music is printed (ADR 0031): groups of parts and printing
;;; options.  LOCATION is #f for the default score.
(define-record-type <score>
  (make-score name title subtitle caption from to system-length breaks
              cycle-numbers? pulse-numbers? numbering background cycle-label
              pulse-label
              font-size cell-width cell-height groups location)
  score?
  (name           score-name)
  (title          score-title)
  (subtitle       score-subtitle)
  (caption        score-caption)
  (from           score-from)
  (to             score-to)
  (system-length  score-system-length)
  (breaks         score-breaks)
  (cycle-numbers? score-cycle-numbers?)
  (pulse-numbers? score-pulse-numbers?)
  (numbering      score-numbering)
  (background     score-background)
  (cycle-label    score-cycle-label)
  (pulse-label    score-pulse-label)
  (font-size      score-font-size)
  (cell-width     score-cell-width)
  (cell-height    score-cell-height)
  (groups         score-groups)
  (location       score-location))

;;; A block of rows in a score, with its effective settings filled in
;;; (ADR 0033).  MEMBERS are (PART . ROW-LABEL).  LOCATION is #f for a
;;; group of the default score.
(define-record-type <group>
  (make-group label short subtitle labels rows members note-label
              note-label-octave? fill holds annotation keys
              row-label-octave? key-numbers? row-labels display part-marker
              scheme palette colors background location)
  group?
  (label         group-label)
  (short         group-short)
  (subtitle      group-subtitle)
  (labels        group-labels)
  (rows          group-rows)
  (members       group-members)
  (note-label    group-note-label)      ; none | pitch-name |
                                        ; pitch-display-name | key-number
  (note-label-octave? group-note-label-octave?)
  (fill          group-fill)
  (holds         group-holds)
  (annotation    group-annotation)      ; annotation-row, or #f
  (keys          group-keys)            ; used | all | (LOW . HIGH) notes
  (row-label-octave? group-row-label-octave?)
  (key-numbers?  group-key-numbers?)
  (row-labels    group-row-labels)      ; none | pitch-name | pitch-display-name
  (display       group-display)         ; ((STROKE . STRING) ...)
  (part-marker   group-part-marker)     ; ((PART . MARKER) ...), '() for none
  (scheme        group-scheme)
  (palette       group-palette)
  (colors        group-colors)
  (background    group-background)
  (location      group-location))

;;; A part's marks in a group (ADR 0056): SYMBOL is none, dot, ring or
;;; cross; the others are #f for the template's default.
(define-record-type <marker>
  (make-marker symbol symbol-size symbol-color border border-width)
  marker?
  (symbol       marker-symbol)
  (symbol-size  marker-symbol-size)     ; a fraction of the cell, or #f
  (symbol-color marker-symbol-color)    ; "#rrggbb", or #f
  (border       marker-border)          ; "#rrggbb", or #f
  (border-width marker-border-width))   ; a Typst length, or #f

(define (group-parts group)
  "The parts of GROUP's members, in order."
  (map car (group-members group)))

(define (piece-score piece name)
  "The score of PIECE called NAME, or #f."
  (find (lambda (score) (eq? (score-name score) name))
        (piece-scores piece)))

;;; ------------------------------------------------------------------
;;; Derived values

(define (note-pitch-record instrument note)
  "Return the pitch (or stroke) record of NOTE on INSTRUMENT."
  (list-ref (scale-pitches (instrument-scale instrument))
            (note-pitch note)))

(define (note-pitch-index instrument note)
  "Return NOTE's pitch on INSTRUMENT as octave × scale size + pitch index: a
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
    (+ (* (note-octave note) (length (scale-pitches scale)))
       (note-pitch note))))

(define* (note-display instrument note #:key damped?)
  "Return the short form of NOTE drawn in grid cells, e.g. \"i\" for ding2;
with DAMPED?, its damped form (\"na'\"), or the display form when it has
none."
  (let ((pitch (note-pitch-record instrument note)))
    (or (and damped? (pitch-damped pitch))
        (pitch-display pitch))))

(define* (note-row-label instrument note #:key (octave? #t))
  "Return NOTE's row label: the pitch display name plus the octave
(\"i2\"), or just the display name for a stroke, or with OCTAVE? false."
  (let ((shown (note-display instrument note))
        (octave (note-octave note)))
    (if (and octave octave?)
        (string-append shown (number->string octave))
        shown)))

(define (group-row-keys group)
  "Return the notes the parts of GROUP play, each once, as note records:
one row per key or stroke.  Pitched notes come highest first; strokes in their
instrument's order.  With several instruments, each instrument's lanes
follow in the order its first part appears in GROUP."
  (define (instrument-keys instrument)
    (let* ((used (append-map
                  (lambda (part)
                    (if (eq? (part-instrument part) instrument)
                        (append-map event-notes (part-events part))
                        '()))
                  (group-parts group)))
           (notes (map (lambda (i) (vector-ref (instrument-notes instrument) i))
                       (sort (delete-duplicates used) <))))
      ;; Keys of a pitched instrument are in ascending pitch order
      ;; (invariant 5), so reversing puts the highest first.
      (if (scale-pitched? (instrument-scale instrument))
          (reverse notes)
          notes)))
  (append-map instrument-keys
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

;;; ------------------------------------------------------------------
;;; Positions (02, "Derived values"): derived from time, never stored.

(define (piece-cycle piece)
  "The length of PIECE's colotomy, or #f without one."
  (match (piece-colotomies piece)
    (() #f)
    (((_ . colotomy) . _) (colotomy-length colotomy))))

(define (time->position piece time)
  "TIME as a position: (CYCLE PULSE) with a colotomy, PULSE counting
from 1 and the pickup being cycle 0; without one, the pulse number
TIME + 1."
  (match (piece-cycle piece)
    (#f (+ time 1))
    (n (let ((t (- time (piece-pickup piece))))
         (list (+ (floor (/ t n)) 1)
               (+ (- t (* n (floor (/ t n)))) 1))))))

(define position->time
  (case-lambda
    ((piece pulse)
     "The time of pulse PULSE, in a piece without a colotomy."
     (- pulse 1))
    ((piece cycle pulse)
     "The time of CYCLE and PULSE in PIECE: the inverse of
`time->position'."
     (+ (piece-pickup piece)
        (* (piece-cycle piece) (- cycle 1))
        (- pulse 1)))))
