;;; Unit tests for (notasi style): palettes, the text-colour rule, the
;;; look record, make-style / default-style and the by-pitch scheme.
;;;
;;; Written from doc/design/04-layout.md ("Note style") and ADRs 0003,
;;; 0005 and 0017, not from the implementation.  Error tests check
;;; `error?` and the irritants, never the message text.
;;;
;;; Expected text colours were computed independently with the WCAG
;;; formula given in the doc (contrast of the fill with white):
;;;   dark2: #1b9e77 3.39  #d95f02 3.76  #7570b3 4.44  #e7298a 4.13
;;;          #66a61e 2.98  #e6ab02 2.06  #a6761d 4.01  #666666 5.74
;;;   set1:  #e41a1c 4.71  #377eb8 4.34
;;;   threshold neighbours: #767676 4.54 (white), #777777 4.48 (dark).
;;; The threshold was 3:1 (WCAG's minimum for bold text) until note text
;;; stopped being bold in feat/gallery; it is 4.5:1 since.
;;;
;;; Choices made where the doc is not explicit:
;;; - text-color-for is only given lowercase input: the doc does not say
;;;   whether it accepts uppercase hex.
;;; - The contrast threshold is tested with the nearest grey on each side
;;;   of 4.5:1; no #rrggbb colour gives exactly 4.5:1, so "at least" (>=) is
;;;   not tested at equality.
;;; - A pitch-colors entry naming a stroke still gives fill #f: the doc
;;;   says strokes have no box, unconditionally.
;;; - For a bad pitch-colors entry, the irritants must include either
;;;   the whole entry or its bad part (the key or the colour); the doc
;;;   only says "the bad value".
;;; - Not tested: whether note-look lowercases colours a custom scheme
;;;   returns in uppercase; whether pitch-colors keys may be aliases;
;;;   the type of a non-list, non-symbol palette or pitch-colors.
;;;
;;; Slice feat/collapsed-terms (iteration 5; 04, "Note style", the
;;; Planned paragraph; ADRs 0051, 0056): `by-degree` is renamed
;;; `by-pitch`, the procedure and the scheme name, `#:degree-colors`
;;; `#:pitch-colors` and `style-degree-colors` `style-pitch-colors`.
;;; Choices made where the doc is not explicit:
;;; - The old names are no longer exported, and `#:degree-colors` is no
;;;   longer a keyword of make-style: what it raises is not fixed (Guile
;;;   raises its own keyword error), only that it raises.
;;; - The scheme name `by-degree` is an unknown scheme name like any
;;;   other: an &error with `by-degree` among its irritants.

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 match)
             (notasi piece)
             (notasi reader)
             (notasi style))

;;; ------------------------------------------------------------------
;;; Helpers

