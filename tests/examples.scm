;;; The examples and their drawings: doc/design/07-environment.md,
;;; "Examples and their drawings" and "Drawings" (ADR 0052; names from
;;; ADR 0040).  Written from the design doc for milestone feat/examples,
;;; before the files moved.
;;;
;;; What it checks:
;;; - The folders: examples/gallery (with images/), demos, contrib (kept
;;;   in git by an empty .gitkeep), manual (with templates/, mistakes/
;;;   and images/).
;;; - The pieces: gallery/ holds jaya-semara, baris, gambangan-excerpt
;;;   and gambangan-readme, and one LilyPond file, gambangan-readme-piano
;;;   (ADR 0064); demos/ holds gilak and tenzer1; no .nts lies directly
;;;   in examples/.
;;; - Names are unique across examples/: no two folders hold a .nts file
;;;   of the same name.
;;; - Nothing is left behind: the manual's old examples/ and mistakes/
;;;   folders are gone, no example .nts is under doc/, scripts/preview.scm
;;;   is gone, and the Makefile has an `images' target and no `preview'.
;;;   It has a `lilypond' target (ADR 0064).
;;; - The set of images (07, "make check checks the set of images"):
;;;   gallery/images/ holds exactly NAME.png for a gallery file with only
;;;   the default score, or NAME_SCORE.png for each score of a file with
;;;   scores, and NAME.png for each gallery LilyPond file NAME.ly (ADR
;;;   0064); manual/images/ holds exactly one X.png for each distinct
;;;   figures/X.png a manual page links to.  Nothing else in either.
;;;   Each image starts with the PNG signature (the bytes themselves are
;;;   compared only by CI).
;;; - A manual page links PNGs only: no figures/*.svg.
;;;
;;; Choices made where the docs are not explicit:
;;; - "Only the default score" means the piece's only score has no source
;;;   location (03: the default score's location is #f), as in
;;;   tests/golden.scm.
;;; - Unique names compare the basenames of the .nts files in gallery/,
;;;   demos/, contrib/, manual/ and manual/mistakes/, any depth, except
;;;   files in a templates/ folder: templates are not examples, and are
;;;   loaded by a path relative to the file that uses them.  Mistakes are
;;;   included: they are .nts files under examples/, in their own folder.
;;; - "No .nts under doc/" leaves out doc/manual/book/ (mdBook's output,
;;;   not committed) and doc/iterations/*/targets/ (an iteration's
;;;   hand-made targets, records of the design rather than examples).
;;; - Dotfiles (.gitkeep, .DS_Store) in an images/ folder are ignored.
;;; - Manual pages are the .md files directly in doc/manual/src/, where
;;;   every page lives; a link is any `figures/NAME.EXT' in a page.
;;;
;;; Milestone feat/gallery, iteration 5's acceptance test
;;; (doc/iterations/05-collapsed-and-gallery/README.md, "Acceptance
;;; test" and milestone 5's "Decided when it started"), checked on
;;; examples/gallery/jaya-semara.nts and baris.nts, each laid out with
;;; layout-score:
;;; - The score `collapsed' has a group other than the gong and kempli
;;;   one with `:rows' parts or compact.
;;; - In `collapsed', the group holding the gong and kempli parts has
;;;   `:rows compact' and lays out as exactly two rows in every system.
;;; - Annotation rows, below their group: Jaya Semara's polos group in
;;;   `collapsed' reads 1 6 3 2 1 6 3 2 (the melody twice), and the
;;;   group of `kotekan' holding polos reads 1 6 3 2; Baris's reyong
;;;   group (the group holding polos) in `collapsed' includes "na' - ni'".
;;; - Piece information: Jaya Semara has composer "I Wayan Beratha",
;;;   composition-year "1964" and a non-empty source and remarks; Baris
;;;   has a non-empty source and remarks and no composer.
;;; - Acceptance 2 (an image NAME_SCORE.png for every score) is already
;;;   checked for every gallery file by "The set of images" above.
;;; Choices made where the docs are not explicit:
;;; - A group of a score is found by its members' part names (polos;
;;;   gong and kempli), not by its label, which the examples may change.
;;;   The figure's groups are taken to be the score's groups, in order,
;;;   in every system.
;;; - An annotation row's texts are those of its items that are not
;;;   continued, over all systems in order, so a pattern cut at a system
;;;   boundary counts once.
;;;
;;; Run from the repo root: guile --fresh-auto-compile -L . tests/examples.scm

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 ftw)
             (ice-9 match)
             (ice-9 regex)
             (ice-9 textual-ports)
             (rnrs bytevectors)
             (rnrs io ports)
             (notasi layout)
             (notasi piece)
             (notasi reader))

(define examples "examples")
(define gallery (string-append examples "/gallery"))
(define gallery-images (string-append gallery "/images"))
(define demos (string-append examples "/demos"))
(define contrib (string-append examples "/contrib"))
(define manual (string-append examples "/manual"))
(define manual-images (string-append manual "/images"))
(define manual-src "doc/manual/src")

;;; Helpers

(define (directory? path)
  (and (file-exists? path) (eq? 'directory (stat:type (stat path)))))

(define (regular-file? path)
  (and (file-exists? path) (eq? 'regular (stat:type (stat path)))))

(define (slurp path)
  (call-with-input-file path get-string-all #:encoding "UTF-8"))

(define (entries dir)
  "The names in DIR, without dotfiles, sorted; none if DIR doesn't exist."
  (or (and (directory? dir)
           (scandir dir (lambda (f) (not (string-prefix? "." f)))))
      '()))

(define (files-in dir suffix)
  "The names of the regular files directly in DIR ending in SUFFIX."
  (filter (lambda (f)
            (and (string-suffix? suffix f)
                 (regular-file? (string-append dir "/" f))))
          (entries dir)))

(define (files-under dir suffix)
  "Every file below DIR, at any depth, whose name ends in SUFFIX, as
paths.  None if DIR doesn't exist."
  (let walk ((dir dir))
    (append-map
     (lambda (name)
       (let ((path (string-append dir "/" name)))
         (cond ((directory? path) (walk path))
               ((string-suffix? suffix name) (list path))
               (else '()))))
     (entries dir))))

(define (template-file? path)
  (string-contains path "/templates/"))

(define (duplicates names)
  "The names that occur more than once in NAMES, once each, sorted."
  (sort (delete-duplicates
         (filter (lambda (n) (> (count (lambda (m) (string=? n m)) names) 1))
                 names))
        string<?))

(define (sorted strings) (sort strings string<?))

(define png-signature #vu8(137 80 78 71 13 10 26 10))

(define (png? path)
  "Does the file at PATH start with the PNG signature?"
  (let ((head (call-with-input-file path
                (lambda (port) (get-bytevector-n port 8))
                #:binary #t)))
    (and (bytevector? head) (bytevector=? head png-signature))))

(define (default-score-only? piece)
  (match (piece-scores piece)
    ((score) (not (score-location score)))
    (_ #f)))

(define (image-names name piece)
  "The images, NAME.png or NAME_SCORE.png, of the gallery file NAME."
  (if (default-score-only? piece)
      (list (string-append name ".png"))
      (map (lambda (score)
             (string-append name "_" (symbol->string (score-name score))
                            ".png"))
           (piece-scores piece))))

(define (read-or-false path)
  (guard (e (#t #f)) (read-piece-file path)))

(define pages
  (map (lambda (f) (string-append manual-src "/" f))
       (files-in manual-src ".md")))

(define (figure-links page suffix)
  "The NAME.SUFFIX of each figures/NAME.SUFFIX link in PAGE."
  (map (lambda (m) (match:substring m 1))
       (list-matches (string-append "figures/([A-Za-z0-9_.-]+\\." suffix ")")
                     (slurp page))))

(test-begin "examples")

;;; 1. The folders

(for-each
 (lambda (dir)
   (test-assert (string-append "folder exists: " dir) (directory? dir)))
 (list gallery gallery-images demos contrib manual
       (string-append manual "/templates")
       (string-append manual "/mistakes")
       manual-images))

(test-assert "examples/contrib/.gitkeep exists"
  (regular-file? (string-append contrib "/.gitkeep")))

;;; 2. The pieces

(test-equal "gallery/ holds jaya-semara, baris, gambangan-excerpt and gambangan-readme"
  '("baris.nts" "gambangan-excerpt.nts" "gambangan-readme.nts"
    "jaya-semara.nts")
  (sorted (files-in gallery ".nts")))

(test-equal "gallery/ holds one LilyPond file, gambangan-readme-piano"
  '("gambangan-readme-piano.ly")
  (sorted (files-in gallery ".ly")))

(test-equal "demos/ holds gilak and tenzer1"
  '("gilak.nts" "tenzer1.nts")
  (sorted (files-in demos ".nts")))

(test-equal "no .nts file lies directly in examples/"
  '()
  (files-in examples ".nts"))

;;; 3. Names are unique across examples/

(test-equal "no two folders under examples/ hold a .nts file of the same name"
  '()
  (duplicates
   (map basename
        (remove template-file?
                (append-map (lambda (dir) (files-under dir ".nts"))
                            (list gallery demos contrib manual))))))

;;; 4. Nothing left behind

(test-assert "doc/manual/src/examples/ is gone"
  (not (file-exists? (string-append manual-src "/examples"))))

(test-assert "doc/manual/src/mistakes/ is gone"
  (not (file-exists? (string-append manual-src "/mistakes"))))

(test-equal "no example .nts file is under doc/"
  '()
  (remove (lambda (path)
            (or (string-prefix? "doc/manual/book/" path)
                (string-match "^doc/iterations/[^/]+/targets/" path)))
          (files-under "doc" ".nts")))

(test-assert "scripts/preview.scm is gone"
  (not (file-exists? "scripts/preview.scm")))

(define makefile (slurp "Makefile"))

(test-assert "the Makefile has an images target"
  (string-match "(^|\n)images:" makefile))

(test-assert "the Makefile has a lilypond target"
  (string-match "(^|\n)lilypond:" makefile))

(test-assert "the Makefile has no preview target"
  (not (string-match "(^|\n)preview:" makefile)))

;;; 5. The set of images

(define gallery-files (files-in gallery ".nts"))

(for-each
 (lambda (f)
   (test-assert (string-append "gallery file reads: " f)
     (read-or-false (string-append gallery "/" f))))
 gallery-files)

(test-equal "gallery/images/ holds one PNG per score of each gallery file and per LilyPond file, nothing else"
  (sorted
   (append
    (append-map
     (lambda (f)
       (let ((piece (read-or-false (string-append gallery "/" f))))
         (if piece (image-names (string-drop-right f 4) piece) '())))
     gallery-files)
    (map (lambda (f) (string-append (string-drop-right f 3) ".png"))
         (files-in gallery ".ly"))))
  (sorted (entries gallery-images)))

(define linked-pngs
  (sorted (delete-duplicates
           (append-map (lambda (page) (figure-links page "png")) pages))))

(test-assert "the manual's pages link at least one image"
  (pair? linked-pngs))

(test-equal "manual/images/ holds one PNG per image a page links, nothing else"
  linked-pngs
  (entries manual-images))

(for-each
 (lambda (dir)
   (for-each
    (lambda (f)
      (let ((path (string-append dir "/" f)))
        (test-assert (string-append "is a PNG: " path)
          (and (regular-file? path) (png? path)))))
    (entries dir)))
 (list gallery-images manual-images))

;;; 6. Manual pages link PNG only

(for-each
 (lambda (page)
   (test-equal (string-append "links no SVG figure: " page)
     '()
     (figure-links page "svg")))
 pages)

;;; 7. The acceptance test (iteration 5)

(define (json-ref obj key)
  "The value of KEY in the JSON object OBJ (an alist), or the symbol
missing."
  (match (assq key obj)
    ((_ . value) value)
    (#f 'missing)))

(define (member-names group)
  "The names of the parts in GROUP, in order."
  (map (lambda (m) (part-name (car m))) (group-members group)))

(define (group-index score pred)
  "The index of the first group of SCORE whose member names satisfy
PRED, or #f."
  (list-index (lambda (g) (pred (member-names g))) (score-groups score)))

(define (holds-part? name) (lambda (names) (memq name names)))

(define (gong-kempli? names) (and (memq 'gong names) (memq 'kempli names)))

(define (figure-groups fig g)
  "Group G of FIG in each of its systems."
  (map (lambda (system) (vector-ref (json-ref system 'groups) g))
       (vector->list (json-ref fig 'systems))))

(define (annotation-texts fig g)
  "The texts of group G's annotation items in FIG that are not
continued, over every system in order."
  (append-map
   (lambda (group)
     (let ((a (json-ref group 'annotation)))
       (if (pair? a)
           (filter-map (lambda (item)
                         (and (not (eq? #t (json-ref item 'continued)))
                              (json-ref item 'text)))
                       (vector->list (json-ref a 'items)))
           '())))
   (figure-groups fig g)))

(define (annotation-positions fig g)
  "The position of group G's annotation in each system of FIG (missing
or null when there is none)."
  (map (lambda (group)
         (let ((a (json-ref group 'annotation)))
           (if (pair? a) (json-ref a 'position) a)))
       (figure-groups fig g)))

(define-syntax-rule (or-false body ...)
  (guard (e (#t (format (current-error-port) "error: ~a~%"
                        (if (exception-with-message? e)
                            (exception-message e)
                            e))
                #f))
    body ...))

(define (score-of piece name)
  (and piece (piece-score piece name)))

(define (figure-of piece name)
  (let ((score (score-of piece name)))
    (and score (or-false (layout-score piece score)))))

(define (annotation-check piece score-name part)
  "(TEXTS POSITIONS) of the annotation row of the group of SCORE-NAME
holding PART, or #f."
  (let* ((score (score-of piece score-name))
         (g (and score (group-index score (holds-part? part))))
         (fig (and g (figure-of piece score-name))))
    (and fig (or-false (list (annotation-texts fig g)
                             (delete-duplicates (annotation-positions fig g)))))))

(define (info-ref piece key)
  (and piece (assq-ref (piece-info piece) key)))

(define (non-empty-string? x) (and (string? x) (not (string-null? x))))

(define jaya-semara (read-or-false (string-append gallery "/jaya-semara.nts")))
(define baris (read-or-false (string-append gallery "/baris.nts")))

(test-group "the acceptance test (iteration 5)"
  (for-each
   (match-lambda
     ((name piece)
      (let* ((collapsed (score-of piece 'collapsed))
             (gk (and collapsed (group-index collapsed gong-kempli?)))
             (fig (figure-of piece 'collapsed)))
        (test-assert (string-append name ": has a score `collapsed'")
          collapsed)
        (test-assert (string-append name ": collapsed has a group other than"
                                    " the gong and kempli with :rows parts or compact")
          (and collapsed
               (any (lambda (g i)
                      (and (not (eqv? i gk))
                           (memq (group-rows g) '(parts compact))))
                    (score-groups collapsed)
                    (iota (length (score-groups collapsed))))))
        (test-assert (string-append name ": collapsed has a group with the gong and kempli")
          gk)
        (test-eq (string-append name ": the gong and kempli group is :rows compact")
          'compact
          (and gk (group-rows (list-ref (score-groups collapsed) gk))))
        (test-equal (string-append name ": the gong and kempli group lays out as two rows")
          '(2)
          (and gk fig
               (or-false
                (delete-duplicates
                 (map (lambda (group) (vector-length (json-ref group 'rows)))
                      (figure-groups fig gk)))))))))
   (list (list "jaya-semara" jaya-semara) (list "baris" baris)))

  (test-equal "jaya-semara: collapsed's polos group has an annotation row below: 1 6 3 2, twice"
    '(("1" "6" "3" "2" "1" "6" "3" "2") ("below"))
    (annotation-check jaya-semara 'collapsed 'polos))

  (test-equal "jaya-semara: kotekan's pemade group has an annotation row below: 1 6 3 2"
    '(("1" "6" "3" "2") ("below"))
    (annotation-check jaya-semara 'kotekan 'polos))

  (let ((check (annotation-check baris 'collapsed 'polos)))
    (test-assert "baris: collapsed's reyong group has an annotation row naming na' - ni'"
      (and check (member "na' - ni'" (car check))))
    (test-equal "baris: the reyong group's annotation row is below"
      '("below")
      (and check (cadr check))))

  (test-equal "jaya-semara: composer" "I Wayan Beratha"
    (info-ref jaya-semara 'composer))
  (test-equal "jaya-semara: composition-year" "1964"
    (info-ref jaya-semara 'composition-year))
  (test-assert "jaya-semara: a source"
    (non-empty-string? (info-ref jaya-semara 'source)))
  (test-assert "jaya-semara: remarks"
    (non-empty-string? (info-ref jaya-semara 'remarks)))
  (test-assert "baris: a source"
    (non-empty-string? (info-ref baris 'source)))
  (test-assert "baris: remarks"
    (non-empty-string? (info-ref baris 'remarks)))
  (test-assert "baris: no composer"
    (and baris (not (assq 'composer (piece-info baris))))))

(define runner (test-runner-current))
(test-end "examples")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
