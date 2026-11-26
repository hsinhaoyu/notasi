;;; Template tests: typst/notasi.typ draws every golden figure.
;;; See doc/design/05-typst-backend.md, "Typst template design"
;;; ("Tests (slice 1)") and "Version pinning".
;;; - Each tests/golden/NAME.json is compiled with `score`, from an
;;;   entry file written in a fresh temporary folder next to copies of
;;;   the template and the JSON.  `typst compile` must succeed, write a
;;;   non-empty PDF, and print no warning.
;;; - A few small figures written here by hand cover cases the golden
;;;   files may not: no systems at all (empty content), and a system
;;;   that doesn't start on a pulse.
;;; - If `typst` isn't installed, one test says so and fails (CI always
;;;   installs it, 0.15.1); no compile is tried.
;;;
;;; - Slice feat/scores-contract: the hand-written figures are contract
;;;   version 2 (05, "JSON contract (version 2)"; key order from 04):
;;;   `subtitle`, `font_size`, `cell_width`, `cell_height`, each
;;;   system's `header` and `lines`, each group's `overlays` (empty).  A
;;;   third one has both header rows, a pulse label, cycle and pulse
;;;   lines, a figure subtitle and caption, a font size, and a second
;;;   system with no cycle mark; a fourth has both header rows off.
;;;
;;; - Slice feat/scores-rows: a fifth hand-written figure has a group
;;;   on `parts` rows (row labels as `lanes`), a group on a `single` row
;;;   (`lanes` [""]), a chord as one event with joined names, events
;;;   with `fill` null (`:fill none`) and the one-column "-" events of
;;;   `:holds dash`, one of them at the start of a second system.
;;;
;;; - Slice feat/scores-overlays: a sixth hand-written figure has
;;;   overlays (05, "JSON contract (version 2)" and the template's
;;;   "Overlays" bullet): over every lane of a `notes` group, on a
;;;   `parts` group and on a `single` row, a long name over fewer
;;;   columns than it needs, one starting mid-system, one cut by the
;;;   system break and continued in the second system (its text
;;;   written again), and a group with no overlays beside them.  The
;;;   test only checks that it compiles without a warning; how it looks
;;;   is checked by eye.
;;;
;;; - Slice feat/drawing-header (iteration 3; 05, "JSON contract
;;;   (version 3)" and the template's Planned version 3 bullets; ADRs
;;;   0039, 0043, 0044): three hand-written version 3 figures, with
;;;   `header.cycle_label` and `header.pulse_label` in place of `label`
;;;   (strings or null), the pickup's cycle mark "0", and quarter pulses
;;;   (steps_per_pulse 4), so a pulse number spans 4 columns and a
;;;   cycle number the first pulse of its cycle.  Only compiling without
;;;   a warning is tested; the centring and the missing `·` are checked
;;;   by eye (make images).  Their groups keep version 2's keys: the
;;;   other version 3 fields are later slices.

;;; Run from the repo root: guile -L . tests/template.scm

(use-modules (srfi srfi-1)
             (srfi srfi-9)
             (srfi srfi-64)
             (ice-9 ftw)
             (ice-9 textual-ports))

(define template-path "typst/notasi.typ")
(define golden-dir "tests/golden")

