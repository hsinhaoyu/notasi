;;; (notasi style) -- How notes look: palettes, colour schemes and the
;;; contrast rule for note text.  See "Note style" in
;;; doc/design/04-layout.md and ADR 0017.
;;;
;;; The palettes are ColorBrewer's qualitative palettes, by Cynthia
;;; Brewer (colorbrewer2.org), used under the Apache License 2.0.

(define-module (notasi style)
  #:use-module (notasi piece)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (palette-names
            palette-colors
            text-color-for

            make-look look?
            look-fill look-text look-text-color

            make-style default-style style?
            style-scheme style-palette style-pitch-colors

            by-pitch
            note-look))

(define (style-error what value)
  (raise-exception
   (make-exception (make-error)
                   (make-exception-with-message what)
                   (make-exception-with-irritants (list value)))))

;;; ------------------------------------------------------------------
;;; Palettes (ColorBrewer, qualitative, at their largest size)

(define palettes
  '((dark2   "#1b9e77" "#d95f02" "#7570b3" "#e7298a" "#66a61e" "#e6ab02"
             "#a6761d" "#666666")
    (set1    "#e41a1c" "#377eb8" "#4daf4a" "#984ea3" "#ff7f00" "#ffff33"
             "#a65628" "#f781bf" "#999999")
    (set2    "#66c2a5" "#fc8d62" "#8da0cb" "#e78ac3" "#a6d854" "#ffd92f"
             "#e5c494" "#b3b3b3")
    (set3    "#8dd3c7" "#ffffb3" "#bebada" "#fb8072" "#80b1d3" "#fdb462"
             "#b3de69" "#fccde5" "#d9d9d9" "#bc80bd" "#ccebc5" "#ffed6f")
    (paired  "#a6cee3" "#1f78b4" "#b2df8a" "#33a02c" "#fb9a99" "#e31a1c"
             "#fdbf6f" "#ff7f00" "#cab2d6" "#6a3d9a" "#ffff99" "#b15928")
    (accent  "#7fc97f" "#beaed4" "#fdc086" "#ffff99" "#386cb0" "#f0027f"
             "#bf5b17" "#666666")
    (pastel1 "#fbb4ae" "#b3cde3" "#ccebc5" "#decbe4" "#fed9a6" "#ffffcc"
             "#e5d8bd" "#fddaec" "#f2f2f2")
    (pastel2 "#b3e2cd" "#fdcdac" "#cbd5e8" "#f4cae4" "#e6f5c9" "#fff2ae"
             "#f1e2cc" "#cccccc")))

(define (palette-names)
  "Return the names of the built-in palettes, as symbols."
  (map car palettes))

(define (palette-colors name)
  "Return the colours of the palette called NAME, as hex strings."
  (match (assq name palettes)
    ((_ . colors) colors)
    (#f (style-error "no palette with this name" name))))

;;; ------------------------------------------------------------------
;;; Colours and contrast

(define white "#ffffff")
(define near-black "#222222")
(define stroke-grey "#e6e6e6")         ; strokes have no pitch to colour

(define (color? x)
  (and (string? x)
       (= (string-length x) 7)
       (char=? (string-ref x 0) #\#)
       (string-every char-set:hex-digit x 1)))

(define (normalize-color x)
  (if (color? x)
      (string-downcase x)
      (style-error "a colour must be a string #rrggbb" x)))

(define (relative-luminance hex)
  "WCAG relative luminance of the sRGB colour HEX (#rrggbb)."
  (define (channel start)
    (let ((c (/ (string->number (substring hex start (+ start 2)) 16)
                255.0)))
      (if (<= c 0.04045)
          (/ c 12.92)
          (expt (/ (+ c 0.055) 1.055) 2.4))))
  (+ (* 0.2126 (channel 1))
     (* 0.7152 (channel 3))
     (* 0.0722 (channel 5))))

(define (contrast-ratio a b)
  (let ((la (relative-luminance a))
        (lb (relative-luminance b)))
    (/ (+ (max la lb) 0.05)
       (+ (min la lb) 0.05))))

(define (text-color-for fill)
  "Return the colour of text on FILL: white if it has at least 3:1
contrast with FILL (WCAG's minimum for bold text), else near-black."
  (if (>= (contrast-ratio fill white) 3)
      white
      near-black))

;;; ------------------------------------------------------------------
;;; Looks and styles

(define-record-type <look>
  (make-look fill text text-color)
  look?
  (fill       look-fill)                ; hex string, or #f for no box
  (text       look-text)
  (text-color look-text-color))

(define-record-type <style>
  (%make-style scheme palette pitch-colors)
  style?
  (scheme        style-scheme)          ; procedure (style instrument note)
  (palette       style-palette)         ; list of hex strings
  (pitch-colors style-pitch-colors))  ; alist: pitch name -> hex

(define (resolve-scheme scheme)
  (match scheme
    ('by-pitch by-pitch)
    ((? procedure?) scheme)
    (_ (style-error "unknown colour scheme" scheme))))

(define (resolve-palette palette)
  (match palette
    ((? symbol?) (palette-colors palette))
    (() (style-error "a palette needs at least one colour" palette))
    ((? list?) (map normalize-color palette))
    (_ (style-error "a palette is a name or a list of colours" palette))))

(define (resolve-pitch-colors entries)
  (unless (list? entries)
    (style-error "pitch-colors must be a list of (PITCH . COLOUR)" entries))
  (map (match-lambda
         (((? symbol? pitch) . (? string? color))
          (cons pitch (normalize-color color)))
         (entry
          (style-error "a pitch colour must be (PITCH . \"#rrggbb\")" entry)))
       entries))

(define* (make-style #:key (scheme 'by-pitch) (palette 'pastel1)
                     (pitch-colors '()))
  "Return a style.  SCHEME is `by-pitch' or a procedure (style
instrument note) → look; PALETTE a palette name or a list of colours;
PITCH-COLORS an alist from pitch name to colour.  Raise an &error
naming any bad value."
  (%make-style (resolve-scheme scheme)
               (resolve-palette palette)
               (resolve-pitch-colors pitch-colors)))

(define (default-style)
  "Return the default style: `by-pitch' with the pastel1 palette."
  (make-style))

;;; ------------------------------------------------------------------
;;; Schemes

(define (by-pitch style instrument note)
  "Colour a pitched NOTE by its pitch, the same in every octave
and on every instrument; draw a stroke light grey (ADRs 0019, 0021)."
  (let* ((scale (instrument-scale instrument))
         (text (note-display instrument note)))
    (if (scale-pitched? scale)
        (let* ((index (note-pitch note))
               (name (pitch-name (list-ref (scale-pitches scale) index)))
               (palette (style-palette style))
               (fill (or (assq-ref (style-pitch-colors style) name)
                         (list-ref palette (modulo index (length palette))))))
          (make-look fill text (text-color-for fill)))
        (make-look stroke-grey text (text-color-for stroke-grey)))))

(define (note-look style instrument note)
  "Return the look of NOTE on INSTRUMENT under STYLE."
  ((style-scheme style) style instrument note))
