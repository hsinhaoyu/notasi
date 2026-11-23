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

(define (note-events part lanes style names? k)
  "PART's events, one per note (a chord gives several), as
(START DURATION LANE LOOK) lists, in columns of 1/K pulse.  The look's
text is kept only when NAMES? (the group's :note-names)."
  (let ((instrument (part-instrument part)))
    (append-map
     (lambda (event)
       (map (lambda (index)
              (let ((note (vector-ref (instrument-notes instrument) index)))
                (list (* k (event-start event))
                      (* k (event-duration event))
                      (list-index (match-lambda ((_ . n) (eq? n note))) lanes)
                      (let ((look (note-look style instrument note)))
                        (if names?
                            look
                            (make-look (look-fill look) #f
                                       (look-text-color look)))))))
            (event-notes event)))
     (part-events part))))

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
;;; its lanes, and each voice's events in the whole piece, in columns of
;;; 1/K pulse.
(define (prepare-group group k)
  (let ((lanes (lane-owners group))
        (style (group-style group)))
    (list group
          lanes
          (map (lambda (part)
                 (cons (symbol->string (part-name part))
                       (sort (note-events part lanes style
                                          (group-note-names? group) k)
                             event<?)))
               (group-parts group)))))

(define (group-in-system prepared from to)
  (match prepared
    ((group lanes voices)
     `((label . ,(group-label group))
       (subtitle . ,(null-if-false (group-subtitle group)))
       (lanes . ,(list->vector (map lane-label lanes)))
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
       (overlays . #())))))

;;; ------------------------------------------------------------------
;;; The step (04, "The step")

(define (step-columns piece score)
  "K, the number of columns in a pulse: the step is the largest duration
1/K that divides 1 pulse, the piece's length, the system length, and
every start and end of the events the score prints."
  (fold (lambda (time k) (lcm k (denominator time)))
        1
        (append
         (list (piece-length piece) (or (score-system-length score) 1))
         (append-map (lambda (part)
                       (append-map (lambda (e)
                                     (list (event-start e)
                                           (+ (event-start e)
                                              (event-duration e))))
                                   (part-events part)))
                     (append-map group-parts (score-groups score))))))

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
(define (systems length steps prepared score meter k)
  (list->vector
   (map (lambda (start)
          (let ((end (min length (+ start steps))))
            `((start . ,start)
              (steps . ,(- end start))
              (header . ,(header score meter k start end))
              (lines . ,(lines meter k start end))
              (groups . ,(list->vector
                          (map (lambda (g) (group-in-system g start end))
                               prepared))))))
        (if (zero? length) '() (iota (ceiling (/ length steps)) 0 steps)))))

;;; ------------------------------------------------------------------
;;; Sizes

(define (em x)
  "X (exact) as a length in em with one decimal, ties rounded up."
  (let ((tenths (floor (+ (* x 10) 1/2))))
    (string-append (number->string (quotient tenths 10)) "."
                   (number->string (remainder tenths 10)) "em")))

(define (longest strings)
  (fold (lambda (s m) (max m (string-length s))) 0 strings))

(define (sizes prepared score)
  (let ((labels (append-map (match-lambda
                              ((group _ _)
                               (filter string? (list (group-label group)
                                                     (group-subtitle group)))))
                            prepared))
        (lane-labels (append-map (match-lambda
                                   ((_ lanes _) (map lane-label lanes)))
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
         (length (* k (piece-length piece)))
         (prepared (map (lambda (group) (prepare-group group k))
                        (score-groups score))))
    `((version . 2)
      (title . ,(score-title score))
      (subtitle . ,(null-if-false (score-subtitle score)))
      (steps_per_pulse . ,k)
      (sizes . ,(sizes prepared score))
      (systems . ,(systems length
                           (match (score-system-length score)
                             (#f (max length 1))
                             (pulses (* k pulses)))
                           prepared score (piece-meter piece) k))
      (caption . ,(null-if-false (score-caption score))))))