(define (read-text path)
  (call-with-input-file path get-string-all #:encoding "UTF-8"))

(define (write-text path text)
  (call-with-output-file path (lambda (port) (put-string port text))
    #:encoding "UTF-8"))

(define (golden-names)
  "The names of the golden figures, without \".json\", sorted."
  (map (lambda (f) (string-drop-right f 5))
       (or (scandir golden-dir (lambda (f) (string-suffix? ".json" f)))
           '())))

(define (typst-installed?)
  (zero? (status:exit-val
          (system* "sh" "-c" "command -v typst >/dev/null 2>&1"))))

(define (entry-text json-name)
  "The entry file that draws the figure in JSON-NAME with `score`."
  (string-append
   "#import \"notasi.typ\": score\n"
   "#set page(width: auto, height: auto, margin: 14pt)\n"
   "#score(json(\"" json-name "\"))\n"))

(define (remove-folder dir)
  "Delete DIR and the files in it (it has no subfolders)."
  (for-each (lambda (f) (delete-file (string-append dir "/" f)))
            (scandir dir (lambda (f) (not (member f '("." ".."))))))
  (rmdir dir))

(define-record-type <outcome>
  (make-outcome status pdf-size output)
  outcome?
  (status outcome-status)        ; typst's exit status
  (pdf-size outcome-pdf-size)    ; size of out.pdf in bytes, 0 if none
  (output outcome-output))       ; what typst printed (stdout + stderr)

(define (compile-figure json-name json-text)
  "Compile JSON-TEXT, saved as JSON-NAME, with the template in a fresh
temporary folder, and return the outcome.  A missing template is not
copied, so typst itself reports it."
  (let ((dir (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp")
                                     "/notasi-template-XXXXXX"))))
    (dynamic-wind
      (const #f)
      (lambda ()
        (when (file-exists? template-path)
          (copy-file template-path (string-append dir "/notasi.typ")))
        (write-text (string-append dir "/" json-name) json-text)
        (write-text (string-append dir "/entry.typ") (entry-text json-name))
        (let* ((status (status:exit-val
                        (system* "sh" "-c"
                                 "cd \"$1\" && typst compile entry.typ out.pdf >log.txt 2>&1"
                                 "sh" dir)))
               (pdf (string-append dir "/out.pdf"))
               (log (string-append dir "/log.txt")))
          (make-outcome status
                        (if (file-exists? pdf) (stat:size (stat pdf)) 0)
                        (if (file-exists? log) (read-text log) ""))))
      (lambda () (remove-folder dir)))))

(define (warning-lines output)
  "The lines of OUTPUT where typst reports a warning."
  (filter (lambda (line) (string-prefix? "warning" line))
          (string-split output #\newline)))

(define (check-figure label json-name json-text)
  "Two tests for one figure: it compiles to a non-empty PDF, and typst
prints no warning.  Typst's output is shown when either fails."
  (let ((outcome (compile-figure json-name json-text)))
    (unless (and (eqv? 0 (outcome-status outcome))
                 (positive? (outcome-pdf-size outcome))
                 (null? (warning-lines (outcome-output outcome))))
      (format (current-error-port) "typst output for ~a:~%~a~%"
              label (outcome-output outcome)))
    (test-assert (string-append label ": typst compile succeeds")
      (eqv? 0 (outcome-status outcome)))
    (test-assert (string-append label ": out.pdf is not empty")
      (positive? (outcome-pdf-size outcome)))
    (test-equal (string-append label ": typst prints no warning")
      '()
      (warning-lines (outcome-output outcome)))))

;;; Hand-written figures, following 05's contract (key order from 04,
;;; "Public interface").

(define no-systems
  "{
  \"version\": 4,
  \"title\": \"Nothing\",
  \"subtitle\": null,
  \"steps_per_pulse\": 4,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"5em\",
    \"row_label_width\": \"2.0em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [],
  \"caption\": null
}
")

;; A system starting mid-pulse (start 2, steps_per_pulse 4), with a
;; continued note, a note drawn as text only, a null subtitle, and a
;; group with no events.  No colotomy: no cycle row, pulse lines only.
(define off-pulse
  "{
  \"version\": 4,
  \"title\": \"Off pulse\",
  \"subtitle\": null,
  \"steps_per_pulse\": 4,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"6em\",
    \"row_label_width\": \"2.5em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 2,
      \"steps\": 6,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": null,
        \"cycles\": null,
        \"pulses\": [null, null, \"2\", null, null, null]
      },
      \"lines\": [\"none\", \"none\", \"pulse\", \"none\", \"none\", \"none\"],
      \"groups\": [
        {
          \"label\": \"Reyong\",
          \"subtitle\": null,
          \"rows\": [\"nong1\", \"nang1\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"row\": 1,
                  \"text\": \"nang\",
                  \"fill\": \"#1b9e77\",
                  \"text_color\": \"#ffffff\",
                  \"continued\": true
                },
                {
                  \"start\": 3,
                  \"dur\": 1,
                  \"row\": 0,
                  \"text\": \"x\",
                  \"fill\": null,
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": []
        },
        {
          \"label\": \"Kendang\",
          \"subtitle\": \"wadon\",
          \"rows\": [\"dag\"],
          \"voices\": [
            {
              \"name\": \"wadon\",
              \"events\": []
            }
          ],
          \"overlays\": []
        }
      ]
    }
  ],
  \"caption\": null
}
")

;; A 4-pulse cycle with a pickup of 1, half pulses, in two systems of 3
;; pulses: both header rows, a pulse label, cycle and pulse lines, a
;; figure subtitle, caption and font size; the second system has a
;; cycle mark at column 2, numbered gong-first.
(define header-rows
  "{
  \"version\": 4,
  \"title\": \"Header rows\",
  \"subtitle\": \"pangecet\",
  \"steps_per_pulse\": 2,
  \"sizes\": {
    \"font_size\": \"10pt\",
    \"label_width\": \"5em\",
    \"row_label_width\": \"2.0em\",
    \"cell_width\": \"1.5em\",
    \"cell_height\": \"2.5em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 6,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": \"Beats\",
        \"cycles\": [{ \"column\": 2, \"text\": \"1\" }],
        \"pulses\": [\"1\", null, \"2\", null, \"3\", null]
      },
      \"lines\": [\"none\", \"none\", \"cycle\", \"none\", \"pulse\", \"none\"],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [\"i2\", \"a1\"],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#fed9a6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 2,
                  \"dur\": 4,
                  \"row\": 0,
                  \"text\": \"i\",
                  \"fill\": \"#fbb4ae\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    },
    {
      \"start\": 6,
      \"steps\": 6,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": \"Beats\",
        \"cycles\": [{ \"column\": 4, \"text\": \"2\" }],
        \"pulses\": [\"4\", null, \"1\", null, \"2\", null]
      },
      \"lines\": [\"none\", \"none\", \"pulse\", \"none\", \"cycle\", \"none\"],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [\"i2\", \"a1\"],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"row\": 0,
                  \"text\": null,
                  \"fill\": \"#fbb4ae\",
                  \"text_color\": \"#222222\",
                  \"continued\": true
                }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    },
    {
      \"start\": 12,
      \"steps\": 2,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": \"Beats\",
        \"cycles\": [],
        \"pulses\": [\"3\", null]
      },
      \"lines\": [\"none\", \"none\"],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [\"i2\", \"a1\"],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": []
            }
          ],
          \"overlays\": []
        }
      ]
    }
  ],
  \"caption\": \"From Tenzer\"
}
")

