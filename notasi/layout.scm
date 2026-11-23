;;; (notasi layout) -- Lay out one score of a piece as a figure: systems,
;;; groups, lanes and events, each event with its look.  See
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
;;; Lanes

(define (lane-owners group)
  "The lanes of GROUP, top first, as (INSTRUMENT . NOTE) pairs."
  (let ((instruments (delete-duplicates (map part-instrument (group-parts group))
                                        eq?)))
    (map (lambda (note)
           (cons (find (lambda (instrument)
                         (vector-index (lambda (n) (eq? n note))
                                       (instrument-notes instrument)))
                       instruments)
                 note))
         (group-lanes group))))

(define (vector-index pred vector)
  (let loop ((i 0))
    (cond ((= i (vector-length vector)) #f)
          ((pred (vector-ref vector i)) i)
          (else (loop (1+ i))))))

(define (lane-label lane)
  (match lane
    ((instrument . note) (note-label instrument note))))

;;; ------------------------------------------------------------------
;;; Events

(define (note-text instrument note columns)
  "NOTE's name for an event COLUMNS long: its damped form when the note
lasts no longer than one column, its display form otherwise."
  (note-display instrument note #:damped? (<= columns 1)))

(define (event-looks group style instrument indices columns)
  "The looks of an event striking INDICES on INSTRUMENT, COLUMNS long:
one per note on `notes' rows; one for the whole chord on `parts' and
`single' rows, its names joined and the look of its lowest note."
  (define (look-of index text)
    (let ((look (note-look style instrument
                           (vector-ref (instrument-notes instrument) index))))
      (make-look (and (not (eq? (group-fill group) 'none)) (look-fill look))
                 (and (group-note-names? group) text)
                 (look-text-color look))))
  (define (name index)
    (note-text instrument (vector-ref (instrument-notes instrument) index)
               columns))
  (if (eq? (group-rows group) 'notes)
      (map (lambda (index) (cons index (look-of index (name index)))) indices)
      (let ((lowest (apply min indices)))
        (list (cons lowest
                    (look-of lowest
                             (string-join (map name (sort indices <)) " ")))))))

(define (with-holds group events)
  "With `holds' `dash', each event takes its first column only, and
every later column it was held for gets a one-column \"-\" event."
  (if (eq? (group-holds group) 'dash)
      (append-map
       (match-lambda
         ((start duration lane look)
          (cons (list start 1 lane look)
                (map (lambda (c)
                       (list c 1 lane
                             (make-look #f "-" (look-text-color look))))
                     (iota (max 0 (- duration 1)) (+ start 1))))))
       events)
      events))

(define (note-events group part lane-of style k)
  "PART's events in GROUP as (START DURATION LANE LOOK) lists, in columns
of 1/K pulse.  LANE-OF gives a note's lane from its index."
  (let ((instrument (part-instrument part)))
    (with-holds
     group
     (append-map
      (lambda (event)
        (let ((columns (* k (event-duration event))))
          (map (match-lambda
                 ((index . look)
                  (list (* k (event-start event)) columns
                        (lane-of index) look)))
               (event-looks group style instrument (event-notes event)
                            columns))))
      (part-events part)))))

(define (clip-event event from to)
  "EVENT cut to the steps [FROM, TO), as a JSON event object with a
start relative to FROM, or #f if it doesn't sound there."
  (match event
    ((start duration lane look)
     (let ((end (+ start duration)))
       (and (< start to) (> end from)
            (let ((first (max start from)))
              `((start . ,(- first from))
                (dur . ,(- (min end to) first))
                (lane . ,lane)
                (text . ,(null-if-false (look-text look)))
                (fill . ,(null-if-false (look-fill look)))
                (text_color . ,(look-text-color look))
                (continued . ,(< start from)))))))))

(define (event<? a b)
  (match (list a b)
    (((start-a _ lane-a _) (start-b _ lane-b _))
     (or (< start-a start-b)
         (and (= start-a start-b) (< lane-a lane-b))))))

;;; ------------------------------------------------------------------
;;; Groups and systems

;;; The style of GROUP, from its effective scheme, palette and colours
;;; (ADR 0032).  The reader has checked them.
(define (group-style group)
  (make-style #:scheme (group-scheme group)
              #:palette (group-palette group)
              #:degree-colors (group-colors group)))

;;; A group prepared once for the whole piece: its JSON label fields,
;;; its row labels, and each voice's events in the whole piece, in
;;; columns of 1/K pulse.  Rows are the notes used (`notes'), one per
;;; member (`parts'), or one for all (`single').
(define (prepare-group group k from to)
  (append (prepare-rows group k from to) (list (group-overlays group k))))

(define (sounds-in? event from to)
  "Whether EVENT sounds somewhere in [FROM, TO), in pulses."
  (and (< (event-start event) to)
       (> (+ (event-start event) (event-duration event)) from)))

(define (lanes-in-range group from to)
  "GROUP's lanes that some note of its parts sounds on in [FROM, TO)."
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
            (lane-owners group))))

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
earlier voice already has (the same start, duration and lane: a unison,
which the reader allows on `notes' rows) left out, so it is drawn once."
  (let loop ((voices voices) (seen '()) (out '()))
    (match voices
      (() (reverse out))
      (((name . events) . rest)
       (let* ((cell (match-lambda ((start duration lane _)
                                   (list start duration lane))))
              (kept (remove (lambda (e) (member (cell e) seen)) events)))
         (loop rest (append (map cell events) seen)
               (cons (cons name kept) out)))))))

(define (prepare-rows group k from to)
  (let ((style (group-style group)))
    (define (voices lane-of-part)
      (map (lambda (part)
             (cons (symbol->string (part-name part))
                   (sort (note-events group part (lane-of-part part) style k)
                         event<?)))
           (group-parts group)))
    (match (group-rows group)
      ('notes
       (let ((lanes (lanes-in-range group from to)))
         (list group (map lane-label lanes)
               (without-unisons
                (voices
                (lambda (part)
                  (lambda (index)
                    (let ((note (vector-ref (instrument-notes
                                             (part-instrument part))
                                            index)))
                      (list-index (match-lambda ((_ . n) (eq? n note)))
                                  lanes)))))))))
      ('parts
       (list group (map cdr (group-members group))
             (voices (lambda (part)
                       (let ((row (list-index (match-lambda ((p . _) (eq? p part)))
                                              (group-members group))))
                         (const row))))))
      ('single
       (list group '("") (voices (lambda (part) (const 0))))))))

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
    ((group lanes voices overlays)
     `((label . ,(printed-label group index))
       (subtitle . ,(null-if-false (group-subtitle group)))
       (lanes . ,(list->vector lanes))
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
            (filter-map (lambda (o) (clip-overlay o (length lanes) from to))
                        overlays)))))))

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
  `((label . ,(null-if-false (score-pulse-label score)))
    (cycles
     . ,(if (and meter (score-cycle-numbers? score))
            (list->vector
             (filter-map
              (lambda (c)
                (let ((t (/ c k)))
                  (and (integer? t) (cycle-start? t meter)
                       `((column . ,(- c start))
                         (text . ,(number->string
                                   (+ (/ (- t (cdr meter)) (car meter))
                                      1)))))))
              (iota (- end start) start)))
            'null))
    (pulses
     . ,(if (score-pulse-numbers? score)
            (list->vector
             (map (lambda (c)
                    (let ((t (/ c k)))
                      (if (integer? t)
                          (pulse-text t meter (score-numbering score))
                          'null)))
                  (iota (- end start) start)))
            'null))))

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
                 ;; A subtitle is under its label, or after it on a
                 ;; group of one row (05, "Groups"), which then needs
                 ;; room for both: the longest label it prints, a space
                 ;; and the subtitle.
                 (filter-map
                  (match-lambda
                    ((group lanes _ _)
                     (and (group-subtitle group)
                          (if (= (length lanes) 1)
                              (string-append
                               (make-string
                                (longest (list (group-label group)
                                               (group-short group)))
                                #\x)
                               "  " (group-subtitle group))
                              (group-subtitle group)))))
                  prepared)))
        (lane-labels (append-map (match-lambda ((_ lanes _ _) lanes))
                                 prepared)))
    `((font_size . ,(null-if-false (score-font-size score)))
      (label_width . ,(em (+ (* 3/5 (longest labels)) 3/2)))
      (lane_width . ,(em (+ (* 13/25 (longest lane-labels)) 1)))
      (cell_width . ,(score-cell-width score))
      (cell_height . ,(score-cell-height score)))))

;;; ------------------------------------------------------------------
;;; Entry point

(define (layout-score piece score)
  "Lay out SCORE, one of PIECE's scores, as a figure: the JSON value of
the contract in doc/design/05-typst-backend.md (version 2).  Its groups
carry their effective settings (ADR 0033)."
  (let* ((k (step-columns piece score))
         (prepared (map (lambda (group)
                          (prepare-group group k (score-from score)
                                         (score-to score)))
                        (score-groups score)))
         (systems (systems prepared score (piece-meter piece) k)))
    `((version . 2)
      (title . ,(score-title score))
      (subtitle . ,(null-if-false (score-subtitle score)))
      (steps_per_pulse . ,k)
      (sizes . ,(sizes prepared score systems))
      (systems . ,systems)
      (caption . ,(null-if-false (score-caption score))))))
