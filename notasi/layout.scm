;;; (notasi layout) -- Lay out one score of a piece as a figure: systems,
;;; groups, key-rows and events, each event with its look.  See
;;; doc/design/04-layout.md.
;;;
;;; The figure is the JSON value of 05's contract itself: alists with
;;; symbol keys for objects, vectors for arrays, the symbol `null' for
;;; null.  `write-json' from (notasi json) writes it as it is.

(define-module (notasi layout)
  #:use-module (notasi piece)
  #:use-module (notasi style)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (layout-score))

(define (null-if-false x)
  (or x 'null))

;;; ------------------------------------------------------------------
;;; Rows

(define (row-owners group)
  "The key-rows of GROUP, top first, as (INSTRUMENT . NOTE) pairs."
  (let ((instruments (delete-duplicates (map part-instrument (group-parts group))
                                        eq?)))
    (map (lambda (note)
           (cons (find (lambda (instrument)
                         (vector-index (lambda (n) (eq? n note))
                                       (instrument-notes instrument)))
                       instruments)
                 note))
         (group-row-keys group))))

(define (vector-index pred vector)
  (let loop ((i 0))
    (cond ((= i (vector-length vector)) #f)
          ((pred (vector-ref vector i)) i)
          (else (loop (1+ i))))))

(define (pitch-name-of instrument note)
  "The name of NOTE's pitch (ding for ding2), or a stroke's name, as a
string."
  (symbol->string
   (pitch-name (list-ref (scale-pitches (instrument-scale instrument))
                         (note-pitch note)))))

(define (with-octave text note octave?)
  "TEXT followed by NOTE's octave number, when it has one and OCTAVE?."
  (if (and octave? (note-octave note))
      (string-append text (number->string (note-octave note)))
      text))

(define (row-label group key-row)
  "ROW's row label in GROUP (04, \"The pitch column\"), by its
`row-labels': the pitch name or pitch display name, with the octave by
`row-label-octave?'; a stroke's name or display name (from the group's
:display); \"\" for none."
  (match key-row
    ((instrument . note)
     (match (group-row-labels group)
       ('none "")
       ('pitch-name
        (with-octave (pitch-name-of instrument note) note
                     (group-row-label-octave? group)))
       ('pitch-display-name
        (or (assq-ref (group-display group) (note-name note))
            (note-row-label instrument note
                            #:octave? (group-row-label-octave? group))))))))

(define (stroke-instrument? instrument)
  (not (scale-pitched? (instrument-scale instrument))))

(define (row-key-number key-row)
  "ROW's key number on its instrument, counted from 1, as a string."
  (match key-row
    ((instrument . note) (key-number-of instrument note))))

;;; ------------------------------------------------------------------
;;; Events

(define (key-number-of instrument note)
  "NOTE's key number on INSTRUMENT, counted from 1, as a string."
  (number->string
   (1+ (vector-index (lambda (n) (eq? n note)) (instrument-notes instrument)))))

(define (note-text group instrument note columns)
  "NOTE's label for an event COLUMNS long (as written), by GROUP's
`note-label' (04, \"What a note shows\"), or #f for none.  A pitch
display name is the damped form when the note lasts no longer than one
column; a stroke shows its name, or its display name (from the group's
:display) for pitch-display-name and key-number; octave numbers follow
`note-label-octave?' and never apply to strokes or key numbers."
  (define (display-name)
    (or (assq-ref (group-display group) (note-name note))
        (note-display instrument note #:damped? (<= columns 1))))
  (define octave? (group-note-label-octave? group))
  (match (group-note-label group)
    ('none #f)
    ('pitch-name
     (if (stroke-instrument? instrument)
         (symbol->string (note-name note))
         (with-octave (pitch-name-of instrument note) note octave?)))
    ('pitch-display-name
     (with-octave (display-name) note octave?))
    ('key-number
     (if (stroke-instrument? instrument)
         (display-name)
         (key-number-of instrument note)))))

(define (event-looks group style instrument indices columns)
  "The looks of an event striking INDICES on INSTRUMENT, COLUMNS long:
one per note on `notes' rows; one for the whole chord on `parts' and
`single' rows, its names joined and the look of its lowest note."
  (define (look-of index text)
    (let ((look (note-look style instrument
                           (vector-ref (instrument-notes instrument) index))))
      ;; The scheme gives the fill and the text colour; the text is the
      ;; note label (ADR 0054).
      (make-look (and (not (eq? (group-fill group) 'none)) (look-fill look))
                 text
                 (look-text-color look))))
  (define (name index)
    (note-text group instrument (vector-ref (instrument-notes instrument) index)
               columns))
  (if (eq? (group-rows group) 'notes)
      (map (lambda (index) (cons index (look-of index (name index)))) indices)
      (let ((lowest (apply min indices)))
        (list (cons lowest
                    (look-of lowest
                             (and (not (eq? (group-note-label group) 'none))
                                  (string-join (map name (sort indices <))
                                               " "))))))))

(define (with-holds group instrument events)
  "With `holds' `dash', each event takes its first column only, and
every later column it was held for gets a one-column \"-\" event.
Strokes are not held (ADR 0042): they get no dashes."
  (if (and (eq? (group-holds group) 'dash)
           (not (stroke-instrument? instrument)))
      (append-map
       (match-lambda
         ((start duration key-row look)
          (cons (list start 1 key-row look)
                (map (lambda (c)
                       (list c 1 key-row
                             (make-look #f "-" (look-text-color look))))
                     (iota (max 0 (- duration 1)) (+ start 1))))))
       events)
      events))

(define (note-events group part row-of style k)
  "PART's events in GROUP as (START DURATION ROW LOOK) lists, in columns
of 1/K pulse.  ROW-OF gives a note's key-row from its index."
  (let ((instrument (part-instrument part)))
    (with-holds
     group instrument
     (append-map
      (lambda (event)
        (let* ((columns (* k (event-duration event)))
               ;; A stroke is drawn one column wide (ADR 0042); its
               ;; name still follows its written length.
               (drawn (if (stroke-instrument? instrument) 1 columns)))
          (map (match-lambda
                 ((index . look)
                  (list (* k (event-start event)) drawn
                        (row-of index) look)))
               (event-looks group style instrument (event-notes event)
                            columns))))
      (part-events part)))))

(define (clip-event event from to)
  "EVENT cut to the steps [FROM, TO), as a JSON event object with a
start relative to FROM, or #f if it doesn't sound there."
  (match event
    ((start duration key-row look)
     (let ((end (+ start duration)))
       (and (< start to) (> end from)
            (let ((first (max start from)))
              `((start . ,(- first from))
                (dur . ,(- (min end to) first))
                (row . ,key-row)
                (text . ,(null-if-false (look-text look)))
                (fill . ,(null-if-false (look-fill look)))
                (text_color . ,(look-text-color look))
                (continued . ,(< start from)))))))))

(define (event<? a b)
  (match (list a b)
    (((start-a _ row-a _) (start-b _ row-b _))
     (or (< start-a start-b)
         (and (= start-a start-b) (< row-a row-b))))))

;;; ------------------------------------------------------------------
;;; Groups and systems

;;; The style of GROUP, from its effective scheme, palette and colours
;;; (ADR 0032).  The reader has checked them.
(define (group-style group)
  (make-style #:scheme (group-scheme group)
              #:palette (group-palette group)
              #:pitch-colors (group-colors group)))

;;; A group prepared once for the whole piece: its JSON label fields,
;;; its row labels, and each voice's events in the whole piece, in
;;; columns of 1/K pulse.  Rows are the notes used (`notes'), one per
;;; member (`parts'), or one for all (`single').
(define (prepare-group group k from to)
  "(GROUP ROW-LABELS VOICES OVERLAYS KEY-NUMBERS), KEY-NUMBERS a string
per key-row or #f."
  (match (prepare-rows group k from to)
    ((group labels voices key-numbers)
     (list group labels voices (group-overlays group k) key-numbers))))

(define (sounds-in? event from to)
  "Whether EVENT sounds somewhere in [FROM, TO), in pulses."
  (and (< (event-start event) to)
       (> (+ (event-start event) (event-duration event)) from)))

(define (rows-in-range group from to)
  "GROUP's key-rows that some note of its parts sounds on in [FROM, TO)."
  (let ((used (append-map
               (lambda (part)
                 (let ((notes (instrument-notes (part-instrument part))))
                   (append-map
                    (lambda (event)
                      (if (sounds-in? event from to)
                          (map (lambda (i) (vector-ref notes i))
                               (event-notes event))
                          '()))
                    (part-events part))))
               (group-parts group))))
    (filter (match-lambda ((_ . note) (memq note used)))
            (row-owners group))))

(define (named-spans group)
  "The spans of GROUP's members at its pattern level, as (START END
TEXT) in pulses: none when it prints no pattern names."
  (if (eq? (group-pattern-names group) 'none)
      '()
      (append-map
       (lambda (part)
         (filter-map
          (lambda (span)
            (and (= (pattern-span-depth span) (group-pattern-level group))
                 (list (pattern-span-start span) (pattern-span-end span)
                       (if (eq? (group-pattern-names group) 'long)
                           (pattern-span-long span)
                           (pattern-span-short span)))))
          (part-spans part)))
       (group-parts group))))

(define (group-overlays group k)
  "GROUP's pattern names as (START DURATION TEXT) in columns of 1/K
pulse, identical ones written once, sorted by start."
  (sort (delete-duplicates
         (map (match-lambda
                ((start end text) (list (* k start) (* k (- end start)) text)))
              (named-spans group)))
        (lambda (a b) (< (car a) (car b)))))

(define (without-unisons voices)
  "VOICES, (NAME . EVENTS) in member order, with every event that an
earlier voice already has (the same start, duration and key-row: a unison,
which the reader allows on `notes' rows) left out, so it is drawn once."
  (let loop ((voices voices) (seen '()) (out '()))
    (match voices
      (() (reverse out))
      (((name . events) . rest)
       (let* ((cell (match-lambda ((start duration key-row _)
                                   (list start duration key-row))))
              (kept (remove (lambda (e) (member (cell e) seen)) events)))
         (loop rest (append (map cell events) seen)
               (cons (cons name kept) out)))))))

(define (prepare-rows group k from to)
  (let ((style (group-style group)))
    (define (voices row-of-part)
      (map (lambda (part)
             (cons (symbol->string (part-name part))
                   (sort (note-events group part (row-of-part part) style k)
                         event<?)))
           (group-parts group)))
    (match (group-rows group)
      ('notes
       (let ((key-rows (group-key-rows group from to)))
         (list group (map (lambda (key-row) (row-label group key-row)) key-rows)
               (without-unisons
                (voices
                (lambda (part)
                  (lambda (index)
                    (let ((note (vector-ref (instrument-notes
                                             (part-instrument part))
                                            index)))
                      (list-index (match-lambda ((_ . n) (eq? n note)))
                                  key-rows))))))
               (and (group-key-numbers? group)
                    (map row-key-number key-rows)))))
      ('parts
       (list group (map (lambda (m)
                          (if (eq? (group-row-labels group) 'none) "" (cdr m)))
                        (group-members group))
             (voices (lambda (part)
                       (let ((row (list-index (match-lambda ((p . _) (eq? p part)))
                                              (group-members group))))
                         (const row))))
             #f))
      ('single
       (list group '("") (voices (lambda (part) (const 0))) #f)))))

(define (group-key-rows group from to)
  "The key-rows of a `notes' group, top first, by its `keys' (04): the keys
played in [FROM, TO), every key of the instruments, or LOW to HIGH."
  (match (group-keys group)
    ('used (rows-in-range group from to))
    ('all (all-key-rows group))
    ((low . high)
     (let* ((instrument (part-instrument (car (group-parts group))))
            (notes (vector->list (instrument-notes instrument)))
            (lo (list-index (lambda (n) (eq? n low)) notes))
            (hi (list-index (lambda (n) (eq? n high)) notes)))
       (map (lambda (n) (cons instrument n))
            (reverse (list-head (list-tail notes lo) (1+ (- hi lo)))))))))

(define (all-key-rows group)
  "Every key of GROUP's instrument, highest first, or every stroke of
each stroke instrument, in its order, as blocks in the order their first
part appears."
  (append-map
   (lambda (instrument)
     (let ((notes (vector->list (instrument-notes instrument))))
       (map (lambda (n) (cons instrument n))
            (if (stroke-instrument? instrument) notes (reverse notes)))))
   (delete-duplicates (map part-instrument (group-parts group)) eq?)))

(define (clip-overlay overlay rows from to)
  "OVERLAY cut to the columns [FROM, TO), as a JSON overlay object, or
#f.  A continued piece shows its text again."
  (match overlay
    ((start duration text)
     (let ((end (+ start duration)))
       (and (< start to) (> end from)
            (let ((first (max start from)))
              `((start . ,(- first from))
                (dur . ,(- (min end to) first))
                (row . 0)
                (rows . ,rows)
                (text . ,text)
                (continued . ,(< start from)))))))))

(define (printed-label group index)
  "The label GROUP prints on the system numbered INDEX (from 0)."
  (match (group-labels group)
    ('long (group-label group))
    ('short (group-short group))
    ('first-long (if (zero? index) (group-label group) (group-short group)))))

(define (group-in-system prepared index from to)
  (match prepared
    ((group key-rows voices overlays key-numbers)
     `((label . ,(printed-label group index))
       (subtitle . ,(null-if-false (group-subtitle group)))
       (rows . ,(list->vector key-rows))
       (key_numbers . ,(if key-numbers (list->vector key-numbers) 'null))
       (voices
        . ,(list->vector
            (map (match-lambda
                   ((name . events)
                    `((name . ,name)
                      (events
                       . ,(list->vector
                           (filter-map (lambda (e) (clip-event e from to))
                                       events))))))
                 voices)))
       (overlays
        . ,(list->vector
            (filter-map (lambda (o) (clip-overlay o (length key-rows) from to))
                        overlays)))
       ;; The lines behind the group's rows (ADRs 0041, 0043).
       (pulse_lines . ,(pulse-lines? (group-background group)))
       (row_lines . ,(and (memq (group-background group) '(grid horizontal))
                          #t))))))

(define (pulse-lines? background)
  "Does BACKGROUND draw pulse lines?"
  (and (memq background '(grid vertical)) #t))

;;; ------------------------------------------------------------------
;;; The step (04, "The step")

(define (step-columns piece score)
  "K, the number of columns in a pulse: the step is the largest duration
1/K that divides 1 pulse, the range's ends, the breaks, the system
length, and every start and end, within the range, of the events and
pattern names the score prints."
  (let* ((from (score-from score))
         (to (score-to score))
         (edges (lambda (start end)
                  (if (and (< start to) (> end from))
                      (list (max start from) (min end to))
                      '()))))
    (fold (lambda (time k) (lcm k (denominator time)))
          1
          (append
           (list from to (or (score-system-length score) 1))
           (score-breaks score)
           (append-map (lambda (part)
                         (append-map (lambda (e)
                                       (edges (event-start e)
                                              (+ (event-start e)
                                                 (event-duration e))))
                                     (part-events part)))
                       (append-map group-parts (score-groups score)))
           (append-map (lambda (group)
                         (append-map (match-lambda
                                       ((start end _) (edges start end)))
                                     (named-spans group)))
                       (score-groups score))))))

;;; ------------------------------------------------------------------
;;; Header and lines (04, "Header and lines")

;;; The meter the header counts by: (CYCLE . PICKUP), or #f without a
;;; colotomy.
(define (piece-meter piece)
  (match (piece-colotomies piece)
    (() #f)
    (((_ . colotomy) . _)
     (cons (colotomy-length colotomy) (piece-pickup piece)))))

(define (pulse-text t meter numbering)
  "The number printed for the pulse starting at time T."
  (number->string
   (match meter
     (#f (+ t 1))
     ((cycle . pickup)
      (let ((p (+ (modulo (- t pickup) cycle) 1)))
        (if (eq? numbering 'gong-first)
            (+ (modulo p cycle) 1)
            p))))))

(define (cycle-start? t meter)
  (match meter
    (#f #f)
    ((cycle . pickup)
     (and (>= t pickup) (zero? (modulo (- t pickup) cycle))))))

(define (header score meter k start end)
  (let ((cycles
         (if (and meter (score-cycle-numbers? score))
             (list->vector
              (append
               ;; The pickup is cycle 0: a system that starts in it, or
               ;; with it, shows 0 at its first column (ADR 0043).
               (if (< (/ start k) (cdr meter))
                   (list `((column . 0) (text . "0")))
                   '())
               (filter-map
                (lambda (c)
                  (let ((t (/ c k)))
                    (and (integer? t) (cycle-start? t meter)
                         `((column . ,(- c start))
                           (text . ,(number->string
                                     (+ (/ (- t (cdr meter)) (car meter))
                                        1)))))))
                (iota (- end start) start))))
             'null))
        (pulses
         (if (score-pulse-numbers? score)
             (list->vector
              (map (lambda (c)
                     (let ((t (/ c k)))
                       (if (integer? t)
                           (pulse-text t meter (score-numbering score))
                           'null)))
                   (iota (- end start) start)))
             'null)))
    `((cycle_label . ,(if (eq? cycles 'null)
                          'null
                          (null-if-false (score-cycle-label score))))
      (pulse_label . ,(if (eq? pulses 'null)
                          'null
                          (null-if-false (score-pulse-label score))))
      (cycles . ,cycles)
      (pulses . ,pulses)
      (pulse_lines . ,(pulse-lines? (score-background score))))))

(define (lines meter k start end)
  (list->vector
   (map (lambda (c)
          (let ((t (/ c k)))
            (cond ((= c start) "none")
                  ((not (integer? t)) "none")
                  ((cycle-start? t meter) "cycle")
                  (else "pulse"))))
        (iota (- end start) start))))

;;; Systems of STEPS columns each (default: one for the whole piece),
;;; LENGTH columns in all.  The last may be shorter.
(define (system-starts score k)
  "The columns where the score's systems start: its start, every break,
and every system length from its start, in order."
  (let* ((from (* k (score-from score)))
         (to (* k (score-to score)))
         (every (match (score-system-length score)
                  (#f '())
                  (pulses (let ((steps (* k pulses)))
                            (iota (ceiling (/ (- to from) steps)) from steps))))))
    (if (>= from to)
        '()
        (sort (delete-duplicates
               (filter (lambda (c) (and (>= c from) (< c to)))
                       (append (list from)
                               (map (lambda (b) (* k b)) (score-breaks score))
                               every)))
              <))))

(define (systems prepared score meter k)
  (let* ((starts (system-starts score k))
         (ends (match starts
                 (() '())
                 ((_ . later) (append later (list (* k (score-to score))))))))
    (list->vector
     (map (lambda (index start end)
            `((start . ,start)
              (steps . ,(- end start))
              (header . ,(header score meter k start end))
              (lines . ,(lines meter k start end))
              (groups . ,(list->vector
                          (map (lambda (g) (group-in-system g index start end))
                               prepared)))))
          (iota (length starts)) starts ends))))

;;; ------------------------------------------------------------------
;;; Sizes

(define (em x)
  "X (exact) as a length in em with one decimal, ties rounded up."
  (let ((tenths (floor (+ (* x 10) 1/2))))
    (string-append (number->string (quotient tenths 10)) "."
                   (number->string (remainder tenths 10)) "em")))

(define (longest strings)
  (fold (lambda (s m) (max m (string-length s))) 0 strings))

(define (sizes prepared score systems)
  (let ((labels (append
                 ;; The labels printed, on any system.
                 (append-map (lambda (system)
                               (map (lambda (g) (assq-ref g 'label))
                                    (vector->list (assq-ref system 'groups))))
                             (vector->list systems))
                 ;; The header labels sit in the same column.
                 (append-map (lambda (system)
                               (let ((h (assq-ref system 'header)))
                                 (filter string?
                                         (list (assq-ref h 'cycle_label)
                                               (assq-ref h 'pulse_label)))))
                             (vector->list systems))
                 ;; A subtitle is under its label, or after it on a
                 ;; group of one row (05, "Groups"), which then needs
                 ;; room for both: the longest label it prints, a space
                 ;; and the subtitle.
                 (filter-map
                  (match-lambda
                    ((group key-rows _ _ _)
                     (and (group-subtitle group)
                          (if (= (length key-rows) 1)
                              (string-append
                               (make-string
                                (longest (list (group-label group)
                                               (group-short group)))
                                #\x)
                               "  " (group-subtitle group))
                              (group-subtitle group)))))
                  prepared)))
        (row-labels (append-map (match-lambda
                                   ((group key-rows _ _ _)
                                    (if (eq? (group-row-labels group) 'none)
                                        '()
                                        key-rows)))
                                 prepared))
        (key-numbers (append-map (match-lambda ((_ _ _ _ keys) (or keys '())))
                                 prepared))
        (any-labels? (any (match-lambda
                            ((group . _)
                             (not (eq? (group-row-labels group) 'none))))
                          prepared)))
    `((font_size . ,(null-if-false (score-font-size score)))
      (label_width . ,(em (+ (* 3/5 (longest labels)) 3/2)))
      ;; The key-number and row-label columns take no space when no
      ;; group shows them (ADR 0047).
      (key_width . ,(if (null? key-numbers)
                        "0.0em"
                        (em (+ (* 13/25 (longest key-numbers)) 1))))
      (row_label_width . ,(if (and (null? prepared) #t)
                         (em (+ (* 13/25 (longest row-labels)) 1))
                         (if any-labels?
                             (em (+ (* 13/25 (longest row-labels)) 1))
                             "0.0em")))
      (cell_width . ,(score-cell-width score))
      (cell_height . ,(score-cell-height score)))))

;;; ------------------------------------------------------------------
;;; Entry point

(define (layout-score piece score)
  "Lay out SCORE, one of PIECE's scores, as a figure: the JSON value of
the contract in doc/design/05-typst-backend.md (version 4).  Its groups
carry their effective settings (ADR 0033)."
  (let* ((k (step-columns piece score))
         (prepared (map (lambda (group)
                          (prepare-group group k (score-from score)
                                         (score-to score)))
                        (score-groups score)))
         (systems (systems prepared score (piece-meter piece) k)))
    `((version . 4)
      (title . ,(score-title score))
      (subtitle . ,(null-if-false (score-subtitle score)))
      (steps_per_pulse . ,k)
      (sizes . ,(sizes prepared score systems))
      (systems . ,systems)
      (caption . ,(null-if-false (score-caption score))))))