;; Both header rows off (:cycle-numbers no, :pulse-numbers no), with a
;; pulse label and a cycle line.
(define no-header-rows
  "{
  \"version\": 4,
  \"title\": \"\",
  \"subtitle\": null,
  \"steps_per_pulse\": 1,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"3em\",
    \"row_label_width\": \"1.5em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 4,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": \"Beats\",
        \"cycles\": null,
        \"pulses\": null
      },
      \"lines\": [\"none\", \"pulse\", \"cycle\", \"pulse\"],
      \"groups\": [
        {
          \"label\": \"Gong\",
          \"subtitle\": null,
          \"rows\": [\"G\"],
          \"voices\": [
            {
              \"name\": \"gong\",
              \"events\": [
                {
                  \"start\": 1,
                  \"dur\": 1,
                  \"row\": 0,
                  \"text\": \"G\",
                  \"fill\": \"#cccccc\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    }
  ],
  \"caption\": null
}
")

;; Rows of slice feat/scores-rows, in two systems: a group on parts rows
;; (a chord as one event, a dash, fill null for the dash only) and a
;; sung line on a single row with fill null throughout and dashes, one
;; of them starting the second system; a held note cut into it.
(define rows
  "{
  \"version\": 4,
  \"title\": \"Rows\",
  \"subtitle\": null,
  \"steps_per_pulse\": 1,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"6.3em\",
    \"row_label_width\": \"4.6em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 4,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": null,
        \"cycles\": null,
        \"pulses\": [\"1\", \"2\", \"3\", \"4\"]
      },
      \"lines\": [\"none\", \"pulse\", \"pulse\", \"pulse\"],
      \"groups\": [
        {
          \"label\": \"Kotekan\",
          \"subtitle\": null,
          \"rows\": [\"polos\", \"sangsih\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"row\": 0, \"text\": \"i\",
                  \"fill\": \"#fbb4ae\", \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 1, \"dur\": 1, \"row\": 0, \"text\": \"-\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 2, \"dur\": 1, \"row\": 0, \"text\": \"o'\",
                  \"fill\": \"#b3cde3\", \"text_color\": \"#222222\", \"continued\": false }
              ]
            },
            {
              \"name\": \"sangsih\",
              \"events\": [
                { \"start\": 1, \"dur\": 1, \"row\": 1, \"text\": \"i' o'\",
                  \"fill\": \"#fbb4ae\", \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 3, \"dur\": 1, \"row\": 1, \"text\": \"nang\",
                  \"fill\": \"#fed9a6\", \"text_color\": \"#222222\", \"continued\": false }
              ]
            }
          ],
          \"overlays\": []
        },
        {
          \"label\": \"Sung\",
          \"subtitle\": null,
          \"rows\": [\"\"],
          \"voices\": [
            {
              \"name\": \"vocal\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"row\": 0, \"text\": \"nang\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 1, \"dur\": 1, \"row\": 0, \"text\": \"-\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 2, \"dur\": 1, \"row\": 0, \"text\": \"-\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 3, \"dur\": 1, \"row\": 0, \"text\": \"ni'\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    },
    {
      \"start\": 4,
      \"steps\": 2,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": null,
        \"cycles\": null,
        \"pulses\": [\"5\", \"6\"]
      },
      \"lines\": [\"none\", \"pulse\"],
      \"groups\": [
        {
          \"label\": \"Kotekan\",
          \"subtitle\": null,
          \"rows\": [\"polos\", \"sangsih\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": []
            },
            {
              \"name\": \"sangsih\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"row\": 1, \"text\": \"nang\",
                  \"fill\": \"#fed9a6\", \"text_color\": \"#222222\", \"continued\": true }
              ]
            }
          ],
          \"overlays\": []
        },
        {
          \"label\": \"Sung\",
          \"subtitle\": null,
          \"rows\": [\"\"],
          \"voices\": [
            {
              \"name\": \"vocal\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"row\": 0, \"text\": \"-\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    }
  ],
  \"caption\": null
}
")