(define (raised thunk)
  "The object THUNK raises, or the symbol no-error."
  (guard (c (#t c))
    (thunk)
    'no-error))

(define (irritants-of c)
  (if (and (exception? c) (exception-with-irritants? c))
      (exception-irritants c)
      '()))

(define (error-with-any? thunk . bad-values)
  "Does THUNK raise an &error whose irritants include one of BAD-VALUES?"
  (let ((c (raised thunk)))
    (and (exception? c)
         (error? c)
         (any (lambda (bad) (member bad (irritants-of c))) bad-values)
         #t)))

(define (style-error? bad . args)
  "Does (apply make-style ARGS) raise an &error with BAD as irritant?"
  (error-with-any? (lambda () (apply make-style args)) bad))

(define (look->list look)
  (list (look-fill look) (look-text look) (look-text-color look)))

(define (instrument-named piece name)
  (find (lambda (i) (eq? (instrument-name i) name))
        (piece-instruments piece)))

(define (looks style instrument)
  "The look of every note of INSTRUMENT, as lists, in note order."
  (map (lambda (note) (look->list (note-look style instrument note)))
       (vector->list (instrument-notes instrument))))

(define white "#ffffff")
(define dark "#222222")

;;; ------------------------------------------------------------------
;;; Fixtures

;; A selisir scale where some degrees have a display form and some don't,
;; two instruments on it, a 7-degree and a 9-degree scale, and strokes.
(define pc
  (read-piece-string
   (string-join
    '("(piece \"Style test\")"
      "(scale selisir"
      "  (ding :alias i :display \"i\")"
      "  dong"
      "  (deng :alias e :display \"e\")"
      "  dung"
      "  (dang :alias a :display \"a\"))"
      "(scale seven a b c d e f g)"
      "(scale nine p q r s t u v w x)"
      "(strokes kendang-strokes (dag :display \"D\") dug du)"
      "(strokes gong-strokes G)"
      "(instrument reyong selisir"
      "  deng1 dung1 dang1 ding2 dong2 deng2 dung2 dang2 ding3)"
      "(instrument ugal selisir ding1 dong1 deng1 dung1 dang1 ding2)"
      "(instrument sevens seven a1 b1 c1 d1 e1 f1 g1 a2)"
      "(instrument nines nine p1 q1 r1 s1 t1 u1 v1 w1 x1 p2)"
      "(instrument kendang kendang-strokes dag dug du)"
      "(instrument gong gong-strokes G)")
    "\n")))

(define reyong  (instrument-named pc 'reyong))
(define ugal    (instrument-named pc 'ugal))
(define sevens  (instrument-named pc 'sevens))
(define nines   (instrument-named pc 'nines))
(define kendang (instrument-named pc 'kendang))
(define gong    (instrument-named pc 'gong))

(define dark2
  '("#1b9e77" "#d95f02" "#7570b3" "#e7298a"
    "#66a61e" "#e6ab02" "#a6761d" "#666666"))

(define pastel1
  '("#fbb4ae" "#b3cde3" "#ccebc5" "#decbe4" "#fed9a6" "#ffffcc"
    "#e5d8bd" "#fddaec" "#f2f2f2"))

;; Default-style look of each selisir degree: colour k of pastel1 (the
;; default palette, ADR 0021) for degree k, text = display form or
;; degree name, text colour by contrast (dark on every pastel).
(define ding-look (list "#fbb4ae" "i"    dark))
(define dong-look (list "#b3cde3" "dong" dark))
(define deng-look (list "#ccebc5" "e"    dark))
(define dung-look (list "#decbe4" "dung" dark))
(define dang-look (list "#fed9a6" "a"    dark))

(test-begin "style")

;;; ------------------------------------------------------------------
;;; Palettes

(test-group "palettes"
  (test-equal "palette-names, in table order"
    '(dark2 set1 set2 set3 paired accent pastel1 pastel2)
    (palette-names))
  (test-equal "dark2" dark2 (palette-colors 'dark2))
  (test-equal "set1"
    '("#e41a1c" "#377eb8" "#4daf4a" "#984ea3" "#ff7f00"
      "#ffff33" "#a65628" "#f781bf" "#999999")
    (palette-colors 'set1))
  (test-equal "set2"
    '("#66c2a5" "#fc8d62" "#8da0cb" "#e78ac3"
      "#a6d854" "#ffd92f" "#e5c494" "#b3b3b3")
    (palette-colors 'set2))
  (test-equal "set3"
    '("#8dd3c7" "#ffffb3" "#bebada" "#fb8072" "#80b1d3" "#fdb462"
      "#b3de69" "#fccde5" "#d9d9d9" "#bc80bd" "#ccebc5" "#ffed6f")
    (palette-colors 'set3))
  (test-equal "paired"
    '("#a6cee3" "#1f78b4" "#b2df8a" "#33a02c" "#fb9a99" "#e31a1c"
      "#fdbf6f" "#ff7f00" "#cab2d6" "#6a3d9a" "#ffff99" "#b15928")
    (palette-colors 'paired))
  (test-equal "accent"
    '("#7fc97f" "#beaed4" "#fdc086" "#ffff99"
      "#386cb0" "#f0027f" "#bf5b17" "#666666")
    (palette-colors 'accent))
  (test-equal "pastel1"
    '("#fbb4ae" "#b3cde3" "#ccebc5" "#decbe4" "#fed9a6"
      "#ffffcc" "#e5d8bd" "#fddaec" "#f2f2f2")
    (palette-colors 'pastel1))
  (test-equal "pastel2"
    '("#b3e2cd" "#fdcdac" "#cbd5e8" "#f4cae4"
      "#e6f5c9" "#fff2ae" "#f1e2cc" "#cccccc")
    (palette-colors 'pastel2))
  (test-assert "every listed name has a palette"
    (every (lambda (name) (pair? (palette-colors name))) (palette-names)))
  (test-assert "unknown palette name is an &error naming it"
    (error-with-any? (lambda () (palette-colors 'no-such-palette))
                     'no-such-palette)))

;;; ------------------------------------------------------------------
;;; text-color-for

(test-group "text-color-for"
  ;; dark2: all take dark except grey #666666.
  (test-equal "dark2 teal #1b9e77"   dark  (text-color-for "#1b9e77"))
  (test-equal "dark2 orange #d95f02" dark  (text-color-for "#d95f02"))
  (test-equal "dark2 purple #7570b3" dark  (text-color-for "#7570b3"))
  (test-equal "dark2 pink #e7298a"   dark  (text-color-for "#e7298a"))
  (test-equal "dark2 green #66a61e"  dark  (text-color-for "#66a61e"))
  (test-equal "dark2 yellow #e6ab02" dark  (text-color-for "#e6ab02"))
  (test-equal "dark2 brown #a6761d"  dark  (text-color-for "#a6761d"))
  (test-equal "dark2 grey #666666"   white (text-color-for "#666666"))
  (test-equal "dark2: dark except grey"
    (list dark dark dark dark dark dark dark white)
    (map text-color-for dark2))

  (test-equal "white fill" dark  (text-color-for "#ffffff"))
  (test-equal "black fill" white (text-color-for "#000000"))

  (test-equal "pastel1 #fbb4ae" dark (text-color-for "#fbb4ae"))
  (test-equal "pastel1 #ffffcc" dark (text-color-for "#ffffcc"))
  (test-equal "pastel2 #b3e2cd" dark (text-color-for "#b3e2cd"))
  (test-equal "pastel2 #cccccc" dark (text-color-for "#cccccc"))
  (test-equal "set3 #8dd3c7"    dark (text-color-for "#8dd3c7"))

  (test-equal "set1 red #e41a1c"    white (text-color-for "#e41a1c"))
  (test-equal "set1 blue #377eb8 (4.34:1)" dark (text-color-for "#377eb8"))
  (test-equal "set1 green #4daf4a (2.78:1)" dark (text-color-for "#4daf4a"))
  (test-equal "set1 orange #ff7f00 (2.53:1)" dark (text-color-for "#ff7f00"))

  ;; Threshold: #767676 is 4.54:1 with white, #777777 is 4.48:1.
  (test-equal "just above 4.5:1 takes white" white (text-color-for "#767676"))
  (test-equal "just below 4.5:1 takes dark"  dark  (text-color-for "#777777")))

;;; ------------------------------------------------------------------
;;; The look record

(test-group "look record"
  (let ((lk (make-look "#123456" "i" "#ffffff")))
    (test-assert "look? on a look" (look? lk))
    (test-equal "look-fill" "#123456" (look-fill lk))
    (test-equal "look-text" "i" (look-text lk))
    (test-equal "look-text-color" "#ffffff" (look-text-color lk)))
  (let ((lk (make-look #f "D" "#222222")))
    (test-assert "a look with no box" (look? lk))
    (test-equal "fill #f" #f (look-fill lk)))
  (test-assert "look? on a string" (not (look? "#123456")))
  (test-assert "look? on a list" (not (look? '("#123456" "i" "#ffffff")))))

;;; ------------------------------------------------------------------
;;; make-style and default-style

(test-group "make-style defaults"
  (for-each
   (match-lambda
     ((label style)
      (test-assert (string-append label ": style?") (style? style))
      (test-assert (string-append label ": scheme is by-pitch")
        (eq? by-pitch (style-scheme style)))
      (test-equal (string-append label ": palette is pastel1") pastel1
        (style-palette style))
      (test-equal (string-append label ": no pitch-colors") '()
        (style-pitch-colors style))))
   (list (list "default-style" (default-style))
         (list "make-style" (make-style))))
  (test-assert "by-pitch is a procedure" (procedure? by-pitch))
  (test-assert "style? on a non-style" (not (style? 'by-pitch))))

(test-group "make-style options"
  (test-assert "scheme name by-pitch resolves to the procedure"
    (eq? by-pitch (style-scheme (make-style #:scheme 'by-pitch))))
  (test-equal "palette by name"
    (palette-colors 'set2)
    (style-palette (make-style #:palette 'set2)))
  (test-equal "palette by name: pastel1"
    (palette-colors 'pastel1)
    (style-palette (make-style #:palette 'pastel1)))
  (test-equal "palette as a list"
    '("#111111" "#eeeeee")
    (style-palette (make-style #:palette '("#111111" "#eeeeee"))))
  (test-equal "palette list colours are lowercased"
    '("#abcdef" "#1b9e77" "#abcdef")
    (style-palette (make-style #:palette '("#ABCDEF" "#1B9E77" "#AbCdEf"))))
  (test-equal "a one-colour palette"
    '("#000000")
    (style-palette (make-style #:palette '("#000000"))))
  (test-equal "pitch-colors are stored"
    '((ding . "#000000") (dang . "#ff0000"))
    (style-pitch-colors
     (make-style #:pitch-colors '((ding . "#000000") (dang . "#ff0000")))))
  (test-equal "pitch-colors values are lowercased"
    '((ding . "#abcdef"))
    (style-pitch-colors (make-style #:pitch-colors '((ding . "#ABCDEF")))))
  (test-assert "a degree name no scale has is allowed"
    (style? (make-style #:pitch-colors '((zzz . "#000000")))))
  (let* ((proc (lambda (style instrument note)
                 (make-look "#123456" "x" "#ffffff")))
         (style (make-style #:scheme proc)))
    (test-assert "a scheme procedure is stored"
      (eq? proc (style-scheme style)))))

(test-group "make-style errors"
  ;; Unknown scheme names: anything that is neither by-pitch nor a procedure.
  (test-assert "unknown scheme symbol" (style-error? 'by-part #:scheme 'by-part))
  (test-assert "scheme as a string" (style-error? "by-pitch" #:scheme "by-pitch"))
  (test-assert "scheme as a number" (style-error? 42 #:scheme 42))
  ;; Palettes.
  (test-assert "unknown palette name" (style-error? 'nope #:palette 'nope))
  (test-assert "empty colour list" (style-error? '() #:palette '()))
  ;; Colours in a palette list that are not #rrggbb strings.
  (for-each
   (lambda (bad)
     (test-assert (call-with-output-string
                    (lambda (port)
                      (display "bad palette colour " port)
                      (write bad port)))
       (style-error? bad #:palette (list "#1b9e77" bad))))
   '("red" "1b9e77" "#12345" "#1234567" "#gggggg" "#1b9e7" red 1193046))
  ;; Colours in pitch-colors that are not #rrggbb strings.
  (for-each
   (lambda (bad)
     (let ((entry (cons 'ding bad)))
       (test-assert (call-with-output-string
                      (lambda (port)
                        (display "bad degree colour " port)
                        (write bad port)))
         (error-with-any? (lambda () (make-style #:pitch-colors (list entry)))
                          bad entry))))
   '("black" "000000" "#00000" "#0000000" "#00000g" black))
  ;; pitch-colors entries that are not (SYMBOL . COLOUR).
  (let ((entry '("ding" . "#000000")))
    (test-assert "pitch-colors key is a string"
      (error-with-any? (lambda () (make-style #:pitch-colors (list entry)))
                       entry "ding")))
  (let ((entry '(ding "#000000")))
    (test-assert "pitch-colors entry is a list, not a pair"
      (error-with-any? (lambda () (make-style #:pitch-colors (list entry)))
                       entry '("#000000"))))
  (test-assert "pitch-colors entry is a bare symbol"
    (error-with-any? (lambda () (make-style #:pitch-colors '(ding)))
                     'ding))
  (let ((entry '(3 . "#000000")))
    (test-assert "pitch-colors key is a number"
      (error-with-any? (lambda () (make-style #:pitch-colors (list entry)))
                       entry 3)))
  (test-assert "a bad entry after a good one"
    (error-with-any? (lambda ()
                       (make-style #:pitch-colors
                                   '((ding . "#000000") (dong . "nope"))))
                     "nope" '(dong . "nope"))))

;;; ------------------------------------------------------------------
;;; by-pitch, through note-look

(test-group "by-pitch: pitched notes"
  (let ((style (default-style)))
    ;; reyong: deng1 dung1 dang1 ding2 dong2 deng2 dung2 dang2 ding3
    (test-equal "reyong, every octave"
      (list deng-look dung-look dang-look ding-look dong-look
            deng-look dung-look dang-look ding-look)
      (looks style reyong))
    ;; ugal: ding1 dong1 deng1 dung1 dang1 ding2
    (test-equal "ugal, same colours as reyong"
      (list ding-look dong-look deng-look dung-look dang-look ding-look)
      (looks style ugal))
    (test-assert "note-look returns a look"
      (look? (note-look style ugal (vector-ref (instrument-notes ugal) 0))))
    (test-equal "by-pitch called directly gives the same look"
      (looks style ugal)
      (map (lambda (note) (look->list (by-pitch style ugal note)))
           (vector->list (instrument-notes ugal)))))

  (test-equal "custom palette by name: set1"
    (list (list "#e41a1c" "i"    white)
          (list "#377eb8" "dong" dark)
          (list "#4daf4a" "e"    dark)
          (list "#984ea3" "dung" white)
          (list "#ff7f00" "a"    dark)
          (list "#e41a1c" "i"    white))
    (looks (make-style #:palette 'set1) ugal))

  (test-equal "uppercase palette colours come out lowercase in looks"
    (list (list "#abcdef" "i" dark) (list "#000000" "dong" white))
    (take (looks (make-style #:palette '("#ABCDEF" "#000000")) ugal) 2))

  ;; seven-degree scale a..g, instrument a1 b1 c1 d1 e1 f1 g1 a2, and a
  ;; three-colour palette: colours repeat every three degrees.
  (test-equal "palette repeats with more degrees than colours"
    (list (list "#111111" "a" white)
          (list "#eeeeee" "b" dark)
          (list "#ff0000" "c" dark)
          (list "#111111" "d" white)
          (list "#eeeeee" "e" dark)
          (list "#ff0000" "f" dark)
          (list "#111111" "g" white)
          (list "#111111" "a" white))
    (looks (make-style #:palette '("#111111" "#eeeeee" "#ff0000")) sevens))

  ;; nine degrees with dark2 (eight colours): degree 8 wraps to colour 0.
  (test-equal "dark2 wraps after eight degrees"
    (append (map (lambda (colour name)
                   (list colour name (text-color-for colour)))
                 dark2 '("p" "q" "r" "s" "t" "u" "v" "w"))
            (list (list "#1b9e77" "x" dark)
                  (list "#1b9e77" "p" dark)))
    (looks (make-style #:palette 'dark2) nines))
  (test-equal "pastel1 has nine colours: nine degrees, no wrap"
    (map (lambda (colour name) (list colour name dark))
         pastel1 '("p" "q" "r" "s" "t" "u" "v" "w" "x"))
    (take (looks (default-style) nines) 9))

  (test-equal "one-colour palette colours every degree"
    (map (lambda (text) (list "#000000" text white))
         '("i" "dong" "e" "dung" "a" "i"))
    (looks (make-style #:palette '("#000000")) ugal)))

(test-group "by-pitch: pitch-colors"
  (let ((style (make-style #:pitch-colors
                           '((deng . "#000000") (dang . "#FFFFFF")))))
    (test-equal "overrides take the fill; text colour from their contrast"
      (list ding-look dong-look
            (list "#000000" "e" white)
            dung-look
            (list "#ffffff" "a" dark)
            ding-look)
      (looks style ugal))
    (test-equal "overrides apply in every octave and on every instrument"
      (list (list "#000000" "e" white) dung-look (list "#ffffff" "a" dark)
            ding-look dong-look
            (list "#000000" "e" white) dung-look (list "#ffffff" "a" dark)
            ding-look)
      (looks style reyong)))
  (test-equal "override on top of a custom palette"
    (list (list "#111111" "a" white)
          (list "#e6ab02" "b" dark)
          (list "#ff0000" "c" dark))
    (take (looks (make-style #:palette '("#111111" "#eeeeee" "#ff0000")
                             #:pitch-colors '((b . "#e6ab02")))
                 sevens)
          3))
  (test-equal "an override for a degree no scale has changes nothing"
    (looks (default-style) ugal)
    (looks (make-style #:pitch-colors '((zzz . "#000000"))) ugal))
  ;; Keys are degree names only: an alias is ignored like any unused name.
  (test-equal "an override keyed by an alias changes nothing"
    (looks (default-style) ugal)
    (looks (make-style #:pitch-colors '((i . "#000000"))) ugal)))

(test-group "make-style: wrong types"
  (test-assert "a palette that is neither a name nor a list"
    (style-error? 42 #:palette 42))
  (test-assert "a palette that is a string"
    (style-error? "dark2" #:palette "dark2"))
  (test-assert "pitch-colors that is not a list"
    (style-error? 'x #:pitch-colors 'x)))

;;; Strokes are light grey boxes (ADRs 0019 and 0021).
(test-group "by-pitch: strokes"
  (let ((stroke-looks (list (list "#e6e6e6" "D" dark)
                            (list "#e6e6e6" "dug" dark)
                            (list "#e6e6e6" "du" dark))))
    (test-equal "kendang: grey box, display form or name, near-black"
      stroke-looks (looks (default-style) kendang))
    (test-equal "gong" (list (list "#e6e6e6" "G" dark)) (looks (default-style) gong))
    (test-equal "palette does not affect strokes"
      stroke-looks (looks (make-style #:palette 'set1) kendang))
    (test-equal "pitch-colors naming a stroke leave it grey"
      stroke-looks
      (looks (make-style #:pitch-colors '((dag . "#000000") (du . "#ffffff")))
             kendang))))

;;; Slice feat/drawing-lines (04, "Note style" and "Slices (iteration
;;; 3)" slice 2's decided bullet; ADR 0041): strokes are a lighter grey,
;;; `#e6e6e6`, so the grey note border shows against it, with near-black
;;; text. The old "#cccccc" tests above break with this slice.
(test-group "by-pitch: strokes in the lighter grey"
  (let ((stroke-looks (list (list "#e6e6e6" "D" dark)
                            (list "#e6e6e6" "dug" dark)
                            (list "#e6e6e6" "du" dark))))
    (test-equal "kendang: #e6e6e6, display form or name, near-black"
      stroke-looks (looks (default-style) kendang))
    (test-equal "gong" (list (list "#e6e6e6" "G" dark)) (looks (default-style) gong))
    (test-equal "palette does not affect strokes"
      stroke-looks (looks (make-style #:palette 'dark2) kendang))
    (test-equal "pitch-colors naming a stroke leave it #e6e6e6"
      stroke-looks
      (looks (make-style #:pitch-colors '((dag . "#000000") (du . "#ffffff")))
             kendang)))
  (test-equal "#e6e6e6 takes near-black text" dark (text-color-for "#e6e6e6"))
  (test-assert "#e6e6e6 is no palette's colour"
    (not (any (lambda (name) (member "#e6e6e6" (palette-colors name)))
              (palette-names)))))

;;; ------------------------------------------------------------------
;;; Custom schemes

(test-group "custom scheme"
  (let* ((calls '())
         (proc (lambda (style instrument note)
                 (set! calls (cons (list style instrument note) calls))
                 (make-look "#123456" "x" "#ffffff")))
         (style (make-style #:scheme proc))
         (note (vector-ref (instrument-notes ugal) 2))
         (lk (note-look style ugal note)))
    (test-equal "note-look returns the scheme's look"
      (list "#123456" "x" "#ffffff") (look->list lk))
    (test-equal "the scheme is called once" 1 (length calls))
    (test-assert "the scheme gets the style, instrument and note"
      (match calls
        (((s i n)) (and (eq? s style) (eq? i ugal) (eq? n note)))
        (_ #f))))

  ;; A scheme that boxes strokes in grey and falls back on by-pitch.
  (let* ((grey-strokes
          (lambda (style instrument note)
            (if (scale-pitched? (instrument-scale instrument))
                (by-pitch style instrument note)
                (make-look "#666666"
                           (look-text (by-pitch style instrument note))
                           (text-color-for "#666666")))))
         (style (make-style #:scheme grey-strokes #:palette 'set1)))
    (test-equal "fallback: pitched notes as by-pitch"
      (looks (make-style #:palette 'set1) ugal)
      (looks style ugal))
    (test-equal "fallback: strokes from the custom branch"
      (list (list "#666666" "D" white)
            (list "#666666" "dug" white)
            (list "#666666" "du" white))
      (looks style kendang))))

;;; ------------------------------------------------------------------
;;; Slice feat/collapsed-terms: by-pitch and pitch-colors

(define (exported-by-style? name)
  "Does (notasi style) export NAME?"
  (and (module-variable (resolve-interface '(notasi style)) name) #t))

(define (raises? thunk)
  "Does THUNK raise anything?"
  (guard (c (#t #t))
    (thunk)
    #f))

(test-group "[collapsed-terms] by-pitch"
  (test-assert "by-pitch is a procedure" (procedure? by-pitch))
  (test-assert "default-style: the scheme is by-pitch"
    (eq? by-pitch (style-scheme (default-style))))
  (test-assert "make-style: the scheme is by-pitch"
    (eq? by-pitch (style-scheme (make-style))))
  (test-assert "scheme name by-pitch resolves to the procedure"
    (eq? by-pitch (style-scheme (make-style #:scheme 'by-pitch))))
  (test-assert "scheme name by-degree is an unknown name"
    (style-error? 'by-degree #:scheme 'by-degree))
  (test-assert "scheme name by-pitch as a string is not a name"
    (style-error? "by-pitch" #:scheme "by-pitch"))
  (test-equal "by-pitch: each pitch its palette colour, in every octave"
    (list ding-look dong-look deng-look dung-look dang-look ding-look)
    (looks (make-style #:scheme 'by-pitch) ugal))
  (test-equal "by-pitch called directly gives note-look's look"
    (looks (default-style) ugal)
    (map (lambda (note) (look->list (by-pitch (default-style) ugal note)))
         (vector->list (instrument-notes ugal))))
  (test-equal "by-pitch: strokes are grey boxes"
    (looks (default-style) kendang)
    (map (lambda (note) (look->list (by-pitch (default-style) kendang note)))
         (vector->list (instrument-notes kendang)))))

(test-group "[collapsed-terms] pitch-colors"
  (test-equal "default: no pitch-colors" '()
    (style-pitch-colors (default-style)))
  (test-equal "pitch-colors are stored"
    '((ding . "#000000") (dang . "#ff0000"))
    (style-pitch-colors
     (make-style #:pitch-colors '((ding . "#000000") (dang . "#ff0000")))))
  (test-equal "pitch-colors values are lowercased"
    '((ding . "#abcdef"))
    (style-pitch-colors (make-style #:pitch-colors '((ding . "#ABCDEF")))))
  (test-equal "overrides take the fill; text colour from their contrast"
    (list ding-look dong-look
          (list "#000000" "e" white)
          dung-look
          (list "#ffffff" "a" dark)
          ding-look)
    (looks (make-style #:pitch-colors '((deng . "#000000") (dang . "#FFFFFF")))
           ugal))
  (test-equal "an override keyed by an alias changes nothing"
    (looks (default-style) ugal)
    (looks (make-style #:pitch-colors '((i . "#000000"))) ugal))
  (test-assert "a pitch-colors colour that is not #rrggbb"
    (error-with-any? (lambda () (make-style #:pitch-colors '((ding . "black"))))
                     '(ding . "black") "black"))
  (test-assert "pitch-colors that is not a list"
    (style-error? 'x #:pitch-colors 'x))
  (test-assert "#:degree-colors is no longer taken"
    (raises? (lambda () (make-style #:degree-colors '((ding . "#000000")))))))

(test-group "[collapsed-terms] the old names are gone"
  (for-each
   (lambda (name)
     (test-assert (format #f "~a is not exported" name)
       (not (exported-by-style? name))))
   '(by-degree style-degree-colors))
  (for-each
   (lambda (name)
     (test-assert (format #f "~a is exported" name)
       (exported-by-style? name)))
   '(by-pitch style-pitch-colors)))

(define runner (test-runner-current))
(test-end "style")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
