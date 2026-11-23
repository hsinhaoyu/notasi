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
  \"version\": 2,
  \"title\": \"Nothing\",
  \"subtitle\": null,
  \"steps_per_pulse\": 4,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"5em\",
    \"lane_width\": \"2.0em\",
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
  \"version\": 2,
  \"title\": \"Off pulse\",
  \"subtitle\": null,
  \"steps_per_pulse\": 4,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"6em\",
    \"lane_width\": \"2.5em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 2,
      \"steps\": 6,
      \"header\": {
        \"label\": null,
        \"cycles\": null,
        \"pulses\": [null, null, \"2\", null, null, null]
      },
      \"lines\": [\"none\", \"none\", \"pulse\", \"none\", \"none\", \"none\"],
      \"groups\": [
        {
          \"label\": \"Reyong\",
          \"subtitle\": null,
          \"lanes\": [\"nong1\", \"nang1\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"lane\": 1,
                  \"text\": \"nang\",
                  \"fill\": \"#1b9e77\",
                  \"text_color\": \"#ffffff\",
                  \"continued\": true
                },
                {
                  \"start\": 3,
                  \"dur\": 1,
                  \"lane\": 0,
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
          \"lanes\": [\"dag\"],
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
  \"version\": 2,
  \"title\": \"Header rows\",
  \"subtitle\": \"pangecet\",
  \"steps_per_pulse\": 2,
  \"sizes\": {
    \"font_size\": \"10pt\",
    \"label_width\": \"5em\",
    \"lane_width\": \"2.0em\",
    \"cell_width\": \"1.5em\",
    \"cell_height\": \"2.5em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 6,
      \"header\": {
        \"label\": \"Beats\",
        \"cycles\": [{ \"column\": 2, \"text\": \"1\" }],
        \"pulses\": [\"1\", null, \"2\", null, \"3\", null]
      },
      \"lines\": [\"none\", \"none\", \"cycle\", \"none\", \"pulse\", \"none\"],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"lanes\": [\"i2\", \"a1\"],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"lane\": 1,
                  \"text\": null,
                  \"fill\": \"#fed9a6\",
                  \"text_color\": \"#222222\",
                  \"continued\": false
                },
                {
                  \"start\": 2,
                  \"dur\": 4,
                  \"lane\": 0,
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
        \"label\": \"Beats\",
        \"cycles\": [{ \"column\": 4, \"text\": \"2\" }],
        \"pulses\": [\"4\", null, \"1\", null, \"2\", null]
      },
      \"lines\": [\"none\", \"none\", \"pulse\", \"none\", \"cycle\", \"none\"],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"lanes\": [\"i2\", \"a1\"],
          \"voices\": [
            {
              \"name\": \"ugal\",
              \"events\": [
                {
                  \"start\": 0,
                  \"dur\": 2,
                  \"lane\": 0,
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
        \"label\": \"Beats\",
        \"cycles\": [],
        \"pulses\": [\"3\", null]
      },
      \"lines\": [\"none\", \"none\"],
      \"groups\": [
        {
          \"label\": \"Ugal\",
          \"subtitle\": null,
          \"lanes\": [\"i2\", \"a1\"],
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
  \"version\": 2,
  \"title\": \"\",
  \"subtitle\": null,
  \"steps_per_pulse\": 1,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"3em\",
    \"lane_width\": \"1.5em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 4,
      \"header\": {
        \"label\": \"Beats\",
        \"cycles\": null,
        \"pulses\": null
      },
      \"lines\": [\"none\", \"pulse\", \"cycle\", \"pulse\"],
      \"groups\": [
        {
          \"label\": \"Gong\",
          \"subtitle\": null,
          \"lanes\": [\"G\"],
          \"voices\": [
            {
              \"name\": \"gong\",
              \"events\": [
                {
                  \"start\": 1,
                  \"dur\": 1,
                  \"lane\": 0,
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
  \"version\": 2,
  \"title\": \"Rows\",
  \"subtitle\": null,
  \"steps_per_pulse\": 1,
  \"sizes\": {
    \"font_size\": null,
    \"label_width\": \"6.3em\",
    \"lane_width\": \"4.6em\",
    \"cell_width\": \"2em\",
    \"cell_height\": \"2em\"
  },
  \"systems\": [
    {
      \"start\": 0,
      \"steps\": 4,
      \"header\": {
        \"label\": null,
        \"cycles\": null,
        \"pulses\": [\"1\", \"2\", \"3\", \"4\"]
      },
      \"lines\": [\"none\", \"pulse\", \"pulse\", \"pulse\"],
      \"groups\": [
        {
          \"label\": \"Kotekan\",
          \"subtitle\": null,
          \"lanes\": [\"polos\", \"sangsih\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"lane\": 0, \"text\": \"i\",
                  \"fill\": \"#fbb4ae\", \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 1, \"dur\": 1, \"lane\": 0, \"text\": \"-\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 2, \"dur\": 1, \"lane\": 0, \"text\": \"o'\",
                  \"fill\": \"#b3cde3\", \"text_color\": \"#222222\", \"continued\": false }
              ]
            },
            {
              \"name\": \"sangsih\",
              \"events\": [
                { \"start\": 1, \"dur\": 1, \"lane\": 1, \"text\": \"i' o'\",
                  \"fill\": \"#fbb4ae\", \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 3, \"dur\": 1, \"lane\": 1, \"text\": \"nang\",
                  \"fill\": \"#fed9a6\", \"text_color\": \"#222222\", \"continued\": false }
              ]
            }
          ],
          \"overlays\": []
        },
        {
          \"label\": \"Sung\",
          \"subtitle\": null,
          \"lanes\": [\"\"],
          \"voices\": [
            {
              \"name\": \"vocal\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"lane\": 0, \"text\": \"nang\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 1, \"dur\": 1, \"lane\": 0, \"text\": \"-\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 2, \"dur\": 1, \"lane\": 0, \"text\": \"-\",
                  \"fill\": null, \"text_color\": \"#222222\", \"continued\": false },
                { \"start\": 3, \"dur\": 1, \"lane\": 0, \"text\": \"ni'\",
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
        \"label\": null,
        \"cycles\": null,
        \"pulses\": [\"5\", \"6\"]
      },
      \"lines\": [\"none\", \"pulse\"],
      \"groups\": [
        {
          \"label\": \"Kotekan\",
          \"subtitle\": null,
          \"lanes\": [\"polos\", \"sangsih\"],
          \"voices\": [
            {
              \"name\": \"polos\",
              \"events\": []
            },
            {
              \"name\": \"sangsih\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"lane\": 1, \"text\": \"nang\",
                  \"fill\": \"#fed9a6\", \"text_color\": \"#222222\", \"continued\": true }
              ]
            }
          ],
          \"overlays\": []
        },
        {
          \"label\": \"Sung\",
          \"subtitle\": null,
          \"lanes\": [\"\"],
          \"voices\": [
            {
              \"name\": \"vocal\",
              \"events\": [
                { \"start\": 0, \"dur\": 1, \"lane\": 0, \"text\": \"-\",
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
                    rows))
    (test-assert "typst is installed (CI installs 0.15.1)" #f))

(define runner (test-runner-current))
(test-end "template")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