;; Overlays (slice feat/scores-overlays): two systems of 4 and 2
;; columns.  "Gangsa" (notes rows, 3 lanes): "norot" over all 3 rows at
;; 0-2, "Norot polos on 1" over 2 columns from 2, cut at the break and
;; continued in system 2.  "Kotekan" (parts rows, 2 rows): one overlay
;; over both rows.  "Sung" (a single row): an overlay of 1 row.  "Gong"
;; has none.
(define overlays
  "{
  \"version\": 4,
  \"title\": \"Overlays\",
  \"subtitle\": null,
  \"steps_per_pulse\": 1,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"6.3em\",
    \"row_label_width\": \"4.6em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 4,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": null,
        \"cycles\": null,
        \"pulses\": [\"1\", \"2\", \"3\", \"4\"]
      },
      \"lines\": [\"none\", \"pulse\", \"pulse\", \"pulse\"],
      \"groups\": [
        {
          \"label\": \"Gangsa\",
          \"subtitle\": null,
          \"rows\": [\"e2\", \"o2\", \"i2\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"row\": 2, \"text\": null,
                  \"fill\": \"#fbb4ae\", \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 1, \"dur\": 1, \"row\": 1, \"text\": null,
                  \"fill\": \"#b3cde3\", \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 2, \"dur\": 2, \"row\": 0, \"text\": null,
                  \"fill\": \"#ccebc5\", \"text_color\": \"#222222\", \"continued\": false }
              ]
            }
          ],
          \"overlays\": [
            { \"start\": 0, \"dur\": 2, \"row\": 0, \"rows\": 3,
              \"text\": \"norot\", \"continued\": false },
            { \"start\": 2, \"dur\": 2, \"row\": 0, \"rows\": 3,
              \"text\": \"Norot polos on 1\", \"continued\": false }
          ]
        },
        {
          \"label\": \"Kotekan\",
          \"subtitle\": null,
          \"rows\": [\"polos\", \"sangsih\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                { \"start\": 1, \"dur\": 1, \"row\": 0, \"text\": \"i\",
                  \"fill\": \"#fbb4ae\", \"text_color\": \"#222222\", \"continued\": false }
              ]
            },
            {
              \"name\": \"sangsih\",
              \"events\": [
                { \"start\": 2, \"dur\": 1, \"row\": 1, \"text\": \"o'\",
                  \"fill\": \"#b3cde3\", \"text_color\": \"#222222\", \"continued\": false }
              ]
            }
          ],
          \"overlays\": [
            { \"start\": 1, \"dur\": 3, \"row\": 0, \"rows\": 2,
              \"text\": \"6\", \"continued\": false }
          ]
        },
        {
          \"label\": \"Sung\",
          \"subtitle\": null,
          \"rows\": [\"\"],
          \"voices\": [
            {
              \"name\": \"vocal\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"row\": 0, \"text\": \"nang\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false }
              ]
            }
          ],
          \"overlays\": [
            { \"start\": 0, \"dur\": 1, \"row\": 0, \"rows\": 1,
              \"text\": \"S\", \"continued\": false }
          ]
        },
        {
          \"label\": \"Gong\",
          \"subtitle\": null,
          \"rows\": [\"G\"],
          \"voices\": [
            {
              \"name\": \"gong\",
              \"events\": [
                { \"start\": 3, \"dur\": 1, \"row\": 0, \"text\": null,
                  \"fill\": \"#cccccc\", \"text_color\": \"#222222\", \"continued\": false }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    },
    {
      \"start\": 4,
      \"steps\": 2,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": null,
        \"cycles\": null,
        \"pulses\": [\"5\", \"6\"]
      },
      \"lines\": [\"none\", \"pulse\"],
      \"groups\": [
        {
          \"label\": \"Gangsa\",
          \"subtitle\": null,
          \"rows\": [\"e2\", \"o2\", \"i2\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"row\": 0, \"text\": null,
                  \"fill\": \"#ccebc5\", \"text_color\": \"#222222\", \"continued\": true }
              ]
            }
          ],
          \"overlays\": [
            { \"start\": 0, \"dur\": 1, \"row\": 0, \"rows\": 3,
              \"text\": \"Norot polos on 1\", \"continued\": true }
          ]
        },
        {
          \"label\": \"Kotekan\",
          \"subtitle\": null,
          \"rows\": [\"polos\", \"sangsih\"],
          \"voices\": [
            { \"name\": \"polos\", \"events\": [] },
            { \"name\": \"sangsih\", \"events\": [] }
          ],
          \"overlays\": []
        },
        {
          \"label\": \"Sung\",
          \"subtitle\": null,
          \"rows\": [\"\"],
          \"voices\": [ { \"name\": \"vocal\", \"events\": [] } ],
          \"overlays\": [
            { \"start\": 1, \"dur\": 1, \"row\": 0, \"rows\": 1,
              \"text\": \"T\", \"continued\": false }
          ]
        },
        {
          \"label\": \"Gong\",
          \"subtitle\": null,
          \"rows\": [\"G\"],
          \"voices\": [ { \"name\": \"gong\", \"events\": [] } ],
          \"overlays\": []
        }
      ]
    }
  ],
  \"caption\": null
}
")

;; Contract version 3 (slice feat/drawing-header): quarter pulses, a
;; pickup of 1 with its cycle mark "0" at column 0 and cycle 1 at column
;; 4; both header labels; a second system with longer labels and a cycle
;; mark on its last pulse; a third with no cycle mark and its cycle label
;; null.
(define v3-header
  "{
  \"version\": 4,
  \"title\": \"Version 3 header\",
  \"subtitle\": null,
  \"steps_per_pulse\": 4,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"4.5em\",
    \"row_label_width\": \"2.0em\",
    \"cell_width\": \"1em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 16,
      \"header\": {
        \"cycle_label\": \"Cycle\",
        \"pulse_label\": \"Pulse\",
        \"cycles\": [
          {
            \"column\": 0,
            \"text\": \"0\"
          },
          {
            \"column\": 4,
            \"text\": \"1\"
          }
        ],
        \"pulses\": [
          \"4\",
          null,
          null,
          null,
          \"1\",
          null,
          null,
          null,
          \"2\",
          null,
          null,
          null,
          \"3\",
          null,
          null,
          null
        ]
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"none\",
        \"none\",
        \"cycle\",
        \"none\",
        \"none\",
        \"none\",
        \"pulse\",
        \"none\",
        \"none\",
        \"none\",
        \"pulse\",
        \"none\",
        \"none\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\",
            \"a1\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 4,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#fed9a6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 4,
                  \"dur\": 2,
                  \"row\": 0,
                  \"text\": \"i\",
                  \"fill\": \"#fbb4ae\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 6,
                  \"dur\": 10,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#fed9a6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    },
    {
      \"start\": 16,
      \"steps\": 8,
      \"header\": {
        \"cycle_label\": \"Gong · é\",
        \"pulse_label\": \"Ketukan\",
        \"cycles\": [
          {
            \"column\": 4,
            \"text\": \"2\"
          }
        ],
        \"pulses\": [
          \"4\",
          null,
          null,
          null,
          \"1\",
          null,
          null,
          null
        ]
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"none\",
        \"none\",
        \"cycle\",
        \"none\",
        \"none\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\",
            \"a1\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 8,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#fed9a6\",
                  \"text_color\": \"#222222\",
                  \"continued\": true
                }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    },
    {
      \"start\": 24,
      \"steps\": 8,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": \"Pulse\",
        \"cycles\": [],
        \"pulses\": [
          \"2\",
          null,
          null,
          null,
          \"3\",
          null,
          null,
          null
        ]
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"none\",
        \"none\",
        \"pulse\",
        \"none\",
        \"none\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\",
            \"a1\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": []
            }
          ],
          \"overlays\": []
        }
      ]
    }
  ],
  \"caption\": null
}
")

;; Version 3: a one-pulse pickup on a system of its own (quarter pulses,
;; 4 columns), its cycle mark "0" at column 0, centred over the pulse.
(define v3-pickup-alone
  "{
  \"version\": 4,
  \"title\": \"Pickup alone\",
  \"subtitle\": null,
  \"steps_per_pulse\": 4,
  \"sizes\": {
    \"font_size\": \"8pt\",
    \"label_width\": \"4.5em\",
    \"row_label_width\": \"2.0em\",
    \"cell_width\": \"1em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 4,
      \"header\": {
        \"cycle_label\": \"Cycle\",
        \"pulse_label\": \"Pulse\",
        \"cycles\": [
          {
            \"column\": 0,
            \"text\": \"0\"
          }
        ],
        \"pulses\": [
          \"8\",
          null,
          null,
          null
        ]
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"none\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\",
            \"a1\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 4,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#fed9a6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    }
  ],
  \"caption\": null
}
")

;; Version 3 with labels null: the cycle row only (the pickup's "0"
;; and cycle 1), then the pulse row only, then both rows off.
(define v3-labels-off
  "{
  \"version\": 4,
  \"title\": \"\",
  \"subtitle\": null,
  \"steps_per_pulse\": 4,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"3.9em\",
    \"row_label_width\": \"2.0em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 8,
      \"header\": {
        \"cycle_label\": \"Cycle\",
        \"pulse_label\": null,
        \"cycles\": [
          {
            \"column\": 0,
            \"text\": \"0\"
          },
          {
            \"column\": 4,
            \"text\": \"1\"
          }
        ],
        \"pulses\": null
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"none\",
        \"none\",
        \"cycle\",
        \"none\",
        \"none\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\",
            \"a1\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 8,
                  \"row\": 0,
                  \"text\": null,
                  \"fill\": \"#fbb4ae\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": []
        }
      ]
    },
    {
      \"start\": 8,
      \"steps\": 8,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": \"Pulse\",
        \"cycles\": null,
        \"pulses\": [
          \"2\",
          null,
          null,
          null,
          \"3\",
          null,
          null,
          null
        ]
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"none\",
        \"none\",
        \"pulse\",
        \"none\",
        \"none\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\",
            \"a1\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": []
            }
          ],
          \"overlays\": []
        }
      ]
    },
    {
      \"start\": 16,
      \"steps\": 8,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": null,
        \"cycles\": null,
        \"pulses\": null
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"none\",
        \"none\",
        \"cycle\",
        \"none\",
        \"none\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\",
            \"a1\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": []
            }
          ],
          \"overlays\": []
        }
      ]
    }
  ],
  \"caption\": null
}
")

;;; Slice feat/drawing-lines (05, "JSON contract (version 3)" and the
;;; template's Planned Lines, Frame and Note borders bullets; ADRs 0041,
;;; 0043, 0044): two hand-written figures with this slice's keys,
;;; `header.pulse_lines` after `pulses` and each group's `pulse_lines`
;;; and `row_lines` after `overlays`.  The first has two systems, the
;;; header's pulse lines off in the first and on in the second, groups on
;;; `notes`, `parts` and `single` rows and a stroke group, one for each
;;; background (grid, horizontal, vertical, empty), strokes in
;;; `#e6e6e6`, events with `fill` null (`:fill none`, and a "-"),
;;; overlays over a group with row lines, and notes, a stroke and an
;;; overlay cut by the system break and continued.  The second has both
;;; header rows off with `pulse_lines` false, and a group of one row
;;; with both flags true.  Only compiling without a warning is tested;
;;; the lines, the frame and the note borders are checked by eye (make
;;; preview).  These figures have no `key_numbers` or `key_width`: those
;;; are slice feat/drawing-rows.

(define v3-lines
  "{
  \"version\": 4,
  \"title\": \"Lines\",
  \"subtitle\": \"pulse and row lines by group\",
  \"steps_per_pulse\": 2,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"7.0em\",
    \"row_label_width\": \"4.6em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 8,
      \"header\": {
        \"cycle_label\": \"Cycle\",
        \"pulse_label\": \"Pulse\",
        \"cycles\": [
          {
            \"column\": 0,
            \"text\": \"0\"
          },
          {
            \"column\": 2,
            \"text\": \"1\"
          }
        ],
        \"pulses\": [
          \"4\",
          null,
          \"1\",
          null,
          \"2\",
          null,
          \"3\",
          null
        ],
        \"pulse_lines\": false
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"pulse\",
        \"none\",
        \"pulse\",
        \"none\",
        \"pulse\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": \"grid\",
          \"rows\": [
            \"e2\",
            \"o2\",
            \"i2\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"row\": 2,
                  \"text\": null,
                  \"fill\": \"#fbb4ae\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 2,
                  \"dur\": 2,
                  \"row\": 1,
                  \"text\": \"o\",
                  \"fill\": \"#b3cde3\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 4,
                  \"dur\": 1,
                  \"row\": 0,
                  \"text\": \"e\",
                  \"fill\": null,
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 6,
                  \"dur\": 2,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#b3cde3\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": [],
          \"pulse_lines\": true,
          \"row_lines\": true
        },
        {
          \"label\": \"Reyong\",
          \"subtitle\": \"horizontal\",
          \"rows\": [
            \"polos\",
            \"sangsih\"
          ],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 4,
                  \"row\": 0,
                  \"text\": \"i\",
                  \"fill\": \"#fbb4ae\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 4,
                  \"dur\": 4,
                  \"row\": 0,
                  \"text\": \"o\",
                  \"fill\": \"#b3cde3\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            },
            {
              \"name\": \"sangsih\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"row\": 1,
                  \"text\": \"e\",
                  \"fill\": null,
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 2,
                  \"dur\": 2,
                  \"row\": 1,
                  \"text\": \"-\",
                  \"fill\": null,
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": [
            {
              \"start\": 0,
              \"dur\": 4,
              \"row\": 0,
              \"rows\": 2,
              \"text\": \"P\",
              \"continued\": false
            },
            {
              \"start\": 4,
              \"dur\": 4,
              \"row\": 0,
              \"rows\": 2,
              \"text\": \"Pair long\",
              \"continued\": false
            }
          ],
          \"pulse_lines\": false,
          \"row_lines\": true
        },
        {
          \"label\": \"Kendang\",
          \"subtitle\": \"vertical\",
          \"rows\": [
            \"\"
          ],
          \"voices\": [
            {
              \"name\": \"kendang\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 1,
                  \"row\": 0,
                  \"text\": \"D\",
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 2,
                  \"dur\": 1,
                  \"row\": 0,
                  \"text\": \"d\",
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 4,
                  \"dur\": 2,
                  \"row\": 0,
                  \"text\": \"dug\",
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": [],
          \"pulse_lines\": true,
          \"row_lines\": false
        },
        {
          \"label\": \"Gong\",
          \"subtitle\": \"empty\",
          \"rows\": [
            \"G\",
            \"K\"
          ],
          \"voices\": [
            {
              \"name\": \"gong\",
              \"events\": [
                {
                  \"start\": 6,
                  \"dur\": 2,
                  \"row\": 0,
                  \"text\": \"G\",
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            },
            {
              \"name\": \"kempli\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 1,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 2,
                  \"dur\": 1,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 4,
                  \"dur\": 1,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 6,
                  \"dur\": 1,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": [],
          \"pulse_lines\": false,
          \"row_lines\": false
        }
      ]
    },
    {
      \"start\": 8,
      \"steps\": 8,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": \"Pulse\",
        \"cycles\": null,
        \"pulses\": [
          \"4\",
          null,
          \"1\",
          null,
          \"2\",
          null,
          \"3\",
          null
        ],
        \"pulse_lines\": true
      },
      \"lines\": [
        \"none\",
        \"none\",
        \"pulse\",
        \"none\",
        \"pulse\",
        \"none\",
        \"cycle\",
        \"none\"
      ],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": \"grid\",
          \"rows\": [
            \"e2\",
            \"o2\",
            \"i2\"
          ],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#b3cde3\",
                  \"text_color\": \"#222222\",
                  \"continued\": true
                },
                {
                  \"start\": 2,
                  \"dur\": 6,
                  \"row\": 2,
                  \"text\": null,
                  \"fill\": \"#fbb4ae\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": [],
          \"pulse_lines\": true,
          \"row_lines\": true
        },
        {
          \"label\": \"Reyong\",
          \"subtitle\": \"horizontal\",
          \"rows\": [
            \"polos\",
            \"sangsih\"
          ],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"row\": 0,
                  \"text\": null,
                  \"fill\": \"#b3cde3\",
                  \"text_color\": \"#222222\",
                  \"continued\": true
                },
                {
                  \"start\": 2,
                  \"dur\": 2,
                  \"row\": 1,
                  \"text\": \"i\",
                  \"fill\": null,
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            },
            {
              \"name\": \"sangsih\",
              \"events\": []
            }
          ],
          \"overlays\": [
            {
              \"start\": 0,
              \"dur\": 2,
              \"row\": 0,
              \"rows\": 2,
              \"text\": \"Pair long\",
              \"continued\": true
            }
          ],
          \"pulse_lines\": false,
          \"row_lines\": true
        },
        {
          \"label\": \"Kendang\",
          \"subtitle\": \"vertical\",
          \"rows\": [
            \"\"
          ],
          \"voices\": [
            {
              \"name\": \"kendang\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"row\": 0,
                  \"text\": null,
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": true
                }
              ]
            }
          ],
          \"overlays\": [],
          \"pulse_lines\": true,
          \"row_lines\": false
        },
        {
          \"label\": \"Gong\",
          \"subtitle\": \"empty\",
          \"rows\": [
            \"G\",
            \"K\"
          ],
          \"voices\": [
            {
              \"name\": \"gong\",
              \"events\": []
            },
            {
              \"name\": \"kempli\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 1,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 4,
                  \"dur\": 1,
                  \"row\": 1,
                  \"text\": null,
                  \"fill\": \"#e6e6e6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": [],
          \"pulse_lines\": false,
          \"row_lines\": false
        }
      ]
    }
  ],
  \"caption\": null
}
")

(define v3-lines-off
  "{
  \"version\": 4,
  \"title\": \"\",
  \"subtitle\": null,
  \"steps_per_pulse\": 1,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"3.0em\",
    \"row_label_width\": \"2.0em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 8,
      \"header\": {
        \"cycle_label\": null,
        \"pulse_label\": null,
        \"cycles\": null,
        \"pulses\": null,
        \"pulse_lines\": false
      },
      \"lines\": [
        \"none\",
        \"pulse\",
        \"pulse\",
        \"pulse\",
        \"cycle\",
        \"pulse\",
        \"pulse\",
        \"pulse\"
      ],
      \"groups\": [
        {
          \"label\": \"A\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\",
            \"a1\"
          ],
          \"voices\": [
            {
              \"name\": \"a\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 8,
                  \"row\": 0,
                  \"text\": null,
                  \"fill\": \"#fbb4ae\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": [],
          \"pulse_lines\": false,
          \"row_lines\": false
        },
        {
          \"label\": \"B\",
          \"subtitle\": null,
          \"rows\": [
            \"i2\"
          ],
          \"voices\": [
            {
              \"name\": \"b\",
              \"events\": [
                {
                  \"start\": 1,
                  \"dur\": 1,
                  \"row\": 0,
                  \"text\": \"i\",
                  \"fill\": null,
                  \"text_color\": \"#222222\",
                  \"continued\": false
                }
              ]
            }
          ],
          \"overlays\": [],
          \"pulse_lines\": true,
          \"row_lines\": true
        }
      ]
    }
  ],
  \"caption\": null
}
")

;;; Slice feat/drawing-rows (05, "JSON contract (version 3)" and the
;;; template's Planned "Columns" bullet; 04, the keys table; ADRs 0042,
;;; 0047): two hand-written figures with this slice's keys, each
;;; group's `key_numbers` after `lanes` and `sizes.key_width` after
;;; `label_width`.  The first has two systems, a group with key numbers
;;; (two digits among them) and its row labels, a group with key numbers
;;; and every lane "" (`:row-labels no`), a stroke group with
;;; `key_numbers` null and one-column strokes, and a `parts` group with
;;; null; `key_width` "2.0em".  The second has `key_width` and
;;; `lane_width` both "0.0em": no key numbers and no row labels in any
;;; group, so the group label sits next to the grid.  Only compiling
;;; without a warning is tested; the columns are checked by eye (make
;;; preview).

(define (rows3-event start dur lane text fill)
  (string-append
   "{ \"start\": " (number->string start) ", \"dur\": " (number->string dur)
   ", \"row\": " (number->string lane) ", \"text\": " text
   ", \"fill\": " fill ", \"text_color\": \"#222222\", \"continued\": false }"))

(define (rows3-group label lanes key-numbers voices)
  (string-append
   "{ \"label\": \"" label "\", \"subtitle\": null, \"rows\": " lanes
   ", \"key_numbers\": " key-numbers ", \"voices\": " voices
   ", \"overlays\": [], \"pulse_lines\": true, \"row_lines\": true }"))

(define (rows3-system start groups)
  (string-append
   "{ \"start\": " (number->string start) ", \"steps\": 4,"
   " \"header\": { \"cycle_label\": null, \"pulse_label\": \"Pulse\","
   " \"cycles\": null, \"pulses\": [\"1\", \"2\", \"3\", \"4\"],"
   " \"pulse_lines\": true },"
   " \"lines\": [\"none\", \"pulse\", \"pulse\", \"pulse\"],"
   " \"groups\": [" (string-join groups ", ") "] }"))

(define (rows3-figure key-width lane-width systems)
  (string-append
   "{ \"version\": 4, \"title\": \"Rows\", \"subtitle\": null,"
   " \"steps_per_pulse\": 1,"
   " \"sizes\": { \"font_size\": null, \"label_width\": \"4.5em\","
   " \"key_width\": \"" key-width "\", \"row_label_width\": \"" lane-width "\","
   " \"cell_width\": \"2em\", \"cell_height\": \"2em\" },"
   " \"systems\": [" (string-join systems ", ") "], \"caption\": null }\n"))

(define (rows3-groups)
  (list
   (rows3-group "Ugal" "[\"i3\", \"a2\", \"u1\"]" "[\"10\", \"9\", \"3\"]"
                (string-append
                 "[{ \"name\": \"m\", \"events\": ["
                 (rows3-event 0 2 2 "\"u\"" "\"#decbe4\"") ", "
                 (rows3-event 2 1 0 "\"i\"" "\"#fbb4ae\"") "] }]"))
   (rows3-group "Gangsa" "[\"\", \"\"]" "[\"5\", \"4\"]"
                (string-append
                 "[{ \"name\": \"g\", \"events\": ["
                 (rows3-event 1 1 1 "null" "\"#fed9a6\"") ", "
                 (rows3-event 3 1 0 "null" "\"#fbb4ae\"") "] }]"))
   (rows3-group "Gong" "[\"Gong\", \"P\"]" "null"
                (string-append
                 "[{ \"name\": \"gong\", \"events\": ["
                 (rows3-event 0 1 1 "\"P\"" "\"#e6e6e6\"") ", "
                 (rows3-event 2 1 0 "\"Gong\"" "\"#e6e6e6\"") "] }]"))
   (rows3-group "Parts" "[\"polos\", \"sangsih\"]" "null"
                (string-append
                 "[{ \"name\": \"polos\", \"events\": ["
                 (rows3-event 0 1 0 "\"i\"" "null") "] },"
                 " { \"name\": \"sangsih\", \"events\": [] }]"))))

(define v3-rows
  (rows3-figure "2.0em" "3.6em"
                (list (rows3-system 0 (rows3-groups))
                      (rows3-system 4 (rows3-groups)))))

(define v3-rows-off
  (rows3-figure "0.0em" "0.0em"
                (list (rows3-system
                       0
                       (list
                        (rows3-group "Ugal" "[\"\", \"\", \"\"]" "null"
                                     (string-append
                                      "[{ \"name\": \"m\", \"events\": ["
                                      (rows3-event 0 4 2 "null" "\"#decbe4\"") "] }]"))
                        (rows3-group "Gong" "[\"\"]" "null"
                                     (string-append
                                      "[{ \"name\": \"gong\", \"events\": ["
                                      (rows3-event 3 1 0 "null" "\"#e6e6e6\"")
                                      "] }]")))))))

;;; The tests.

(test-begin "template")

(define names (golden-names))

(test-assert "there is at least one golden figure in tests/golden/"
  (pair? names))

(if (typst-installed?)
    (begin
      (for-each
       (lambda (name)
         (let ((file (string-append name ".json")))
           (check-figure (string-append golden-dir "/" file) file
                         (read-text (string-append golden-dir "/" file)))))
       names)
      (check-figure "a figure with no systems" "empty.json" no-systems)
      (check-figure "a system starting mid-pulse" "off-pulse.json"
                    off-pulse)
      (check-figure "header rows, lines, subtitle and caption" "header-rows.json"
                    header-rows)
      (check-figure "both header rows off" "no-header-rows.json"
                    no-header-rows)
      (check-figure "parts and single rows, fill null, dashes" "rows.json"
                    rows)
      (check-figure "overlays, one continued and one over several rows"
                    "overlays.json" overlays)
      (check-figure "version 3: header labels, the pickup's \"0\", quarter pulses"
                    "v3-header.json" v3-header)
      (check-figure "version 3: the pickup alone on a system"
                    "v3-pickup-alone.json" v3-pickup-alone)
      (check-figure "version 3: labels null, rows on and off"
                    "v3-labels-off.json" v3-labels-off)
      (check-figure "version 3: pulse and row lines by group, strokes #e6e6e6"
                    "v3-lines.json" v3-lines)
      (check-figure "version 3: every line flag off, a one-row group with both on"
                    "v3-lines-off.json" v3-lines-off)
      (check-figure "version 3: key numbers, row labels left out, one-column strokes"
                    "v3-rows.json" v3-rows)
      (check-figure "version 3: key_width and lane_width both 0.0em"
                    "v3-rows-off.json" v3-rows-off))
    (test-assert "typst is installed (CI installs 0.15.1)" #f))

(define runner (test-runner-current))
(test-end "template")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
