;;; Unit tests for (notasi reader).
;;;
;;; The v1 tests (slices feat/reader-forms, feat/reader-scales,
;;; feat/reader-parts and feat/reader-templates), translated to the
;;; notation of iteration 2's first slice, feat/music-syntax
;;; (03-reader.md, "Slices (iteration 2)"), plus that slice's own cases:
;;; reading with `keywords` off, `:key value` options, degrees and
;;; strokes with `:alias`, `:display` and `:damped`, instruments without
;;; options, `(part INSTRUMENT :name NAME TOKEN ...)`, `·` no longer a
;;; rest, `group-outside-score`, `text` gone, and `colotomy`, `pattern`
;;; and `score` raising `not-implemented`. Every part is in its own
;;; default group.
;;;
;;; Slice feat/music-durations (slice 2): times are exact rationals in
;;; pulses; duration suffixes, `_`, `-`, `|` and `/` are expanded by
;;; (notasi expand); the condition has `time` (pulses, or #f) and `uses`
;;; ('() until patterns) instead of v1's `step`; `piece` takes no options
;;; until slice 4, so the transitional `:steps-per-pulse` and
;;; `:steps-per-system` are `unknown-option`. With no duration written,
;;; every token is one pulse, so the v1 token tests keep their numbers:
;;; a 0-based step is now a time in pulses.
;;;
;;; Written from doc/design/01-notation.md, 02-piece.md and 03-reader.md,
;;; not from the implementation. Tests check the error kind and the
;;; location fields, never the message text.
;;;
;;; Choices made where the docs are not explicit (or disagree):
;;; - A piece form with anything after its title that is not a
;;;   `:key value` pair (a number, a bare symbol, a v1 list option) is
;;;   `bad-option`, as in v1: the piece form has no body.
;;; - `:alias`, `:display` and `:damped` with a value of the wrong kind
;;;   are `bad-degree` (03, "Definitions"), although 03's "Options" names
;;;   `:alias 3` as a `bad-option` example. A key with no value is
;;;   `bad-option`, an unknown key `unknown-option`, a key twice
;;;   `duplicate-option`, all at the degree's line. `:alias ()` is
;;;   `bad-degree`: an empty list is not a list of names.
;;; - Two parts on one instrument, neither with `:name`, are
;;;   `parts-need-names` (03 and 01's example message), although both
;;;   then default to the same name, which check 7 would report as a
;;;   `duplicate-definition` first. Tests avoid any other case where the
;;;   two kinds overlap.
;;; - `colotomy`, `pattern` and `score` raise `not-implemented` whatever
;;;   their contents. Where `not-implemented` falls in the check order is
;;;   not fixed, so only checks 1 to 4 are tested against it.
;;; - A key in a scale's or stroke set's degrees is `option-after-body`;
;;;   a key before the degrees is `unknown-option` (they take none).
;;; - `(part :name p 1 2)` has no instrument: `bad-form`.
;;;
;;; Slice feat/music-rep (slice 3, [rep]): parts with `(rep N TOKEN ...)`;
;;; `bad-rep` at the rep's own line (03, "Error reporting" and slice 3's
;;; decided bullets), other errors inside a rep at the part's line. As in
;;; tests/expand.scm, bad-rep's time is where the rep starts.
;;;
;;; Slice feat/music-colotomy (slice 4, [colotomy]): `colotomy` forms in
;;; a piece or a template, `:colotomy` and `:pickup`, `||` checks,
;;; lengths of the pickup plus whole cycles, the generated parts (the
;;; colotomy's, then the timekeeper `kempli`, always generated, on the
;;; piece's `kempli` instrument or a built-in one), `part-origin`,
;;; `piece-pickup` and `piece-colotomies`. Existing tests now expect the
;;; generated `kempli` at the end of `piece-parts`, and, when the piece
;;; has a `kempli` instrument, a default group for it; tests of part
;;; lines and files look at the written parts only. examples/tenzer1.nts
;;; loses its written kempli part (the generated one has the same
;;; strokes).
;;; Choices made where the docs are not explicit:
;;; - The timekeeper is generated even for a piece of length 0: a part
;;;   `kempli` with no events (and a default group when the piece has a
;;;   `kempli` instrument).
;;; - Without a colotomy, the timekeeper's location is not fixed; only
;;;   its origin, instrument and events are tested.
;;; - The colotomy in `piece-colotomies` starts at time 0.
;;; - `||` is tested through the reader only: it is checked against the
;;;   piece's colotomy and pickup, which `expand-tokens` is not given
;;;   (its interface for that is not documented), so tests/expand.scm is
;;;   unchanged.
;;; - `||` at time 0 with no pickup is on a cycle boundary.
;;; - `:pickup 0` without `:colotomy` is still `no-colotomy`.
;;; - `:pickup 1.5` is `bad-option` (03, "Options"); `-1`, `1/2` and a
;;;   pickup longer than the cycle are `bad-pickup`.
;;; - `incomplete-cycle` and `colotomy-part-length` are checked for kind,
;;;   line and (for the latter) part; their `time` is not fixed.
;;; - A malformed colotomy is written on one line, so the colotomy's line
;;;   and the line of a part list inside it are the same.
;;; - unequal-length comes before incomplete-cycle (the order of check
;;;   14).
;;;
;;; Slice feat/music-patterns (slice 5, [patterns]): `pattern` forms in a
;;; piece or a template, checked where they are defined (step 8, check
;;; 11); `@NAME` and `(@ NAME :step :short :long)` in parts; spans
;;; (`part-spans`) and `piece-patterns`; errors at a use with the part,
;;; the time in the piece and the uses, innermost first, as
;;; (PATTERN . LINE-OF-ITS-FORM). `pattern` is no longer
;;; `not-implemented`: those tests now cover `score` only, and the
;;; template test that read a pattern now expects it to be checked.
;;; Choices made where the docs are not explicit:
;;; - `uses` lists the patterns the offending token lies inside. For
;;;   `undefined-pattern`, `wrong-instrument` and `pattern-cycle` the
;;;   offending token is the use itself, so the pattern it names is not
;;;   in the list: `@nope` written in a part has uses '().
;;; - `undefined-pattern` and `pattern-cycle` are reported where the
;;;   pattern is used (01, "Errors where the pattern is used"), with the
;;;   part set; tests don't read pieces where such a pattern is unused.
;;; - Errors in a pattern's body where it is defined are at the pattern
;;;   form's line (or a `rep`'s line, for bad-rep), part #f, time within
;;;   the pattern; their `uses` is not tested.
;;; - Option errors in a `(@ ...)` use (bad-option, unknown-option,
;;;   duplicate-option) are at the line of the `(@ ...)` list, like
;;;   bad-pattern-use (03, "Options": "at the line of the list that
;;;   holds the option"); a key with no value is bad-option.
;;; - A `(@ ...)` whose name is missing, not a symbol, or followed by a
;;;   token that is not a key is bad-pattern-use.
;;; - A pattern's `:instrument` that is not a symbol is bad-option, a
;;;   name starting with `:` (no name) is bad-form, and `:step` on a
;;;   pattern form is unknown-option.
;;; - missing-option is check 11 (03 lists it there), so an earlier
;;;   pattern's token error comes before a later pattern's missing
;;;   `:instrument`; bad-form and the option kinds are check 6.
;;; - Spans that start together are not tested for order.
;;;
;;; Milestone 2, slice feat/scores-form (04, "Slices (iteration 2)",
;;; slice 1; 03, step 12 and check 16; 02, the `score` and `group`
;;; records): `score` and `group` forms, the default score, groups with
;;; their effective settings (ADR 0033), `piece-scores` in place of
;;; `piece-groups`, `piece-score`, and the **[scores]** errors this slice
;;; raises. Existing tests that looked at `piece-groups` now look at the
;;; groups of the piece's first score (`default-groups`: the default
;;; score when the file has none), and a group's parts are the parts of
;;; its members. `score` is no longer `not-implemented` as a form: the
;;; tests that used a score to stand for "a form not built yet" use a
;;; score with an option a later slice builds (`:labels`; `:font-size`
;;; until slice feat/scores-contract), which is
;;; `not-implemented` at the score's line.
;;; Choices made where the docs are not explicit (or disagree):
;;; - Check 6 ("the shape and options of each form") and check 16
;;;   ("each score: its options, then each group") both name a score's
;;;   options. Tests order option errors only within check 16 (a score's
;;;   options before its groups, a group's options before its members),
;;;   and a score's top-level shape (`(score)`) as check 6.
;;; - A group's errors (`bad-form`, its option kinds, `undefined-part`,
;;;   `part-in-two-groups`, `mixed-pitched-group`, `pitched-with-strokes`,
;;;   `option-wrong-level`, `not-implemented`) are at the group's line;
;;;   tests write each group, with its members, on one line, so that
;;;   the group's line and a member list's line are the same.
;;; - `part-in-two-groups` is at the line of the group where the part
;;;   comes the second time; its `part` field is not tested.
;;; - `undefined-part`, `mixed-pitched-group` and `pitched-with-strokes`
;;;   have `part` set as 03 says; `time` is #f for every score error.
;;; - A score-only option on a group is `option-wrong-level` for the
;;;   options this slice reads (`:title`, `:system-length`,
;;;   `:cell-width`, `:cell-height`); the score-only options of later
;;;   slices on a group are not tested (either kind would do).
;;; - `not-implemented` is tested with valid values for each later
;;;   option, on the score and (for the options a group takes) on a
;;;   group, at that form's line.
;;; - `:system-length` takes an exact positive integer here; 0, a
;;;   negative number, a decimal, a string and a symbol are
;;;   `bad-option`. Fractions are not tested.
;;; - A LENGTH is a string of a number and one of Typst's units; "2em",
;;;   "2.5em", "4mm", "10pt", "1cm" and "0.5in" read, and "3", "em",
;;;   "three em", a number and a symbol are `bad-option`.
;;; - Colours are tested in lowercase only, `:palette ()` is
;;;   `bad-option` (make-style refuses an empty list), and `:colors`
;;;   entries are `(DEGREE "#rrggbb")` lists, stored as
;;;   `(DEGREE . "#rrggbb")` pairs. A group's `:colors` replaces the
;;;   score's whole list; it is not merged with it.
;;; - The default score's `cycle-numbers?` is #t with a colotomy and #f
;;;   without (01: "yes with a colotomy"); `font-size` is #f (02).
;;; - A file with scores has no default score: `piece-scores` is exactly
;;;   its scores, in file order.
;;;
;;; Slice feat/scores-contract (04, "Slices (iteration 2)", slice 2 and
;;; its decided bullets; 01, the score options; 03, [scores]): the
;;; reader now reads, on a score, `:cycle-numbers`, `:pulse-numbers`,
;;; `:numbering`, `:pulse-label`, `:subtitle`, `:caption` and
;;; `:font-size`; they leave the `not-implemented` list, and the tests
;;; that used `:font-size` or `:caption` to stand for "an option not
;;; built yet" use `:labels short` or `:breaks (3)` instead.
;;; Choices made where the docs are not explicit:
;;; - yes/no options are stored as #t/#f; `:numbering` as the symbol
;;;   written; strings and lengths as written.
;;; - `:cycle-numbers yes` on a piece without a colotomy reads (layout
;;;   then prints no cycle row, 04 slice 2); the value stored is not
;;;   tested.
;;; - `:font-size` takes a LENGTH like `:cell-width` (01: "A LENGTH is
;;;   a string holding a Typst length").
;;; - All seven are score-only except `:subtitle` (01: "score, group"),
;;;   so the six others on a group are `option-wrong-level`. Whether a
;;;   score's `:subtitle` becomes its groups' default is not tested.
;;;
;;; Slice feat/scores-rows (04, "Slices (iteration 2)", slice 3 and its
;;; decided bullets; 01, `:rows`, `:fill`, `:holds` and "Rules"; 02,
;;; invariant 7; 03, [scores]): the reader now reads `:rows
;;; notes|parts|single`, `:fill colour|none` and `:holds none|dash` on a
;;; score and on a group; they leave the `not-implemented` lists, and
;;; the two tests that used `:holds dash` or `:rows parts` to stand for
;;; "a group option not built yet" use `:labels long` instead. New
;;; cases: `needs-note-names` and `notes-collide`.
;;; Choices made where the docs are not explicit:
;;; - `:fill color` (American spelling) is `bad-option`: the choices are
;;;   `colour` and `none`.
;;; - `needs-note-names` is at the group's line, whether `:rows` or
;;;   `:fill` was set on the group or inherited from the score; only its
;;;   kind and line are tested.
;;; - `notes-collide`: `part` is the later of the two parts in the
;;;   group's member order, `time` the time of the first column where two
;;;   notes sound. Tests write members in file order, so "later" means
;;;   the same either way. With three parts, the earliest shared column
;;;   decides, and the later part of the pair sounding there is named.
;;; - A chord in one part on a `single` row is not a collision: 04 draws
;;;   it as one event on that row.
;;; - `needs-note-names` (the group's options) comes before
;;;   `notes-collide` (the checks that need the music), and a later
;;;   group's member errors come before an earlier group's collision
;;;   (03, check 16: "then the checks that need the music"); a score's
;;;   collision comes before a later score's errors.

(use-modules (srfi srfi-1)
             (srfi srfi-64)
             (ice-9 exceptions)
             (ice-9 match)
             (ice-9 rdelim)
             (notasi piece)
             (notasi reader))

;;; ------------------------------------------------------------------
;;; Helpers

(define (catch-syntax-error thunk)
  "Run THUNK. Return the condition it raises, or the symbol no-error
if it returns normally. Conditions that are not &notasi-syntax-error
are returned too, so a wrong condition type fails the kind checks."
  (guard (c (#t c))
    (thunk)
    'no-error))

(define (kind-of c)
  (if (notasi-syntax-error? c) (notasi-syntax-error-kind c) c))

(define (error-kind+line thunk)
  "Run THUNK and return (KIND LINE) of the &notasi-syntax-error it
raises, or the raised object (or no-error) unchanged."
  (let ((c (catch-syntax-error thunk)))
    (if (notasi-syntax-error? c)
        (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c))
        c)))

(define (string-error str)
  "(KIND LINE) for reading STR with read-piece-string."
  (error-kind+line (lambda () (read-piece-string str))))

(define (string-kind str)
  "KIND only, for errors whose line the doc does not fix."
  (kind-of (catch-syntax-error (lambda () (read-piece-string str)))))

(define (lines . strs)
  "Join STRS with newlines, so line numbers in tests are easy to see."
  (string-join strs "\n"))

(define (try-read thunk)
  "Run THUNK and return the piece it reads, or #f if it raises. A test
that then takes a field of #f fails with an error instead of stopping
the whole file."
  (guard (c (#t #f)) (thunk)))

(define (try-read-string . strs)
  "Read the lines STRS as a piece, or #f if reading raises."
  (try-read (lambda () (read-piece-string (apply lines strs)))))

(define (valid-guile-line? line)
  (and (integer? line) (exact? line) (>= line 1)))

(define (line-in file prefix)
  "The number of the first line of FILE that starts with PREFIX, after
leading blanks. Used for the repository's templates and examples, so
tests follow their layout instead of hard-coding it."
  (call-with-input-file file
    (lambda (port)
      (let loop ((n 1))
        (let ((line (read-line port)))
          (cond ((eof-object? line) (error "no line starting with" prefix file))
                ((string-prefix? prefix (string-trim line)) n)
                (else (loop (+ n 1)))))))))

;;; Temporary files for read-piece-file.

(define tmp-dir
  (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp") "/notasi-XXXXXX")))

(define tmp-files '())

(define (write-temp-file name contents)
  "Write CONTENTS to NAME inside tmp-dir and return its path."
  (let ((path (string-append tmp-dir "/" name)))
    (call-with-output-file path
      (lambda (port) (display contents port)))
    (set! tmp-files (cons path tmp-files))
    path))

(define (remove-temp-files)
  (for-each (lambda (f) (when (file-exists? f) (delete-file f))) tmp-files)
  (rmdir tmp-dir))

;;; A pattern on an instrument no fixture defines (ugal is not defined
;;; where this is used), and a score with an option a later slice
;;; builds, which is not-implemented at its line.
(define pattern-form "(pattern polos-1 :instrument ugal 1 2)")
(define score-form "(score full :labels short (group \"Ugal\" ugal))")

(define (default-groups pc)
  "The groups of PC's first score: its default score when the file has
none (what v1 called piece-groups)."
  (score-groups (car (piece-scores pc))))

(define (member-parts g)
  "The part records of G's members, in order."
  (map car (group-members g)))

(test-begin "reader")

;;; ------------------------------------------------------------------
;;; Successful reads

(test-group "successful read"
  (let ((pc (try-read-string "(piece \"Only a title\")")))
    (test-assert "returns a piece record" (piece? pc))
    (test-equal "title" "Only a title" (piece-title pc))
    (test-equal "length is 0" 0 (piece-length pc))
    (test-equal "no scales" '() (piece-scales pc))
    (test-equal "no instruments" '() (piece-instruments pc))
    (test-equal "no written parts: only the timekeeper, with no events"
      '((kempli timekeeper ()))
      (map (lambda (p) (list (part-name p) (part-origin p) (part-events p)))
           (piece-parts pc)))
    (test-equal "no groups: the built-in kempli is not printed" '()
      (default-groups pc))
    (test-equal "pickup 0" 0 (piece-pickup pc))
    (test-equal "no colotomies" '() (piece-colotomies pc)))

  (let ((pc (try-read-string "(piece" "  \"Over two lines\")")))
    (test-equal "a title on the next line" "Over two lines"
      (and pc (piece-title pc)))))

(test-group "comments and whitespace"
  (let ((pc (try-read
             (lambda ()
              (read-piece-string
               (lines ""
                    ";; A comment before the piece form"
                    "   "
                    "#| a block"
                    "   comment |#"
                    "\t(piece ; trailing comment"
                    "   \"Commented\"      ; the title on the next line"
                    "   )"
                    ""
                    "; comment at the end"
                    ""))))))
    (test-equal "title after comments" "Commented" (piece-title pc)))

  (test-equal "empty title string is a string" ""
    (piece-title (read-piece-string "(piece \"\")"))))

;;; ------------------------------------------------------------------
;;; Step 1: read options. `:key` is an ordinary symbol, and the caller's
;;; read options are restored afterwards.

(test-group "read options"
  (let ((before (read-options)))
    (catch-syntax-error
     (lambda () (read-piece-string "(piece \"P\")")))
    (test-equal "restored after a read" before (read-options))
    (catch-syntax-error (lambda () (read-piece-string "(piece \"P\"")))
    (test-equal "restored after a read-error" before (read-options))
    (catch-syntax-error (lambda () (read-piece-string "(piece \"P\" :tempo 60)")))
    (test-equal "restored after a notasi-syntax-error" before (read-options)))

  (let ((saved (read-options)))
    (dynamic-wind
      (lambda () (read-set! keywords 'prefix))
      (lambda ()
        (test-equal "`:key` is a key even when the caller reads :x as a keyword"
          '(p kempli)
          (map part-name
               (piece-parts
                (read-piece-string
                 (lines "(piece \"P\")" "(strokes k K)" "(instrument kempli k K)"
                        "(part kempli :name p K)")))))
        (test-equal "the caller's keywords option is restored"
          'prefix
          (begin
            (catch-syntax-error
             (lambda () (read-piece-string "(piece \"P\" :tempo 3)")))
            (cadr (memq 'keywords (read-options))))))
      (lambda () (read-set! keywords (cadr (memq 'keywords saved)))))))

;;; ------------------------------------------------------------------
;;; The three entry points

(test-group "read-piece-string"
  (test-equal "#:directory is accepted" "D"
    (piece-title (read-piece-string "(piece \"D\")" #:directory tmp-dir)))
  (let ((c (catch-syntax-error (lambda () (read-piece-string "(foo)")))))
    (test-assert "raises a notasi-syntax-error" (notasi-syntax-error? c))
    (test-equal "file is #f" #f (notasi-syntax-error-file c))))

(test-group "read-piece-port"
  (let ((pc (try-read
             (lambda ()
               (call-with-input-string "(piece \"From a port\")"
                 read-piece-port)))))
    (test-equal "title" "From a port" (piece-title pc))
    (test-equal "length" 0 (piece-length pc)))
  (test-equal "#:directory is accepted" "D"
    (piece-title (call-with-input-string "(piece \"D\")"
                   (lambda (p) (read-piece-port p #:directory tmp-dir)))))
  (let ((c (catch-syntax-error
            (lambda ()
              (call-with-input-string (lines "(piece \"P\")" "" "(bogus)")
                read-piece-port)))))
    (test-assert "raises a notasi-syntax-error" (notasi-syntax-error? c))
    (test-equal "kind" 'unknown-form (kind-of c))
    (test-equal "file is #f for a string port" #f (notasi-syntax-error-file c))
    (test-equal "line" 3 (notasi-syntax-error-line c))))

(test-group "read-piece-file"
  (let* ((path (write-temp-file "ok.nts"
                                (lines ";; a piece" "(piece \"From a file\")" "")))
         (pc (try-read (lambda () (read-piece-file path)))))
    (test-equal "title" "From a file" (piece-title pc))
    (test-equal "length 0" 0 (piece-length pc)))

  (let* ((path (write-temp-file "dup.nts"
                                (lines "(piece \"A\")" ";; again" "(piece \"B\")")))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "error kind" 'duplicate-piece (kind-of c))
    (test-equal "error file is the path given" path
      (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
    (test-equal "error line" 3
      (and (notasi-syntax-error? c) (notasi-syntax-error-line c))))

  (let* ((path (write-temp-file "missing.nts" ";; nothing here\n"))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "missing-piece kind" 'missing-piece (kind-of c))
    (test-equal "missing-piece file is the path given" path
      (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
    (test-equal "missing-piece line is #f" #f
      (and (notasi-syntax-error? c) (notasi-syntax-error-line c))))

  (let* ((path (write-temp-file "unbalanced.nts"
                                (lines "(piece \"P\")" "" "(part a 1 2")))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "read-error kind" 'read-error (kind-of c))
    (test-equal "read-error file is the path given" path
      (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
    (test-assert "read-error line is an exact integer >= 1"
      (and (notasi-syntax-error? c)
           (valid-guile-line? (notasi-syntax-error-line c))))))

;;; ------------------------------------------------------------------
;;; The condition type

(test-group "condition type"
  (let ((c (catch-syntax-error
            (lambda () (read-piece-string (lines "(piece \"A\")" "(piece \"B\")"))))))
    (test-assert "notasi-syntax-error?" (notasi-syntax-error? c))
    (test-assert "is an &error" (error? c))
    (test-assert "carries a &message" (exception-with-message? c))
    (test-assert "message is a string" (string? (exception-message c)))
    (test-equal "kind is a symbol" 'duplicate-piece (notasi-syntax-error-kind c))
    (test-equal "file" #f (notasi-syntax-error-file c))
    (test-equal "line" 2 (notasi-syntax-error-line c))
    (test-equal "part is #f for a piece-form error" #f
      (notasi-syntax-error-part c))
    (test-equal "time is #f for a piece-form error" #f
      (notasi-syntax-error-time c))
    (test-equal "uses is '() for a piece-form error" '()
      (notasi-syntax-error-uses c)))
  (test-assert "predicate is #f for other conditions"
    (not (notasi-syntax-error?
          (make-exception (make-error) (make-exception-with-message "x")))))
  (test-assert "predicate is #f for non-conditions"
    (not (notasi-syntax-error? 'duplicate-piece))))

;;; ------------------------------------------------------------------
;;; Step 1: read errors

(test-group "read-error"
  (for-each
   (match-lambda
     ((name str)
      (let ((c (catch-syntax-error (lambda () (read-piece-string str)))))
        (test-equal (string-append name ": kind") 'read-error (kind-of c))
        (test-equal (string-append name ": file is #f") #f
          (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
        (test-assert (string-append name ": line is an exact integer >= 1")
          (and (notasi-syntax-error? c)
               (valid-guile-line? (notasi-syntax-error-line c)))))))
   (list (list "missing close paren" "(piece \"P\"")
         (list "missing close paren on a later line"
               (lines "(piece \"P\")" "" "(part a 1 2"))
         (list "extra close paren" (lines "(piece \"P\"))"))
         (list "dot dot" (lines "(piece \"P\")" "(part a 1 . . 2)"))
         (list "unterminated string" "(piece \"P)")))

  (test-equal "read-error comes before missing-piece" 'read-error
    (string-kind (lines "(foo" "")))
  (test-equal "read-error comes before unknown-form" 'read-error
    (string-kind (lines "(foo)" "(piece \"P\")" "(bar")))
  (test-equal "read-error after a bad form still wins (all forms read first)"
    'read-error
    (string-kind (lines "(piece 42)" "(part a 1 . 2)" "(")))
  (test-equal "read-error comes before improper-form" 'read-error
    (string-kind (lines "(piece \"P\")" "(part a 1 . 2)" "(part a . . b)")))
  (test-equal "read-error comes before group-outside-score" 'read-error
    (string-kind (lines "(piece \"P\")" "(group \"G\" a)" "("))))

;;; ------------------------------------------------------------------
;;; Step 2: dispatch

(test-group "improper-form"
  (test-equal "lone dot in a part, line 3" '(improper-form 3)
    (string-error (lines "(piece \"P\")" "" "(part reyong :name polos 1 . 2)")))
  (test-equal "improper piece form, line 1" '(improper-form 1)
    (string-error "(piece \"P\" . 4)"))
  (test-equal "improper form before piece: improper-form, not piece-not-first"
    '(improper-form 1)
    (string-error (lines "(part a 1 . 2)" "(piece \"P\")")))
  (test-equal "improper form with no piece: improper-form, not missing-piece"
    '(improper-form 2)
    (string-error (lines ";; no piece" "(part a 1 . 2)")))
  (test-equal "improper form comes before bad-title" '(improper-form 2)
    (string-error (lines "(piece 1)" "(scale . \"x\")"))))

(test-group "unknown-form"
  (test-equal "unknown head, line 1" '(unknown-form 1)
    (string-error (lines "(foo 1 2)" "(piece \"P\")")))
  (test-equal "unknown head after piece, line 3" '(unknown-form 3)
    (string-error (lines "(piece \"P\")" "" "(foo 1 2)")))
  (test-equal "head is case-sensitive" '(unknown-form 2)
    (string-error (lines "(piece \"P\")" "(Part a 1)")))
  (test-equal "head is a string, not a symbol" '(unknown-form 2)
    (string-error (lines "(piece \"P\")" "(\"part\" a 1)")))
  (test-equal "head is a number" '(unknown-form 2)
    (string-error (lines "(piece \"P\")" "(42 a b)")))
  (test-equal "head is a list" '(unknown-form 2)
    (string-error (lines "(piece \"P\")" "((part) a b)")))
  (test-equal "head is a key" '(unknown-form 2)
    (string-error (lines "(piece \"P\")" "(:part a 1)")))
  ;; Atoms carry no source position, so only the kind is checked.
  (test-equal "top-level symbol" 'unknown-form
    (string-kind (lines "(piece \"P\")" "foo")))
  (test-equal "top-level key" 'unknown-form
    (string-kind (lines "(piece \"P\")" ":steps-per-pulse")))
  (test-equal "top-level number" 'unknown-form
    (string-kind (lines "(piece \"P\")" "42")))
  (test-equal "top-level string" 'unknown-form
    (string-kind (lines "(piece \"P\")" "\"hello\"")))
  (test-equal "top-level empty list" 'unknown-form
    (string-kind (lines "(piece \"P\")" "()")))
  (test-equal "top-level vector" 'unknown-form
    (string-kind (lines "(piece \"P\")" "#(1 2)")))
  (test-equal "unknown form before missing piece: unknown-form" '(unknown-form 2)
    (string-error (lines ";; no piece" "(foo)")))
  (test-equal "unknown form after a misplaced piece: unknown-form, not piece-not-first"
    '(unknown-form 3)
    (string-error (lines "(scale s a)" "(piece \"P\")" "(foo)")))
  (test-equal "unknown form after a duplicate piece: unknown-form" '(unknown-form 3)
    (string-error (lines "(piece \"A\")" "(piece \"B\")" "(foo)")))
  (test-equal "unknown form after a bad title: unknown-form" '(unknown-form 2)
    (string-error (lines "(piece 1)" "(foo)")))
  (test-equal "unknown form after a bad option: unknown-form" '(unknown-form 4)
    (string-error (lines "(piece \"P\" 4)" "" "" "(foo)")))
  (test-equal "first bad form in file order wins: improper then unknown"
    '(improper-form 2)
    (string-error (lines "(piece \"P\")" "(part a 1 . 2)" "(foo)")))
  (test-equal "first bad form in file order wins: unknown then improper"
    '(unknown-form 2)
    (string-error (lines "(piece \"P\")" "(foo)" "(part a 1 . 2)"))))

;;; v1's `text` form is gone: it is an unknown form now (03, "Files and
;;; forms").
(test-group "text is an unknown form"
  (test-equal "text after piece" '(unknown-form 2)
    (string-error (lines "(piece \"P\")" "(text \"A note\")")))
  (test-equal "text on line 4" '(unknown-form 4)
    (string-error (lines "(piece \"P\")" "" ";; c" "(text \"x\")")))
  (test-equal "text before piece: unknown-form, not piece-not-first"
    '(unknown-form 1)
    (string-error (lines "(text \"x\")" "(piece \"P\")")))
  (test-equal "text with no piece: unknown-form, not missing-piece"
    '(unknown-form 1)
    (string-error "(text \"x\")"))
  (test-equal "text comes before bad-title" '(unknown-form 2)
    (string-error (lines "(piece 1)" "(text \"x\")"))))

;;; A top-level group is its own error: groups are written in scores
;;; (ADR 0031). It is found with the other form checks (item 2).
(test-group "group-outside-score"
  (for-each
   (match-lambda
     ((name expected str)
      (test-equal name expected (string-error str))))
   (list
    (list "after piece" '(group-outside-score 3)
          (lines "(piece \"P\")" "" "(group \"G\" a)"))
    (list "with iteration 2 options" '(group-outside-score 2)
          (lines "(piece \"P\")" "(group \"Reyong\" :subtitle \"x\" polos sangsih)"))
    (list "a v1 group with a list option" '(group-outside-score 2)
          (lines "(piece \"P\")" "(group \"G\" a (subtitle \"x\"))"))
    (list "an empty group" '(group-outside-score 2)
          (lines "(piece \"P\")" "(group)"))
    (list "multi-line: the form's line" '(group-outside-score 2)
          (lines "(piece \"P\")" "(group \"G\"" "  a b)"))
    (list "before the piece: not piece-not-first" '(group-outside-score 1)
          (lines "(group \"G\" a)" "(piece \"P\")"))
    (list "with no piece: not missing-piece" '(group-outside-score 2)
          (lines ";; no piece" "(group \"G\" a)"))
    (list "before a duplicate piece" '(group-outside-score 2)
          (lines "(piece \"A\")" "(group \"G\" a)" "(piece \"B\")"))
    (list "before bad-title" '(group-outside-score 2)
          (lines "(piece 1)" "(group \"G\" a)"))
    (list "before bad-option" '(group-outside-score 2)
          (lines "(piece \"P\" 4)" "(group \"G\" a)"))
    (list "file order: an unknown form first" '(unknown-form 2)
          (lines "(piece \"P\")" "(foo)" "(group \"G\" a)"))
    (list "file order: the group first" '(group-outside-score 2)
          (lines "(piece \"P\")" "(group \"G\" a)" "(foo)"))
    (list "file order: an improper form first" '(improper-form 2)
          (lines "(piece \"P\")" "(part a 1 . 2)" "(group \"G\" a)"))
    (list "the first of two groups" '(group-outside-score 3)
          (lines "(piece \"P\")" "(part reyong 1)" "(group \"A\" reyong)"
                 "(group \"B\" reyong)"))
    (list "a group inside a score is not top-level" '(undefined-part 2)
          (lines "(piece \"P\")" "(score full (group \"G\" a))"))))
  (let ((c (catch-syntax-error
            (lambda () (read-piece-string (lines "(piece \"P\")" "(group \"G\" a)"))))))
    (test-equal "fields: file, part and time #f" '(#f #f #f)
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-file c) (notasi-syntax-error-part c)
                 (notasi-syntax-error-time c)))))
  (let* ((path (write-temp-file "group.nts"
                                (lines "(piece \"P\")" ";; c" "(group \"G\" a)")))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "from a file: kind, file and line"
      (list 'group-outside-score path 3)
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-kind c) (notasi-syntax-error-file c)
                 (notasi-syntax-error-line c))))))

;;; ------------------------------------------------------------------
;;; Step 3: the piece form is present, first and only once

(test-group "missing-piece"
  (test-equal "empty string" '(missing-piece #f) (string-error ""))
  (test-equal "only whitespace and comments" '(missing-piece #f)
    (string-error (lines "  " ";; comment" "#| block |#" "")))
  (test-equal "only not-yet-implemented forms: missing-piece, not not-implemented"
    '(missing-piece #f)
    (string-error (lines "(scale selisir ding dong)" score-form))))

(test-group "piece-not-first"
  (test-equal "use before piece" '(piece-not-first 1)
    (string-error (lines "(use gong-kebyar)" "(piece \"P\")")))
  (test-equal "scale before piece, after comments" '(piece-not-first 3)
    (string-error (lines ";; c" "" "(scale selisir ding)" "(piece \"P\")")))
  (test-equal "piece-not-first comes before bad-title" '(piece-not-first 1)
    (string-error (lines "(scale s a)" "(piece 1)")))
  (test-equal "piece-not-first comes before not-implemented" '(piece-not-first 1)
    (string-error (lines score-form "(piece \"P\")"))))

(test-group "duplicate-piece"
  (test-equal "second piece on line 2" '(duplicate-piece 2)
    (string-error (lines "(piece \"A\")" "(piece \"B\")")))
  (test-equal "second piece on line 4" '(duplicate-piece 4)
    (string-error (lines "(piece \"A\")" "" ";; again" "(piece \"B\")")))
  (test-equal "identical duplicate is still a duplicate" '(duplicate-piece 2)
    (string-error (lines "(piece \"A\")" "(piece \"A\")")))
  (test-equal "duplicate-piece comes before bad-title" '(duplicate-piece 2)
    (string-error (lines "(piece 1)" "(piece 2)")))
  (test-equal "duplicate-piece comes before bad-option" '(duplicate-piece 2)
    (string-error (lines "(piece \"A\" 4)" "(piece \"B\")")))
  (test-equal "duplicate-piece comes before not-implemented" '(duplicate-piece 3)
    (string-error (lines "(piece \"A\")" score-form "(piece \"B\")"))))

;;; ------------------------------------------------------------------
;;; Step 4: title and options. Option errors are at the line of the list
;;; that holds the option: the piece form, wherever the key is.

(test-group "bad-title"
  (test-equal "title is a symbol" '(bad-title 1) (string-error "(piece title)"))
  (test-equal "title is a number" '(bad-title 1) (string-error "(piece 42)"))
  (test-equal "title is missing" '(bad-title 1) (string-error "(piece)"))
  (test-equal "title missing, an option in its place" '(bad-title 1)
    (string-error "(piece :pickup 1)"))
  (test-equal "title is a list" '(bad-title 1)
    (string-error "(piece (\"P\"))"))
  (test-equal "bad title on line 3" '(bad-title 3)
    (string-error (lines ";; c" "" "(piece #t)")))
  (test-equal "bad-title comes before bad-option" '(bad-title 1)
    (string-error "(piece 1 4)"))
  (test-equal "bad-title comes before unknown-option" '(bad-title 1)
    (string-error "(piece 1 :tempo 60)"))
  (test-equal "bad-title comes before not-implemented" '(bad-title 1)
    (string-error (lines "(piece 1)" score-form))))

(test-group "bad-option"
  ;; `piece` takes no options in this slice, so a bad-option is anything
  ;; after the title that is not a `:key value` pair. A key with no value
  ;; is not tested here: every key is unknown until slice 4, and which of
  ;; the two errors comes first is not fixed (part options test it).
  (for-each
   (match-lambda
     ((name str)
      (test-equal name '(bad-option 1) (string-error str))))
   (list (list "a value with no key: a number" "(piece \"P\" 4)")
         (list "a value with no key: a string" "(piece \"P\" \"subtitle\")")
         (list "a v1 option without its colon" "(piece \"P\" steps-per-pulse 4)")
         (list "a v1 list option" "(piece \"P\" (steps-per-pulse 4))")))
  (test-equal "bad option on line 2" '(bad-option 2)
    (string-error (lines ";; c" "(piece \"P\" 4)")))
  (test-equal "an option on the next line: the piece form's line" '(bad-option 1)
    (string-error (lines "(piece \"P\"" "  4)")))
  (test-equal "bad-option comes before not-implemented" '(bad-option 1)
    (string-error (lines "(piece \"P\" 4)" score-form))))

(test-group "unknown-option"
  (test-equal "unknown key" '(unknown-option 1)
    (string-error "(piece \"P\" :tempo 60)"))
  ;; The transitional options of slice 1 are gone (03, slice 2).
  (test-equal ":steps-per-pulse is gone" '(unknown-option 1)
    (string-error "(piece \"P\" :steps-per-pulse 4)"))
  (test-equal ":steps-per-system is gone" '(unknown-option 1)
    (string-error "(piece \"P\" :steps-per-system 16)"))
  (test-equal "both are gone" '(unknown-option 1)
    (string-error "(piece \"P\" :steps-per-pulse 4 :steps-per-system 16)"))
  (test-equal ":steps-per-pulse with a bad value: still unknown-option"
    '(unknown-option 1)
    (string-error "(piece \"P\" :steps-per-pulse 0)"))
  ;; :colotomy and :pickup are taken since slice 4: see "[colotomy]".
  (test-equal "keys are case-sensitive" '(unknown-option 1)
    (string-error "(piece \"P\" :Steps-Per-Pulse 4)"))
  (test-equal "a part's key is not a piece key" '(unknown-option 1)
    (string-error "(piece \"P\" :name p)"))
  (test-equal "unknown key on line 3" '(unknown-option 3)
    (string-error (lines "" "" "(piece \"P\" :subtitle \"x\")")))
  (test-equal "an unknown key on the next line: the piece form's line"
    '(unknown-option 1)
    (string-error (lines "(piece \"P\"" "  :steps-per-pulse 4)")))
  (test-equal "unknown-option comes before not-implemented" '(unknown-option 1)
    (string-error (lines "(piece \"P\" :tempo 60)" score-form))))

;;; v1's duplicate-option tests of the piece form are gone: the piece
;;; takes no options in this slice, so a key given twice is first an
;;; unknown key. `part options` tests duplicate-option.

;;; ------------------------------------------------------------------
;;; A score with an option a later slice builds is not-implemented at
;;; the score's line (04, slice 1); the [scores] section below tests
;;; every such option.

(test-group "not-implemented"
  (test-equal "a score option not built yet: not-implemented at the score's line"
    '(not-implemented 3)
    (string-error (lines "(piece \"P\")" ";; next" score-form)))
  (test-equal "a multi-line score: the form's line" '(not-implemented 2)
    (string-error (lines "(piece \"P\")" "(score full :labels short"
                         "  (group \"G\" a))")))
  (test-equal "the first not-implemented score in file order" '(not-implemented 4)
    (string-error (lines "(piece \"P\")" "" "" score-form
                         "(score other :breaks (3) (group \"G\" a))")))
  (let ((c (catch-syntax-error
            (lambda () (read-piece-string (lines "(piece \"P\")" score-form))))))
    (test-equal "not-implemented: file #f" #f
      (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
    (test-equal "not-implemented: part field #f" #f
      (and (notasi-syntax-error? c) (notasi-syntax-error-part c)))
    (test-equal "not-implemented: time field #f" #f
      (and (notasi-syntax-error? c) (notasi-syntax-error-time c))))
  (let* ((path (write-temp-file "score.nts" (lines "(piece \"P\")" score-form)))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "not-implemented from a file: kind" 'not-implemented (kind-of c))
    (test-equal "not-implemented from a file: file" path
      (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
    (test-equal "not-implemented from a file: line" 2
      (and (notasi-syntax-error? c) (notasi-syntax-error-line c)))))

;;; ==================================================================
;;; Scale, strokes and instrument forms
;;; ==================================================================

;;; ------------------------------------------------------------------
;;; Helpers

(define (find-named name-of name lst)
  "The element of LST whose NAME-OF is NAME. Raises if there is none,
so a test using it fails rather than passing on #f."
  (or (find (lambda (x) (eq? (name-of x) name)) lst)
      (error "not found:" name)))

(define (scale-named pc name) (find-named scale-name name (piece-scales pc)))
(define (instrument-named pc name)
  (find-named instrument-name name (piece-instruments pc)))

(define (note-fields n)
  "A note as (NAME DEGREE OCTAVE)."
  (list (note-name n) (note-degree n) (note-octave n)))

(define (instrument-note-fields inst)
  (map note-fields (vector->list (instrument-notes inst))))

(define (location-line x)
  (source-location-line
   (cond ((scale? x) (scale-location x))
         ((degree? x) (degree-location x))
         ((instrument? x) (instrument-location x))
         (else (error "no location:" x)))))

(define (location-file x)
  (source-location-file
   (cond ((scale? x) (scale-location x))
         ((degree? x) (degree-location x))
         ((instrument? x) (instrument-location x))
         (else (error "no location:" x)))))

(define (degree-fields d)
  "A degree as (NAME ALIASES DISPLAY DAMPED)."
  (list (degree-name d) (degree-aliases d) (degree-display d)
        (degree-damped d)))

;;; The main fixture. Line numbers matter: the comments give them.
(define defs-text
  (lines "(piece \"Definitions\")"                          ; 1
         "(strokes gong-strokes G P)"                       ; 2
         "(scale selisir"                                   ; 3
         "  (ding :alias i :display \"i\")"                 ; 4
         "  dong"                                           ; 5
         "  (deng :alias (e ee))"                           ; 6
         "  dung (dang :display \"•\" :damped \"•.\"))"     ; 7
         "(strokes kendang-strokes (dag :alias D :display \"D\") (dug :damped \"d\"))" ; 8
         "(instrument ugal selisir i1 dong1 e1 dung1 dang1 ding2)" ; 9
         "(instrument gong gong-strokes P G)"               ; 10
         "(instrument kendang"                              ; 11
         "  kendang-strokes D dug)"                         ; 12
         ""))

;;; ------------------------------------------------------------------
;;; Successful reads

(test-group "scales and stroke sets"
  (let ((pc (try-read-string defs-text)))
    (test-assert "reads into a piece" (piece? pc))
    (test-equal "scales and stroke sets together, in file order"
      '(gong-strokes selisir kendang-strokes)
      (map scale-name (piece-scales pc)))
    (test-equal "pitched? is #t for scale, #f for strokes"
      '(#f #t #f)
      (map scale-pitched? (piece-scales pc)))
    (test-equal "degree names in order"
      '(ding dong deng dung dang)
      (map degree-name (scale-degrees (scale-named pc 'selisir))))
    (test-equal "aliases: a single name, a list of names, empty by default"
      '((i) () (e ee) () ())
      (map degree-aliases (scale-degrees (scale-named pc 'selisir))))
    (test-equal "display: given, or the name as a string; Unicode works"
      '("i" "dong" "deng" "dung" "•")
      (map degree-display (scale-degrees (scale-named pc 'selisir))))
    (test-equal "damped: given, or #f by default"
      '(#f #f #f #f "•.")
      (map degree-damped (scale-degrees (scale-named pc 'selisir))))
    (test-equal "stroke names in order"
      '(G P)
      (map degree-name (scale-degrees (scale-named pc 'gong-strokes))))
    (test-equal "stroke defaults: no aliases, display is the name, damped #f"
      '((G () "G" #f) (P () "P" #f))
      (map degree-fields (scale-degrees (scale-named pc 'gong-strokes))))
    (test-equal "strokes with :alias, :display and :damped"
      '((dag (D) "D" #f) (dug () "dug" "d"))
      (map degree-fields (scale-degrees (scale-named pc 'kendang-strokes))))
    (test-equal "scale lines" '(2 3 8)
      (map location-line (piece-scales pc)))
    (test-equal "degree lines: own line for a list, scale's line for a bare name"
      '(4 3 6 3 7)
      (map location-line (scale-degrees (scale-named pc 'selisir))))
    (test-equal "stroke lines: bare strokes use the stroke set's line" '(2 2)
      (map location-line (scale-degrees (scale-named pc 'gong-strokes))))
    (test-equal "files are #f when read from a string"
      '(#f #f #f #f #f #f #f #f)
      (append (map location-file (piece-scales pc))
              (map location-file (scale-degrees (scale-named pc 'selisir)))))
    (test-assert "locations are source-location records"
      (every (lambda (d) (source-location? (degree-location d)))
             (scale-degrees (scale-named pc 'selisir)))))

  (let ((pc (try-read-string "(piece \"P\")" "(scale s (ding))")))
    (test-equal "(NAME) with no options: defaults" '(ding () "ding" #f)
      (degree-fields (car (scale-degrees (scale-named pc 's))))))

  (let ((pc (try-read-string "(piece \"P\")" "(strokes s (k1 :alias (k2 kk)) k3)")))
    (test-equal "stroke names and aliases may end in a digit"
      '((k1 (k2 kk)) (k3 ()))
      (map (lambda (d) (list (degree-name d) (degree-aliases d)))
           (scale-degrees (scale-named pc 's))))))

(test-group "degree options"
  (define (degrees . strs)
    (let ((pc (apply try-read-string "(piece \"P\")" strs)))
      (map degree-fields (scale-degrees (car (piece-scales pc))))))
  (test-equal "01's Baris example: :alias list, :display and :damped"
    '((dang (a nang) "nang" "na'"))
    (degrees "(scale s (dang :alias (a nang) :display \"nang\" :damped \"na'\"))"))
  (test-equal ":alias as a list of one name" '((ding (i) "ding" #f))
    (degrees "(scale s (ding :alias (i)))"))
  (test-equal ":damped alone: display still defaults to the name"
    '((ding () "ding" "x"))
    (degrees "(scale s (ding :damped \"x\"))"))
  (test-equal "options in any order"
    '((ding (i) "I" "i'"))
    (degrees "(scale s (ding :damped \"i'\" :alias i :display \"I\"))"))
  (test-equal "options over several lines"
    '((ding (i) "I" "i'"))
    (degrees "(scale s (ding" "  :alias i" "  :display \"I\"" "  :damped \"i'\"))"))
  (test-equal "the empty string is a string"
    '((ding () "" ""))
    (degrees "(scale s (ding :display \"\" :damped \"\"))"))
  (test-equal "a stroke set takes the same options"
    '((G () "G" #f) (GL (L) "G" "g"))
    (degrees "(strokes gongs G (GL :alias L :display \"G\" :damped \"g\"))"))
  (test-equal "a name that only starts with rep is not reserved"
    '((reps () "reps" #f))
    (degrees "(strokes k reps)"))

  (let ((pc (try-read-string "(piece \"P\")"
                             "(scale s (ding :alias (i nding)) (dong :alias o))"
                             "(instrument x s nding1 o1 i2)")))
    (test-equal "every alias in a list resolves in an instrument"
      '((ding1 0 1) (dong1 1 1) (ding2 0 2))
      (instrument-note-fields (instrument-named pc 'x))))

  (let ((pc (try-read-string "(piece \"P\")"
                             "(scale s (dang :alias (a nang) :display \"nang\" :damped \"na'\"))"
                             "(instrument x s nang1)")))
    (test-equal "note-display is the display form, not the damped one" "nang"
      (let ((inst (instrument-named pc 'x)))
        (note-display inst (vector-ref (instrument-notes inst) 0))))))

(test-group "instruments"
  (let ((pc (try-read-string defs-text)))
    (test-equal "instruments in file order" '(ugal gong kendang)
      (map instrument-name (piece-instruments pc)))
    (test-equal "instrument lines" '(9 10 11)
      (map location-line (piece-instruments pc)))
    (test-equal "instrument files are #f from a string" '(#f #f #f)
      (map location-file (piece-instruments pc)))
    (test-assert "instrument scale is the scale record in piece-scales"
      (eq? (instrument-scale (instrument-named pc 'ugal))
           (scale-named pc 'selisir)))
    (test-assert "instrument stroke set is the record in piece-scales"
      (eq? (instrument-scale (instrument-named pc 'gong))
           (scale-named pc 'gong-strokes)))
    (test-assert "notes is a vector"
      (vector? (instrument-notes (instrument-named pc 'ugal))))
    (test-equal "pitched notes: canonical name, degree index, octave"
      '((ding1 0 1) (dong1 1 1) (deng1 2 1) (dung1 3 1) (dang1 4 1) (ding2 0 2))
      (instrument-note-fields (instrument-named pc 'ugal)))
    (test-equal "stroke notes in the instrument's order, octave #f"
      '((P 1 #f) (G 0 #f))
      (instrument-note-fields (instrument-named pc 'gong)))
    (test-equal "stroke notes given by alias are stored by name"
      '((dag 0 #f) (dug 1 #f))
      (instrument-note-fields (instrument-named pc 'kendang)))
    (test-equal "length 0" 0 (piece-length pc))
    (test-equal "no written parts: only the timekeeper" '(kempli)
      (map part-name (piece-parts pc)))
    (test-equal "no groups: no kempli instrument, so it is not printed" '()
      (default-groups pc))
    (test-equal "title" "Definitions" (piece-title pc)))

  (let ((pc (try-read-string "(piece \"P\")"
                             "(scale s ding dong)"
                             "(instrument x s ding0 dong0 ding1)")))
    (test-equal "octave 0 is allowed and below octave 1"
      '((ding0 0 0) (dong0 1 0) (ding1 0 1))
      (instrument-note-fields (instrument-named pc 'x))))

  (let ((pc (try-read-string "(piece \"P\")"
                             "(scale s ding dong)"
                             "(instrument x s dong9 ding10 dong10 ding12)")))
    (test-equal "multi-digit octaves, compared as numbers"
      '((dong9 1 9) (ding10 0 10) (dong10 1 10) (ding12 0 12))
      (instrument-note-fields (instrument-named pc 'x))))

  (let ((pc (try-read-string "(piece \"P\")"
                             "(strokes s k1 (k2 :alias k22) k3)"
                             "(instrument x s k3 k22 k1)")))
    (test-equal "strokes ending in a digit, any order, alias resolved"
      '((k3 2 #f) (k2 1 #f) (k1 0 #f))
      (instrument-note-fields (instrument-named pc 'x))))

  (let ((pc (try-read-string "(piece \"P\")"
                             "(instrument ugal selisir a1 ding2)"
                             "(instrument gong gong G)"
                             "(strokes gong G)"
                             "(scale selisir ding (dang :alias a))")))
    (test-equal "instrument before its scale: scales in file order"
      '(gong selisir)
      (map scale-name (piece-scales pc)))
    (test-equal "instrument before its scale: instruments in file order"
      '(ugal gong)
      (map instrument-name (piece-instruments pc)))
    (test-equal "instrument before its scale: notes resolved"
      '((dang1 1 1) (ding2 0 2))
      (instrument-note-fields (instrument-named pc 'ugal)))
    (test-assert "instrument may share a name with a stroke set"
      (eq? (instrument-scale (instrument-named pc 'gong))
           (scale-named pc 'gong))))

  (let ((pc (try-read-string "(piece \"P\")"
                             "(scale s (ding :alias i :display \"i\") dong)"
                             "(strokes k (dag :display \"D\") G)"
                             "(instrument x s i1 dong1 i2)"
                             "(instrument y k G dag)")))
    (test-equal "note-display on a read instrument" '("i" "dong" "i")
      (let ((inst (instrument-named pc 'x)))
        (map (lambda (n) (note-display inst n))
             (vector->list (instrument-notes inst)))))
    (test-equal "note-label on a read instrument" '("i1" "dong1" "i2")
      (let ((inst (instrument-named pc 'x)))
        (map (lambda (n) (note-label inst n))
             (vector->list (instrument-notes inst)))))
    (test-equal "note-label for strokes is the display" '("G" "D")
      (let ((inst (instrument-named pc 'y)))
        (map (lambda (n) (note-label inst n))
             (vector->list (instrument-notes inst)))))))

(test-group "definitions read from a file"
  (let* ((path (write-temp-file "defs.nts" defs-text))
         (pc (try-read (lambda () (read-piece-file path)))))
    (test-assert "reads into a piece" (piece? pc))
    (test-equal "scale files are the path given" (list path path path)
      (map location-file (piece-scales pc)))
    (test-equal "degree files are the path given"
      (list path path path path path)
      (map location-file (scale-degrees (scale-named pc 'selisir))))
    (test-equal "degree lines from a file" '(4 3 6 3 7)
      (map location-line (scale-degrees (scale-named pc 'selisir))))
    (test-equal "instrument files are the path given" (list path path path)
      (map location-file (piece-instruments pc)))
    (test-equal "instrument lines from a file" '(9 10 11)
      (map location-line (piece-instruments pc)))))

(test-group "definitions read from a port"
  (let ((pc (try-read (lambda ()
                        (call-with-input-string defs-text read-piece-port)))))
    (test-equal "instruments" '(ugal gong kendang)
      (map instrument-name (piece-instruments pc)))
    (test-equal "files are #f from a port" '(#f #f #f)
      (map location-file (piece-scales pc)))))

;;; The contents of templates/selisir.nts (before it had display forms)
;;; and templates/gong-kebyar.nts (without its `use`), pasted into one
;;; file.
(test-group "gong kebyar definitions"
  (let ((pc (try-read-string
             "(piece \"Gong kebyar\")"
             ";; Selisir: the five-tone pelog scale of Balinese gong kebyar."
             ";; Degrees can be written by name (ding) or by vowel (i)."
             ""
             "(scale selisir"
             "  (ding :alias i)"
             "  (dong :alias o)"
             "  (deng :alias e)"
             "  (dung :alias u)"
             "  (dang :alias a))"
             ""
             "(strokes kempli-strokes  K)"
             "(strokes gong-strokes"
             "  G                                           ; gong"
             "  P)                                          ; kempur"
             "(strokes kendang-strokes  dag dug du)"
             ""
             ";; Ugal: 10 keys, o1 (dong1) to i3 (ding3), an octave below the pemade."
             "(instrument ugal    selisir  o1 e1 u1 a1 i2 o2 e2 u2 a2 i3)"
             ""
             ";; Reyong: 12 pots, e1 (deng1) to u3 (dung3)."
             "(instrument reyong  selisir  e1 u1 a1 i2 o2 e2 u2 a2 i3 o3 e3 u3)"
             ""
             "(instrument kempli  kempli-strokes   K)"
             "(instrument gong    gong-strokes     G P)"
             "(instrument kendang kendang-strokes  dag dug du)"
             "")))
    (test-equal "scales" '(selisir kempli-strokes gong-strokes kendang-strokes)
      (map scale-name (piece-scales pc)))
    (test-equal "scale lines" '(5 12 13 16)
      (map location-line (piece-scales pc)))
    (test-equal "selisir degree lines" '(6 7 8 9 10)
      (map location-line (scale-degrees (scale-named pc 'selisir))))
    (test-equal "selisir displays default to names"
      '("ding" "dong" "deng" "dung" "dang")
      (map degree-display (scale-degrees (scale-named pc 'selisir))))
    (test-equal "instruments" '(ugal reyong kempli gong kendang)
      (map instrument-name (piece-instruments pc)))
    (test-equal "instrument lines" '(19 22 24 25 26)
      (map location-line (piece-instruments pc)))
    (test-equal "ugal notes"
      '((dong1 1 1) (deng1 2 1) (dung1 3 1) (dang1 4 1)
        (ding2 0 2) (dong2 1 2) (deng2 2 2) (dung2 3 2) (dang2 4 2)
        (ding3 0 3))
      (instrument-note-fields (instrument-named pc 'ugal)))
    (test-equal "reyong has 12 notes, deng1 to dung3"
      '(12 deng1 dung3)
      (let ((v (instrument-notes (instrument-named pc 'reyong))))
        (list (vector-length v)
              (note-name (vector-ref v 0))
              (note-name (vector-ref v 11)))))
    (test-equal "kendang notes" '((dag 0 #f) (dug 1 #f) (du 2 #f))
      (instrument-note-fields (instrument-named pc 'kendang)))
    (test-equal "reyong lane labels use the default display"
      '("deng1" "dung3")
      (let* ((inst (instrument-named pc 'reyong))
             (v (instrument-notes inst)))
        (list (note-label inst (vector-ref v 0))
              (note-label inst (vector-ref v 11)))))
    (test-equal "length 0, only the timekeeper, its default group"
      '(0 (kempli) ("kempli"))
      (list (piece-length pc) (map part-name (piece-parts pc))
            (map group-label (default-groups pc))))))

;;; ------------------------------------------------------------------
;;; Error cases for definitions. Each checks (KIND LINE).

(define (table-tests expected-kind cases)
  "CASES is a list of (NAME LINE STRING). Check each reads to
(EXPECTED-KIND LINE)."
  (for-each
   (match-lambda
     ((name line str)
      (test-equal name (list expected-kind line) (string-error str))))
   cases))

(test-group "bad-form"
  (table-tests 'bad-form
   (list (list "scale with no name" 2 (lines "(piece \"P\")" "(scale)"))
         (list "scale name is a string" 2
               (lines "(piece \"P\")" "(scale \"selisir\" ding dong)"))
         (list "scale name is a number" 2
               (lines "(piece \"P\")" "(scale 5 ding dong)"))
         (list "scale name is a list" 2
               (lines "(piece \"P\")" "(scale (selisir) ding dong)"))
         (list "scale with no degrees" 2
               (lines "(piece \"P\")" "(scale selisir)"))
         (list "strokes with no name" 2 (lines "(piece \"P\")" "(strokes)"))
         (list "strokes name is a string" 2
               (lines "(piece \"P\")" "(strokes \"gong\" G)"))
         (list "strokes with no strokes" 2
               (lines "(piece \"P\")" "(strokes gong)"))
         (list "instrument with no name" 2
               (lines "(piece \"P\")" "(instrument)"))
         (list "instrument name is a string" 3
               (lines "(piece \"P\")" "(strokes g G)"
                      "(instrument \"gong\" g G)"))
         (list "instrument name is a number" 3
               (lines "(piece \"P\")" "(strokes g G)" "(instrument 1 g G)"))
         (list "instrument with a name only" 3
               (lines "(piece \"P\")" "(strokes g G)" "(instrument gong)"))
         (list "instrument with no notes" 3
               (lines "(piece \"P\")" "(strokes g G)" "(instrument gong g)"))
         (list "bad form on line 4 after comments" 4
               (lines "(piece \"P\")" ";; c" "" "(scale selisir)"))
         (list "first bad form in file order" 3
               (lines "(piece \"P\")" "(scale s ding)" "(instrument x s)"
                      "(scale)")))))

;;; Instruments take no options (ADR 0031): an option anywhere in one,
;;; v1's list form or a :key, is bad-form at the instrument's line.
(test-group "bad-form: an instrument with an option"
  (table-tests 'bad-form
   (list (list "v1's (show-names yes) after the notes" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g G P (show-names yes))"))
         (list ":show-names after the notes" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g G P :show-names yes)"))
         (list ":show-names before the notes" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g :show-names yes G P)"))
         (list "a key with no value" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g G :show-names)"))
         (list "any key, not only show-names" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g G P :name gongs)"))
         (list "an option on its own line: the instrument's line" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g G P" "  :show-names yes)"))
         (list "an option comes before an undefined scale" 2
               (lines "(piece \"P\")" "(instrument gong no-such G :show-names yes)"))
         (list "an option comes before an unknown note" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g Q :show-names yes)")))))

(test-group "scale and stroke set options"
  (table-tests 'unknown-option
   (list (list "a scale takes no keys" 2
               (lines "(piece \"P\")" "(scale s :colour red ding dong)"))
         (list "a stroke set takes no keys" 2
               (lines "(piece \"P\")" "(strokes k :display \"x\" G)"))))
  (table-tests 'option-after-body
   (list (list "a key among a scale's degrees" 2
               (lines "(piece \"P\")" "(scale s ding dong :alias i)"))
         (list "a key among strokes, on a later line: the form's line" 2
               (lines "(piece \"P\")" "(strokes k G" "  P :display \"P\")")))))

(test-group "duplicate-definition"
  (table-tests 'duplicate-definition
   (list (list "scale / scale" 3
               (lines "(piece \"P\")" "(scale s ding)" "(scale s dong)"))
         (list "identical scales are still duplicates" 3
               (lines "(piece \"P\")" "(scale s ding)" "(scale s ding)"))
         (list "strokes / strokes" 4
               (lines "(piece \"P\")" "(strokes g G)" "" "(strokes g P)"))
         (list "instrument / instrument" 4
               (lines "(piece \"P\")" "(strokes g G P)" "(instrument x g G)"
                      "(instrument x g P)"))
         (list "scale / strokes" 3
               (lines "(piece \"P\")" "(scale g ding)" "(strokes g G)"))
         (list "strokes / scale" 3
               (lines "(piece \"P\")" "(strokes g G)" "(scale g ding)"))
         (list "three definitions: the second is reported" 3
               (lines "(piece \"P\")" "(scale s ding)" "(scale s dong)"
                      "(scale s deng)"))
         (list "first duplicate in file order" 4
               (lines "(piece \"P\")" "(scale b ding)" "(scale a ding)"
                      "(scale a dong)" "(scale b dong)"))))
  (let ((pc (try-read-string "(piece \"P\")" "(strokes gong G)"
                             "(instrument gong gong G)")))
    (test-equal "an instrument may share a name with a stroke set" '(gong)
      (map instrument-name (piece-instruments pc))))
  (let ((pc (try-read-string "(piece \"P\")" "(scale ugal ding)"
                             "(instrument ugal ugal ding1)")))
    (test-equal "an instrument may share a name with a scale" '(ugal)
      (map instrument-name (piece-instruments pc)))))

(test-group "bad-degree"
  ;; Each case is (NAME LINE STRING). A degree written as a list
  ;; reports its own line; a bare degree reports its scale's line.
  (table-tests 'bad-degree
   (list (list "bare degree is a number: scale's line" 2
               (lines "(piece \"P\")" "(scale s ding" "  42)"))
         (list "bare degree is a string: scale's line" 2
               (lines "(piece \"P\")" "(scale s ding" "  \"dong\")"))
         (list "degree list with a string head: its own line" 3
               (lines "(piece \"P\")" "(scale s ding" "  (\"dong\" :alias o))"))
         (list "degree list with a number head" 3
               (lines "(piece \"P\")" "(scale s ding" "  (5 :alias o))"))
         (list "degree list with a key head" 3
               (lines "(piece \"P\")" "(scale s ding" "  (:alias o))"))
         (list "empty list as a degree" 2
               (lines "(piece \"P\")" "(scale s ding ())"))
         (list "a symbol where a key should be" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong alias o))"))
         (list "a string where a key should be" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong \"o\"))"))
         (list "a v1 list option" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong (alias o)))"))
         (list "a stray item after a key and its value" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias o oo))"))
         (list ":display is a symbol" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :display o))"))
         (list ":display is a number" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :display 5))"))
         (list ":display is a list of strings" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :display (\"o\")))"))
         (list ":damped is a symbol" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :damped o))"))
         (list ":damped is a number" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :damped 5))"))
         (list ":alias is a number" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias 3))"))
         (list ":alias is a string" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias \"o\"))"))
         (list ":alias is an empty list" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias ()))"))
         (list ":alias list with a number" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias (o 3)))"))
         (list ":alias list with a string" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias (o \"oo\")))"))
         (list ":alias list with a list" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias (o (oo))))"))
         (list "stroke: :display not a string" 2
               (lines "(piece \"P\")" "(strokes k G (dag :display D))"))
         (list "stroke: :damped not a string" 3
               (lines "(piece \"P\")" "(strokes k G" "  (dag :damped 1))"))
         (list "stroke: bare number" 2
               (lines "(piece \"P\")" "(strokes k G" "  1)"))
         (list "stroke: :alias is a number" 3
               (lines "(piece \"P\")" "(strokes k G" "  (dag :alias 1))"))
         (list "first bad degree in order within a scale" 3
               (lines "(piece \"P\")" "(scale s ding"
                      "  (dong :display x)" "  (deng :display e))"))
         (list "first bad scale in file order" 2
               (lines "(piece \"P\")" "(scale a 1)" "(scale b (ding :display x))")))))

;;; Option errors in a degree are at the degree's line (the list that
;;; holds the option).
(test-group "degree option errors"
  (table-tests 'bad-option
   (list (list ":alias with no value" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias))"))
         (list ":display with no value" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :display))"))
         (list ":alias followed by another key" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias :display \"o\"))"))
         (list ":damped with no value after a good option" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :display \"o\" :damped))"))
         (list "stroke: :display with no value" 2
               (lines "(piece \"P\")" "(strokes k (G :display))"))))
  (table-tests 'unknown-option
   (list (list "an unknown key" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :colour red))"))
         (list "keys are case-sensitive" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :Alias o))"))
         (list "a piece key is not a degree key" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :pickup 1))"))
         (list "an unknown key after good ones" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias o :colour red))"))
         (list "stroke: an unknown key" 3
               (lines "(piece \"P\")" "(strokes k G" "  (dag :colour red))"))
         (list "a key on its own line: the degree's line" 3
               (lines "(piece \"P\")" "(scale s"
                      "  (ding"
                      "    :colour \"red\"))"))))
  (table-tests 'duplicate-option
   (list (list ":alias twice" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias o :alias oo))"))
         (list ":display twice with the same value" 3
               (lines "(piece \"P\")" "(scale s ding"
                      "  (dong :display \"o\" :display \"o\"))"))
         (list "stroke: :damped twice" 2
               (lines "(piece \"P\")" "(strokes k (G :damped \"g\" :damped \"G\"))")))))

(test-group "degree-ends-in-digit"
  (table-tests 'degree-ends-in-digit
   (list (list "bare name ending in a digit: scale's line" 2
               (lines "(piece \"P\")" "(scale s ding" "  dong2)"))
         (list "listed name ending in a digit: own line" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong2 :alias o))"))
         (list "alias ending in a digit" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias o2))"))
         (list "second alias in a list ending in a digit" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias (o o0)))"))
         (list "bare name ending in two digits" 2
               (lines "(piece \"P\")" "(scale s ding a10)")))))

(test-group "duplicate-degree"
  (table-tests 'duplicate-degree
   (list (list "same name twice, bare: scale's line" 2
               (lines "(piece \"P\")" "(scale s ding dong" "  ding)"))
         (list "same name twice, second listed: its line" 3
               (lines "(piece \"P\")" "(scale s ding dong" "  (ding :alias i))"))
         (list "alias equal to another degree's name" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias ding))"))
         (list "name equal to an earlier alias" 3
               (lines "(piece \"P\")" "(scale s (ding :alias i)" "  (i :alias x))"))
         (list "alias equal to an earlier alias" 3
               (lines "(piece \"P\")" "(scale s (ding :alias i)" "  (dong :alias i))"))
         (list "alias in a list equal to an earlier alias" 3
               (lines "(piece \"P\")" "(scale s (ding :alias (i nding))"
                      "  (dong :alias (o nding)))"))
         (list "alias equal to its own degree's name" 2
               (lines "(piece \"P\")" "(scale s (ding :alias ding) dong)"))
         (list "alias repeated in one alias list" 2
               (lines "(piece \"P\")" "(scale s (ding :alias (i i)) dong)"))
         (list "stroke name twice" 2
               (lines "(piece \"P\")" "(strokes k G P G)"))
         (list "stroke alias equal to another stroke" 3
               (lines "(piece \"P\")" "(strokes k G" "  (P :alias G))"))
         (list "stroke alias equal to its own name" 2
               (lines "(piece \"P\")" "(strokes k (G :alias G))")))))

;;; `rep` and `@` are reserved list heads (01, "scale" and "strokes").
(test-group "reserved-name"
  (table-tests 'reserved-name
   (list (list "a bare degree called rep: the scale's line" 2
               (lines "(piece \"P\")" "(scale s ding" "  rep)"))
         (list "a bare degree called @" 2
               (lines "(piece \"P\")" "(scale s ding @)"))
         (list "a listed degree called rep: its own line" 3
               (lines "(piece \"P\")" "(scale s ding" "  (rep :alias r))"))
         (list "a listed degree called @" 3
               (lines "(piece \"P\")" "(scale s ding" "  (@ :display \"@\"))"))
         (list "an alias rep" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias rep))"))
         (list "an alias @ in a list" 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias (o @)))"))
         (list "a stroke called rep" 2
               (lines "(piece \"P\")" "(strokes k G rep)"))
         (list "a stroke called @" 3
               (lines "(piece \"P\")" "(strokes k G" "  (@ :display \"@\"))"))
         (list "a stroke alias rep" 2
               (lines "(piece \"P\")" "(strokes k (G :alias rep))"))
         (list "the first reserved name in file order" 2
               (lines "(piece \"P\")" "(scale a rep)" "(strokes b @)")))))

(test-group "undefined-scale"
  (table-tests 'undefined-scale
   (list (list "nothing defined" 2
               (lines "(piece \"P\")" "(instrument ugal selisir ding1)"))
         (list "a different scale is defined" 3
               (lines "(piece \"P\")" "(scale pelog ding)"
                      "(instrument ugal selisir ding1)"))
         (list "names are case-sensitive" 3
               (lines "(piece \"P\")" "(scale selisir ding)"
                      "(instrument ugal Selisir ding1)"))
         (list "naming an instrument, not a scale" 4
               (lines "(piece \"P\")" "(strokes g G)" "(instrument gong g G)"
                      "(instrument kempli gong G)"))
         (list "multi-line instrument: the form's line" 2
               (lines "(piece \"P\")" "(instrument ugal" "  selisir ding1)"))
         (list "first instrument in file order" 3
               (lines "(piece \"P\")" "(scale s ding)" "(instrument a x ding1)"
                      "(instrument b y ding1)")))))

(test-group "unknown-note"
  (table-tests 'unknown-note
   (list (list "degree not in the scale" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s ding1 dang1)"))
         (list "pitched note without an octave" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s ding)"))
         (list "alias without an octave" 3
               (lines "(piece \"P\")" "(scale s (ding :alias i) dong)"
                      "(instrument x s i)"))
         (list "stroke not in the stroke set" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g G K)"))
         (list "stroke with an octave-like digit" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g G1)"))
         (list "stroke name without its trailing digit" 3
               (lines "(piece \"P\")" "(strokes k k1 k2)"
                      "(instrument x k k)"))
         (list "a note on a continuation line: the instrument's line" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s" "  ding1" "  dang1)"))
         (list "first instrument in file order" 3
               (lines "(piece \"P\")" "(scale s ding)" "(instrument a s foo1)"
                      "(instrument b s bar1)")))))

(test-group "notes-not-ascending"
  (table-tests 'notes-not-ascending
   (list (list "lower octave after higher" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s ding2 ding1)"))
         (list "lower degree after higher, same octave" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s dong1 ding1)"))
         (list "repeated note" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s ding1 ding1)"))
         (list "repeated note through an alias" 3
               (lines "(piece \"P\")" "(scale s (ding :alias i) dong)"
                      "(instrument x s ding1 i1)"))
         (list "octave 0 after octave 1" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s ding1 dong0)"))
         (list "octave 9 after octave 10 (numbers, not text)" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s ding10 dong9)"))
         (list "a later note out of order" 3
               (lines "(piece \"P\")" "(scale s ding dong)"
                      "(instrument x s ding1 dong1 ding2 dong1)")))))

(test-group "duplicate-note"
  (table-tests 'duplicate-note
   (list (list "stroke listed twice" 3
               (lines "(piece \"P\")" "(strokes g G P)"
                      "(instrument gong g G P G)"))
         (list "stroke listed twice through an alias" 3
               (lines "(piece \"P\")" "(strokes k (dag :alias D) dug)"
                      "(instrument kendang k dag dug D)"))
         (list "stroke ending in a digit listed twice" 3
               (lines "(piece \"P\")" "(strokes k k1 k2)"
                      "(instrument x k k2 k1 k2)")))))

(test-group "definition error fields"
  (for-each
   (match-lambda
     ((name kind str)
      (let ((c (catch-syntax-error (lambda () (read-piece-string str)))))
        (test-equal (string-append name ": kind") kind (kind-of c))
        (test-equal (string-append name ": file #f") #f
          (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
        (test-equal (string-append name ": part #f") #f
          (and (notasi-syntax-error? c) (notasi-syntax-error-part c)))
        (test-equal (string-append name ": time #f") #f
          (and (notasi-syntax-error? c) (notasi-syntax-error-time c))))))
   (list (list "bad-form" 'bad-form (lines "(piece \"P\")" "(scale s)"))
         (list "bad-degree" 'bad-degree
               (lines "(piece \"P\")" "(scale s (ding :display 5))"))
         (list "reserved-name" 'reserved-name
               (lines "(piece \"P\")" "(scale s ding rep)"))
         (list "degree unknown-option" 'unknown-option
               (lines "(piece \"P\")" "(scale s (ding :colour x))"))
         (list "undefined-scale" 'undefined-scale
               (lines "(piece \"P\")" "(instrument x s ding1)"))
         (list "unknown-note" 'unknown-note
               (lines "(piece \"P\")" "(scale s ding)" "(instrument x s dong1)"))))

  (for-each
   (match-lambda
     ((name kind line contents)
      (let* ((path (write-temp-file (string-append name ".nts") contents))
             (c (catch-syntax-error (lambda () (read-piece-file path)))))
        (test-equal (string-append name " from a file: kind") kind (kind-of c))
        (test-equal (string-append name " from a file: file") path
          (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
        (test-equal (string-append name " from a file: line") line
          (and (notasi-syntax-error? c) (notasi-syntax-error-line c)))
        (test-equal (string-append name " from a file: part #f") #f
          (and (notasi-syntax-error? c) (notasi-syntax-error-part c)))
        (test-equal (string-append name " from a file: time #f") #f
          (and (notasi-syntax-error? c) (notasi-syntax-error-time c))))))
   (list (list "bad-form" 'bad-form 2 (lines "(piece \"P\")" "(strokes g)"))
         (list "duplicate-definition" 'duplicate-definition 3
               (lines "(piece \"P\")" "(scale s ding)" "(strokes s G)"))
         (list "bad-degree" 'bad-degree 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :display 5))"))
         (list "bad-option" 'bad-option 3
               (lines "(piece \"P\")" "(scale s ding" "  (dong :alias))"))
         (list "reserved-name" 'reserved-name 3
               (lines "(piece \"P\")" "(strokes k G" "  (@ :alias at))"))
         (list "degree-ends-in-digit" 'degree-ends-in-digit 2
               (lines "(piece \"P\")" "(scale s ding1)"))
         (list "duplicate-degree" 'duplicate-degree 2
               (lines "(piece \"P\")" "(scale s ding ding)"))
         (list "undefined-scale" 'undefined-scale 2
               (lines "(piece \"P\")" "(instrument x s ding1)"))
         (list "unknown-note" 'unknown-note 3
               (lines "(piece \"P\")" "(scale s ding)" "(instrument x s ding)"))
         (list "notes-not-ascending" 'notes-not-ascending 3
               (lines "(piece \"P\")" "(scale s ding)"
                      "(instrument x s ding2 ding1)"))
         (list "duplicate-note" 'duplicate-note 3
               (lines "(piece \"P\")" "(strokes g G)" "(instrument x g G G)")))))

;;; ------------------------------------------------------------------
;;; Check order for definitions (03-reader.md, "Error reporting")

(test-group "definitions: check order"
  (for-each
   (match-lambda
     ((name expected str)
      (test-equal name expected (string-error str))))
   (list
    ;; Items 1-4 come before definitions.
    (list "unknown-form comes before bad-form" '(unknown-form 3)
          (lines "(piece \"P\")" "(scale)" "(foo)"))
    (list "group-outside-score comes before bad-form" '(group-outside-score 3)
          (lines "(piece \"P\")" "(scale)" "(group \"G\" a)"))
    (list "bad-title comes before bad-form" '(bad-title 1)
          (lines "(piece 1)" "(scale)"))
    (list "bad-option comes before undefined-scale" '(bad-option 1)
          (lines "(piece \"P\" 4)" "(instrument x s ding1)"))
    ;; Item 5: use.
    (list "a template's scale is defined for the piece's instruments" 'no-error
          (lines "(piece \"P\")" "(use gong-kebyar)"
                 "(instrument ugal selisir ding1)"))
    (list "use, then the piece's own bad-form" '(bad-form 3)
          (lines "(piece \"P\")" "(use gong-kebyar)" "(scale)"))
    (list "template-not-found comes before unknown-note" '(template-not-found 2)
          (lines "(piece \"P\")" "(use \"defs.nts\")" "(scale s ding)"
                 "(instrument x s dong1)"))
    ;; Item 6 before 7.
    (list "bad-form comes before duplicate-definition" '(bad-form 4)
          (lines "(piece \"P\")" "(scale s ding)" "(scale s dong)" "(instrument x)"))
    (list "bad-form comes before an earlier duplicate instrument" '(bad-form 5)
          (lines "(piece \"P\")" "(strokes g G)" "(instrument x g G)"
                 "(instrument x g G)" "(strokes)"))
    (list "an instrument's option comes before an earlier duplicate" '(bad-form 5)
          (lines "(piece \"P\")" "(strokes g G)" "(strokes g G)" ""
                 "(instrument x g G :show-names yes)"))
    (list "a scale's unknown-option comes before a duplicate" '(unknown-option 4)
          (lines "(piece \"P\")" "(scale s ding)" "(scale s dong)"
                 "(scale t :colour red ding)"))
    ;; Item 7 before 8 and 9.
    (list "duplicate-definition comes before bad-degree" '(duplicate-definition 3)
          (lines "(piece \"P\")" "(scale s (ding :display x))" "(scale s dong)"))
    (list "duplicate-definition comes before duplicate-degree"
          '(duplicate-definition 3)
          (lines "(piece \"P\")" "(scale s ding ding)" "(strokes s G)"))
    (list "duplicate-definition comes before reserved-name"
          '(duplicate-definition 3)
          (lines "(piece \"P\")" "(scale s ding rep)" "(strokes s G)"))
    (list "duplicate-definition comes before undefined-scale"
          '(duplicate-definition 3)
          (lines "(piece \"P\")" "(instrument x nowhere ding1)"
                 "(instrument x nowhere ding1)"))
    ;; Item 8 before 9.
    (list "scale errors before instrument errors, instrument first"
          '(bad-degree 3)
          (lines "(piece \"P\")" "(instrument x nowhere ding1)"
                 "(scale s (ding :display x))"))
    (list "degree-ends-in-digit before unknown-note in an earlier instrument"
          '(degree-ends-in-digit 3)
          (lines "(piece \"P\")" "(instrument x s foo1)" "(scale s ding1)"))
    (list "duplicate-degree before undefined-scale in an earlier instrument"
          '(duplicate-degree 3)
          (lines "(piece \"P\")" "(instrument x nowhere ding1)"
                 "(strokes k G G)"))
    (list "reserved-name before undefined-scale in an earlier instrument"
          '(reserved-name 3)
          (lines "(piece \"P\")" "(instrument x nowhere ding1)"
                 "(strokes k G @)"))
    ;; Item 8: within a scale, degree by degree.
    (list "within a degree: bad-degree before degree-ends-in-digit"
          '(bad-degree 2)
          (lines "(piece \"P\")" "(scale s (ding1 :display x))"))
    (list "within a degree: degree-ends-in-digit before duplicate-degree"
          '(degree-ends-in-digit 2)
          (lines "(piece \"P\")" "(scale s (ding :alias (ding i1)))"))
    (list "within a degree: bad-degree before duplicate-degree"
          '(bad-degree 3)
          (lines "(piece \"P\")" "(scale s ding" "  (ding :display 5))"))
    (list "an earlier degree's duplicate before a later bad degree"
          '(duplicate-degree 2)
          (lines "(piece \"P\")" "(scale s ding ding" "  (dong :display x))"))
    (list "an earlier degree's digit before a later bad degree"
          '(degree-ends-in-digit 2)
          (lines "(piece \"P\")" "(scale s ding1" "  (dong :display x))"))
    (list "an earlier reserved name before a later bad degree"
          '(reserved-name 2)
          (lines "(piece \"P\")" "(scale s rep" "  (dong :display x))"))
    (list "an earlier scale's error before a later scale's" '(duplicate-degree 2)
          (lines "(piece \"P\")" "(scale a ding ding)" "(scale b (ding :display x))"))
    ;; Item 9: within an instrument, note by note.
    (list "undefined-scale before a later instrument's unknown-note"
          '(undefined-scale 3)
          (lines "(piece \"P\")" "(scale s ding)" "(instrument a nowhere ding1)"
                 "(instrument b s foo1)"))
    (list "an earlier note's ordering error before a later unknown note"
          '(notes-not-ascending 3)
          (lines "(piece \"P\")" "(scale s ding dong)"
                 "(instrument x s dong1 ding1 foo1)"))
    (list "an earlier unknown note before a later ordering error"
          '(unknown-note 3)
          (lines "(piece \"P\")" "(scale s ding dong)"
                 "(instrument x s foo1 dong1 ding1)"))
    (list "an earlier stroke duplicate before a later unknown stroke"
          '(duplicate-note 3)
          (lines "(piece \"P\")" "(strokes g G P)" "(instrument x g G G K)"))
    ;; Parts come after instruments.
    (list "unknown-note comes before a part's errors" '(unknown-note 4)
          (lines "(piece \"P\")" "(part x 1)" "(scale s ding)"
                 "(instrument x s foo1)"))
    (list "duplicate-note comes before a part's errors"
          '(duplicate-note 4)
          (lines "(piece \"P\")" "(strokes g G)" "(part x 9)"
                 "(instrument x g G G)")))))

(test-group "definitions: cases decided at review"
  (test-equal "instrument's scale is a string: bad-form" '(bad-form 3)
    (string-error (lines "(piece \"P\")" "(strokes g G)"
                         "(instrument gong \"g\" G)")))
  (test-equal "instrument note is a number: bad-form" '(bad-form 3)
    (string-error (lines "(piece \"P\")" "(strokes g G)"
                         "(instrument gong g 1)")))
  (test-equal "alias is a string: bad-degree" '(bad-degree 2)
    (string-error (lines "(piece \"P\")" "(scale s (ding :alias \"i\"))")))
  (test-equal "leading-zero octave: unknown-note" '(unknown-note 3)
    (string-error (lines "(piece \"P\")" "(scale s ding)"
                         "(instrument x s ding02)"))))

;;; ==================================================================
;;; Part forms
;;; ==================================================================

;;; ------------------------------------------------------------------
;;; Helpers

;;; Definitions used by most part tests. Forms added after them start
;;; on line 10.
;;;   reyong (8 notes): 1 deng1  2 dung1  3 dang1  4 ding2
;;;                     5 dong2  6 deng2  7 dung2  8 dang2
;;;   ugal (6 notes):   1 dong1  2 deng1  3 dung1  4 dang1  5 ding2  6 dong2
;;;   gong (2 notes):   1 G  2 P
;;;   kempli (1 note):  1 K
;;; ding has two aliases, i and nding.
(define parts-defs
  (lines "(piece \"Parts\")"                                       ; 1
         "(scale selisir (ding :alias (i nding)) (dong :alias o)"  ; 2
         "  (deng :alias e) (dung :alias u) (dang :alias a))"      ; 3
         "(strokes gong-strokes G P)"                              ; 4
         "(strokes kempli-strokes K)"                              ; 5
         "(instrument reyong selisir e1 u1 a1 i2 o2 e2 u2 a2)"     ; 6
         "(instrument ugal selisir o1 e1 u1 a1 i2 o2)"             ; 7
         "(instrument gong gong-strokes G P)"                      ; 8
         "(instrument kempli kempli-strokes K)"))                  ; 9

(define (defs+ . more)
  "parts-defs followed by the lines MORE, which start on line 10."
  (apply lines parts-defs more))

(define (read-defs+ . more)
  "Read parts-defs plus MORE as a piece, or #f if reading raises."
  (try-read-string (apply defs+ more)))

(define (part-named pc name) (find-named part-name name (piece-parts pc)))

(define (written-parts pc)
  "The parts of PC that the file wrote, without the generated ones."
  (filter (lambda (p) (eq? (part-origin p) 'written)) (piece-parts pc)))

(define (group-labelled pc label)
  (or (find (lambda (g) (equal? (group-label g) label)) (default-groups pc))
      (error "no group labelled:" label)))

(define (event-triple e)
  (list (event-start e) (event-duration e) (event-notes e)))

(define (part-triples pc name)
  "The events of part NAME as (START DURATION NOTES) triples."
  (map event-triple (part-events (part-named pc name))))

(define (part-p-form instrument tokens)
  "(part INSTRUMENT :name p TOKENS) as a string."
  (string-append "(part " instrument " :name p " tokens ")"))

(define (part-p-events instrument tokens)
  "Read parts-defs plus (part INSTRUMENT :name p TOKENS), and return p's
events as (START DURATION NOTES) triples."
  (part-triples (read-defs+ (part-p-form instrument tokens)) 'p))

(define (group-part-names g) (map part-name (member-parts g)))

(define (group-line g)
  (and=> (group-location g) source-location-line))

(define (error-fields str)
  "(KIND LINE PART TIME) of the &notasi-syntax-error raised reading STR,
or the raised object (or no-error) unchanged."
  (let ((c (catch-syntax-error (lambda () (read-piece-string str)))))
    (if (notasi-syntax-error? c)
        (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c)
              (notasi-syntax-error-part c) (notasi-syntax-error-time c))
        c)))

(define (error-kind+line+part str)
  "(KIND LINE PART) of the &notasi-syntax-error raised reading STR."
  (let ((c (catch-syntax-error (lambda () (read-piece-string str)))))
    (if (notasi-syntax-error? c)
        (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c)
              (notasi-syntax-error-part c))
        c)))

(define (token-tests expected-kind cases)
  "CASES is a list of (NAME INSTRUMENT TOKENS TIME). Each reads
parts-defs plus (part INSTRUMENT :name p TOKENS) on line 10, and expects
EXPECTED-KIND at line 10, part p, time TIME (in pulses)."
  (for-each
   (match-lambda
     ((name instrument tokens time)
      (test-equal name (list expected-kind 10 'p time)
        (error-fields (defs+ (part-p-form instrument tokens))))))
   cases))

;;; ------------------------------------------------------------------
;;; Successful reads: events

(test-group "part events"
  (for-each
   (match-lambda
     ((name instrument tokens expected)
      (test-equal name expected (part-p-events instrument tokens))))
   (list
    (list "single notes by number, 0-based" "reyong" "1 2 8"
          '((0 1 (0)) (1 1 (1)) (2 1 (7))))
    (list "single notes by name" "reyong" "deng1 ding2 dang2"
          '((0 1 (0)) (1 1 (3)) (2 1 (7))))
    (list "single notes by alias: resolved" "reyong" "e1 i2 a2"
          '((0 1 (0)) (1 1 (3)) (2 1 (7))))
    (list "number, alias and name of one note" "reyong" "4 i2 ding2"
          '((0 1 (3)) (1 1 (3)) (2 1 (3))))
    (list "each alias of a list resolves" "reyong" "i2 nding2 ding2"
          '((0 1 (3)) (1 1 (3)) (2 1 (3))))
    (list "notes on ugal" "ugal" "6 o1 5"
          '((0 1 (5)) (1 1 (0)) (2 1 (4))))
    (list "_ holds extend the duration" "reyong" "1 _ _ 2 _ 3"
          '((0 3 (0)) (3 2 (1)) (5 1 (2))))
    (list "- rests leave gaps" "reyong" "1 - 2 - - 3"
          '((0 1 (0)) (2 1 (1)) (5 1 (2))))
    (list "a rest first" "reyong" "- 1"
          '((1 1 (0))))
    (list "a rest ends a held note" "reyong" "1 _ - 2"
          '((0 2 (0)) (3 1 (1))))
    (list "only rests: no events" "gong" "- - - -"
          '())
    (list "/ takes no time" "reyong" "1 / 2 / / 3"
          '((0 1 (0)) (1 1 (1)) (2 1 (2))))
    (list "_ after / extends the note before it" "reyong" "1 _ / _ 2 / _ 3"
          '((0 3 (0)) (3 2 (1)) (5 1 (2))))
    (list "/ at the start and the end" "reyong" "/ 1 2 /"
          '((0 1 (0)) (1 1 (1))))
    (list "chord by number, sorted ascending" "reyong" "(5 2)"
          '((0 1 (1 4))))
    (list "chord by name, sorted ascending" "reyong" "(i2 deng1)"
          '((0 1 (0 3))))
    (list "chord mixing number and name" "reyong" "(8 deng2)"
          '((0 1 (5 7))))
    (list "three-note chord" "reyong" "(3 1 2)"
          '((0 1 (0 1 2))))
    (list "chords and single notes" "reyong" "(1 3) 2 (u2 o2)"
          '((0 1 (0 2)) (1 1 (1)) (2 1 (4 6))))
    (list "chord on ugal" "ugal" "(a1 5)"
          '((0 1 (3 4))))
    (list "chord followed by _" "reyong" "(1 3) _ _ 2"
          '((0 3 (0 2)) (3 1 (1))))
    (list "chord, /, then _" "reyong" "(1 3) / _ 2"
          '((0 2 (0 2)) (2 1 (1))))
    (list "last note held to the end" "reyong" "1 2 _ _"
          '((0 1 (0)) (1 3 (1))))
    (list "trailing rests are not stored" "reyong" "1 2 - -"
          '((0 1 (0)) (1 1 (1))))
    (list "strokes by name" "gong" "G - P _"
          '((0 1 (0)) (2 2 (1))))
    (list "strokes by number" "gong" "2 1"
          '((0 1 (1)) (1 1 (0))))
    (list "chord of strokes" "gong" "(P G)"
          '((0 1 (0 1))))))

  (test-assert "events are event records"
    (every event? (part-events (part-named (read-defs+ "(part reyong :name p 1 _ 2)")
                                           'p)))))

(test-group "piece length"
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (piece-length (apply read-defs+ forms)))))
   (list (list "one pulse per token" 3 "(part reyong 1 2 3)")
         (list "holds count" 4 "(part reyong 1 _ _ 2)")
         (list "trailing rests count" 4 "(part reyong 1 2 - -)")
         (list "a part of only rests" 3 "(part gong - - -)")
         (list "/ does not count" 2 "(part reyong / 1 / 2 /)")
         (list "a chord is one pulse" 2 "(part reyong (1 2) (3 4))")
         (list "several parts of equal length" 4
               "(part reyong 1 2 - -)" "(part gong G _ _ _)")))
  (let ((pc (read-defs+)))
    (test-equal "no parts: length 0" 0 (piece-length pc))
    (test-equal "no parts: only the timekeeper's group" '("kempli")
      (map group-label (default-groups pc))))
  (let ((pc (read-defs+ "(part reyong 1 2 - -)" "(part gong G _ _ _)")))
    (test-equal "part-end is the end of the last event (ADR 0012)" '(2 4 4)
      (map part-end (piece-parts pc)))
    (test-assert "part-end <= piece-length"
      (every (lambda (p) (<= (part-end p) (piece-length pc)))
             (piece-parts pc)))))

;;; ------------------------------------------------------------------
;;; Successful reads: part fields and :name

(test-group "part fields"
  (let ((pc (read-defs+ "(part reyong :name polos 1 2 3 4)"    ; 10
                        "(part ugal"                           ; 11
                        "  1 2 3 4)"                           ; 12
                        "(part gong G - - -)"                  ; 13
                        "(part reyong :name sangsih 4 3 2 1)"))) ; 14
    (test-assert "reads into a piece" (piece? pc))
    (test-equal "parts in file order, named by :name or by their instrument"
      '(polos ugal gong sangsih kempli)
      (map part-name (piece-parts pc)))
    (test-equal "written parts, then the generated timekeeper"
      '(written written written written timekeeper)
      (map part-origin (piece-parts pc)))
    (test-assert "parts are part records" (every part? (piece-parts pc)))
    (test-equal "part instruments by name" '(reyong ugal gong reyong kempli)
      (map (lambda (p) (instrument-name (part-instrument p)))
           (piece-parts pc)))
    (test-assert "part instrument is the instrument record in the piece"
      (and (eq? (part-instrument (part-named pc 'polos))
                (instrument-named pc 'reyong))
           (eq? (part-instrument (part-named pc 'sangsih))
                (instrument-named pc 'reyong))
           (eq? (part-instrument (part-named pc 'ugal))
                (instrument-named pc 'ugal))
           (eq? (part-instrument (part-named pc 'gong))
                (instrument-named pc 'gong))))
    (test-equal "part lines: the form's line" '(10 11 13 14)
      (map (lambda (p) (source-location-line (part-location p)))
           (written-parts pc)))
    (test-equal "part files are #f from a string" '(#f #f #f #f)
      (map (lambda (p) (source-location-file (part-location p)))
           (written-parts pc)))
    (test-equal "length" 4 (piece-length pc))
    (test-equal "instruments still in file order" '(reyong ugal gong kempli)
      (map instrument-name (piece-instruments pc))))

  (let ((pc (read-defs+ "(part ugal 1 2)")))
    (test-equal "no :name: the part is named after its instrument" '(ugal kempli)
      (map part-name (piece-parts pc)))
    (test-assert "no :name: its instrument"
      (eq? (part-instrument (part-named pc 'ugal)) (instrument-named pc 'ugal)))
    (test-equal "no :name: its default group" '("ugal" "kempli")
      (map group-label (default-groups pc))))

  (let ((pc (read-defs+ "(part reyong"         ; 10
                        "  :name polos"        ; 11
                        "  1 2 3 4)")))        ; 12
    (test-equal ":name on its own line" '(polos kempli)
      (map part-name (piece-parts pc)))
    (test-equal ":name on its own line: the form's line" '(10)
      (map (lambda (p) (source-location-line (part-location p)))
           (written-parts pc)))
    (test-equal ":name on its own line: the events" '((0 1 (0)) (1 1 (1)) (2 1 (2)) (3 1 (3)))
      (part-triples pc 'polos)))

  (let ((pc (read-defs+ "(part reyong :name ugal 1 2)"
                        "(part ugal :name reyong 1 2)")))
    (test-equal "a :name may be another instrument's name" '(ugal reyong kempli)
      (map part-name (piece-parts pc)))
    (test-assert "a part named like another instrument plays its own"
      (and (eq? (part-instrument (part-named pc 'ugal)) (instrument-named pc 'reyong))
           (eq? (part-instrument (part-named pc 'reyong)) (instrument-named pc 'ugal)))))

  (let ((pc (read-defs+ "(part reyong :name selisir 1)"
                        "(part gong :name gong-strokes G)")))
    (test-equal "parts may share names with scales and stroke sets"
      '(selisir gong-strokes kempli)
      (map part-name (piece-parts pc))))

  (let ((pc (read-defs+ "(part reyong :name polos 1 2)"
                        "(part reyong :name sangsih 3 4)"
                        "(part ugal 1 2)"
                        "(part gong G P)")))
    (test-equal "several named parts on one instrument, one part on others"
      '(polos sangsih ugal gong kempli)
      (map part-name (piece-parts pc)))))

(test-group "parts read from a file"
  (let* ((path (write-temp-file "parts.nts"
                                (defs+ "(part reyong :name a 1 2)"     ; 10
                                       "(part reyong :name b 3 4)")))  ; 11
         (pc (try-read (lambda () (read-piece-file path)))))
    (test-equal "part files are the path given" (list path path)
      (map (lambda (p) (source-location-file (part-location p)))
           (written-parts pc)))
    (test-equal "part lines" '(10 11)
      (map (lambda (p) (source-location-line (part-location p)))
           (written-parts pc)))
    (test-equal "default groups have no location, even from a file" '(#f #f #f)
      (map group-location (default-groups pc)))))

;;; ------------------------------------------------------------------
;;; Default groups: with no top-level groups, every part is in its own
;;; group, in part order, labelled with its name (02, "group").

(test-group "default groups"
  (let ((pc (read-defs+ "(part ugal 1 2 3 4)"                    ; 10
                        "(part reyong :name polos 1 2 3 4)"      ; 11
                        "(part reyong :name sangsih 4 3 2 1)"    ; 12
                        "(part gong G - - P)")))                 ; 13
    (test-equal "one group per part, in part order, labelled with its name"
      '("ugal" "polos" "sangsih" "gong" "kempli")
      (map group-label (default-groups pc)))
    (test-assert "groups are group records" (every group? (default-groups pc)))
    (test-equal "one part each" '((ugal) (polos) (sangsih) (gong) (kempli))
      (map group-part-names (default-groups pc)))
    (test-equal "subtitles #f" '(#f #f #f #f #f)
      (map group-subtitle (default-groups pc)))
    (test-equal "locations #f" '(#f #f #f #f #f)
      (map group-location (default-groups pc)))
    (test-assert "a group's part is the piece's part record"
      (every (lambda (g) (eq? (car (member-parts g))
                              (part-named pc (car (group-part-names g)))))
             (default-groups pc)))
    (test-equal "parts stay in file order, then the timekeeper"
      '(ugal polos sangsih gong kempli)
      (map part-name (piece-parts pc))))

  (let ((pc (read-defs+ "(part reyong :name polos 1 2)"
                        "(part reyong :name sangsih 3 4)")))
    (test-equal "two parts on one instrument: two groups, then kempli"
      '("polos" "sangsih" "kempli")
      (map group-label (default-groups pc)))
    (test-equal "group-lanes of each" '((dung1 deng1) (ding2 dang1) (K))
      (map (lambda (g) (map note-name (group-lanes g)))
           (default-groups pc)))))

;;; ------------------------------------------------------------------
;;; The textbook excerpt at the end of 01-notation.md. In v1 it was
;;; written with `:steps-per-pulse 4` and one token per step; now the
;;; first token of each part sets a quarter pulse, and `|` checks the
;;; pulses where v1 wrote `/`.

(test-group "textbook excerpt"
  (let ((pc (try-read-string
             "(piece \"Reyong kotekan\")"
             "(scale reyong-4  nang ning nong neng)          ; do mi fa sol"
             "(strokes gong-strokes  G)"
             "(instrument reyong reyong-4  nang1 ning1 nong1 neng1)"
             "(instrument gong gong-strokes G)"
             ""
             "(part reyong :name polos    1:1/4 _ 1 2 | _ 1 2 _ | 2 1 _ 2)"
             "(part reyong :name sangsih  4:1/4 3 4 _ | 3 4 _ 3 | _ 4 3 _)"
             "(part gong                  1:1/4 - - - / - - - - / - - - -)")))
    (test-assert "reads into a piece" (piece? pc))
    (test-equal "title" "Reyong kotekan" (piece-title pc))
    (test-equal "length: 3 pulses" 3 (piece-length pc))
    (test-equal "parts, then the built-in timekeeper" '(polos sangsih gong kempli)
      (map part-name (piece-parts pc)))
    (test-equal "part lines" '(7 8 9)
      (map (lambda (p) (source-location-line (part-location p)))
           (written-parts pc)))
    (test-equal "polos events"
      '((0 1/2 (0)) (1/2 1/4 (0)) (3/4 1/2 (1)) (5/4 1/4 (0))
        (3/2 1/2 (1)) (2 1/4 (1)) (9/4 1/2 (0)) (11/4 1/4 (1)))
      (part-triples pc 'polos))
    (test-equal "sangsih events"
      '((0 1/4 (3)) (1/4 1/4 (2)) (1/2 1/2 (3)) (1 1/4 (2))
        (5/4 1/2 (3)) (7/4 1/2 (2)) (9/4 1/4 (3)) (5/2 1/2 (2)))
      (part-triples pc 'sangsih))
    (test-equal "gong events" '((0 1/4 (0))) (part-triples pc 'gong))
    (test-equal "groups: one per written part (the built-in kempli has none)"
      '("polos" "sangsih" "gong")
      (map group-label (default-groups pc)))
    (test-equal "group parts" '((polos) (sangsih) (gong))
      (map group-part-names (default-groups pc)))
    (test-equal "group lines" '(#f #f #f) (map group-line (default-groups pc)))
    ;; Light checks with the derived functions of (notasi piece).
    (test-equal "group-lanes: polos, highest first" '(ning1 nang1)
      (map note-name (group-lanes (group-labelled pc "polos"))))
    (test-equal "group-lanes: sangsih, highest first" '(neng1 nong1)
      (map note-name (group-lanes (group-labelled pc "sangsih"))))
    (test-equal "group-lanes: gong" '(G)
      (map note-name (group-lanes (group-labelled pc "gong"))))
    (test-equal "part-end" '(3 3 1/4 3) (map part-end (piece-parts pc)))
    (test-assert "part-end <= piece-length"
      (every (lambda (p) (<= (part-end p) (piece-length pc)))
             (piece-parts pc)))
    (test-equal "events-at pulse 2: polos starts, sangsih holds, kempli"
      '((polos 2 (1)) (sangsih 7/4 (2)) (kempli 2 (0)))
      (map (match-lambda
             ((p . e) (list (part-name p) (event-start e) (event-notes e))))
           (events-at pc 2)))
    (test-equal "events-at 0: all four parts"
      '((polos 0 (0)) (sangsih 0 (3)) (gong 0 (0)) (kempli 0 (0)))
      (map (match-lambda
             ((p . e) (list (part-name p) (event-start e) (event-notes e))))
           (events-at pc 0)))))

;;; ------------------------------------------------------------------
;;; Token errors. Each is at the part's line (10), part p, and the time
;;; in pulses where the token starts. With no duration written, each
;;; token is one pulse, so the times are v1's 0-based steps.

(test-group "note-out-of-range"
  (token-tests 'note-out-of-range
   (list (list "0" "reyong" "1 0 2" 1)
         (list "n+1" "reyong" "1 2 9" 2)
         (list "a negative number" "reyong" "-1 1" 0)
         (list "n+1 on ugal (6 notes)" "ugal" "7" 0)
         (list "n+1 on a stroke instrument" "gong" "G 3" 1)
         (list "out of range in a chord" "reyong" "1 (1 9)" 1)
         (list "0 in a chord" "reyong" "(0 1)" 0))))

(test-group "unknown-note in a part"
  (token-tests 'unknown-note
   (list (list "name not in the scale" "reyong" "1 foo1" 1)
         (list "pitched name without an octave" "reyong" "ding" 0)
         (list "alias without an octave" "reyong" "1 2 i" 2)
         (list "in the scale but not on the instrument" "reyong" "ding1" 0)
         (list "alias of a note not on the instrument" "reyong" "i1" 0)
         (list "above the instrument's range" "reyong" "1 ding3" 1)
         (list "leading-zero octave" "reyong" "i02" 0)
         (list "names are case-sensitive" "reyong" "Ding2" 0)
         (list "a stroke on a pitched instrument" "reyong" "G" 0)
         (list "a pitched note on a stroke instrument" "gong" "ding2" 0)
         (list "a stroke from another stroke set" "gong" "G K" 1)
         (list "a stroke with an octave-like digit" "gong" "G1" 0)
         (list "unknown name in a chord" "reyong" "(1 foo1)" 0)
         (list "chord member not on the instrument" "reyong" "1 (ding1 2)" 1)
         ;; ADR 0028: `·` is no longer a rest, so it is read as a note name.
         (list "· is not a rest" "reyong" "1 · 2" 1)
         (list "· on a stroke instrument" "gong" "·" 0)
         (list "· as a chord member" "reyong" "(1 ·)" 0))))

(test-group "hold-without-note"
  (token-tests 'hold-without-note
   (list (list "_ first" "reyong" "_ 1" 0)
         (list "_ after -" "reyong" "1 - _" 2)
         (list "_ after a rest first" "gong" "- _" 1)
         (list "_ after a / that follows a rest" "reyong" "1 - / _" 2)
         (list "_ after a / at the start" "reyong" "/ _ 1" 0)
         (list "_ after held note, rest" "reyong" "1 _ - _" 3))))

(test-group "bad-chord"
  (token-tests 'bad-chord
   (list (list "empty chord ()" "reyong" "1 ()" 1)
         (list "chord of one number" "reyong" "(1)" 0)
         (list "chord of one name" "reyong" "1 2 (i2)" 2)
         (list "the same number twice" "reyong" "(2 2)" 0)
         (list "the same name twice" "reyong" "(ding2 ding2)" 0)
         (list "a name and its alias" "reyong" "(ding2 i2)" 0)
         (list "two aliases of one note" "reyong" "(i2 nding2)" 0)
         (list "a number, then the same note by name" "reyong" "(1 deng1)" 0)
         (list "a name, then the same note by number" "reyong" "(i2 4)" 0)
         (list "a repeat among three" "reyong" "(1 2 1)" 0)
         (list "the same stroke twice" "gong" "(G G)" 0)
         (list "member _" "reyong" "(1 _)" 0)
         (list "member _ first" "reyong" "1 (_ 2)" 1)
         (list "member -" "reyong" "(1 -)" 0)
         (list "member /" "reyong" "(1 /)" 0)
         (list "member a string" "reyong" "(1 \"x\")" 0))))

;;; 03-reader.md lists "a list" among bad chord members (bad-chord), but
;;; also lists "a list inside a list" under unknown-token. These tests
;;; follow the bad-chord rule (as in v1).
(test-group "bad-chord: a list as a chord member"
  (token-tests 'bad-chord
   (list (list "member a list" "reyong" "(1 (2 3))" 0)
         (list "member an empty list" "reyong" "1 (2 ())" 1))))

(test-group "unknown-token"
  (token-tests 'unknown-token
   (list (list "a string" "reyong" "1 \"x\"" 1)
         (list "#t" "reyong" "#t" 0)
         (list "1.5" "reyong" "1 2 1.5" 2)
         (list "a vector" "reyong" "1 #(1 2)" 1))))

(test-group "time counting"
  (token-tests 'note-out-of-range
   (list (list "/ takes no time" "reyong" "1 2 / 3 / 9" 3)
         (list "/ before the first token" "reyong" "/ / 9" 0)
         (list "holds and rests take a pulse each" "reyong" "1 _ - - / 2 9" 5)
         (list "a chord takes one pulse" "reyong" "(1 2) / (3 4) / 9" 2)
         (list "| takes no time" "reyong" "1 | 2 | 9" 2)
         (list "durations: whole pulses" "reyong" "1:2 2 9" 4)
         (list "durations: a fraction" "reyong" "1:1/2 2 3 9" 3/2)
         (list "a rest's duration" "reyong" "1 -:3 9" 4)
         (list "a hold of the current duration" "reyong" "1:1/4 _ _ 9" 3/4)
         (list "a chord of the current duration" "reyong" "1:1/3 (1 2) 9" 2/3)
         (list "a suffix on the bad note: where it starts" "reyong" "1:1/2 9:2" 1/2)))
  (token-tests 'hold-without-note
   (list (list "/ around a rest" "reyong" "1 / - / _" 2)))
  (test-equal "a part over several lines: the form's line"
    '(unknown-token 10 p 4)
    (error-fields (defs+ "(part reyong :name p"
                         "  1 2 3 4 /"
                         "  \"x\")")))
  (test-equal "a later part: its own line and name"
    '(note-out-of-range 11 q 1)
    (error-fields (defs+ "(part reyong :name p 1 2)" "(part reyong :name q 1 9)")))
  (test-equal "a part without :name: the error names it after its instrument"
    '(note-out-of-range 10 ugal 1)
    (error-fields (defs+ "(part ugal 1 9)"))))

;;; ------------------------------------------------------------------
;;; Durations, holds, rests and checks through the reader (slice 2,
;;; [durations]). (notasi expand) is tested on its own in
;;; tests/expand.scm; these check that the reader uses it, and that its
;;; errors reach the reader's condition with the part's line and name.

(test-group "durations in parts"
  (for-each
   (match-lambda
     ((name instrument tokens expected)
      (test-equal name expected (part-p-events instrument tokens))))
   (list
    (list "a duration in pulses" "reyong" "1:2 2"
          '((0 2 (0)) (2 2 (1))))
    (list "a fraction stays in force" "reyong" "1:1/4 2 3 4"
          '((0 1/4 (0)) (1/4 1/4 (1)) (1/2 1/4 (2)) (3/4 1/4 (3))))
    (list "a suffix on a name and an alias" "reyong" "ding2:1/2 i2 a2:1"
          '((0 1/2 (3)) (1/2 1/2 (3)) (1 1 (7))))
    (list "a suffix on a stroke" "gong" "G:2 P:1/2"
          '((0 2 (0)) (2 1/2 (1))))
    (list "a chord takes the current duration" "reyong" "1:1/2 (2 5)"
          '((0 1/2 (0)) (1/2 1/2 (1 4))))
    (list "_ extends by the current duration" "reyong" "1:1/2 _ 2"
          '((0 1 (0)) (1 1/2 (1))))
    (list "a rest with a duration sets it" "reyong" "-:1/4 1 - 1"
          '((1/4 1/4 (0)) (3/4 1/4 (0))))
    (list "| takes no time" "reyong" "1:1/2 2 | 3 4 |"
          '((0 1/2 (0)) (1/2 1/2 (1)) (1 1/2 (2)) (3/2 1/2 (3))))))
  (test-assert "event times are exact"
    (every (lambda (t) (and (exact? (car t)) (exact? (cadr t))))
           (part-p-events "reyong" "1:1/3 2 3 4:1/2")))
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (piece-length (apply read-defs+ forms)))))
   (list (list "the length in pulses" 4 "(part reyong 1:2 2)")
         (list "a length that is a fraction" 3/2 "(part reyong 1:1/2 2 3)")
         (list "trailing rests with a duration count" 5 "(part reyong 1 -:4)")
         (list "parts of equal length with different durations" 2
               "(part reyong :name a 1:1/2 2 3 4)" "(part reyong :name b 1:2)")
         (list "a part of only rests" 3/2 "(part gong -:1/2 - -)")))
  (let ((pc (read-defs+ "(part reyong :name a 1:1/4 2 3 4)"
                        "(part reyong :name b 1:1/2 -)")))
    (test-equal "part-end leaves out trailing rests" '(1 1/2 1)
      (and pc (map part-end (piece-parts pc))))
    (test-equal "the piece's length includes them" 1
      (and pc (piece-length pc)))))

(test-group "bad-duration"
  (token-tests 'bad-duration
   (list (list "zero" "reyong" "e2:0" 0)
         (list "negative" "reyong" "1 e2:-1" 1)
         (list "a word" "reyong" "e2:x" 0)
         (list "inexact" "reyong" "e2:0.5" 0)
         (list "on a key number" "reyong" "1 2:0" 1)
         (list "on a rest" "reyong" "-:0" 0)
         (list "on a stroke" "gong" "G:x" 0)
         (list "on _" "reyong" "1 _:2" 1)
         (list "after a fraction: where the token starts" "reyong" "1:1/2 2 e2:0" 1))))

(test-group "hold-without-note with durations"
  (token-tests 'hold-without-note
   (list (list "_ after | at the start" "reyong" "| _ 1" 0)
         (list "_ after a rest with a duration" "reyong" "1 -:2 _" 3)
         (list "_ after a rest of a fraction" "reyong" "1 -:1/2 _" 3/2))))

(test-group "misplaced-pulse-check"
  (token-tests 'misplaced-pulse-check
   (list (list "after a half pulse" "reyong" "1:1/2 | 2" 1/2)
         (list "after three quarters" "reyong" "1:1/4 2 3 | 4" 3/4)
         (list "after a rest" "gong" "-:1/2 | G" 1/2)
         (list "the second check" "reyong" "1 | 2:1/2 | 3" 3/2)))
  (let ((pc (read-defs+ "(part reyong :name p | 1:1/2 2 | 3:2 | 4:1/3 5 6 |)")))
    (test-equal "checks on whole pulses read" 4 (and pc (piece-length pc)))))

(test-group "[durations] error fields"
  (for-each
   (match-lambda
     ((name expected tokens)
      (let ((c (catch-syntax-error
                (lambda () (read-piece-string
                            (defs+ (part-p-form "reyong" tokens)))))))
        (test-equal (string-append name ": kind, line, part, time") expected
          (and (notasi-syntax-error? c)
               (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c)
                     (notasi-syntax-error-part c) (notasi-syntax-error-time c))))
        (test-equal (string-append name ": file #f") #f
          (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
        (test-equal (string-append name ": uses '()") '()
          (and (notasi-syntax-error? c) (notasi-syntax-error-uses c)))
        (test-assert (string-append name ": a &notasi-syntax-error, not an &expansion-error")
          (notasi-syntax-error? c))
        (test-assert (string-append name ": the time is exact")
          (and (notasi-syntax-error? c)
               (exact? (notasi-syntax-error-time c)))))))
   (list (list "bad-duration" '(bad-duration 10 p 1/2) "1:1/2 2:0")
         (list "misplaced-pulse-check" '(misplaced-pulse-check 10 p 3/4)
               "1:1/4 2 3 |")
         (list "hold-without-note" '(hold-without-note 10 p 3/2) "1 -:1/2 _")
         (list "note-out-of-range" '(note-out-of-range 10 p 5/2) "1:1/2 2 3 4 5 9")
         (list "unknown-note" '(unknown-note 10 p 1/3) "1:1/3 foo1"))))

;;; ------------------------------------------------------------------
;;; rep through the reader (slice 3, [rep]). (notasi expand) is tested
;;; on its own in tests/expand.scm; these check that parts read `rep`,
;;; and that bad-rep reports the rep's own line while other errors in a
;;; rep keep the part's line.

(test-group "rep in parts"
  (for-each
   (match-lambda
     ((name instrument tokens expected)
      (test-equal name expected (part-p-events instrument tokens))))
   (list
    (list "a rep" "reyong" "(rep 2 1 2)"
          '((0 1 (0)) (1 1 (1)) (2 1 (0)) (3 1 (1))))
    (list "notes around a rep" "reyong" "1 (rep 2 i2) 3"
          '((0 1 (0)) (1 1 (3)) (2 1 (3)) (3 1 (2))))
    (list "the body takes the duration before it" "reyong" "1:1/2 (rep 2 2) 3"
          '((0 1/2 (0)) (1/2 1/2 (1)) (1 1/2 (1)) (3/2 1/2 (2))))
    (list "after it, the body's last duration" "reyong" "(rep 2 1:2 2:1/2) 3"
          '((0 2 (0)) (2 1/2 (1)) (5/2 2 (0)) (9/2 1/2 (1)) (5 1/2 (2))))
    (list "a lead hold" "reyong" "1 (rep 2 _ 2)"
          '((0 2 (0)) (2 2 (1)) (4 1 (1))))
    (list "nested" "gong" "(rep 2 G (rep 2 P))"
          '((0 1 (0)) (1 1 (1)) (2 1 (1)) (3 1 (0)) (4 1 (1)) (5 1 (1))))
    (list "a chord in the body" "reyong" "(rep 2 (1 3) -)"
          '((0 1 (0 2)) (2 1 (0 2))))
    (list "| checks that hold every time" "reyong" "(rep 2 1:1/2 2 |)"
          '((0 1/2 (0)) (1/2 1/2 (1)) (1 1/2 (0)) (3/2 1/2 (1))))
    (list "a rep over several lines" "reyong" "(rep 2\n  1\n  2)"
          '((0 1 (0)) (1 1 (1)) (2 1 (0)) (3 1 (1))))))
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (piece-length (apply read-defs+ forms)))))
   (list (list "the length of a rep" 6 "(part reyong (rep 3 1 -))")
         (list "parts of equal length, one with a rep" 4
               "(part reyong :name a (rep 4 1))" "(part reyong :name b 1 2 3 4)")))
  (test-equal "a rep makes a part longer than its partner: unequal-length"
    '(unequal-length 11 b #f)
    (error-fields (defs+ "(part reyong :name a 1 2 3)"
                         "(part reyong :name b (rep 2 1 2))"))))

(test-group "bad-rep"
  (for-each
   (match-lambda
     ((name tokens time)
      (test-equal name (list 'bad-rep 10 'p time)
        (error-fields (defs+ (part-p-form "reyong" tokens))))))
   (list (list "(rep)" "(rep)" 0)
         (list "(rep 2)" "(rep 2)" 0)
         (list "(rep 0 a)" "(rep 0 a1)" 0)
         (list "(rep -1 a)" "(rep -1 a1)" 0)
         (list "(rep 1.5 a)" "(rep 1.5 a1)" 0)
         (list "(rep x a)" "(rep x a1)" 0)
         (list "(rep \"2\" a)" "(rep \"2\" a1)" 0)
         (list "after other tokens: where the rep starts" "1 2:1/2 (rep 0 3)" 3/2)
         (list "nested" "(rep 2 1 (rep 0 2))" 1)))
  (test-equal "a rep on its own line in a multi-line part: that line"
    '(bad-rep 12 p 2)
    (error-fields (defs+ "(part reyong :name p"
                         "  1 2"
                         "  (rep 0 3))")))
  (test-equal "a nested rep on its own line: the inner rep's line"
    '(bad-rep 12 p 2)
    (error-fields (defs+ "(part reyong :name p (rep 2 1"
                         "  2"
                         "  (rep x 3)))")))
  (test-equal "a later part: its own name"
    '(bad-rep 11 q 0)
    (error-fields (defs+ "(part reyong :name p 1)" "(part reyong :name q (rep 2))")))
  (let ((c (catch-syntax-error
            (lambda () (read-piece-string (defs+ "(part reyong :name p" "  (rep 0 1))"))))))
    (test-assert "a &notasi-syntax-error" (notasi-syntax-error? c))
    (test-equal "file #f" #f (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))
    (test-equal "uses '()" '() (and (notasi-syntax-error? c) (notasi-syntax-error-uses c))))
  (let* ((path (write-temp-file "rep.nts"
                                (defs+ "(part reyong :name p 1"
                                       "  (rep 0 1))")))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "from a file: kind and line" '(bad-rep 11)
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c))))
    (test-equal "from a file: the file" path
      (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))))

(test-group "errors inside a rep: the part's line"
  (token-tests 'note-out-of-range
   (list (list "in the body" "reyong" "1 (rep 3 2 9)" 2)
         (list "in a nested body" "reyong" "(rep 2 1 (rep 2 2 9))" 2)))
  (token-tests 'hold-without-note
   (list (list "a part starting with (rep 2 _ a)" "reyong" "(rep 2 _ a1)" 0)
         (list "the body ends in a rest: the second time" "reyong" "1 (rep 2 _ 2 -)" 4)))
  (token-tests 'misplaced-pulse-check
   (list (list "a body of 3/4 pulse: the second time" "reyong" "(rep 2 | 1:1/4 2 3)" 3/4)))
  (token-tests 'bad-duration
   (list (list "a suffix in the body" "reyong" "1 (rep 2 2:0)" 1)))
  (test-equal "a rep on its own line: still the part's line"
    '(note-out-of-range 10 p 2)
    (error-fields (defs+ "(part reyong :name p 1"
                         "  (rep 2 2 9))")))
  (test-equal "a | on a later line of a rep: the part's line"
    '(misplaced-pulse-check 10 p 3/4)
    (error-fields (defs+ "(part reyong :name p"
                         "  (rep 2"
                         "    | 1:1/4 2 3))"))))

;;; ------------------------------------------------------------------
;;; Other part errors

(test-group "unequal-length"
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (error-fields (apply defs+ forms)))))
   (list (list "second part shorter" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2 3 4)" "(part reyong :name b 1 2 3)")
         (list "second part longer" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2 3 4)" "(part reyong :name b 1 2 3 4 5)")
         (list "third part differs" '(unequal-length 12 c #f)
               "(part reyong :name a 1 2 3 4)" "(part gong :name b G - - -)"
               "(part reyong :name c 1 2 3 4 5)")
         (list "second and third differ: the second" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2 3 4)" "(part reyong :name b 1 2 3 4 5)"
               "(part reyong :name c 1 2 3 4 5)")
         (list "compared with the first part, not the one before"
               '(unequal-length 11 b #f)
               "(part reyong :name a 1 2 3 4)" "(part reyong :name b 1 2 3)"
               "(part reyong :name c 1 2 3 4 5)")
         (list "only trailing rests differ (ADR 0012)" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2 - -)" "(part reyong :name b 1 2 -)")
         (list "trailing rests make a part longer" '(unequal-length 11 b #f)
               "(part gong :name a G)" "(part gong :name b G - - -)")
         (list "/ does not count towards length" '(unequal-length 11 b #f)
               "(part reyong :name a 1 / 2 / 3)" "(part reyong :name b 1 / 2 3 / 4)")
         (list "a part without :name: named after its instrument"
               '(unequal-length 11 gong #f)
               "(part reyong 1 2 3 4)" "(part gong G)")
         (list "multi-line part: the form's line" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2 3 4)" "(part reyong :name b" "  1 2 3)")
         (list "lengths in pulses, not tokens: shorter" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2)" "(part reyong :name b 1:1/2 2 3)")
         (list "lengths in pulses, not tokens: longer" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2 3 4)" "(part reyong :name b 1:3 2)")
         (list "a quarter pulse short" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2)" "(part reyong :name b 1 2:1/4 3 4)")
         (list "a trailing rest with a duration" '(unequal-length 11 b #f)
               "(part reyong :name a 1 2)" "(part reyong :name b 1 2 -:1/2)")))
  (let ((pc (read-defs+ "(part reyong :name a 1 2 3 4)" "(part reyong :name b 1:2 2)"
                        "(part gong :name c G:1/4 - - - -:3)")))
    (test-equal "equal lengths in pulses with different tokens read" 4
      (and pc (piece-length pc))))
  (let ((pc (read-defs+ "(part reyong :name a 1 / 2)" "(part reyong :name b / 1 2 /)")))
    (test-equal "/ ignored: parts of equal length read" 2 (piece-length pc))))

(test-group "undefined-instrument"
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (error-kind+line+part (apply defs+ forms)))))
   (list (list "nothing by that name" '(undefined-instrument 10 p)
               "(part nowhere :name p 1)")
         (list "no :name: the part is named after the instrument it names"
               '(undefined-instrument 10 nowhere)
               "(part nowhere 1)")
         (list "names are case-sensitive" '(undefined-instrument 10 p)
               "(part Reyong :name p 1)")
         (list "a scale's name" '(undefined-instrument 10 p)
               "(part selisir :name p 1)")
         (list "a stroke set's name" '(undefined-instrument 10 p)
               "(part gong-strokes :name p G)")
         (list "another part's name" '(undefined-instrument 11 b)
               "(part reyong :name a 1)" "(part a :name b 1)")
         (list "multi-line part: the form's line" '(undefined-instrument 10 p)
               "(part" "  nowhere :name p 1)"))))

(test-group "duplicate-definition of a part"
  (table-tests 'duplicate-definition
   (list (list "part / part" 11
               (defs+ "(part reyong :name a 1)" "(part reyong :name a 2)"))
         (list "identical parts are still duplicates" 11
               (defs+ "(part reyong :name a 1)" "(part reyong :name a 1)"))
         (list "on different instruments" 12
               (defs+ "(part reyong :name a 1)" "" "(part gong :name a G)"))
         (list "a :name equal to another part's default name" 11
               (defs+ "(part gong G)" "(part reyong :name gong 1)"))
         (list "a default name equal to an earlier :name" 11
               (defs+ "(part reyong :name gong 1)" "(part gong G)"))
         (list "three definitions: the second is reported" 11
               (defs+ "(part reyong :name a 1)" "(part reyong :name a 2)"
                      "(part reyong :name a 3)")))))

;;; ADR 0027: two parts on one instrument need names.
(test-group "parts-need-names"
  (table-tests 'parts-need-names
   (list (list "two parts, neither with :name: the second's line" 11
               (defs+ "(part reyong 1 2)" "(part reyong 3 4)"))
         (list "the first with :name, the second without" 11
               (defs+ "(part reyong :name polos 1 2)" "(part reyong 3 4)"))
         (list "the first without :name, the second with" 11
               (defs+ "(part reyong 1 2)" "(part reyong :name sangsih 3 4)"))
         (list "other forms between the two parts" 12
               (defs+ "(part reyong :name polos 1 2)" "(part gong G P)"
                      "(part reyong 3 4)"))
         (list "a third part without :name" 12
               (defs+ "(part reyong :name a 1 2)" "(part reyong :name b 3 4)"
                      "(part reyong 1 2)"))
         (list "multi-line second part: its form's line" 11
               (defs+ "(part ugal 1 2)" "(part ugal" "  :name b 3 4)"))))
  (let ((pc (read-defs+ "(part reyong 1 2)" "(part ugal 3 4)")))
    (test-equal "parts on different instruments need no names" '(reyong ugal kempli)
      (and pc (map part-name (piece-parts pc)))))
  (let ((pc (read-defs+ "(part reyong :name a 1 2)" "(part reyong :name b 3 4)")))
    (test-equal "two named parts on one instrument" '(a b kempli)
      (and pc (map part-name (piece-parts pc))))))

(test-group "bad-form for part"
  (table-tests 'bad-form
   (list (list "part with nothing in it" 10 (defs+ "(part)"))
         (list "part instrument is a string" 10 (defs+ "(part \"reyong\" 1)"))
         (list "part instrument is a number" 10 (defs+ "(part 5 1)"))
         (list "part instrument is a list" 10 (defs+ "(part (reyong) 1)"))
         (list "part with no instrument, a key first" 10 (defs+ "(part :name p 1 2)"))
         (list "part with no tokens" 10 (defs+ "(part reyong)"))
         (list "part with options but no tokens" 10 (defs+ "(part reyong :name p)"))
         (list "multi-line part: the form's line" 10
               (defs+ "(part" "  reyong)")))))

(test-group "part options"
  (table-tests 'bad-option
   (list (list ":name is a string" 10 (defs+ "(part reyong :name \"polos\" 1)"))
         (list ":name is a number (the first token taken as its value)" 10
               (defs+ "(part reyong :name 1 2)"))
         (list ":name is a list" 10 (defs+ "(part reyong :name (p) 1)"))
         (list ":name followed by another key" 10
               (defs+ "(part reyong :name :colour red 1)"))
         (list "an option on its own line: the form's line" 10
               (defs+ "(part reyong" "  :name 5" "  1 2)"))))
  (table-tests 'unknown-option
   (list (list "unknown key" 10 (defs+ "(part reyong :colour red 1)"))
         (list "keys are case-sensitive" 10 (defs+ "(part reyong :Name p 1)"))
         (list "a piece key is not a part key" 10
               (defs+ "(part reyong :pickup 1 1)"))
         (list "unknown key after :name" 10
               (defs+ "(part reyong :name p :colour red 1)"))))
  (table-tests 'duplicate-option
   (list (list ":name twice" 10 (defs+ "(part reyong :name a :name b 1)"))
         (list ":name twice with the same value" 10
               (defs+ "(part reyong :name a :name a 1)"))))
  (table-tests 'option-after-body
   (list (list ":name after the first token" 10 (defs+ "(part reyong 1 :name p 2)"))
         (list ":name at the end" 10 (defs+ "(part reyong 1 2 :name p)"))
         (list "an unknown key after the body has started" 10
               (defs+ "(part reyong 1 2 :colour red)"))
         (list "a key on a later line: the form's line" 10
               (defs+ "(part reyong :name p" "  1 2" "  :colour red)")))))

(test-group "part error fields"
  (let ((c (catch-syntax-error
            (lambda () (read-piece-string (defs+ "(part reyong :name p 1 9)"))))))
    (test-equal "token error: file #f from a string" #f
      (and (notasi-syntax-error? c) (notasi-syntax-error-file c))))
  (for-each
   (match-lambda
     ((name expected contents)
      (let* ((path (write-temp-file (string-append name ".nts") contents))
             (c (catch-syntax-error (lambda () (read-piece-file path)))))
        (test-equal (string-append name " from a file: kind, line, part, time")
          expected
          (and (notasi-syntax-error? c)
               (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c)
                     (notasi-syntax-error-part c) (notasi-syntax-error-time c))))
        (test-equal (string-append name " from a file: file") path
          (and (notasi-syntax-error? c) (notasi-syntax-error-file c))))))
   (list (list "note-out-of-range" '(note-out-of-range 10 p 1)
               (defs+ "(part reyong :name p 1 9)"))
         (list "unknown-note for ·" '(unknown-note 10 p 1)
               (defs+ "(part reyong :name p 1 · 2)"))
         (list "hold-without-note" '(hold-without-note 10 p 0)
               (defs+ "(part reyong :name p _)"))
         (list "unequal-length" '(unequal-length 11 q #f)
               (defs+ "(part reyong :name p 1)" "(part reyong :name q 1 2)"))
         (list "bad-duration" '(bad-duration 10 p 1)
               (defs+ "(part reyong :name p 1 2:x)"))
         (list "misplaced-pulse-check" '(misplaced-pulse-check 10 p 1/2)
               (defs+ "(part reyong :name p 1:1/2 |)")))))

;;; ------------------------------------------------------------------
;;; Check order for parts (03-reader.md, "Error reporting")

(test-group "parts: check order"
  (for-each
   (match-lambda
     ((name expected str)
      (test-equal name expected
        (match (length expected)
          (2 (string-error str))
          (3 (error-kind+line+part str))
          (4 (error-fields str))))))
   (list
    ;; Item 5: use.
    (list "use, then the piece's part errors" '(note-out-of-range 3)
          (lines "(piece \"P\")" "(use gong-kebyar)" "(part ugal :name p 99)"))
    ;; Item 2: a top-level group before everything after it.
    (list "a group comes before a duplicate definition" '(group-outside-score 4)
          (lines "(piece \"P\")" "(strokes g G)" "(strokes g G)" "(group \"G\" a)"))
    (list "a group comes before a part's bad-form" '(group-outside-score 3)
          (lines "(piece \"P\")" "(part)" "(group \"G\" a)"))
    ;; Item 6: shape and options, in file order, before everything after.
    (list "a part's bad-form comes before a scale's bad-degree" '(bad-form 3)
          (lines "(piece \"P\")" "(scale s (ding :display x))" "(part)"))
    (list "bad-form in file order: scale before part" '(bad-form 2)
          (lines "(piece \"P\")" "(scale)" "(part)"))
    (list "bad-form in file order: part before scale" '(bad-form 2)
          (lines "(piece \"P\")" "(part)" "(scale)"))
    (list "a part's option error comes before an earlier duplicate"
          '(unknown-option 4)
          (lines "(piece \"P\")" "(strokes g G)" "(strokes g G)"
                 "(part x :colour red 1)"))
    (list "a part's option-after-body comes before a bad degree"
          '(option-after-body 3)
          (lines "(piece \"P\")" "(scale s (ding :display x))" "(part x 1 :name p)"))
    (list "a part's option comes before its undefined instrument" '(bad-option 2)
          (lines "(piece \"P\")" "(part nowhere :name \"p\" 1)"))
    ;; Item 7: duplicates, before scales and instruments.
    (list "a duplicate part comes before an instrument error"
          '(duplicate-definition 5)
          (lines "(piece \"P\")" "(scale s ding)" "(instrument x s foo1)"
                 "(part x :name p 1)" "(part x :name p 1)"))
    (list "a duplicate part comes before a bad degree" '(duplicate-definition 3)
          (lines "(piece \"P\")" "(part x :name p 1)" "(part x :name p 1)"
                 "(scale s (ding :display x))"))
    (list "duplicates in file order: part before instrument"
          '(duplicate-definition 5)
          (lines "(piece \"P\")" "(strokes g G)" "(part x :name p G)"
                 "(instrument x g G)" "(part x :name p G)" "(instrument x g G)"))
    ;; Item 9 before 13.
    (list "an instrument error comes before an earlier part's error"
          '(unknown-note 4)
          (lines "(piece \"P\")" "(strokes g G)" "(part x 9)"
                 "(instrument x g K)"))
    (list "undefined-scale comes before undefined-instrument" '(undefined-scale 3)
          (lines "(piece \"P\")" "(part nowhere 1)" "(instrument x s ding1)"))
    ;; Item 13: within a part, its instrument, parts-need-names, then
    ;; its tokens left to right.
    (list "undefined-instrument comes before the part's token errors"
          '(undefined-instrument 10 p)
          (defs+ "(part nowhere :name p \"x\" _)"))
    (list "parts-need-names comes before the second part's token errors"
          '(parts-need-names 11)
          (defs+ "(part reyong 1 2)" "(part reyong :name b 9 foo1)"))
    (list "an earlier part's token error before a later parts-need-names"
          '(note-out-of-range 10 reyong 0)
          (defs+ "(part reyong 9 2)" "(part reyong :name b 1 2)"))
    (list "parts-need-names comes before unequal-length" '(parts-need-names 11)
          (defs+ "(part reyong 1 2)" "(part reyong :name b 1)"))
    (list "unknown-note before a later out-of-range"
          '(unknown-note 10 p 1)
          (defs+ "(part reyong :name p 1 foo1 9 _)"))
    (list "out-of-range before a later unknown-note"
          '(note-out-of-range 10 p 1)
          (defs+ "(part reyong :name p 1 9 foo1)"))
    (list "hold-without-note before a later unknown-token"
          '(hold-without-note 10 p 1)
          (defs+ "(part reyong :name p - _ \"x\")"))
    (list "unknown-token before a later bad-chord"
          '(unknown-token 10 p 1)
          (defs+ "(part reyong :name p 1 \"x\" (1))"))
    (list "bad-chord before a later unknown-token"
          '(bad-chord 10 p 1)
          (defs+ "(part reyong :name p 1 (1) \"x\")"))
    (list "bad-duration before a later unknown-note"
          '(bad-duration 10 p 1)
          (defs+ "(part reyong :name p 1 2:0 foo1)"))
    (list "unknown-note before a later bad-duration"
          '(unknown-note 10 p 1)
          (defs+ "(part reyong :name p 1 foo1 2:0)"))
    (list "misplaced-pulse-check before a later out-of-range note"
          '(misplaced-pulse-check 10 p 1/2)
          (defs+ "(part reyong :name p 1:1/2 | 9)"))
    (list "an out-of-range note before a later misplaced-pulse-check"
          '(note-out-of-range 10 p 0)
          (defs+ "(part reyong :name p 9:1/2 |)"))
    (list "a later part's misplaced-pulse-check before unequal-length"
          '(misplaced-pulse-check 12 c 1/2)
          (defs+ "(part reyong :name a 1 2)" "(part reyong :name b 1)"
                 "(part reyong :name c 1:1/2 | 2)"))
    ;; Item 13: parts in file order.
    (list "an earlier part's token error before a later part's"
          '(note-out-of-range 10 a 2)
          (defs+ "(part reyong :name a 1 2 9)" "(part reyong :name b foo1 1 2)"))
    (list "an earlier part's undefined-instrument before a later token error"
          '(undefined-instrument 10 a)
          (defs+ "(part nowhere :name a 1)" "(part reyong :name b 9)"))
    (list "an earlier part's token error before a later undefined-instrument"
          '(note-out-of-range 10 a 0)
          (defs+ "(part reyong :name a 9)" "(part nowhere :name b 1)"))
    ;; Item 13 before 14.
    (list "all parts' token errors come before unequal-length"
          '(note-out-of-range 12 c 3)
          (defs+ "(part reyong :name a 1 2 3 4)" "(part reyong :name b 1 2)"
                 "(part reyong :name c 1 2 3 9)"))
    (list "a later undefined-instrument comes before unequal-length"
          '(undefined-instrument 12 c)
          (defs+ "(part reyong :name a 1 2)" "(part reyong :name b 1)"
                 "(part nowhere :name c 1 2)")))))

(test-group "parts: cases decided at review"
  ;; reyong has 8 notes; ugal has 6.
  (token-tests 'bad-chord
   (list (list "#t inside a chord" "reyong" "1 (2 #t) 3 4" 1)
         (list "1.5 inside a chord" "reyong" "1 (2 1.5) 3 4" 1)
         (list "a chord with one out-of-range note: bad-chord first"
               "reyong" "1 (9) 3 4" 1)))
  (let ((pc (read-defs+ "(part gong :name a / /)")))
    (test-equal "a part of only / is allowed: length 0" 0
      (and pc (piece-length pc)))
    (test-equal "a part of only / has no events" '()
      (and pc (part-triples pc 'a)))))

;;; ==================================================================
;;; Templates (`use`)
;;; ==================================================================
;;;
;;; Written from 03-reader.md ("Public interface", step 3, "Error
;;; reporting" item 5, the template error cases) and 01-notation.md
;;; ("(use TEMPLATE)"). Template files are written at test time into a
;;; fresh temporary folder per case; `(use NAME)` tests put a templates/
;;; folder there and prepend it to %load-path.

;;; ------------------------------------------------------------------
;;; Helpers

(define tpl-root
  (mkdtemp (string-append (or (getenv "TMPDIR") "/tmp") "/notasi-tpl-XXXXXX")))

(define (fresh-dir)
  "A new empty folder for one test case, so file names never clash."
  (mkdtemp (string-append tpl-root "/case-XXXXXX")))

(define (mkdir-p path)
  (unless (file-exists? path)
    (mkdir-p (dirname path))
    (mkdir path)))

(define (put-file dir rel . strs)
  "Write the lines STRS to DIR/REL, creating folders, and return the path."
  (let ((path (string-append dir "/" rel)))
    (mkdir-p (dirname path))
    (call-with-output-file path
      (lambda (port) (display (apply lines strs) port)))
    path))

(define (remove-tpl-root)
  (system* "rm" "-rf" tpl-root))

(define (with-load-path dir thunk)
  "Run THUNK with DIR in front of %load-path, restoring it afterwards."
  (let ((saved #f))
    (dynamic-wind
      (lambda () (set! saved %load-path) (set! %load-path (cons dir saved)))
      thunk
      (lambda () (set! %load-path saved)))))

(define (with-cwd dir thunk)
  "Run THUNK with DIR as the current directory, restoring it afterwards."
  (let ((saved #f))
    (dynamic-wind
      (lambda () (set! saved (getcwd)) (chdir dir))
      thunk
      (lambda () (chdir saved)))))

(define (canon file)
  "FILE canonicalized, so paths joined in different ways compare equal.
#f stays #f; a path that doesn't exist is returned unchanged."
  (and file (or (false-if-exception (canonicalize-path file)) file)))

(define (err-at thunk)
  "(KIND FILE LINE) of the &notasi-syntax-error THUNK raises, with FILE
canonicalized, or the raised object (or no-error) unchanged."
  (let ((c (catch-syntax-error thunk)))
    (if (notasi-syntax-error? c)
        (list (notasi-syntax-error-kind c)
              (canon (notasi-syntax-error-file c))
              (notasi-syntax-error-line c))
        c)))

(define (at kind file line)
  "The expected (KIND FILE LINE), FILE canonicalized as in err-at."
  (list kind (canon file) line))

(define (string-in dir . strs)
  "A thunk that reads the lines STRS with read-piece-string, #:directory DIR."
  (lambda () (read-piece-string (apply lines strs) #:directory dir)))

(define (read-in dir . strs)
  "Read the lines STRS with #:directory DIR, or #f if reading raises."
  (try-read (apply string-in dir strs)))

(define (file-thunk path) (lambda () (read-piece-file path)))

(define (read-file path) (try-read (file-thunk path)))

(define (loc-of x)
  (cond ((scale? x) (scale-location x))
        ((degree? x) (degree-location x))
        ((instrument? x) (instrument-location x))
        ((part? x) (part-location x))
        ((group? x) (group-location x))
        (else (error "no location:" x))))

(define (file+line x)
  "(FILE LINE) of X's source location, FILE canonicalized."
  (let ((loc (loc-of x)))
    (list (canon (source-location-file loc)) (source-location-line loc))))

(define (scale-names pc) (map scale-name (piece-scales pc)))
(define (instrument-names pc) (map instrument-name (piece-instruments pc)))
(define (degree-names sc) (map degree-name (scale-degrees sc)))
(define (note-names inst) (map note-name (vector->list (instrument-notes inst))))

(define (error-tests cases)
  "CASES is a list of (NAME EXPECTED THUNK): check (err-at THUNK)."
  (for-each
   (match-lambda
     ((name expected thunk) (test-equal name expected (err-at thunk))))
   cases))

;;; The repository's templates, whose line numbers the tests look up.
(define selisir-file "templates/selisir.nts")
(define gong-kebyar-file "templates/gong-kebyar.nts")

;;; ------------------------------------------------------------------
;;; Finding templates ("Public interface")

(test-group "templates: finding by name"
  ;; (use NAME) searches %load-path for templates/NAME.nts.
  (let* ((root (fresh-dir))
         (tpl (put-file root "templates/tfind.nts"
                        ";; a template"              ; 1
                        "(scale tfind-s a b)"        ; 2
                        "(instrument tfind-i tfind-s a1 b1)")) ; 3
         (pc (with-load-path root
               (lambda () (try-read-string "(piece \"P\")" "(use tfind)")))))
    (test-equal "use NAME loads templates/NAME.nts from %load-path" '(tfind-s)
      (scale-names pc))
    (test-equal "use NAME: instruments too" '(tfind-i)
      (instrument-names pc))
    (test-equal "use NAME: the scale's file is where it was found, and its line"
      (list (canon tpl) 2)
      (file+line (car (piece-scales pc))))
    (test-equal "use NAME: bare degrees have their scale's file and line"
      (list (list (canon tpl) 2) (list (canon tpl) 2))
      (map file+line (scale-degrees (car (piece-scales pc)))))
    (test-equal "use NAME: the instrument's file and line"
      (list (canon tpl) 3)
      (file+line (car (piece-instruments pc)))))

  ;; The first %load-path entry that has the template wins.
  (let* ((first (fresh-dir))
         (second (fresh-dir)))
    (put-file first "templates/tfirst.nts" "(scale first-s a)")
    (put-file second "templates/tfirst.nts" "(scale second-s a)")
    (test-equal "the first %load-path entry with the template is used"
      '(first-s)
      (with-load-path second
        (lambda ()
          (with-load-path first
            (lambda ()
              (scale-names (try-read-string "(piece \"P\")" "(use tfirst)"))))))))

  ;; A name is not looked up relative to the file or #:directory.
  (let ((dir (fresh-dir)))
    (put-file dir "tnear.nts" "(scale near-s a)")
    (put-file dir "templates/tnear2.nts" "(scale near2-s a)")
    (error-tests
     (list
      (list "use NAME does not look in #:directory itself"
            (at 'template-not-found #f 2)
            (string-in dir "(piece \"P\")" "(use tnear)"))
      (list "use NAME does not look in #:directory's templates/ unless on %load-path"
            (at 'template-not-found #f 2)
            (string-in dir "(piece \"P\")" "(use tnear2)")))))

  ;; The repository's templates/ folder, found with -L .
  (let ((pc (try-read-string "(piece \"P\")" "(use selisir)")))
    (test-equal "use selisir: the repo template" '(selisir)
      (scale-names pc))
    (test-equal "use selisir: file is templates/selisir.nts"
      '("templates" "selisir.nts")
      (let ((f (source-location-file (scale-location (car (piece-scales pc))))))
        (list (basename (dirname f)) (basename f))))
    (test-equal "use selisir: scale line"
      (line-in selisir-file "(scale selisir")
      (source-location-line (scale-location (car (piece-scales pc)))))
    (test-equal "use selisir: degree lines"
      (map (lambda (d) (line-in selisir-file (string-append "(" d)))
           '("ding" "dong" "deng" "dung" "dang"))
      (map (lambda (d) (source-location-line (degree-location d)))
           (scale-degrees (car (piece-scales pc)))))
    (test-equal "use selisir: degree files are the template's"
      '("selisir.nts" "selisir.nts" "selisir.nts" "selisir.nts" "selisir.nts")
      (map (lambda (d) (basename (source-location-file (degree-location d))))
           (scale-degrees (car (piece-scales pc)))))
    (test-equal "use selisir: aliases and displays, no damped forms"
      '((ding (i) "i" #f) (dong (o) "o" #f) (deng (e) "e" #f)
        (dung (u) "u" #f) (dang (a) "a" #f))
      (map degree-fields (scale-degrees (car (piece-scales pc)))))
    (test-equal "use selisir: aliases work in the piece's instrument"
      '(ding2 dong2)
      (note-names (car (piece-instruments
                        (try-read-string "(piece \"P\")" "(use selisir)"
                                         "(instrument x selisir i2 o2)")))))))

(test-group "templates: finding by string"
  ;; read-piece-file: relative to the piece file's folder.
  (let* ((dir (fresh-dir))
         (tpl (put-file dir "defs.nts" ";; defs" "(scale sdefs a b)"))
         (piece (put-file dir "piece.nts"
                          "(piece \"P\")"                  ; 1
                          "(use \"defs.nts\")"             ; 2
                          "(instrument x sdefs a1 b1)"     ; 3
                          "(part x :name p 1 2)"))         ; 4
         (pc (read-file piece)))
    (test-equal "read-piece-file: string relative to the piece's folder"
      '(sdefs) (scale-names pc))
    (test-equal "read-piece-file: template scale's file and line"
      (list (canon tpl) 2) (file+line (car (piece-scales pc))))
    (test-equal "read-piece-file: piece's own instrument has the piece's file"
      (list (canon piece) 3) (file+line (car (piece-instruments pc))))
    (test-equal "read-piece-file: piece's part has the piece's file"
      (list (canon piece) 4) (file+line (car (piece-parts pc)))))

  ;; A string in a template is relative to that template's folder.
  (let* ((dir (fresh-dir))
         (more (put-file dir "sub/more.nts" "(scale sub-more a)")))
    (put-file dir "more.nts" "(scale decoy-more a)")
    (put-file dir "sub/defs.nts" "(use \"more.nts\")" "(scale sub-defs a)")
    (let* ((piece (put-file dir "piece.nts" "(piece \"P\")" "(use \"sub/defs.nts\")"))
           (pc (read-file piece)))
      (test-equal "a string in a subfolder, and a string in a template is relative to the template"
        '(sub-more sub-defs) (scale-names pc))
      (test-equal "sub/more.nts's location"
        (list (canon more) 1) (file+line (car (piece-scales pc))))))

  ;; read-piece-string and read-piece-port: #:directory.
  (let* ((dir (fresh-dir))
         (tpl (put-file dir "defs.nts" "(scale sdir a)")))
    (let ((pc (read-in dir "(piece \"P\")" "(use \"defs.nts\")")))
      (test-equal "read-piece-string: relative to #:directory" '(sdir)
        (scale-names pc))
      (test-equal "read-piece-string: template file is #:directory joined with the string"
        (list (canon tpl) 1) (file+line (car (piece-scales pc)))))
    (let ((pc (try-read
               (lambda ()
                 (call-with-input-string (lines "(piece \"P\")" "(use \"defs.nts\")")
                   (lambda (p) (read-piece-port p #:directory dir)))))))
      (test-equal "read-piece-port: relative to #:directory" '(sdir)
        (scale-names pc))
      (test-equal "read-piece-port: template file"
        (list (canon tpl) 1) (file+line (car (piece-scales pc)))))
    (let ((pc (read-in dir "(piece \"P\")" "(use \"defs.nts\")" "(scale own a)")))
      (test-equal "read-piece-string: the piece's own definitions have file #f"
        '(#f 3) (file+line (cadr (piece-scales pc))))))

  ;; No #:directory: the current directory.
  (let* ((dir (fresh-dir))
         (tpl (put-file dir "cwd-defs.nts" "(scale scwd a)")))
    (test-equal "read-piece-string without #:directory: current directory"
      (list '(scwd) (list (canon tpl) 1))
      (with-cwd dir
        (lambda ()
          (let ((pc (try-read-string "(piece \"P\")" "(use \"cwd-defs.nts\")")))
            (list (scale-names pc) (file+line (car (piece-scales pc))))))))
    (test-equal "read-piece-port without #:directory: current directory"
      '(scwd)
      (with-cwd dir
        (lambda ()
          (scale-names
           (try-read
            (lambda ()
              (call-with-input-string
                  (lines "(piece \"P\")" "(use \"cwd-defs.nts\")")
                read-piece-port))))))))

  ;; A name inside a string-found template still uses %load-path, and a
  ;; string inside a name-found template is relative to templates/.
  (let ((dir (fresh-dir)))
    (put-file dir "defs.nts" "(use selisir)" "(instrument x selisir i1 o1)")
    (let ((pc (read-in dir "(piece \"P\")" "(use \"defs.nts\")")))
      (test-equal "a name in a string-found template: scales" '(selisir)
        (scale-names pc))
      (test-equal "a name in a string-found template: instruments" '(x)
        (instrument-names pc))))
  (let* ((root (fresh-dir))
         (other (fresh-dir)))
    (put-file root "templates/tnest.nts" "(use \"tnest-part.nts\")" "(scale tnest a)")
    (put-file root "templates/tnest-part.nts" "(scale tnest-part a)")
    (put-file other "tnest-part.nts" "(scale decoy a)")
    (test-equal "a string in a name-found template is relative to its templates/ folder"
      '(tnest-part tnest)
      (with-load-path root
        (lambda ()
          (scale-names (read-in other "(piece \"P\")" "(use tnest)")))))))

(test-group "templates: the same template reached twice"
  ;; Two uses reach the same template when the canonical paths are equal.
  (let ((dir (fresh-dir)))
    (put-file dir "defs.nts" "(scale sdefs a)" "(instrument idefs sdefs a1)")
    (mkdir-p (string-append dir "/sub"))
    (let ((pc (read-in dir "(piece \"P\")" "(use \"defs.nts\")" "(use \"defs.nts\")")))
      (test-equal "same use twice: scales once" '(sdefs) (scale-names pc))
      (test-equal "same use twice: instruments once" '(idefs) (instrument-names pc)))
    (let ((pc (read-in dir "(piece \"P\")" "(use \"defs.nts\")" "(use \"./defs.nts\")"
                       "(use \"sub/../defs.nts\")")))
      (test-equal "different spellings of one path: scales once" '(sdefs)
        (scale-names pc))
      (test-equal "different spellings of one path: instruments once" '(idefs)
        (instrument-names pc))))
  (let ((root (fresh-dir)))
    (put-file root "templates/tsame.nts" "(scale tsame a)")
    (test-equal "a name and a string reaching the same file: once" '(tsame)
      (with-load-path root
        (lambda ()
          (scale-names (read-in root "(piece \"P\")" "(use tsame)"
                                "(use \"templates/tsame.nts\")"))))))
  (let ((pc (try-read-string "(piece \"P\")" "(use selisir)" "(use selisir)")))
    (test-equal "use selisir twice" '(selisir) (scale-names pc))))

;;; ------------------------------------------------------------------
;;; Merging definitions (step 3)

(test-group "templates: merged order"
  ;; Depth-first load order; a template's definitions after those of
  ;; the templates it uses; the piece's own last.
  (let ((dir (fresh-dir)))
    (put-file dir "c.nts" "(scale sc x)" "(instrument ic sc x1)")
    (put-file dir "a.nts" "(use \"c.nts\")" "(scale sa x)" "(instrument ia sa x1)")
    (put-file dir "b.nts" "(scale sb x)" "(instrument ib sb x1)")
    (let ((pc (read-in dir "(piece \"P\")" "(use \"a.nts\")" "(use \"b.nts\")"
                       "(instrument ip sp x1)" "(scale sp x)")))
      (test-equal "scales: depth-first, piece last" '(sc sa sb sp)
        (scale-names pc))
      (test-equal "instruments: depth-first, piece last" '(ic ia ib ip)
        (instrument-names pc))
      (test-equal "each scale's file and line"
        (list (list (canon (string-append dir "/c.nts")) 1)
              (list (canon (string-append dir "/a.nts")) 2)
              (list (canon (string-append dir "/b.nts")) 1)
              (list #f 5))
        (map file+line (piece-scales pc)))
      (test-equal "each instrument's file and line"
        (list (list (canon (string-append dir "/c.nts")) 2)
              (list (canon (string-append dir "/a.nts")) 3)
              (list (canon (string-append dir "/b.nts")) 2)
              (list #f 4))
        (map file+line (piece-instruments pc)))))

  ;; gong-kebyar uses selisir: the real templates.
  (let ((pc (try-read-string "(piece \"P\")" "(use gong-kebyar)")))
    (test-equal "gong-kebyar: scales in load order"
      '(selisir kempli-strokes gong-strokes kendang-strokes)
      (scale-names pc))
    (test-equal "gong-kebyar: instruments in load order"
      '(ugal reyong kempli gong kendang)
      (instrument-names pc))
    (test-equal "gong-kebyar: files"
      '("selisir.nts" "gong-kebyar.nts" "gong-kebyar.nts" "gong-kebyar.nts")
      (map (lambda (s) (basename (source-location-file (scale-location s))))
           (piece-scales pc)))
    (test-equal "gong-kebyar: instrument lines"
      (map (lambda (name)
             (line-in gong-kebyar-file (string-append "(instrument " name " ")))
           '("ugal" "reyong" "kempli" "gong" "kendang"))
      (map (lambda (i) (source-location-line (instrument-location i)))
           (piece-instruments pc)))
    (test-equal "gong-kebyar: ugal notes resolve against selisir"
      '(dong1 deng1 dung1 dang1 ding2 dong2 deng2 dung2 dang2 ding3)
      (note-names (instrument-named pc 'ugal)))
    (test-equal "gong-kebyar: the stroke instruments' notes"
      '((K) (G P) (dag dug du))
      (map (lambda (name) (note-names (instrument-named pc name)))
           '(kempli gong kendang)))
    (test-assert "gong-kebyar: ugal's scale is the merged selisir"
      (eq? (instrument-scale (instrument-named pc 'ugal))
           (scale-named pc 'selisir))))

  ;; A template reached twice contributes once, at its first place.
  (let ((pc (try-read-string "(piece \"P\")" "(use gong-kebyar)" "(use selisir)")))
    (test-equal "selisir via gong-kebyar and directly: once, at its first place"
      '(selisir kempli-strokes gong-strokes kendang-strokes)
      (scale-names pc)))
  (let ((dir (fresh-dir)))
    (put-file dir "d.nts" "(scale sd a)")
    (put-file dir "b.nts" "(use \"d.nts\")" "(scale sb a)")
    (put-file dir "c.nts" "(use \"./d.nts\")" "(scale sc a)")
    (test-equal "diamond (b and c both use d): d once, first, no conflict"
      '(sd sb sc)
      (scale-names (read-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c.nts\")")))
    (test-equal "diamond with d also used directly afterwards: still at its first place"
      '(sd sb sc)
      (scale-names (read-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c.nts\")"
                            "(use \"d.nts\")")))))

(test-group "templates: replacing definitions"
  ;; The piece replaces a scale and an instrument: removed from their
  ;; earlier place, the replacement where the piece puts it.
  (let ((dir (fresh-dir)))
    (put-file dir "t.nts"
              "(scale s1 x)" "(scale s2 x)" "(scale s3 x)"
              "(instrument i1 s1 x1)" "(instrument i2 s2 x1)" "(instrument i3 s3 x1)")
    (let ((pc (read-in dir "(piece \"P\")" "(use \"t.nts\")"
                       "(instrument i2 s1 x1)"     ; 3
                       "(scale s2 y)")))           ; 4
      (test-equal "a replaced scale moves to the piece's place" '(s1 s3 s2)
        (scale-names pc))
      (test-equal "a replaced instrument moves to the piece's place" '(i1 i3 i2)
        (instrument-names pc))
      (test-equal "the replacement scale is the piece's" '(y)
        (degree-names (scale-named pc 's2)))
      (test-equal "the replacement scale's location" '(#f 4)
        (file+line (scale-named pc 's2)))
      (test-equal "the replacement instrument's scale" 's1
        (scale-name (instrument-scale (instrument-named pc 'i2))))
      (test-equal "the replacement instrument's location" '(#f 3)
        (file+line (instrument-named pc 'i2)))
      (test-equal "the template's i2 is gone: one instrument named i2" 1
        (count (lambda (i) (eq? (instrument-name i) 'i2)) (piece-instruments pc)))))

  ;; Names are resolved after merging: a template instrument whose notes
  ;; only exist on the piece's replacement scale.
  (let* ((dir (fresh-dir))
         (t-path (put-file dir "t.nts" "(scale s a b)" "(instrument x s a1 c1)")))
    (test-equal "without the replacement: unknown-note in the template"
      (at 'unknown-note t-path 2)
      (err-at (string-in dir "(piece \"P\")" "(use \"t.nts\")")))
    (let ((pc (read-in dir "(piece \"P\")" "(use \"t.nts\")" "(scale s a b c)")))
      (test-equal "with the replacement: the template instrument resolves against it"
        '(a1 c1) (note-names (instrument-named pc 'x)))
      (test-assert "the template instrument's scale is the replacement record"
        (eq? (instrument-scale (instrument-named pc 'x)) (scale-named pc 's)))
      (test-equal "the template instrument keeps the template's location"
        (list (canon t-path) 2) (file+line (instrument-named pc 'x)))))

  ;; The real gong-kebyar: replace ugal's range.
  (let ((pc (try-read-string "(piece \"P\")" "(use gong-kebyar)"
                             "(instrument ugal selisir i2 o2 e2)"   ; 3
                             "(part ugal :name p 1 2 3)")))         ; 4
    (test-equal "replacing ugal: it moves to the end" '(reyong kempli gong kendang ugal)
      (instrument-names pc))
    (test-equal "replacing ugal: the piece's notes" '(ding2 dong2 deng2)
      (note-names (instrument-named pc 'ugal)))
    (test-equal "replacing ugal: location" '(#f 3)
      (file+line (instrument-named pc 'ugal)))
    (test-assert "replacing ugal: the part plays the replacement"
      (eq? (part-instrument (part-named pc 'p)) (instrument-named pc 'ugal))))
  (test-equal "replacing ugal: the template's 10 notes are gone"
    '(note-out-of-range 4 p 0)
    (error-fields (lines "(piece \"P\")" "(use gong-kebyar)"
                         "(instrument ugal selisir i2 o2 e2)" "(part ugal :name p 4)")))

  ;; A piece replaces the template's scale with one that has damped forms.
  (let ((pc (try-read-string "(piece \"P\")" "(use gong-kebyar)"
                             "(scale selisir (ding :alias i :display \"i\" :damped \"i'\")"
                             "  (dong :alias o) (deng :alias e) (dung :alias u) (dang :alias a))")))
    (test-equal "a replacement selisir with :damped: the template's ugal uses it"
      "i'"
      (degree-damped
       (car (scale-degrees (instrument-scale (instrument-named pc 'ugal)))))))

  ;; A template replaces its own template's definitions.
  (let ((dir (fresh-dir)))
    (put-file dir "d.nts" "(scale s a)" "(instrument x s a1)")
    (let ((m (put-file dir "m.nts" "(use \"d.nts\")" "(scale s a b)")))
      (let ((pc (read-in dir "(piece \"P\")" "(use \"m.nts\")")))
        (test-equal "a template's own definition replaces its template's" '(s)
          (scale-names pc))
        (test-equal "the replacing scale is the template's own" '(a b)
          (degree-names (scale-named pc 's)))
        (test-equal "the replacing scale's location" (list (canon m) 2)
          (file+line (scale-named pc 's)))
        (test-equal "d's instrument uses m's scale" '(a b)
          (degree-names (instrument-scale (instrument-named pc 'x))))))))

(test-group "templates: no conflict"
  (let ((dir (fresh-dir)))
    (put-file dir "b.nts" "(scale s a)")
    (put-file dir "c.nts" "(scale s b)")
    (put-file dir "m.nts" "(use \"b.nts\")" "(use \"c.nts\")" "(scale s m)")
    (let ((pc (read-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c.nts\")"
                       "(scale s c)")))
      (test-equal "the piece's own definition resolves a would-be conflict" '(s)
        (scale-names pc))
      (test-equal "the piece's definition is the one kept" '(c)
        (degree-names (scale-named pc 's)))
      (test-equal "and its location" '(#f 4) (file+line (scale-named pc 's))))
    (test-equal "a template's own definition resolves its templates' conflict" '(m)
      (degree-names
       (scale-named (read-in dir "(piece \"P\")" "(use \"m.nts\")") 's))))
  (let ((dir (fresh-dir)))
    (put-file dir "b.nts" "(scale s a)" "(instrument i s a1)")
    (put-file dir "c.nts" "(strokes i K)")
    (let ((pc (read-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c.nts\")")))
      (test-equal "an instrument and a stroke set of the same name don't conflict: scales"
        '(s i) (scale-names pc))
      (test-equal "an instrument and a stroke set of the same name don't conflict: instruments"
        '(i) (instrument-names pc)))))

(test-group "templates: degree options"
  (let* ((dir (fresh-dir))
         (tpl (put-file dir "baris.nts"
                        "(scale baris"                                          ; 1
                        "  (dang :alias (a nang) :display \"nang\" :damped \"na'\")" ; 2
                        "  ding)"                                               ; 3
                        "(instrument x baris dang1 nang2)")))                   ; 4
    (let ((pc (read-in dir "(piece \"P\")" "(use \"baris.nts\")")))
      (test-equal "a template's degrees keep their options"
        '((dang (a nang) "nang" "na'") (ding () "ding" #f))
        (map degree-fields (scale-degrees (scale-named pc 'baris))))
      (test-equal "a template's degree lines" (list (list (canon tpl) 2) (list (canon tpl) 1))
        (map file+line (scale-degrees (scale-named pc 'baris))))
      (test-equal "a template instrument resolves an alias from a list"
        '(dang1 dang2) (note-names (instrument-named pc 'x))))))

;;; ------------------------------------------------------------------
;;; Template error cases

(test-group "template-not-found"
  (let* ((dir (fresh-dir))
         (t (put-file dir "t.nts" ";; t" "(use \"nope.nts\")"))
         (piece (put-file dir "piece.nts" "(piece \"P\")" "" "(use \"nope.nts\")"))
         (piece2 (put-file dir "piece2.nts" "(piece \"P\")" "(use \"t.nts\")")))
    (error-tests
     (list
      (list "a string that doesn't exist" (at 'template-not-found #f 2)
            (string-in dir "(piece \"P\")" "(use \"nope.nts\")"))
      (list "a name that doesn't exist" (at 'template-not-found #f 2)
            (string-in dir "(piece \"P\")" "(use notasi-test-no-such-template)"))
      (list "from a file: the piece's file and the use's line"
            (at 'template-not-found piece 3) (file-thunk piece))
      (list "inside a template: the template's file and line"
            (at 'template-not-found t 2)
            (string-in dir "(piece \"P\")" "(use \"t.nts\")"))
      (list "inside a template, the piece read from a file"
            (at 'template-not-found t 2) (file-thunk piece2))
      (list "a string relative to #:directory, not the current directory"
            (at 'template-not-found #f 2)
            (string-in dir "(piece \"P\")" "(use \"tests/reader.scm\")"))))
    (let ((c (catch-syntax-error (string-in dir "(piece \"P\")" "(use \"nope.nts\")"))))
      (test-equal "kind, part field #f, time field #f" '(template-not-found #f #f)
        (and (notasi-syntax-error? c)
             (list (notasi-syntax-error-kind c) (notasi-syntax-error-part c)
                   (notasi-syntax-error-time c)))))))

(test-group "template-cycle"
  (let* ((dir (fresh-dir))
         (self (put-file dir "self.nts" ";; self" "(use \"self.nts\")"))
         (self2 (put-file dir "self2.nts" "(use \"./self2.nts\")"))
         (a (put-file dir "a.nts" "(use \"b.nts\")" "(scale sa x)"))
         (b (put-file dir "b.nts" ";; b" "(use \"a.nts\")"))
         (piece (put-file dir "piece.nts" "(piece \"P\")" "(use \"piece.nts\")")))
    (error-tests
     (list
      (list "a template using itself" (at 'template-cycle self 2)
            (string-in dir "(piece \"P\")" "(use \"self.nts\")"))
      (list "a template using itself, spelled differently"
            (at 'template-cycle self2 1)
            (string-in dir "(piece \"P\")" "(use \"self2.nts\")"))
      (list "a uses b, b uses a: at b's use" (at 'template-cycle b 2)
            (string-in dir "(piece \"P\")" "(use \"a.nts\")"))
      (list "b uses a, a uses b: at a's use" (at 'template-cycle a 1)
            (string-in dir "(piece \"P\")" "(use \"b.nts\")"))
      (list "the piece file using itself" (at 'template-cycle piece 2)
            (file-thunk piece)))))
  (let ((root (fresh-dir)))
    (put-file root "templates/cyc-a.nts" "(use cyc-b)")
    (put-file root "templates/cyc-b.nts" "(use cyc-c)")
    (let ((c (put-file root "templates/cyc-c.nts" ";; c" ";; c" "(use cyc-a)")))
      (test-equal "a three-template cycle by name: at the use that closes it"
        (at 'template-cycle c 3)
        (with-load-path root
          (lambda ()
            (err-at (lambda () (read-piece-string
                                (lines "(piece \"P\")" "(use cyc-a)")))))))))
  (let* ((dir (fresh-dir))
         (t1 (put-file dir "t1.nts" "(use \"t1.nts\")" "(use \"nope.nts\")"))
         (t2 (put-file dir "t2.nts" "(use \"nope.nts\")" "(use \"t2.nts\")")))
    (error-tests
     (list
      (list "a cycle at an earlier use before a later not-found"
            (at 'template-cycle t1 1)
            (string-in dir "(piece \"P\")" "(use \"t1.nts\")"))
      (list "a not-found at an earlier use before a later cycle"
            (at 'template-not-found t2 1)
            (string-in dir "(piece \"P\")" "(use \"t2.nts\")"))))))

(test-group "bad-form of a use"
  (let ((dir (fresh-dir)))
    (error-tests
     (map (match-lambda
            ((name form)
             (list name (at 'bad-form #f 3)
                   (string-in dir "(piece \"P\")" ";; c" form))))
          (list (list "(use)" "(use)")
                (list "(use 42)" "(use 42)")
                (list "(use a b)" "(use a b)")
                (list "two strings" "(use \"a.nts\" \"b.nts\")")
                (list "(use #t)" "(use #t)")
                (list "a list" "(use (selisir))"))))
    (let ((t (put-file dir "t.nts" ";; t" "(use 42)")))
      (test-equal "in a template: the template's file and line"
        (at 'bad-form t 2)
        (err-at (string-in dir "(piece \"P\")" "(use \"t.nts\")"))))))

;;; A template may hold scale, strokes, instrument, colotomy, pattern and
;;; use forms. colotomy and pattern are built (see "[colotomy]
;;; colotomies in a template" and "[patterns] patterns in a template").
(test-group "forms in a template"
  (let ((dir (fresh-dir)))
    (error-tests
     (map (match-lambda
            ((name form kind)
             (let ((t (put-file dir (string-append name ".nts")
                                "(scale s a)" form "(scale s2 a)")))
               (list (string-append name " in a template") (at kind t 2)
                     (string-in dir "(piece \"P\")"
                                (string-append "(use \"" name ".nts\")"))))))
          (list (list "piece" "(piece \"T\")" 'not-in-template)
                (list "part" "(part x 1)" 'not-in-template)
                (list "score" score-form 'not-in-template)
                (list "group" "(group \"G\" p)" 'group-outside-score)
                (list "text" "(text \"x\")" 'unknown-form))))
    (let ((t (put-file dir "two.nts" "(scale s a)" score-form "(part x 1)")))
      (test-equal "not-in-template: the first such form in file order"
        (at 'not-in-template t 2)
        (err-at (string-in dir "(piece \"P\")" "(use \"two.nts\")"))))
    (let ((t (put-file dir "grp.nts" "(part x 1)" "(group \"G\" p)")))
      (test-equal "a later group comes before an earlier part's not-in-template"
        (at 'group-outside-score t 2)
        (err-at (string-in dir "(piece \"P\")" "(use \"grp.nts\")"))))
    (let* ((t (put-file dir "pattern.nts" "(scale s a)" pattern-form "(scale s2 a)"))
           (piece (put-file dir "pat-piece.nts" "(piece \"P\")" "(use \"pattern.nts\")")))
      (test-equal "a pattern in a template is read and checked: undefined-instrument, the piece read from a file"
        (at 'undefined-instrument t 2)
        (err-at (file-thunk piece))))))

(test-group "use-not-first"
  (let ((dir (fresh-dir)))
    (put-file dir "t.nts" "(scale ts a)")
    (error-tests
     (list
      (list "after a scale" (at 'use-not-first #f 3)
            (string-in dir "(piece \"P\")" "(scale s a)" "(use \"t.nts\")"))
      (list "after a stroke set" (at 'use-not-first #f 3)
            (string-in dir "(piece \"P\")" "(strokes k K)" "(use \"t.nts\")"))
      (list "after an instrument" (at 'use-not-first #f 4)
            (string-in dir "(piece \"P\")" "(use \"t.nts\")"
                       "(instrument x ts a1)" "(use \"t.nts\")"))
      (list "after a part" (at 'use-not-first #f 3)
            (string-in dir "(piece \"P\")" "(part x 1)" "(use \"t.nts\")"))
      (list "a group before a use: group-outside-score first"
            (at 'group-outside-score #f 2)
            (string-in dir "(piece \"P\")" "(group \"G\" p)" "(use \"t.nts\")"))
      (list "the first late use" (at 'use-not-first #f 4)
            (string-in dir "(piece \"P\")" "(use \"t.nts\")" "(scale s a)"
                       "(use \"t.nts\")" "(use \"t.nts\")"))))
    (test-assert "several uses right after piece are fine"
      (piece? (read-in dir "(piece \"P\")" "(use \"t.nts\")" "(use selisir)"
                       "(scale s a)")))
    (let ((t (put-file dir "late.nts" "(scale s a)" ";; c" "(use \"t.nts\")")))
      (test-equal "in a template: the template's file and line"
        (at 'use-not-first t 3)
        (err-at (string-in dir "(piece \"P\")" "(use \"late.nts\")"))))))

(test-group "template-conflict"
  (let* ((dir (fresh-dir))
         (b (put-file dir "b.nts" "(scale s a)"))
         (c (put-file dir "c.nts" ";; c" "(scale s b)"))
         (c-same (put-file dir "c-same.nts" "(scale s a)"))
         (c-strokes (put-file dir "c-strokes.nts" "(strokes s K)"))
         (bi (put-file dir "bi.nts" "(scale sb a)" "(instrument x sb a1)"))
         (ci (put-file dir "ci.nts" "(scale sc a)" "(instrument x sc a1)"))
         (e (put-file dir "e.nts" "(scale s e)"))
         (ce (put-file dir "ce.nts" "(use \"e.nts\")" "(scale other a)"))
         (cr (put-file dir "cr.nts" "(use \"e.nts\")" "(scale s r)"))
         (m (put-file dir "m.nts" "(use \"b.nts\")" "(use \"c.nts\")")))
    (error-tests
     (list
      (list "two templates define the same scale: at the second"
            (at 'template-conflict c 2)
            (string-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c.nts\")"))
      (list "the other use order: at the second in load order"
            (at 'template-conflict b 1)
            (string-in dir "(piece \"P\")" "(use \"c.nts\")" "(use \"b.nts\")"))
      (list "identical text in two files is still a conflict"
            (at 'template-conflict c-same 1)
            (string-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c-same.nts\")"))
      (list "a scale and a stroke set share names"
            (at 'template-conflict c-strokes 1)
            (string-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c-strokes.nts\")"))
      (list "two templates define the same instrument"
            (at 'template-conflict ci 2)
            (string-in dir "(piece \"P\")" "(use \"bi.nts\")" "(use \"ci.nts\")"))
      (list "a name a template gets from its own template conflicts too"
            (at 'template-conflict e 1)
            (string-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"ce.nts\")"))
      (list "a template's replacement conflicts at its own definition"
            (at 'template-conflict cr 2)
            (string-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"cr.nts\")"))
      (list "a conflict between a template's templates"
            (at 'template-conflict c 2)
            (string-in dir "(piece \"P\")" "(use \"m.nts\")"))))
    (let ((cnd (catch-syntax-error
                (string-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c.nts\")"))))
      (test-assert "the message names the first definition's file"
        (and (notasi-syntax-error? cnd)
             (string-contains (exception-message cnd) "b.nts")))
      (test-equal "kind, part field #f, time field #f" '(template-conflict #f #f)
        (and (notasi-syntax-error? cnd)
             (list (notasi-syntax-error-kind cnd) (notasi-syntax-error-part cnd)
                   (notasi-syntax-error-time cnd))))))
  ;; With the real templates: my.nts also uses selisir (no conflict
  ;; there) but defines ugal, which gong-kebyar defines too.
  (let* ((dir (fresh-dir))
         (my (put-file dir "my.nts" "(use selisir)" "(instrument ugal selisir i2)")))
    (test-equal "ugal from gong-kebyar and from another template"
      (at 'template-conflict my 2)
      (err-at (string-in dir "(piece \"P\")" "(use gong-kebyar)" "(use \"my.nts\")")))))

(test-group "errors inside a template"
  (let* ((dir (fresh-dir))
         (t (lambda (name . strs)
              (apply put-file dir (string-append name ".nts") strs)))
         (use (lambda (name)
                (string-in dir "(piece \"P\")"
                           (string-append "(use \"" name ".nts\")")))))
    (let ((rd (t "rd" "(scale s a)" "(scale s2 b")))
      (test-equal "read-error: kind and file" (list 'read-error (canon rd))
        (list-head (err-at (use "rd")) 2))
      (test-assert "read-error: a line"
        (match (err-at (use "rd"))
          (('read-error _ line) (valid-guile-line? line))
          (_ #f))))
    (error-tests
     (list
      (list "improper-form" (at 'improper-form (t "imp" ";; x" "(scale s a . b)") 2)
            (use "imp"))
      (list "unknown-form" (at 'unknown-form (t "unk" "(scale s a)" "(foo)") 2)
            (use "unk"))
      (list "bad-form" (at 'bad-form (t "bf" "(scale s a)" "(instrument x)") 2)
            (use "bf"))
      (list "bad-form: an instrument with an option"
            (at 'bad-form (t "bfo" "(strokes k K)" "(instrument x k K :show-names yes)") 2)
            (use "bfo"))
      (list "duplicate-definition"
            (at 'duplicate-definition (t "dup" "(scale s a)" "(strokes s K)") 2)
            (use "dup"))
      (list "bad-degree at the degree's own line"
            (at 'bad-degree (t "bd" "(scale s" "  a" "  (b :display 1))") 3)
            (use "bd"))
      (list "a degree's unknown-option at the degree's own line"
            (at 'unknown-option (t "uo" "(scale s" "  a" "  (b :colour red))") 3)
            (use "uo"))
      (list "reserved-name"
            (at 'reserved-name (t "rn" ";; x" "(strokes k K rep)") 2)
            (use "rn"))
      (list "degree-ends-in-digit"
            (at 'degree-ends-in-digit (t "dig" ";; x" "(scale s a1)") 2)
            (use "dig"))
      (list "duplicate-degree"
            (at 'duplicate-degree (t "dd" "(scale s a (b :alias a))") 1)
            (use "dd"))
      (list "undefined-scale"
            (at 'undefined-scale (t "us" "(scale s a)" "(instrument x nosuch a1)") 2)
            (use "us"))
      (list "unknown-note"
            (at 'unknown-note (t "un" "(scale s a)" "" "(instrument x s b1)") 3)
            (use "un"))
      (list "notes-not-ascending"
            (at 'notes-not-ascending (t "na" "(scale s a b)" "(instrument x s b1 a1)") 2)
            (use "na"))
      (list "duplicate-note"
            (at 'duplicate-note (t "dn" "(strokes k K)" "(instrument x k K K)") 2)
            (use "dn"))
      (list "an error two templates deep"
            (at 'bad-form (t "deep2" "(scale)") 1)
            (begin (t "deep1" "(use \"deep2.nts\")") (use "deep1")))))
    (let* ((piece (put-file dir "piece.nts" "(piece \"P\")" "(use \"un.nts\")")))
      (test-equal "from a file: the template's file, not the piece's"
        (at 'unknown-note (string-append dir "/un.nts") 3)
        (err-at (file-thunk piece))))))

;;; ------------------------------------------------------------------
;;; Check order (03-reader.md "Error reporting", item 5)

(test-group "templates: check order"
  (let* ((dir (fresh-dir))
         (t (lambda (name . strs)
              (apply put-file dir (string-append name ".nts") strs)))
         (bf (t "bf" "(scale)"))                           ; bad-form at 1
         (dup (t "dup" "(scale s a)" "(scale s b)"))       ; duplicate at 2
         (q (t "q" "(instrument)"))                         ; bad-form at 1
         (m (t "m" "(use \"q.nts\")" "(scale)"))
         (late (t "late" "(use \"q.nts\")" "(scale s a)" "(use \"nope.nts\")"))
         (nit (t "nit" "(use \"nope.nts\")" "(part x 1)"))
         (nit2 (t "nit2" "(use)" "(part x 1)"))
         (nit3 (t "nit3" "(scale)" score-form))
         (grp (t "grp" "(use)" "(group \"G\" p)"))
         (unk (t "unk" "(part x 1)" "(foo)"))
         (b (t "b" "(scale s a)"))
         (c (t "c" "(scale s b)"))
         (mc (t "mc" "(use \"b.nts\")" "(use \"c.nts\")"))
         (tdeg (t "tdeg" "(scale s (a :display 1))"))
         (tnote (t "tnote" "(scale ts a)" "(instrument tx ts b1)"))
         (tus (t "tus" "(instrument tx nosuch a1)"))
         (tshape (t "tshape" "(scale s)")))
    (error-tests
     (list
      ;; Items 1-4 of the piece come before its templates.
      (list "unknown-form in the piece before template-not-found"
            (at 'unknown-form #f 4)
            (string-in dir "(piece \"P\")" "(use \"nope.nts\")" "(scale s a)" "(foo)"))
      (list "the piece's text (an unknown form) before a template's error"
            (at 'unknown-form #f 3)
            (string-in dir "(piece \"P\")" "(use \"bf.nts\")" "(text \"x\")"))
      (list "the piece's group before a template's error"
            (at 'group-outside-score #f 3)
            (string-in dir "(piece \"P\")" "(use \"bf.nts\")" "(group \"G\" p)"))
      (list "bad-title before template-not-found" (at 'bad-title #f 1)
            (string-in dir "(piece 1)" "(use \"nope.nts\")"))
      (list "bad-option before a template's error" (at 'bad-option #f 1)
            (string-in dir "(piece \"P\" 4)" "(use \"bf.nts\")"))
      ;; 5.1: the piece's use forms before loading any template.
      (list "use-not-first before bad-form of an earlier use"
            (at 'use-not-first #f 4)
            (string-in dir "(piece \"P\")" "(use)" "(scale s a)" "(use \"bf.nts\")"))
      (list "use-not-first before template-not-found"
            (at 'use-not-first #f 4)
            (string-in dir "(piece \"P\")" "(use \"nope.nts\")" "(scale s a)"
                       "(use \"bf.nts\")"))
      (list "a later use's bad-form before an earlier use's template-not-found"
            (at 'bad-form #f 3)
            (string-in dir "(piece \"P\")" "(use \"nope.nts\")" "(use 42)"))
      (list "a later use's bad-form before an earlier template's error"
            (at 'bad-form #f 3)
            (string-in dir "(piece \"P\")" "(use \"bf.nts\")" "(use)"))
      ;; 5.2: templates in use order, depth-first.
      (list "the first use's template error first" (at 'bad-form bf 1)
            (string-in dir "(piece \"P\")" "(use \"bf.nts\")" "(use \"nope.nts\")"))
      (list "the first use's not-found first" (at 'template-not-found #f 2)
            (string-in dir "(piece \"P\")" "(use \"nope.nts\")" "(use \"bf.nts\")"))
      (list "depth-first: a template's template before the template's own forms"
            (at 'bad-form q 1)
            (string-in dir "(piece \"P\")" "(use \"m.nts\")"))
      (list "depth-first: a template's template before a later use"
            (at 'bad-form q 1)
            (string-in dir "(piece \"P\")" "(use \"m.nts\")" "(use \"dup.nts\")"))
      (list "in a template: use-not-first before loading its templates"
            (at 'use-not-first late 3)
            (string-in dir "(piece \"P\")" "(use \"late.nts\")"))
      (list "in a template: not-in-template before its use errors"
            (at 'not-in-template nit 2)
            (string-in dir "(piece \"P\")" "(use \"nit.nts\")"))
      (list "in a template: not-in-template before a use's bad-form"
            (at 'not-in-template nit2 2)
            (string-in dir "(piece \"P\")" "(use \"nit2.nts\")"))
      (list "in a template: not-in-template (a score) before bad-form of a definition"
            (at 'not-in-template nit3 2)
            (string-in dir "(piece \"P\")" "(use \"nit3.nts\")"))
      (list "in a template: group-outside-score before a use's bad-form"
            (at 'group-outside-score grp 2)
            (string-in dir "(piece \"P\")" "(use \"grp.nts\")"))
      (list "in a template: unknown-form before not-in-template"
            (at 'unknown-form unk 2)
            (string-in dir "(piece \"P\")" "(use \"unk.nts\")"))
      ;; 5.3: a conflict after all of a file's templates are loaded.
      (list "a later template's error before a conflict between earlier ones"
            (at 'bad-form bf 1)
            (string-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c.nts\")"
                       "(use \"bf.nts\")"))
      (list "a conflict inside a template before a later use's error"
            (at 'template-conflict c 1)
            (string-in dir "(piece \"P\")" "(use \"mc.nts\")" "(use \"bf.nts\")"))
      ;; Templates before the piece's own items 6-13.
      (list "a template error before the piece's bad-form" (at 'duplicate-definition dup 2)
            (string-in dir "(piece \"P\")" "(use \"dup.nts\")" "(scale)"))
      (list "a template error before the piece's duplicate-definition"
            (at 'bad-form bf 1)
            (string-in dir "(piece \"P\")" "(use \"bf.nts\")" "(scale s a)" "(scale s b)"))
      (list "a template error before the piece's part errors"
            (at 'bad-form bf 1)
            (string-in dir "(piece \"P\")" "(use \"bf.nts\")" "(part nope :name p 1)"))
      (list "a template error before the piece's part option errors"
            (at 'bad-form bf 1)
            (string-in dir "(piece \"P\")" "(use \"bf.nts\")" "(part nope 1 :name p)"))
      (list "template-conflict before the piece's bad-form"
            (at 'template-conflict c 1)
            (string-in dir "(piece \"P\")" "(use \"b.nts\")" "(use \"c.nts\")" "(part)"))
      ;; Items 8 and 9 run over the merged definitions, after item 6 of
      ;; the piece.
      (list "the piece's bad-form before a template's bad-degree"
            (at 'bad-form #f 3)
            (string-in dir "(piece \"P\")" "(use \"tdeg.nts\")" "(scale)"))
      (list "the piece's bad-degree before a template's unknown-note"
            (at 'bad-degree #f 3)
            (string-in dir "(piece \"P\")" "(use \"tnote.nts\")" "(scale s (a :display 1))"))
      (list "the piece's degree-ends-in-digit before a template's undefined-scale"
            (at 'degree-ends-in-digit #f 3)
            (string-in dir "(piece \"P\")" "(use \"tus.nts\")" "(scale s a1)"))
      (list "a template's bad-degree before the piece's (merged order)"
            (at 'bad-degree tdeg 1)
            (string-in dir "(piece \"P\")" "(use \"tdeg.nts\")" "(scale s2 (b :display 1))"))
      (list "a template's unknown-note before the piece's (merged order)"
            (at 'unknown-note tnote 2)
            (string-in dir "(piece \"P\")" "(use \"tnote.nts\")" "(scale s a)"
                       "(instrument x s b1)"))
      ;; Replaced definitions.
      (list "a replaced template scale's bad-form is still an error"
            (at 'bad-form tshape 1)
            (string-in dir "(piece \"P\")" "(use \"tshape.nts\")" "(scale s a)"))
      (list "a duplicate in a template is an error even if the piece replaces the name"
            (at 'duplicate-definition dup 2)
            (string-in dir "(piece \"P\")" "(use \"dup.nts\")" "(scale s c)"))
      (list "a replaced template scale's bad-degree is not checked"
            'no-error
            (string-in dir "(piece \"P\")" "(use \"tdeg.nts\")" "(scale s a)"))
      (list "a replaced template instrument's unknown-note is not checked"
            'no-error
            (string-in dir "(piece \"P\")" "(use \"tnote.nts\")"
                       "(instrument tx ts a1)"))))
    (test-equal "read-error in the piece before a template error" 'read-error
      (kind-of (catch-syntax-error
                (string-in dir "(piece \"P\")" "(use \"bf.nts\")" "(scale s a"))))))

;;; ==================================================================
;;; [colotomy] Colotomies, the pickup, `||` and generated parts
;;; (slice feat/music-colotomy)
;;; ==================================================================

;;; ------------------------------------------------------------------
;;; Fixtures. Line numbers matter: the comments give them. Parts start
;;; on line 12.
;;;
;;;   ugal (7 notes):   0 o1  1 e1  2 u1  3 a1  4 i2  5 o2  6 e2
;;;   gong (3 notes):   0 G  1 GL  2 P
;;;   kempur (1 note):  0 P
;;;   kempli (1 note):  0 K
;;;
;;; gilak's gong over one cycle: GL at 3, P at 4, P at 6, G at 7.
;;; pair's kempur (2 pulses, twice a cycle): P at 1 and 3; its gong: G at 3.
;;; long's gong: P at 2, held 2 pulses (to the cycle's end).

(define colo-lines
  (list "(scale selisir (ding :alias i) (dong :alias o) (deng :alias e) (dung :alias u) (dang :alias a))" ; 2
        "(strokes gong-strokes G GL P)"                       ; 3
        "(strokes kempli-strokes K)"                          ; 4
        "(instrument ugal selisir o1 e1 u1 a1 i2 o2 e2)"      ; 5
        "(instrument gong gong-strokes G GL P)"               ; 6
        "(instrument kempur gong-strokes P)"                  ; 7
        "(instrument kempli kempli-strokes K)"                ; 8
        "(colotomy gilak 8 (gong gong -:3 GL:1 P - P G))"     ; 9
        "(colotomy pair 4 (kempur kempur - P) (gong gong -:3 G:1))" ; 10
        "(colotomy long 4 (gong gong -:2 P:2))"))             ; 11

(define (piece-with options)
  "The piece form on line 1, with OPTIONS (a string) after its title."
  (string-append "(piece \"C\" " options ")"))

(define (colo+ options . more)
  "A piece with OPTIONS, the colotomy fixtures, then the lines MORE from
line 12."
  (apply lines (piece-with options) (append colo-lines more)))

(define (read-colo+ options . more)
  (try-read-string (apply colo+ options more)))

;;; No kempli instrument: the timekeeper plays the built-in one. Parts
;;; start on line 7.
;;;   u (2 notes): 0 a1  1 b1
(define bare-lines
  (list "(scale s a b)"                                       ; 2
        "(strokes gong-strokes G GL P)"                       ; 3
        "(instrument u s a1 b1)"                              ; 4
        "(instrument gong gong-strokes G GL P)"               ; 5
        "(colotomy gilak 8 (gong gong -:3 GL:1 P - P G))"))   ; 6

(define (bare+ options . more)
  (apply lines (piece-with options) (append bare-lines more)))

(define (read-bare+ options . more)
  (try-read-string (apply bare+ options more)))

(define (safe thunk)
  "THUNK's value, or #f if it raises, for bindings outside test forms."
  (guard (c (#t #f)) (thunk)))

(define (ones from to note)
  "One-pulse events of NOTE at every pulse from FROM below TO."
  (map (lambda (i) (list i 1 (list note))) (iota (- to from) from)))

(define (the-colotomy pc)
  "The colotomy of PC's single entry in piece-colotomies."
  (cdr (car (piece-colotomies pc))))

(define (colotomy-part-named c name)
  (find-named part-name name (colotomy-parts c)))

(define (line-of-part pc name)
  (source-location-line (part-location (part-named pc name))))

(define (file-of-part pc name)
  (source-location-file (part-location (part-named pc name))))

(define gilak-gong-1
  ;; gilak's gong over its one cycle, in the colotomy record
  '((3 1 (1)) (4 1 (2)) (6 1 (2)) (7 1 (0))))

;;; ------------------------------------------------------------------
;;; Reading a colotomy

(test-group "[colotomy] the colotomy record"
  (let* ((pc (read-colo+ ":colotomy gilak" "(part ugal 1:16)"))
         (c (safe (lambda () (the-colotomy pc)))))
    (test-equal "piece-colotomies: one entry, starting at 0" '(0)
      (map car (piece-colotomies pc)))
    (test-assert "a colotomy record" (colotomy? c))
    (test-equal "name" 'gilak (colotomy-name c))
    (test-equal "length in pulses" 8 (colotomy-length c))
    (test-equal "timekeeper" 'kempli (colotomy-timekeeper c))
    (test-equal "location: its form's line, file #f from a string" '(#f 9)
      (let ((loc (colotomy-location c)))
        (list (source-location-file loc) (source-location-line loc))))
    (test-equal "parts, named as the colotomy names them" '(gong)
      (map part-name (colotomy-parts c)))
    (test-assert "its part plays the piece's gong"
      (eq? (part-instrument (colotomy-part-named c 'gong))
           (instrument-named pc 'gong)))
    (test-equal "its part's events over one cycle" gilak-gong-1
      (map event-triple (part-events (colotomy-part-named c 'gong)))))

  (let* ((pc (read-colo+ ":colotomy pair" "(part ugal 1:8)"))
         (c (safe (lambda () (the-colotomy pc)))))
    (test-equal "two parts, in the colotomy's order" '(kempur gong)
      (map part-name (colotomy-parts c)))
    (test-equal "a shorter part is written out over the cycle"
      '((1 1 (0)) (3 1 (0)))
      (map event-triple (part-events (colotomy-part-named c 'kempur))))
    (test-equal "the other part" '((3 1 (0)))
      (map event-triple (part-events (colotomy-part-named c 'gong)))))

  (let ((pc (read-colo+ ":colotomy one"
                        "(colotomy one 8 (gong gong G))"    ; 12
                        "(part ugal 1:8)")))
    (test-equal "a part of one pulse is written out on every pulse"
      (ones 0 8 0)
      (map event-triple
           (part-events (colotomy-part-named (the-colotomy pc) 'gong))))
    (test-equal "a part of one pulse: the generated gong" (ones 0 8 0)
      (part-triples pc 'gong)))

  (let ((pc (read-colo+ ":colotomy gilak"
                        "(colotomy gong 4 (gong gong G:4))" ; 12
                        "(part ugal 1:8)")))
    (test-assert "a colotomy may share its name with an instrument" (piece? pc)))

  (for-each
   (match-lambda
     ((name form)
      (test-assert name
        (piece? (read-colo+ "" form)))))
   (list (list "a part as long as the cycle" "(colotomy c 8 (gong gong G:8))")
         (list "a part of half the cycle" "(colotomy c 8 (gong gong G:4))")
         (list "a part of a quarter of the cycle" "(colotomy c 8 (gong gong G -))")
         (list "several parts" "(colotomy c 8 (gong gong G:8) (kempur kempur P:4))")
         (list "a colotomy on several lines"
               "(colotomy c 8\n  (gong gong -:7 G:1)\n  (kempur kempur - P))")
         (list "a part with rep and |"
               "(colotomy c 8 (gong gong (rep 2 -:3 | G:1)))"))))

(test-group "[colotomy] a colotomy that the piece does not use"
  (let ((pc (read-colo+ "" "(part gong G - - -)" "(part kempur P - - -)")))
    (test-assert "reads" (piece? pc))
    (test-equal "no colotomies, pickup 0" '(() 0)
      (and pc (list (piece-colotomies pc) (piece-pickup pc))))
    (test-equal "written gong and kempur parts are allowed; then kempli"
      '((gong written) (kempur written) (kempli timekeeper))
      (and pc (map (lambda (p) (list (part-name p) (part-origin p)))
                   (piece-parts pc))))
    (test-equal "a length that is not whole cycles is fine" 4
      (and pc (piece-length pc)))))

;;; ------------------------------------------------------------------
;;; Generated parts

(test-group "[colotomy] generated parts, no pickup"
  (let ((pc (read-colo+ ":colotomy gilak" "(part ugal 1:16)")))  ; 12
    (test-equal "length: two cycles" 16 (piece-length pc))
    (test-equal "pickup 0" 0 (piece-pickup pc))
    (test-equal "written parts, then the colotomy's, then kempli"
      '(ugal gong kempli)
      (map part-name (piece-parts pc)))
    (test-equal "origins" '(written colotomy timekeeper)
      (map part-origin (piece-parts pc)))
    (test-equal "gong: the cycle laid end to end"
      '((3 1 (1)) (4 1 (2)) (6 1 (2)) (7 1 (0))
        (11 1 (1)) (12 1 (2)) (14 1 (2)) (15 1 (0)))
      (part-triples pc 'gong))
    (test-equal "kempli: K on every pulse" (ones 0 16 0)
      (part-triples pc 'kempli))
    (test-assert "gong plays the piece's gong"
      (eq? (part-instrument (part-named pc 'gong)) (instrument-named pc 'gong)))
    (test-assert "kempli plays the piece's kempli"
      (eq? (part-instrument (part-named pc 'kempli))
           (instrument-named pc 'kempli)))
    (test-equal "generated parts have the colotomy's location" '((#f 9) (#f 9))
      (map (lambda (name) (list (file-of-part pc name) (line-of-part pc name)))
           '(gong kempli)))
    (test-equal "the written part keeps its own line" 12 (line-of-part pc 'ugal))
    (test-equal "default groups: one per part, generated ones included"
      '("ugal" "gong" "kempli")
      (map group-label (default-groups pc)))
    (test-equal "part-end of each" '(16 16 16) (map part-end (piece-parts pc))))

  (let ((pc (read-colo+ ":colotomy gilak :pickup 0" "(part ugal 1:16)")))
    (test-equal ":pickup 0 is no pickup" '(0 16)
      (list (piece-pickup pc) (piece-length pc)))
    (test-equal ":pickup 0: the same gong"
      '((3 1 (1)) (4 1 (2)) (6 1 (2)) (7 1 (0))
        (11 1 (1)) (12 1 (2)) (14 1 (2)) (15 1 (0)))
      (part-triples pc 'gong)))

  (let ((pc (read-colo+ ":colotomy gilak" "(part ugal :name a 1:8)"
                        "(part ugal :name b -:8)")))
    (test-equal "several written parts come first"
      '(a b gong kempli)
      (map part-name (piece-parts pc)))))

(test-group "[colotomy] generated parts with a pickup"
  (let ((pc (read-colo+ ":colotomy gilak :pickup 1" "(part ugal 1:17)")))
    (test-equal "length: the pickup plus two cycles" 17 (piece-length pc))
    (test-equal "pickup" 1 (piece-pickup pc))
    (test-equal "gong: every cycle ends on the gong; the pickup is its last pulse"
      '((0 1 (0))
        (4 1 (1)) (5 1 (2)) (7 1 (2)) (8 1 (0))
        (12 1 (1)) (13 1 (2)) (15 1 (2)) (16 1 (0)))
      (part-triples pc 'gong))
    (test-equal "kempli: K on every pulse, the pickup included" (ones 0 17 0)
      (part-triples pc 'kempli))
    (test-equal "time->position: the pickup is cycle 0, pulse 8"
      '((0 8) (1 1) (1 8) (2 1) (2 8))
      (map (lambda (t) (time->position pc t)) '(0 1 8 9 16)))
    (test-equal "position->time" '(0 1 9)
      (list (position->time pc 0 8) (position->time pc 1 1)
            (position->time pc 2 1))))

  (let ((pc (read-colo+ ":colotomy gilak :pickup 8" "(part ugal 1:16)")))
    (test-equal "a pickup of a whole cycle" '(8 16)
      (list (piece-pickup pc) (piece-length pc)))
    (test-equal "a pickup of a whole cycle: the gong as without one"
      '((3 1 (1)) (4 1 (2)) (6 1 (2)) (7 1 (0))
        (11 1 (1)) (12 1 (2)) (14 1 (2)) (15 1 (0)))
      (part-triples pc 'gong)))

  (let ((pc (read-colo+ ":colotomy gilak :pickup 3" "(part ugal 1:11)")))
    (test-equal "a pickup of 3: strokes before time 0 are left out"
      '((1 1 (2)) (2 1 (0))
        (6 1 (1)) (7 1 (2)) (9 1 (2)) (10 1 (0)))
      (part-triples pc 'gong)))

  (let ((pc (read-colo+ ":colotomy pair :pickup 1" "(part ugal 1:9)")))
    (test-equal "two colotomy parts, in the colotomy's order, then kempli"
      '(ugal kempur gong kempli)
      (map part-name (piece-parts pc)))
    (test-equal "origins" '(written colotomy colotomy timekeeper)
      (map part-origin (piece-parts pc)))
    (test-equal "kempur: a part of half the cycle, repeated"
      '((0 1 (0)) (2 1 (0)) (4 1 (0)) (6 1 (0)) (8 1 (0)))
      (part-triples pc 'kempur))
    (test-equal "gong" '((0 1 (0)) (4 1 (0)) (8 1 (0)))
      (part-triples pc 'gong))
    (test-equal "kempli" (ones 0 9 0) (part-triples pc 'kempli))
    (test-equal "locations: the colotomy's line" '(10 10 10)
      (map (lambda (name) (line-of-part pc name)) '(kempur gong kempli)))
    (test-equal "default groups" '("ugal" "kempur" "gong" "kempli")
      (map group-label (default-groups pc))))

  (let ((pc (read-colo+ ":colotomy long :pickup 1" "(part ugal 1:5)")))
    (test-equal "a stroke starting before time 0 is cut at 0"
      '((0 1 (2)) (3 2 (2)))
      (part-triples pc 'gong))))

(test-group "[colotomy] 01's Gilak"
  (let ((pc (read-colo+ ":colotomy gilak :pickup 1"
                        "(part ugal  a1 ||  o2 i2 e2 o2 | a1 o2 i2 a1 ||)")))
    (test-assert "reads" (piece? pc))
    (test-equal "length 9" 9 (and pc (piece-length pc)))
    (test-equal "ugal events"
      '((0 1 (3)) (1 1 (5)) (2 1 (4)) (3 1 (6)) (4 1 (5))
        (5 1 (3)) (6 1 (5)) (7 1 (4)) (8 1 (3)))
      (and pc (part-triples pc 'ugal)))
    (test-equal "parts" '(ugal gong kempli)
      (and pc (map part-name (piece-parts pc))))))

;;; ------------------------------------------------------------------
;;; The timekeeper

(test-group "[colotomy] the built-in kempli"
  (let* ((pc (read-bare+ ":colotomy gilak" "(part u 1:8)"))   ; 7
         (k (safe (lambda () (part-named pc 'kempli))))
         (inst (safe (lambda () (part-instrument k)))))
    (test-equal "parts: written, colotomy, timekeeper" '(u gong kempli)
      (map part-name (piece-parts pc)))
    (test-equal "origin" 'timekeeper (part-origin k))
    (test-equal "events: K on every pulse" (ones 0 8 0) (part-triples pc 'kempli))
    (test-equal "an instrument called kempli with one stroke, K" '(kempli (K))
      (list (instrument-name inst)
            (map note-name (vector->list (instrument-notes inst)))))
    (test-assert "not in piece-instruments"
      (not (memq inst (piece-instruments pc))))
    (test-equal "piece-instruments are the file's" '(u gong)
      (instrument-names pc))
    (test-assert "its stroke set is not in piece-scales"
      (not (memq (instrument-scale inst) (piece-scales pc))))
    (test-equal "piece-scales are the file's" '(s gong-strokes) (scale-names pc))
    (test-equal "never printed: no default group" '("u" "gong")
      (map group-label (default-groups pc)))
    (test-equal "location: the colotomy's" 6 (line-of-part pc 'kempli)))

  (let* ((pc (read-bare+ "" "(part u 1 2 1)"))
         (k (safe (lambda () (part-named pc 'kempli)))))
    (test-equal "without a colotomy: still generated" '(u kempli)
      (map part-name (piece-parts pc)))
    (test-equal "without a colotomy: origin" 'timekeeper (part-origin k))
    (test-equal "without a colotomy: events" (ones 0 3 0)
      (part-triples pc 'kempli))
    (test-equal "without a colotomy: the built-in instrument" 'kempli
      (instrument-name (part-instrument k)))
    (test-assert "without a colotomy: not in piece-instruments"
      (not (memq (part-instrument k) (piece-instruments pc))))
    (test-equal "without a colotomy: no group" '("u")
      (map group-label (default-groups pc)))))

(test-group "[colotomy] the piece's kempli"
  (let* ((pc (read-defs+ "(part ugal 1 2 3)"))
         (k (safe (lambda () (part-named pc 'kempli)))))
    (test-equal "without a colotomy: after the written parts" '(ugal kempli)
      (map part-name (piece-parts pc)))
    (test-equal "origin" 'timekeeper (part-origin k))
    (test-assert "plays the piece's kempli instrument"
      (eq? (part-instrument k) (instrument-named pc 'kempli)))
    (test-equal "events" (ones 0 3 0) (part-triples pc 'kempli))
    (test-equal "printed: it has a default group" '("ugal" "kempli")
      (map group-label (default-groups pc)))))

(test-group "[colotomy] the timekeeper in a piece of fractional length"
  (for-each
   (match-lambda
     ((name part expected)
      (test-equal name expected
        (part-triples (read-bare+ "" part) 'kempli))))
   (list (list "2 1/2 pulses: the last stroke cut at the end" "(part u 1:5/2)"
               '((0 1 (0)) (1 1 (0)) (2 1/2 (0))))
         (list "half a pulse" "(part u 1:1/2)"
               '((0 1/2 (0))))
         (list "2 1/4 pulses, trailing rests counted" "(part u 1:7/4 -:1/2)"
               '((0 1 (0)) (1 1 (0)) (2 1/4 (0))))
         (list "a whole number of pulses: no cut" "(part u 1:1/2 2:5/2)"
               '((0 1 (0)) (1 1 (0)) (2 1 (0))))))
  (test-equal "on the piece's kempli too"
    '((0 1 (0)) (1 1/2 (0)))
    (part-triples (read-defs+ "(part ugal 1:3/2)") 'kempli)))

;;; ------------------------------------------------------------------
;;; `||` checks

(test-group "[colotomy] || on a cycle boundary reads"
  (for-each
   (match-lambda
     ((name options part length)
      (test-equal name length
        (and=> (read-colo+ options part) piece-length))))
   (list (list "at the end of each cycle" ":colotomy gilak"
               "(part ugal 1:8 || 2:8 ||)" 16)
         (list "at time 0 with no pickup" ":colotomy gilak"
               "(part ugal || 1:8 ||)" 8)
         (list "after the pickup" ":colotomy gilak :pickup 1"
               "(part ugal 1 || 2:8 ||)" 9)
         (list "with durations of a fraction" ":colotomy gilak"
               "(part ugal 1:1/2 2 3:7 ||)" 8)
         (list "in a rep, every repetition" ":colotomy gilak"
               "(part ugal (rep 2 1:8 ||))" 16)
         (list "in a rep after a pickup" ":colotomy gilak :pickup 1"
               "(part ugal 1 || (rep 2 2:8 ||))" 17)
         (list "a cycle of 4" ":colotomy pair"
               "(part ugal 1:4 || 2:4 ||)" 8)
         (list "with | checks too" ":colotomy pair"
               "(part ugal 1 | 2 | 3 | 4 || 5:4 ||)" 8))))

(test-group "misplaced-cycle-check"
  (for-each
   (match-lambda
     ((name options part time)
      (test-equal name (list 'misplaced-cycle-check 12 'p time)
        (error-fields (colo+ options part)))))
   (list (list "after three pulses" ":colotomy gilak"
               "(part ugal :name p 1:3 || 2:5)" 3)
         (list "after half a pulse" ":colotomy gilak"
               "(part ugal :name p 1:1/2 || 2:1/2 3:7)" 1/2)
         (list "a pulse after the cycle" ":colotomy gilak"
               "(part ugal :name p 1:9 || 2:7)" 9)
         (list "the second check" ":colotomy gilak"
               "(part ugal :name p 1:8 || 2:4 || 3:4)" 12)
         (list "in a rep: the first repetition" ":colotomy gilak"
               "(part ugal :name p (rep 2 1:4 ||))" 4)
         (list "in a rep: a later repetition" ":colotomy gilak"
               "(part ugal :name p 1:4 (rep 2 2:4 ||))" 12)
         (list "with a pickup: the end of a cycle without it" ":colotomy gilak :pickup 1"
               "(part ugal :name p 1:8 || 2:9)" 8)
         (list "with a pickup: time 0" ":colotomy gilak :pickup 1"
               "(part ugal :name p || 1:9)" 0)
         (list "a cycle of 4: after 2 pulses" ":colotomy pair"
               "(part ugal :name p 1:2 || 2:2)" 2)))
  (test-equal "a multi-line part: the form's line" '(misplaced-cycle-check 12 p 3)
    (error-fields (colo+ ":colotomy gilak" "(part ugal :name p" "  1:3 || 2:5)")))
  (test-equal "without :name: part is the instrument's name"
    '(misplaced-cycle-check 12 ugal 3)
    (error-fields (colo+ ":colotomy gilak" "(part ugal 1:3 || 2:5)"))))

(test-group "no-colotomy for ||"
  (for-each
   (match-lambda
     ((name text expected)
      (test-equal name expected (error-fields text))))
   (list (list "after a pulse" (defs+ "(part reyong :name p 1 || 2)")
               '(no-colotomy 10 p 1))
         (list "at time 0" (defs+ "(part reyong :name p || 1)")
               '(no-colotomy 10 p 0))
         (list "a colotomy defined but not the piece's"
               (colo+ "" "(part ugal :name p 1:8 ||)")
               '(no-colotomy 12 p 8))
         (list "in a rep" (defs+ "(part reyong :name p 1 (rep 2 2 ||))")
               '(no-colotomy 10 p 2)))))

;;; ------------------------------------------------------------------
;;; Lengths

(test-group "incomplete-cycle"
  (for-each
   (match-lambda
     ((name options line . parts)
      (test-equal name (list 'incomplete-cycle line)
        (string-error (apply colo+ options parts)))))
   (list (list "a pulse short of a cycle" ":colotomy gilak" 12 "(part ugal 1:7)")
         (list "a pulse more than a cycle" ":colotomy gilak" 12 "(part ugal 1:9)")
         (list "half a pulse short" ":colotomy gilak" 12 "(part ugal 1:15/2)")
         (list "the first written part's line" ":colotomy gilak" 12
               "(part ugal :name a 1:7)" "(part ugal :name b 1:7)")
         (list "a multi-line first part" ":colotomy gilak" 12
               "(part ugal" "  1:7)")
         (list "with a pickup: whole cycles without it" ":colotomy gilak :pickup 1" 12
               "(part ugal 1:16)")
         (list "with a pickup: the pickup short" ":colotomy gilak :pickup 1" 12
               "(part ugal 1:8)")
         (list "a pickup of a whole cycle" ":colotomy gilak :pickup 8" 12
               "(part ugal 1:9)")
         (list "a cycle of 4" ":colotomy pair" 12 "(part ugal 1:6)")))
  (test-equal "the first written part's line, after other forms"
    '(incomplete-cycle 13)
    (string-error (colo+ ":colotomy gilak" "" "(part ugal 1:7)")))
  (for-each
   (match-lambda
     ((name options length . parts)
      (test-equal name length
        (and=> (apply read-colo+ options parts) piece-length))))
   (list (list "one cycle" ":colotomy gilak" 8 "(part ugal 1:8)")
         (list "three cycles" ":colotomy gilak" 24 "(part ugal 1:24)")
         (list "fractions adding up to a cycle" ":colotomy gilak" 8
               "(part ugal 1:15/2 -:1/2)")
         (list "pickup 1 plus one cycle" ":colotomy gilak :pickup 1" 9 "(part ugal 1:9)")
         (list "pickup 3 plus one cycle" ":colotomy gilak :pickup 3" 11 "(part ugal 1:11)")
         (list "a cycle of 4: three cycles" ":colotomy pair" 12 "(part ugal 1:12)"))))

;;; ------------------------------------------------------------------
;;; Colotomy forms: errors

(test-group "bad-form of a colotomy"
  (table-tests 'bad-form
   (map (match-lambda
          ((name form) (list name 12 (colo+ "" form))))
        (list (list "no name" "(colotomy)")
              (list "a name that is not a symbol" "(colotomy \"c\" 8 (gong gong G:8))")
              (list "a number for a name" "(colotomy 8 (gong gong G:8))")
              (list "no length" "(colotomy c (gong gong G:8))")
              (list "only a name" "(colotomy c)")
              (list "length 0" "(colotomy c 0 (gong gong G))")
              (list "a negative length" "(colotomy c -8 (gong gong G))")
              (list "a fractional length" "(colotomy c 15/2 (gong gong G))")
              (list "an inexact length" "(colotomy c 8.0 (gong gong G:8))")
              (list "a symbol for a length" "(colotomy c x (gong gong G:8))")
              (list "a string for a length" "(colotomy c \"8\" (gong gong G:8))")
              (list "no parts" "(colotomy c 8)")
              (list "a part that is not a list" "(colotomy c 8 gong)")
              (list "a part with no instrument" "(colotomy c 8 (gong))")
              (list "a part with no tokens" "(colotomy c 8 (gong gong))")
              (list "a part whose name is not a symbol" "(colotomy c 8 (\"gong\" gong G:8))")
              (list "a part whose instrument is not a symbol" "(colotomy c 8 (gong 3 G:8))")
              (list "an empty part" "(colotomy c 8 ())"))))
  (test-equal "a colotomy option that doesn't exist: unknown-option"
    '(unknown-option 12)
    (string-error (colo+ "" "(colotomy c 8 :foo 1 (gong gong G:8))"))))

(test-group "duplicate-definition of a colotomy"
  (table-tests 'duplicate-definition
   (list (list "two colotomies of one name: the second" 12
               (colo+ "" "(colotomy gilak 4 (gong gong G:4))"))
         (list "identical colotomies are still duplicates" 12
               (colo+ "" "(colotomy pair 4 (kempur kempur - P) (gong gong -:3 G:1))"))))
  (test-assert "a colotomy may have a part's name"
    (piece? (read-colo+ "" "(part ugal :name gilak 1)"))))

(test-group "token errors in a colotomy part"
  (for-each
   (match-lambda
     ((name form expected)
      (test-equal name expected (error-fields (colo+ "" form)))))
   (list (list "unknown-note" "(colotomy c 8 (gong gong G:4 X))"
               '(unknown-note 12 gong 4))
         (list "a stroke of another instrument" "(colotomy c 8 (kempur kempur G:8))"
               '(unknown-note 12 kempur 0))
         (list "note-out-of-range" "(colotomy c 8 (gong gong G 4 -:6))"
               '(note-out-of-range 12 gong 1))
         (list "hold-without-note" "(colotomy c 8 (gong gong _ G:7))"
               '(hold-without-note 12 gong 0))
         (list "bad-duration" "(colotomy c 8 (gong gong G:0))"
               '(bad-duration 12 gong 0))
         (list "misplaced-pulse-check" "(colotomy c 8 (gong gong G:1/2 | G:15/2))"
               '(misplaced-pulse-check 12 gong 1/2))
         (list "unknown-token" "(colotomy c 8 (gong gong G:4 \"x\" -:3))"
               '(unknown-token 12 gong 4))
         (list "in the second part" "(colotomy c 8 (gong gong G:8) (kempur kempur P:2 X))"
               '(unknown-note 12 kempur 2)))))

(test-group "undefined-instrument in a colotomy"
  (for-each
   (match-lambda
     ((name form expected)
      (test-equal name expected (error-kind+line+part (colo+ "" form)))))
   (list (list "nothing by that name" "(colotomy c 8 (gong nowhere G:8))"
               '(undefined-instrument 12 gong))
         (list "a scale's name" "(colotomy c 8 (gong gong-strokes G:8))"
               '(undefined-instrument 12 gong))
         (list "the second part" "(colotomy c 8 (gong gong G:8) (kp nowhere P:8))"
               '(undefined-instrument 12 kp)))))

(test-group "colotomy-part-length"
  (for-each
   (match-lambda
     ((name form part)
      (test-equal name (list 'colotomy-part-length 12 part)
        (error-kind+line+part (colo+ "" form)))))
   (list (list "3 pulses in a cycle of 8" "(colotomy c 8 (gong gong G - -))" 'gong)
         (list "longer than the cycle" "(colotomy c 8 (gong gong G:9))" 'gong)
         (list "twice the cycle" "(colotomy c 8 (gong gong G:16))" 'gong)
         (list "a fraction that does not divide" "(colotomy c 8 (gong gong G:5/2))" 'gong)
         (list "6 pulses in a cycle of 8" "(colotomy c 8 (gong gong -:5 G:1))" 'gong)
         (list "the second part" "(colotomy c 8 (gong gong G:8) (kempur kempur P:3))"
               'kempur)))
  (test-equal "a multi-line colotomy: its form's line"
    '(colotomy-part-length 12 gong)
    (error-kind+line+part (colo+ "" "(colotomy c 8" "  (gong gong G:3))"))))

;;; ------------------------------------------------------------------
;;; The piece's :colotomy and :pickup

(test-group "undefined-colotomy"
  (for-each
   (match-lambda
     ((name text)
      (test-equal name '(undefined-colotomy 1) (string-error text))))
   (list (list "nothing by that name" (colo+ ":colotomy nowhere" "(part ugal 1:8)"))
         (list "names are case-sensitive" (colo+ ":colotomy Gilak" "(part ugal 1:8)"))
         (list "an instrument's name" (colo+ ":colotomy gong" "(part ugal 1:8)"))
         (list "a part's name" (colo+ ":colotomy ugal" "(part ugal 1:8)"))
         (list "no colotomies at all" "(piece \"P\" :colotomy gilak)")
         (list "with a pickup" (colo+ ":colotomy nowhere :pickup 1" "(part ugal 1:9)"))))
  (test-equal "the piece form's line" '(undefined-colotomy 2)
    (string-error (lines ";; c" "(piece \"P\" :colotomy gilak)")))
  (let ((c (catch-syntax-error
            (lambda () (read-piece-string "(piece \"P\" :colotomy gilak)")))))
    (test-equal "part and time #f" '(#f #f)
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-part c) (notasi-syntax-error-time c))))))

(test-group ":colotomy and :pickup option errors"
  (for-each
   (match-lambda
     ((name kind options)
      (test-equal name (list kind 1)
        (string-error (colo+ options "(part ugal 1:9)")))))
   (list (list ":colotomy with no value" 'bad-option ":colotomy")
         (list ":colotomy followed by a key" 'bad-option ":colotomy :pickup 1")
         (list ":colotomy a number" 'bad-option ":colotomy 8")
         (list ":colotomy a string" 'bad-option ":colotomy \"gilak\"")
         (list ":pickup with no value" 'bad-option ":colotomy gilak :pickup")
         (list ":pickup 1.5" 'bad-option ":colotomy gilak :pickup 1.5")
         (list ":colotomy twice" 'duplicate-option ":colotomy gilak :colotomy gilak")
         (list ":pickup twice" 'duplicate-option ":colotomy gilak :pickup 1 :pickup 1"))))

(test-group "bad-pickup"
  (for-each
   (match-lambda
     ((name options)
      (test-equal name '(bad-pickup 1)
        (string-error (colo+ options "(part ugal 1:9)")))))
   (list (list "more than a cycle" ":colotomy gilak :pickup 9")
         (list "two cycles" ":colotomy gilak :pickup 16")
         (list "negative" ":colotomy gilak :pickup -1")
         (list "a fraction of a pulse" ":colotomy gilak :pickup 1/2")
         (list "a whole number and a fraction" ":colotomy gilak :pickup 3/2")
         (list "more than a cycle of 4" ":colotomy pair :pickup 5")
         (list "the key order does not matter" ":pickup 9 :colotomy gilak")))
  (for-each
   (match-lambda
     ((name options part)
      (test-assert name (piece? (read-colo+ options part)))))
   (list (list "pickup 0" ":colotomy gilak :pickup 0" "(part ugal 1:8)")
         (list "pickup of one cycle" ":colotomy gilak :pickup 8" "(part ugal 1:16)")
         (list "pickup of one cycle of 4" ":colotomy pair :pickup 4" "(part ugal 1:8)")
         (list ":pickup before :colotomy" ":pickup 1 :colotomy gilak" "(part ugal 1:9)"))))

(test-group "no-colotomy for :pickup"
  (for-each
   (match-lambda
     ((name text)
      (test-equal name '(no-colotomy 1) (string-error text))))
   (list (list ":pickup 1 alone" "(piece \"P\" :pickup 1)")
         (list ":pickup 0 alone" "(piece \"P\" :pickup 0)")
         (list "colotomies defined, none named" (colo+ ":pickup 1" "(part ugal 1:9)"))))
  (let ((c (catch-syntax-error
            (lambda () (read-piece-string "(piece \"P\" :pickup 1)")))))
    (test-equal "part and time #f" '(#f #f)
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-part c) (notasi-syntax-error-time c))))))

;;; ------------------------------------------------------------------
;;; Generated parts' names

(test-group "duplicate-definition of a generated part"
  (for-each
   (match-lambda
     ((name expected text)
      (test-equal name expected (string-error text))))
   (list (list "a written gong with gilak" '(duplicate-definition 12)
               (colo+ ":colotomy gilak" "(part gong G:8)"))
         (list "a written kempli with a colotomy" '(duplicate-definition 13)
               (colo+ ":colotomy gilak" "(part ugal 1:8)" "(part kempli K:8)"))
         (list "a :name of kempli" '(duplicate-definition 12)
               (colo+ ":colotomy gilak" "(part ugal :name kempli 1:8)"))
         (list "a :name of a colotomy part" '(duplicate-definition 12)
               (colo+ ":colotomy gilak" "(part ugal :name gong 1:8)"))
         (list "the second part of a colotomy" '(duplicate-definition 13)
               (colo+ ":colotomy pair" "(part ugal :name a 1:4)"
                      "(part ugal :name kempur 1:4)"))
         (list "a written kempli without a colotomy" '(duplicate-definition 10)
               (defs+ "(part kempli K)"))
         (list "a :name of kempli without a colotomy" '(duplicate-definition 10)
               (defs+ "(part reyong :name kempli 1)"))
         (list "kempli with the built-in timekeeper" '(duplicate-definition 7)
               (bare+ "" "(part u :name kempli 1)"))
         (list "the first such part" '(duplicate-definition 12)
               (colo+ ":colotomy gilak" "(part ugal :name kempli 1:8)"
                      "(part ugal :name gong 1:8)")))))

;;; ------------------------------------------------------------------
;;; Check order (03, "Error reporting", items 4, 7, 9, 10, 12 to 15)

(test-group "[colotomy] check order"
  (for-each
   (match-lambda
     ((name expected text)
      (test-equal name expected (string-error text))))
   (list
    (list "4 before 10: a piece option before a colotomy" '(bad-option 1)
          (colo+ ":colotomy gilak :pickup 1.5" "(colotomy c 8 (gong gong G:3))"))
    (list "6 before 10: a colotomy's shape before another's tokens" '(bad-form 13)
          (colo+ "" "(colotomy c 8 (gong gong X:8))" "(colotomy d 0 (gong gong G))"))
    (list "7 before 10: duplicate parts before a colotomy's tokens"
          '(duplicate-definition 14)
          (colo+ "" "(colotomy c 8 (gong gong X:8))"
                 "(part ugal :name a 1)" "(part ugal :name a 1)"))
    (list "9 before 10: an instrument before a colotomy" '(unknown-note 13)
          (colo+ "" "(colotomy c 8 (gong gong X:8))" "(instrument bad gong-strokes X)"))
    (list "10: colotomies in file order" '(colotomy-part-length 12)
          (colo+ "" "(colotomy c 8 (gong gong G:3))" "(colotomy d 8 (gong gong X:8))"))
    (list "10: a part's tokens before its length" '(note-out-of-range 12)
          (colo+ "" "(colotomy c 8 (gong gong G 9 -))"))
    (list "10 before 12: a colotomy before the piece's" '(colotomy-part-length 12)
          (colo+ ":colotomy nowhere" "(colotomy c 8 (gong gong G:3))"))
    (list "10 before 12: an unused colotomy is checked" '(colotomy-part-length 12)
          (colo+ ":colotomy gilak" "(colotomy c 8 (gong gong G:3))" "(part ugal 1:8)"))
    (list "12: undefined-colotomy before bad-pickup" '(undefined-colotomy 1)
          (colo+ ":colotomy nowhere :pickup 99" "(part ugal 1:8)"))
    (list "12 before 13: undefined-colotomy before a part" '(undefined-colotomy 1)
          (colo+ ":colotomy nowhere" "(part ugal 99)"))
    (list "12 before 13: bad-pickup before a part" '(bad-pickup 1)
          (colo+ ":colotomy gilak :pickup 9" "(part nowhere 1)"))
    (list "12 before 13: no-colotomy before a part" '(no-colotomy 1)
          (colo+ ":pickup 1" "(part ugal 99)"))
    (list "13: a misplaced || before the length" '(misplaced-cycle-check 12)
          (colo+ ":colotomy gilak" "(part ugal 1:3 || 2)"))
    (list "13 before 14: a later part's token before the length" '(note-out-of-range 13)
          (colo+ ":colotomy gilak" "(part ugal :name a 1:7)" "(part ugal :name b 99)"))
    (list "14: unequal-length before incomplete-cycle" '(unequal-length 13)
          (colo+ ":colotomy gilak" "(part ugal :name a 1:7)" "(part ugal :name b 1:8)"))
    (list "14 before 15: the length before a generated name" '(incomplete-cycle 12)
          (colo+ ":colotomy gilak" "(part gong G:7)"))
    (list "14 before 15: unequal-length before a generated name" '(unequal-length 13)
          (colo+ ":colotomy gilak" "(part kempli K:8)" "(part ugal 1:7)"))
    (list "7 before 15: written duplicates first" '(duplicate-definition 13)
          (colo+ ":colotomy gilak" "(part ugal :name gong 1:8)" "(part ugal :name gong 1:8)")))))

;;; ------------------------------------------------------------------
;;; Colotomies in templates (03, step 3)

(test-group "[colotomy] colotomies in a template"
  (let* ((dir (fresh-dir))
         (tpl (put-file dir "colo.nts"
                        "(strokes gs G P)"                       ; 1
                        "(instrument gong gs G P)"               ; 2
                        "(colotomy gilak 4 (gong gong -:3 G:1))")) ; 3
         (pc (read-in dir
                      "(piece \"P\" :colotomy gilak)"            ; 1
                      "(use \"colo.nts\")"                       ; 2
                      "(scale s a)"                              ; 3
                      "(instrument u s a1)"                      ; 4
                      "(part u 1:8)")))                          ; 5
    (test-assert "reads" (piece? pc))
    (test-equal "the template's colotomy: file and line" (list (canon tpl) 3)
      (and pc (let ((loc (colotomy-location (the-colotomy pc))))
                (list (canon (source-location-file loc))
                      (source-location-line loc)))))
    (test-equal "generated parts have the colotomy's location, in the template"
      (list (list (canon tpl) 3) (list (canon tpl) 3))
      (and pc (map (lambda (name) (file+line (part-named pc name)))
                   '(gong kempli))))
    (test-equal "the written part has the piece's location" '(#f 5)
      (and pc (list (file-of-part pc 'u) (line-of-part pc 'u))))
    (test-equal "gong events" '((3 1 (0)) (7 1 (0)))
      (and pc (part-triples pc 'gong))))

  (let* ((dir (fresh-dir))
         (tpl (put-file dir "colo.nts"
                        "(strokes gs G P)"
                        "(instrument gong gs G P)"
                        "(colotomy gilak 4 (gong gong -:3 G:1))"))
         (pc (read-in dir
                      "(piece \"P\" :colotomy gilak)"            ; 1
                      "(use \"colo.nts\")"                       ; 2
                      "(colotomy gilak 2 (gong gong - P))"       ; 3
                      "(scale s a)"
                      "(instrument u s a1)"
                      "(part u 1:4)")))
    (test-equal "the piece's colotomy replaces the template's" '(2 #f 3)
      (and pc (let* ((c (the-colotomy pc)) (loc (colotomy-location c)))
                (list (colotomy-length c) (source-location-file loc)
                      (source-location-line loc)))))
    (test-equal "the replacement's gong" '((1 1 (1)) (3 1 (1)))
      (and pc (part-triples pc 'gong))))

  (let* ((dir (fresh-dir))
         (a (put-file dir "a.nts" "(strokes gs G)" "(instrument gong gs G)"
                      "(colotomy c 4 (gong gong -:3 G:1))"))
         (b (put-file dir "b.nts" "(colotomy c 2 (gong gong - G))")))
    (error-tests
     (list (list "the same colotomy from two templates: template-conflict"
                 (at 'template-conflict b 1)
                 (string-in dir "(piece \"P\")" "(use \"a.nts\")" "(use \"b.nts\")")))))

  (let* ((dir (fresh-dir))
         (t (put-file dir "bad.nts" "(strokes gs G)" "(instrument gong gs G)"
                      "(colotomy c 4 (gong gong G - -))")))
    (error-tests
     (list (list "an error in a template's colotomy: the template's file and line"
                 (at 'colotomy-part-length t 3)
                 (string-in dir "(piece \"P\")" "(use \"bad.nts\")"))
           (list "a bad-form colotomy in a template"
                 (let ((t2 (put-file dir "bf.nts" "(colotomy c)")))
                   (at 'bad-form t2 1))
                 (string-in dir "(piece \"P\")" "(use \"bf.nts\")"))))))

;;; ------------------------------------------------------------------
;;; examples/tenzer1.nts reads end to end

(define tenzer-file "examples/tenzer1.nts")

(test-group "tenzer1"
  (let ((pc (read-file tenzer-file)))
    (test-assert "reads into a piece" (piece? pc))
    (test-equal "title" "Eight-pulse gong cycle" (piece-title pc))
    (test-equal "length: 9 pulses" 9 (piece-length pc))
    (test-equal "scales: selisir, then gong-kebyar's stroke sets"
      '(selisir kempli-strokes gong-strokes kendang-strokes)
      (scale-names pc))
    (test-equal "instruments, including those no part plays"
      '(ugal reyong kempli gong kendang)
      (instrument-names pc))
    (test-equal "parts: the written ugal and gong, then the generated kempli"
      '(ugal gong kempli)
      (map part-name (piece-parts pc)))
    (test-equal "origins" '(written written timekeeper)
      (map part-origin (piece-parts pc)))
    (test-equal "no colotomy, no pickup" '(() 0)
      (list (piece-colotomies pc) (piece-pickup pc)))
    (test-assert "the kempli plays the template's kempli instrument"
      (eq? (part-instrument (part-named pc 'kempli))
           (instrument-named pc 'kempli)))
    (test-equal "groups: one default group per part, kempli printed"
      '("ugal" "gong" "kempli")
      (map group-label (default-groups pc)))
    (test-equal "ugal events"
      '((0 1 (3)) (1 1 (5)) (2 1 (4)) (3 1 (6)) (4 1 (5))
        (5 1 (3)) (6 1 (5)) (7 1 (4)) (8 1 (3)))
      (part-triples pc 'ugal))
    (test-equal "kempli events: one K per pulse"
      (map (lambda (i) (list i 1 '(0))) (iota 9))
      (part-triples pc 'kempli))
    (test-equal "gong events"
      '((0 1 (0)) (4 1 (0)) (5 1 (1)) (7 1 (1)) (8 1 (0)))
      (part-triples pc 'gong))
    (test-equal "selisir shows its degrees by vowel"
      '("i" "o" "e" "u" "a")
      (map degree-display (scale-degrees (scale-named pc 'selisir))))
    (test-equal "ugal lane labels are vowel and octave"
      '("o1" "i3")
      (let* ((inst (instrument-named pc 'ugal))
             (v (instrument-notes inst)))
        (list (note-label inst (vector-ref v 0))
              (note-label inst (vector-ref v 9)))))
    (test-equal "selisir's file and line"
      (list "selisir.nts" (line-in selisir-file "(scale selisir"))
      (let ((loc (scale-location (scale-named pc 'selisir))))
        (list (basename (source-location-file loc)) (source-location-line loc))))
    (test-equal "ugal instrument's file and line"
      (list "gong-kebyar.nts" (line-in gong-kebyar-file "(instrument ugal "))
      (let ((loc (instrument-location (instrument-named pc 'ugal))))
        (list (basename (source-location-file loc)) (source-location-line loc))))
    (test-equal "parts' files are tenzer1.nts, with their lines"
      (map (lambda (name)
             (list "tenzer1.nts"
                   (line-in tenzer-file (string-append "(part " name " "))))
           '("ugal" "gong"))
      (map (lambda (p)
             (let ((loc (part-location p)))
               (list (basename (source-location-file loc))
                     (source-location-line loc))))
           (written-parts pc)))
    (test-equal "groups have no location" '(#f #f #f)
      (map group-line (default-groups pc)))))

;;; ==================================================================
;;; [patterns] Patterns, their uses and spans (slice feat/music-patterns)
;;; ==================================================================

;;; ------------------------------------------------------------------
;;; Fixtures. parts-defs (lines 1 to 9: reyong, ugal, gong, kempli), then
;;; these patterns on lines 10 to 18, then the lines given, from line 19.
;;;   reyong: key k is index k-1; i2 = 3, a2 = 7.  ugal: a1 = 3.

(define pat-lines
  (list "(pattern two :instrument reyong 3 4)"                            ; 10
        "(pattern named :instrument reyong :short \"1\" :long \"Norot on 1\" 3 4)" ; 11
        "(pattern short-only :instrument reyong :short \"S\" 1)"           ; 12
        "(pattern outer :instrument reyong 1:1/2 @two 2)"                 ; 13
        "(pattern hold :instrument reyong _ 3)"                           ; 14
        "(pattern checked :instrument reyong 1 |)"                        ; 15
        "(pattern top :instrument reyong a2)"                             ; 16
        "(pattern g :instrument gong G P)"                                ; 17
        "(pattern a1 :instrument ugal 2)"))                               ; 18

(define (pat+ . more)
  "parts-defs, pat-lines, then the lines MORE from line 19."
  (apply lines parts-defs (append pat-lines more)))

(define (read-pat+ . more)
  (try-read-string (apply pat+ more)))

(define (pattern-named pc name)
  (find-named pattern-name name (piece-patterns pc)))

(define (span-row s)
  "(NAME SHORT LONG START END DEPTH) of the pattern-span S."
  (list (pattern-name (pattern-span-pattern s))
        (pattern-span-short s) (pattern-span-long s)
        (pattern-span-start s) (pattern-span-end s)
        (pattern-span-depth s)))

(define (part-span-rows pc name)
  (map span-row (part-spans (part-named pc name))))

(define (pattern-file+line pat)
  (let ((loc (pattern-location pat)))
    (list (canon (source-location-file loc)) (source-location-line loc))))

(define (use-error str)
  "(KIND LINE PART TIME USES) of the &notasi-syntax-error raised reading
STR, or the raised object (or no-error) unchanged."
  (let ((c (catch-syntax-error (lambda () (read-piece-string str)))))
    (if (notasi-syntax-error? c)
        (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c)
              (notasi-syntax-error-part c) (notasi-syntax-error-time c)
              (notasi-syntax-error-uses c))
        c)))

;;; ------------------------------------------------------------------
;;; Reading patterns

(test-group "[patterns] the pattern records"
  (let ((pc (read-pat+ "(part reyong :name p 1 2)")))
    (test-assert "reads" (piece? pc))
    (test-equal "piece-patterns, in file order"
      '(two named short-only outer hold checked top g a1)
      (and pc (map pattern-name (piece-patterns pc))))
    (test-assert "pattern records"
      (and pc (every pattern? (piece-patterns pc))))
    (test-eq "the instrument is the piece's instrument record"
      (and pc (instrument-named pc 'reyong))
      (and pc (pattern-instrument (pattern-named pc 'two))))
    (test-eq "another instrument" (and pc (instrument-named pc 'gong))
      (and pc (pattern-instrument (pattern-named pc 'g))))
    (test-equal "no :short or :long: the name, as a string" '("two" "two")
      (and pc (let ((p (pattern-named pc 'two)))
                (list (pattern-short p) (pattern-long p)))))
    (test-equal ":short and :long" '("1" "Norot on 1")
      (and pc (let ((p (pattern-named pc 'named)))
                (list (pattern-short p) (pattern-long p)))))
    (test-equal ":short only: :long is the short name" '("S" "S")
      (and pc (let ((p (pattern-named pc 'short-only)))
                (list (pattern-short p) (pattern-long p)))))
    (test-equal "location: file #f from a string, the form's line" '(#f 10)
      (and pc (pattern-file+line (pattern-named pc 'two))))
    (test-equal "location of a later pattern" '(#f 17)
      (and pc (pattern-file+line (pattern-named pc 'g))))
    (test-equal "a part without patterns has no spans" '()
      (and pc (part-spans (part-named pc 'p))))
    (test-equal "the generated kempli has no spans" '()
      (and pc (part-spans (part-named pc 'kempli)))))
  (let ((pc (try-read-string (defs+ "(part reyong 1)"))))
    (test-equal "a piece without patterns: piece-patterns is '()" '()
      (and pc (piece-patterns pc))))
  (let* ((path (write-temp-file "patterns.nts"
                                (pat+ "(part reyong :name p 1)")))
         (pc (read-file path)))
    (test-equal "read from a file: the file and line" (list (canon path) 11)
      (and pc (pattern-file+line (pattern-named pc 'named))))))

(test-group "[patterns] using patterns in a part"
  (let ((pc (read-pat+
             "(part reyong :name p 1 @two (@ named :step 1 :short \"x\" :long \"y\") 2)")))
    (test-assert "reads" (piece? pc))
    (test-equal "events"
      '((0 1 (0)) (1 1 (2)) (2 1 (3)) (3 1 (3)) (4 1 (4)) (5 1 (1)))
      (and pc (part-triples pc 'p)))
    (test-equal "length" 6 (and pc (piece-length pc)))
    (test-equal "spans: names in force at each use"
      '((two "two" "two" 1 3 0) (named "x" "y" 3 5 0))
      (and pc (part-span-rows pc 'p)))
    (test-eq "a span's pattern is the record in piece-patterns"
      (and pc (pattern-named pc 'two))
      (and pc (pattern-span-pattern (car (part-spans (part-named pc 'p)))))))
  (for-each
   (match-lambda
     ((name part-form events spans)
      (let ((pc (read-pat+ part-form)))
        (test-equal (string-append name ": events") events
          (and pc (part-triples pc 'p)))
        (test-equal (string-append name ": spans") spans
          (and pc (part-span-rows pc 'p))))))
   (list
    (list "a pattern's names" "(part reyong :name p @named)"
          '((0 1 (2)) (1 1 (3))) '((named "1" "Norot on 1" 0 2 0)))
    (list "nested: the inner span at depth 1" "(part reyong :name p 1 @outer)"
          '((0 1 (0)) (1 1/2 (0)) (3/2 1 (2)) (5/2 1 (3)) (7/2 1/2 (1)))
          '((outer "outer" "outer" 1 4 0) (two "two" "two" 3/2 7/2 1)))
    (list "the pattern starts at 1 pulse; the part's duration comes back"
          "(part reyong :name p 1:1/4 @two 2)"
          '((0 1/4 (0)) (1/4 1 (2)) (5/4 1 (3)) (9/4 1/4 (1)))
          '((two "two" "two" 1/4 9/4 0)))
    (list "a leading _ holds the note before"
          "(part reyong :name p 1 @hold 2)"
          '((0 2 (0)) (2 1 (2)) (3 1 (1)))
          '((hold "hold" "hold" 1 3 0)))
    (list "a rep: one span per repetition" "(part reyong :name p (rep 2 @two))"
          '((0 1 (2)) (1 1 (3)) (2 1 (2)) (3 1 (3)))
          '((two "two" "two" 0 2 0) (two "two" "two" 2 4 0)))
    (list "| in a pattern, on the pulse where it is used"
          "(part reyong :name p @checked 2)"
          '((0 1 (0)) (1 1 (1)))
          '((checked "checked" "checked" 0 1 0)))
    (list ":step by name" "(part reyong :name p (@ top :step -1))"
          '((0 1 (6))) '((top "top" "top" 0 1 0)))))
  (let ((pc (read-pat+ "(part ugal a1 @a1)")))
    (test-equal "a pattern named like a note: a1 is the note, @a1 the pattern"
      '((0 1 (3)) (1 1 (1)))
      (and pc (part-triples pc 'ugal))))
  (let ((pc (try-read-string (defs+ "(part reyong :name p @late)"          ; 10
                                    "(pattern late :instrument reyong 1)")))) ; 11
    (test-equal "a pattern defined after the part that uses it"
      '((0 1 (0)))
      (and pc (part-triples pc 'p)))
    (test-equal "its span" '((late "late" "late" 0 1 0))
      (and pc (part-span-rows pc 'p))))
  (let ((pc (try-read-string (defs+ "(pattern reyong :instrument reyong 1)"
                                    "(part reyong @reyong)"))))
    (test-equal "patterns have their own names: a pattern called reyong"
      '((0 1 (0)))
      (and pc (part-triples pc 'reyong)))))

;;; ------------------------------------------------------------------
;;; Errors where a pattern is defined (step 8, check 11)

(test-group "bad-form of a pattern"
  (for-each
   (match-lambda
     ((name form)
      (test-equal name '(bad-form 10) (string-error (defs+ form)))))
   (list (list "nothing" "(pattern)")
         (list "no name: a key first" "(pattern :instrument reyong 1)")
         (list "a string as the name" "(pattern \"a\" :instrument reyong 1)")
         (list "a number as the name" "(pattern 3 :instrument reyong 1)")
         (list "a list as the name" "(pattern (a) :instrument reyong 1)")
         (list "a name starting with @" "(pattern @a :instrument reyong 1)")
         (list "no tokens" "(pattern a :instrument reyong)")
         (list "no tokens, no options" "(pattern a)")))
  (test-equal "a multi-line pattern: the form's line" '(bad-form 10)
    (string-error (defs+ "(pattern a" "  :instrument reyong)"))))

(test-group "missing-option: a pattern without :instrument"
  (for-each
   (match-lambda
     ((name form)
      (test-equal name '(missing-option 10) (string-error (defs+ form)))))
   (list (list "no options" "(pattern a 1 2)")
         (list "other options" "(pattern a :short \"x\" :long \"y\" 1)"))))

(test-group "undefined-instrument in a pattern"
  (for-each
   (match-lambda
     ((name form)
      (test-equal name '(undefined-instrument 10) (string-error (defs+ form)))))
   (list (list "nothing by that name" "(pattern a :instrument nowhere 1)")
         (list "a scale's name" "(pattern a :instrument selisir 1)")
         (list "a pattern's name" "(pattern a :instrument two 1)"))))

(test-group "pattern options"
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (string-error (apply defs+ forms)))))
   (list (list ":instrument not a symbol" '(bad-option 10)
               "(pattern a :instrument 3 1)")
         (list ":short not a string" '(bad-option 10)
               "(pattern a :instrument reyong :short 3 1)")
         (list ":long not a string" '(bad-option 10)
               "(pattern a :instrument reyong :long x 1)")
         (list "an unknown key" '(unknown-option 10)
               "(pattern a :instrument reyong :name b 1)")
         (list "an operator is not a pattern's option" '(unknown-option 10)
               "(pattern a :instrument reyong :step 1 1)")
         (list "a key twice" '(duplicate-option 10)
               "(pattern a :instrument reyong :short \"x\" :short \"y\" 1)")
         (list "a key after the first token" '(option-after-body 10)
               "(pattern a :instrument reyong 1 :short \"x\")")
         (list "multi-line: the form's line" '(bad-option 10)
               "(pattern a" "  :instrument reyong :short 3" "  1)"))))

(test-group "duplicate-definition of a pattern"
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (string-error (apply defs+ forms)))))
   (list (list "two patterns with one name: the second" '(duplicate-definition 11)
               "(pattern a :instrument reyong 1)" "(pattern a :instrument reyong 2)")
         (list "on different instruments" '(duplicate-definition 12)
               "(pattern a :instrument reyong 1)" "(part reyong 1)"
               "(pattern a :instrument gong G)")))
  (test-assert "a pattern may share a name with an instrument and a part"
    (piece? (try-read-string (defs+ "(pattern gong :instrument gong G)"
                                    "(part gong G)")))))

(test-group "[patterns] token errors where a pattern is defined"
  ;; part #f, time within the pattern, at the pattern's line
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (error-fields (apply defs+ forms)))))
   (list (list "a key out of range" '(note-out-of-range 10 #f 1)
               "(pattern a :instrument reyong 1 9)")
         (list "an unknown note, after a fraction" '(unknown-note 10 #f 1/2)
               "(pattern a :instrument reyong 1:1/2 foo1)")
         (list "a pitched note on a stroke instrument" '(unknown-note 10 #f 1)
               "(pattern a :instrument gong G ding2)")
         (list "a bad duration" '(bad-duration 10 #f 1)
               "(pattern a :instrument reyong 1 2:0)")
         (list "a bad chord" '(bad-chord 10 #f 0)
               "(pattern a :instrument reyong (1))")
         (list "an unknown token" '(unknown-token 10 #f 1)
               "(pattern a :instrument reyong 1 \"x\")")
         (list "_ after a rest" '(hold-without-note 10 #f 2)
               "(pattern a :instrument reyong 1 - _)")
         (list "a multi-line pattern: the form's line" '(note-out-of-range 10 #f 1)
               "(pattern a :instrument reyong 1" "  9)")
         (list "bad-rep: the rep's line" '(bad-rep 11 #f 1)
               "(pattern a :instrument reyong 1" "  (rep 0 2))")
         (list "a pattern for another instrument used inside it"
               '(wrong-instrument 11 #f 1)
               "(pattern g :instrument gong G)" "(pattern a :instrument reyong 1 @g)")
         (list "an unused pattern is checked" '(note-out-of-range 10 #f 0)
               "(pattern a :instrument reyong 9)" "(part reyong 1)")))
  (let* ((path (write-temp-file "pattern-error.nts"
                                (defs+ "(pattern a :instrument reyong 1 9)")))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "from a file: kind, line, part, time" '(note-out-of-range 10 #f 1)
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-kind c) (notasi-syntax-error-line c)
                 (notasi-syntax-error-part c) (notasi-syntax-error-time c))))
    (test-equal "from a file: the file" path
      (and (notasi-syntax-error? c) (notasi-syntax-error-file c)))))

(test-group "[patterns] not errors where a pattern is defined"
  (for-each
   (match-lambda
     ((name form)
      (test-assert name (piece? (try-read-string (defs+ form "(part reyong 1)"))))))
   (list (list "| off the pulse: checked where used" "(pattern a :instrument reyong 1:1/2 |)")
         (list "a leading _" "(pattern a :instrument reyong _ 1)")
         (list "a pattern for the same instrument inside it"
               "(pattern a :instrument reyong 1 @two)\n(pattern two :instrument reyong 1)"))))

;;; ------------------------------------------------------------------
;;; Errors where a pattern is used: the part's line, the part, the time
;;; in the piece, and the uses, innermost first, each with the line of
;;; its pattern form.

(test-group "[patterns] errors at a use"
  (for-each
   (match-lambda
     ((name expected . more)
      (test-equal name expected (use-error (apply pat+ more)))))
   (list
    (list "misplaced-pulse-check: | checked where used"
          '(misplaced-pulse-check 19 p 3/2 ((checked . 15)))
          "(part reyong :name p 1:1/2 @checked 2:1/2)")
    (list "hold-without-note: a pattern starting with _ first in the part"
          '(hold-without-note 19 p 0 ((hold . 14)))
          "(part reyong :name p @hold)")
    (list "hold-without-note: after a rest"
          '(hold-without-note 19 p 1 ((hold . 14)))
          "(part reyong :name p - @hold)")
    (list "moved-note-out-of-range: a name moved off the top"
          '(moved-note-out-of-range 19 p 1 ((top . 16)))
          "(part reyong :name p 1 (@ top :step 1))")
    (list "moved-note-out-of-range: keys in a nested pattern"
          '(moved-note-out-of-range 19 p 1/2 ((two . 10) (outer . 13)))
          "(part reyong :name p (@ outer :step 7))")
    (list "moved-note-out-of-range: a multi-line part, the part's line"
          '(moved-note-out-of-range 19 p 1 ((top . 16)))
          "(part reyong :name p 1" "  (@ top :step 1))")
    (list "undefined-pattern" '(undefined-pattern 19 p 1 ())
          "(part reyong :name p 1 @nope)")
    (list "undefined-pattern in the list form" '(undefined-pattern 19 p 0 ())
          "(part reyong :name p (@ nope :step 1))")
    (list "wrong-instrument: a gong pattern on the reyong"
          '(wrong-instrument 19 p 1 ())
          "(part reyong :name p 1 @g)")
    (list "wrong-instrument: a reyong pattern on the gong"
          '(wrong-instrument 19 p 1 ())
          "(part gong :name p G @two)")
    (list "without :name: the part is the instrument's name"
          '(undefined-pattern 19 reyong 0 ())
          "(part reyong @nope)")))
  (for-each
   (match-lambda
     ((name expected . forms)
      (test-equal name expected (use-error (apply defs+ forms)))))
   (list
    (list "pattern-cycle: a pattern that uses itself"
          '(pattern-cycle 11 p 1 ((self . 10)))
          "(pattern self :instrument reyong 1 @self)"           ; 10
          "(part reyong :name p @self)")                        ; 11
    (list "pattern-cycle: through another pattern"
          '(pattern-cycle 12 p 3 ((pong . 11) (ping . 10)))
          "(pattern ping :instrument reyong 1 @pong)"           ; 10
          "(pattern pong :instrument reyong 2 @ping)"           ; 11
          "(part reyong :name p 1 @ping)")                      ; 12
    (list "undefined-pattern inside a pattern: that pattern's use"
          '(undefined-pattern 11 p 1 ((a . 10)))
          "(pattern a :instrument reyong 1 @nope)"              ; 10
          "(part reyong :name p @a)"))))                        ; 11

(test-group "[patterns] bad-pattern-use, at its own line"
  (for-each
   (match-lambda
     ((name use time)
      (test-equal name (list 'bad-pattern-use 20 'p time '())
        (use-error (pat+ "(part reyong :name p 1"              ; 19
                         (string-append "  " use ")"))))))      ; 20
   (list (list "no name" "(@)" 1)
         (list "a number as the name" "(@ 3)" 1)
         (list "a string as the name" "(@ \"two\")" 1)
         (list "a key where the name goes" "(@ :step 1)" 1)
         (list "a token after the name" "(@ two 1)" 1)
         (list "at its time" "2:1/2 (@)" 3/2)))
  (test-equal "on the part's line when written there" '(bad-pattern-use 19 p 1 ())
    (use-error (pat+ "(part reyong :name p 1 (@))"))))

(test-group "[patterns] operators: option kinds at the (@ ...) line"
  (for-each
   (match-lambda
     ((name kind use)
      (test-equal name (list kind 20 'p 1 '())
        (use-error (pat+ "(part reyong :name p 1"               ; 19
                         (string-append "  " use ")"))))))       ; 20
   (list (list ":step a fraction" 'bad-option "(@ two :step 1/2)")
         (list ":step inexact" 'bad-option "(@ two :step 1.0)")
         (list ":step a symbol" 'bad-option "(@ two :step x)")
         (list ":short not a string" 'bad-option "(@ two :short 3)")
         (list ":long not a string" 'bad-option "(@ two :long x)")
         (list "a key with no value" 'bad-option "(@ two :step)")
         (list "a key twice" 'duplicate-option "(@ two :short \"a\" :short \"b\")")
         (list ":octave is not built yet" 'unknown-option "(@ two :octave 1)")
         (list ":drop-first is not built yet" 'unknown-option "(@ two :drop-first 1)")
         (list ":drop-last is not built yet" 'unknown-option "(@ two :drop-last 1)")
         (list ":instrument is not an operator" 'unknown-option "(@ two :instrument reyong)"))))

;;; || inside a pattern is checked where it is used, against the piece's
;;; colotomy (colo fixtures: parts from line 12).
(test-group "[patterns] || in a pattern"
  (let ((pc (read-colo+ ":colotomy gilak"
                        "(pattern cyc :instrument ugal 1:8 ||)"  ; 12
                        "(part ugal :name p @cyc)")))            ; 13
    (test-assert "on a cycle boundary where used: reads" (piece? pc))
    (test-equal "events" '((0 8 (0))) (and pc (part-triples pc 'p))))
  (test-equal "off the boundary where used"
    '(misplaced-cycle-check 13 p 9 ((cyc . 12)))
    (use-error (colo+ ":colotomy gilak"
                      "(pattern cyc :instrument ugal 1:8 ||)"     ; 12
                      "(part ugal :name p 1 @cyc 2:7)"))))       ; 13

;;; ------------------------------------------------------------------
;;; Patterns in templates (03, step 3)

(test-group "[patterns] patterns in a template"
  (let* ((dir (fresh-dir))
         (tpl (put-file dir "pat.nts"
                        "(scale s a b c)"                              ; 1
                        "(instrument u s a1 b1 c1)"                    ; 2
                        "(pattern up :instrument u :short \"U\" 1 2)")) ; 3
         (pc (read-in dir
                      "(piece \"P\")"                                  ; 1
                      "(use \"pat.nts\")"                              ; 2
                      "(pattern mine :instrument u 3)"                 ; 3
                      "(part u @up (@ up :step 1) @mine)")))           ; 4
    (test-assert "reads" (piece? pc))
    (test-equal "merged order: the template's patterns, then the piece's"
      '(up mine)
      (and pc (map pattern-name (piece-patterns pc))))
    (test-equal "the template's pattern: its file and line" (list (canon tpl) 3)
      (and pc (pattern-file+line (pattern-named pc 'up))))
    (test-equal "the piece's pattern: file #f" '(#f 3)
      (and pc (pattern-file+line (pattern-named pc 'mine))))
    (test-eq "the template's pattern plays the piece's instrument record"
      (and pc (instrument-named pc 'u))
      (and pc (pattern-instrument (pattern-named pc 'up))))
    (test-equal "events" '((0 1 (0)) (1 1 (1)) (2 1 (1)) (3 1 (2)) (4 1 (2)))
      (and pc (part-triples pc 'u)))
    (test-equal "spans"
      '((up "U" "U" 0 2 0) (up "U" "U" 2 4 0) (mine "mine" "mine" 4 5 0))
      (and pc (part-span-rows pc 'u))))

  (let* ((dir (fresh-dir))
         (tpl (put-file dir "pat.nts"
                        "(scale s a b c)"
                        "(instrument u s a1 b1 c1)"
                        "(pattern up :instrument u 1 2)"))             ; 3
         (pc (read-in dir
                      "(piece \"P\")"
                      "(use \"pat.nts\")"
                      "(pattern up :instrument u 3)"                   ; 3
                      "(part u @up)")))
    (test-equal "the piece's pattern replaces the template's" '((0 1 (2)))
      (and pc (part-triples pc 'u)))
    (test-equal "the replacement's location" '(#f 3)
      (and pc (pattern-file+line (pattern-named pc 'up))))
    (test-equal "only the replacement is kept" '(up)
      (and pc (map pattern-name (piece-patterns pc)))))

  (let* ((dir (fresh-dir))
         (tpl (put-file dir "pat.nts"
                        "(scale s a b c)"
                        "(instrument u s a1 b1 c1)"
                        "(pattern up :instrument u 1 2)"))             ; 3
         (c (catch-syntax-error
             (string-in dir
                        "(piece \"P\")"
                        "(use \"pat.nts\")"
                        "(part u 1 (@ up :step 2))"))))                ; 3
    (test-equal "an error at a use of a template's pattern: the piece's part line, the template's pattern line in uses"
      '(moved-note-out-of-range #f 3 u 2 ((up . 3)))
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-kind c) (notasi-syntax-error-file c)
                 (notasi-syntax-error-line c) (notasi-syntax-error-part c)
                 (notasi-syntax-error-time c) (notasi-syntax-error-uses c)))))

  (let* ((dir (fresh-dir))
         (bad (put-file dir "bad.nts"
                        "(scale s a)"
                        "(instrument u s a1)"
                        "(pattern p :instrument u 1 2)"))              ; 3
         (good (put-file dir "good.nts"
                         "(scale s a b)"
                         "(instrument u s a1 b1)"
                         "(pattern p :instrument u 1 2)"))             ; 3
         (a (put-file dir "a.nts" "(scale s a)" "(instrument u s a1)"
                      "(pattern x :instrument u 1)"))
         (b (put-file dir "b.nts" "(pattern x :instrument u 1)")))
    (error-tests
     (list (list "an error in a template's pattern: the template's file and line"
                 (at 'note-out-of-range bad 3)
                 (string-in dir "(piece \"P\")" "(use \"bad.nts\")"))
           (list "a template's pattern is checked against the piece's replacement instrument"
                 (at 'note-out-of-range good 3)
                 (string-in dir "(piece \"P\")" "(use \"good.nts\")"
                            "(instrument u s a1)"))
           (list "the same pattern name from two templates: template-conflict"
                 (at 'template-conflict b 1)
                 (string-in dir "(piece \"P\")" "(use \"a.nts\")" "(use \"b.nts\")"))
           (list "a bad-form pattern in a template"
                 (let ((t (put-file dir "bf.nts" "(pattern)")))
                   (at 'bad-form t 1))
                 (string-in dir "(piece \"P\")" "(use \"bf.nts\")"))))))

;;; ------------------------------------------------------------------
;;; Check order (03, "Error reporting", items 6, 7, 9 to 14)

(test-group "[patterns] check order"
  (for-each
   (match-lambda
     ((name expected text)
      (test-equal name expected (string-error text))))
   (list
    (list "6 before 11: a later pattern's shape before an earlier's tokens"
          '(bad-form 11)
          (defs+ "(pattern a :instrument reyong 9)" "(pattern b :instrument reyong)"))
    (list "6 before 11: a later pattern's option before an earlier's tokens"
          '(bad-option 11)
          (defs+ "(pattern a :instrument reyong 9)" "(pattern b :instrument reyong :short 3 1)"))
    (list "7 before 11: duplicate patterns before a pattern's tokens"
          '(duplicate-definition 12)
          (defs+ "(pattern a :instrument reyong 9)" "(pattern b :instrument reyong 1)"
                 "(pattern b :instrument reyong 1)"))
    (list "9 before 11: an instrument before a pattern" '(unknown-note 11)
          (defs+ "(pattern a :instrument reyong 9)" "(instrument bad selisir x1)"))
    (list "10 before 11: a colotomy before a pattern" '(colotomy-part-length 13)
          (colo+ "" "(pattern a :instrument ugal 99)" "(colotomy c 8 (gong gong G:3))"))
    (list "11: missing-option before the tokens" '(missing-option 10)
          (defs+ "(pattern a 9)"))
    (list "11: undefined-instrument before the tokens" '(undefined-instrument 10)
          (defs+ "(pattern a :instrument nowhere \"x\")"))
    (list "11: patterns in file order" '(note-out-of-range 10)
          (defs+ "(pattern a :instrument reyong 9)" "(pattern b :instrument nowhere 1)"))
    (list "11: patterns in file order, the other way" '(undefined-instrument 10)
          (defs+ "(pattern b :instrument nowhere 1)" "(pattern a :instrument reyong 9)"))
    (list "11: an earlier pattern's tokens before a later one's missing :instrument"
          '(note-out-of-range 10)
          (defs+ "(pattern a :instrument reyong 9)" "(pattern b 1)"))
    (list "11: tokens left to right" '(unknown-note 10)
          (defs+ "(pattern a :instrument reyong 1 foo1 9)"))
    (list "11 before 12: a pattern before the piece's colotomy" '(note-out-of-range 12)
          (colo+ ":colotomy nowhere" "(pattern a :instrument ugal 99)"))
    (list "11 before 13: a pattern after a part is checked first" '(note-out-of-range 11)
          (defs+ "(part reyong :name p 9)" "(pattern a :instrument reyong 99)"))
    (list "13: tokens and uses left to right: a note first" '(note-out-of-range 10)
          (defs+ "(part reyong :name p 9 @nope)"))
    (list "13: tokens and uses left to right: a use first" '(undefined-pattern 10)
          (defs+ "(part reyong :name p @nope 9)"))
    (list "13: parts in file order" '(note-out-of-range 10)
          (defs+ "(part reyong :name a 9 1)" "(part reyong :name b @nope 1)"))
    (list "13 before 14: a use before unequal-length" '(undefined-pattern 11)
          (defs+ "(part reyong :name a 1 2)" "(part reyong :name b @nope)")))))

;;; ==================================================================
;;; [scores] Scores and groups (slice feat/scores-form)
;;; ==================================================================

;;; ------------------------------------------------------------------
;;; Helpers

;;; parts-defs (lines 1 to 9) and four parts; scores start on line 14.
;;; The parts: ugal, polos and sangsih (both on reyong), gong, and the
;;; generated kempli (on the piece's kempli instrument).
(define scores-parts
  (list "(part ugal 1 2 3 4)"                    ; 10
        "(part reyong :name polos 1 2 3 4)"      ; 11
        "(part reyong :name sangsih 4 3 2 1)"    ; 12
        "(part gong G - - P)"))                  ; 13

(define (scores+ . more)
  "parts-defs, the four parts, then the lines MORE from line 14."
  (apply defs+ (append scores-parts more)))

(define (read-scores+ . more)
  (try-read-string (apply scores+ more)))

(define (score-named pc name)
  (or (piece-score pc name) (error "no score:" name)))

(define (score-line sc)
  (and=> (score-location sc) source-location-line))

(define (group-settings g)
  "Every setting of G but its members and location, in 02's order."
  (list (group-label g) (group-short g) (group-subtitle g) (group-labels g)
        (group-rows g) (group-note-names? g) (group-fill g) (group-holds g)
        (group-pattern-names g) (group-pattern-level g) (group-scheme g)
        (group-palette g) (group-colors g)))

(define (default-group-settings label)
  "group-settings of a group LABEL with every option at its default."
  (list label label #f 'first-long 'notes #f 'colour 'none 'none 0
        'by-degree 'pastel1 '()))

(define (member-names g)
  "G's members as (PART-NAME ROW-LABEL)."
  (map (match-lambda ((part . label) (list (part-name part) label)))
       (group-members g)))

(define (score-settings sc)
  "Every setting of SC but its name, groups and location, in 02's order."
  (list (score-title sc) (score-subtitle sc) (score-caption sc)
        (score-from sc) (score-to sc) (score-system-length sc)
        (score-breaks sc) (score-cycle-numbers? sc) (score-pulse-numbers? sc)
        (score-numbering sc) (score-pulse-label sc) (score-font-size sc)
        (score-cell-width sc) (score-cell-height sc)))

(define (score-group-labels sc) (map group-label (score-groups sc)))

(define (score-error+part . more)
  "(KIND LINE PART) for reading scores+ with the lines MORE."
  (error-kind+line+part (apply scores+ more)))

(define (score-error . more)
  "(KIND LINE) for reading scores+ with the lines MORE."
  (string-error (apply scores+ more)))

(define (group-in-score . group-lines)
  "A score on line 14 whose groups are GROUP-LINES, from line 15."
  (append (list "(score s") group-lines (list ")")))

(define (one-group group-line)
  "scores+ with a score on line 14 and GROUP-LINE on line 15."
  (apply scores+ (group-in-score group-line)))

;;; ------------------------------------------------------------------
;;; Successful reads

(test-group "[scores] reading scores and groups"
  (let ((pc (read-scores+
             "(score full :title \"Full\" :system-length 2 :note-names yes"   ; 14
             "  :palette set1 :colors ((ding \"#000000\"))"                    ; 15
             "  :cell-width \"3em\" :cell-height \"1.5em\""                    ; 16
             "  (group \"Gangsa\" :subtitle \"norot\"  polos sangsih)"         ; 17
             "  (group \"Ugal\" :note-names no :palette dark2  ugal)"          ; 18
             "  (group \"\" :colors ((dong \"#ffffff\")) :scheme by-degree  gong kempli))" ; 19
             "(score parts"                                                    ; 20
             "  (group \"P\"  (polos :label \"Pol.\") sangsih))")))             ; 21
    (test-assert "reads" (piece? pc))
    (test-equal "piece-scores: the file's scores, in file order, no default"
      '(full parts)
      (map score-name (piece-scores pc)))
    (test-assert "score records" (every score? (piece-scores pc)))
    (test-eq "piece-score finds the first" (car (piece-scores pc))
      (piece-score pc 'full))
    (test-eq "piece-score finds the second" (cadr (piece-scores pc))
      (piece-score pc 'parts))
    (test-eq "piece-score: no default score when the file has scores" #f
      (piece-score pc 'default))
    (test-eq "piece-score: an unknown name is #f" #f (piece-score pc 'nope))

    (test-equal "full: the score's settings, the unbuilt ones at their defaults"
      (list "Full" #f #f 0 4 2 '() #f #t 'gong-last #f #f "3em" "1.5em")
      (score-settings (score-named pc 'full)))
    (test-equal "parts: every setting at its default; the title is the piece's"
      (list "Parts" #f #f 0 4 #f '() #f #t 'gong-last #f #f "2em" "2em")
      (score-settings (score-named pc 'parts)))
    (test-assert ":system-length stays exact"
      (exact? (score-system-length (score-named pc 'full))))
    (test-equal "score locations: the form's line, file #f"
      '((#f 14) (#f 20))
      (map (lambda (sc) (list (source-location-file (score-location sc))
                              (score-line sc)))
           (piece-scores pc)))

    (test-equal "full: its groups, in the order written"
      '("Gangsa" "Ugal" "")
      (score-group-labels (score-named pc 'full)))
    (test-assert "group records" (every group? (score-groups (score-named pc 'full))))
    (test-equal "group locations: the group's line, file #f"
      '((#f 17) (#f 18) (#f 19))
      (map (lambda (g) (list (source-location-file (group-location g))
                             (source-location-line (group-location g))))
           (score-groups (score-named pc 'full))))
    (test-equal "a group without options: the score's settings, else the defaults"
      (list "Gangsa" "Gangsa" "norot" 'first-long 'notes #t 'colour 'none 'none 0
            'by-degree 'set1 '((ding . "#000000")))
      (group-settings (car (score-groups (score-named pc 'full)))))
    (test-equal "a group's own :note-names and :palette override the score's"
      (list "Ugal" "Ugal" #f 'first-long 'notes #f 'colour 'none 'none 0
            'by-degree 'dark2 '((ding . "#000000")))
      (group-settings (cadr (score-groups (score-named pc 'full)))))
    (test-equal "a group's own :colors replace the score's; an empty label"
      (list "" "" #f 'first-long 'notes #t 'colour 'none 'none 0
            'by-degree 'set1 '((dong . "#ffffff")))
      (group-settings (caddr (score-groups (score-named pc 'full)))))
    (test-equal "members: (part . row-label), the label the part's name"
      '(((polos "polos") (sangsih "sangsih"))
        ((ugal "ugal"))
        ((gong "gong") (kempli "kempli")))
      (map member-names (score-groups (score-named pc 'full))))
    (test-assert "members hold the piece's part records"
      (every (lambda (g)
               (every (lambda (m) (eq? (car m) (part-named pc (part-name (car m)))))
                      (group-members g)))
             (score-groups (score-named pc 'full))))
    (test-assert "the generated kempli may be in a group"
      (eq? (part-named pc 'kempli)
           (car (cadr (group-members (caddr (score-groups (score-named pc 'full))))))))

    (test-equal "parts: a member's :label is its row label"
      '(((polos "Pol.") (sangsih "sangsih")))
      (map member-names (score-groups (score-named pc 'parts))))
    (test-equal "parts: a group in a score without options has the defaults"
      (list (default-group-settings "P"))
      (map group-settings (score-groups (score-named pc 'parts))))
    (test-equal "the same part in two scores: the same part record"
      (part-named pc 'polos)
      (car (car (group-members (car (score-groups (score-named pc 'parts)))))))
    (test-equal "parts stay as they were" '(ugal polos sangsih gong kempli)
      (map part-name (piece-parts pc))))

  (let ((pc (read-scores+ "(score s :palette (\"#111111\" \"#eeeeee\")"       ; 14
                          "  (group \"U\" ugal)"                               ; 15
                          "  (group \"G\" :palette (\"#123456\") gong))")))    ; 16
    (test-equal "a palette written as a list of colours, on the score and a group"
      '(("#111111" "#eeeeee") ("#123456"))
      (map group-palette (score-groups (score-named pc 's)))))

  (let ((pc (read-scores+ "(score s :palette dark2 (group \"U\" :palette set1 ugal))")))
    (test-equal "a group's palette name over the score's" '(set1)
      (map group-palette (score-groups (score-named pc 's)))))

  (let ((pc (read-scores+ "(score s :colors ((ding \"#000000\") (dang \"#ff0000\"))"
                          "  (group \"U\" ugal))")))
    (test-equal ":colors with several degrees, in order"
      '(((ding . "#000000") (dang . "#ff0000")))
      (map group-colors (score-groups (score-named pc 's)))))

  (let ((pc (read-scores+ "(score s :note-names no (group \"U\" :note-names yes ugal)"
                          "  (group \"G\" gong))")))
    (test-equal ":note-names: the group's yes over the score's no" '(#t #f)
      (map group-note-names? (score-groups (score-named pc 's)))))

  (for-each
   (match-lambda
     ((len)
      (test-equal (string-append "a length " len " reads, as written")
        (list len len)
        (let ((pc (read-scores+
                   (string-append "(score s :cell-width \"" len
                                  "\" :cell-height \"" len "\" (group \"U\" ugal))"))))
          (and pc (list (score-cell-width (score-named pc 's))
                        (score-cell-height (score-named pc 's))))))))
   '(("2em") ("2.5em") ("4mm") ("10pt") ("1cm") ("0.5in")))

  (let ((pc (read-scores+ "(score ugal (group \"U\" ugal))"
                          "(score polos (group \"P\" polos))")))
    (test-equal "scores may be named like parts" '(ugal polos)
      (and pc (map score-name (piece-scores pc)))))

  (let ((pc (read-scores+ "(score s (group \"Ugal\" ugal) (group \"Ugal\" gong))")))
    (test-equal "group labels need not be unique" '("Ugal" "Ugal")
      (and pc (score-group-labels (score-named pc 's)))))

  (let ((pc (read-scores+ "(score s (group \"Gangsa\" polos sangsih))")))
    (test-equal "parts on one pitched instrument share a group"
      '((polos "polos") (sangsih "sangsih"))
      (and pc (member-names (car (score-groups (score-named pc 's)))))))

  (let ((pc (read-scores+ "(score s (group \"Pulse\" kempli gong))")))
    (test-equal "parts on two stroke instruments share a group"
      '((kempli "kempli") (gong "gong"))
      (and pc (member-names (car (score-groups (score-named pc 's)))))))

  (let ((pc (read-scores+ "(score s (group \"U\" ugal))")))
    (test-equal "a part in no group is not in the score" '(("U" ((ugal "ugal"))))
      (and pc (map (lambda (g) (list (group-label g) (member-names g)))
                   (score-groups (score-named pc 's))))))

  (let ((pc (read-scores+ "(score s"                                   ; 14
                          "  :title \"T\""                             ; 15
                          "  (group \"U\""                             ; 16
                          "    :subtitle \"s\""                        ; 17
                          "    ugal))")))                              ; 18
    (test-equal "options on their own lines: the form's and group's lines"
      '(14 16)
      (and pc (let ((sc (score-named pc 's)))
                (list (score-line sc)
                      (source-location-line
                       (group-location (car (score-groups sc)))))))))

  (let ((pc (read-colo+ ":colotomy gilak :pickup 1" "(part ugal 1:17)"    ; 12
                        "(score s (group \"U\" ugal) (group \"G\" gong kempli))")))
    (test-equal "a colotomy's generated parts in a score"
      '(((ugal "ugal")) ((gong "gong") (kempli "kempli")))
      (and pc (map member-names (score-groups (score-named pc 's)))))
    (test-equal "with a colotomy: to is the length, cycle-numbers? #t"
      '(0 17 #t)
      (and pc (let ((sc (score-named pc 's)))
                (list (score-from sc) (score-to sc) (score-cycle-numbers? sc))))))

  (let* ((path (write-temp-file "scores.nts"
                                (scores+ "(score s"                 ; 14
                                         "  (group \"U\" ugal))"))) ; 15
         (pc (try-read (lambda () (read-piece-file path)))))
    (test-equal "from a file: score and group locations have the file"
      (list (list path 14) (list path 15))
      (and pc (let ((sc (score-named pc 's)))
                (list (list (source-location-file (score-location sc))
                            (score-line sc))
                      (let ((loc (group-location (car (score-groups sc)))))
                        (list (source-location-file loc)
                              (source-location-line loc)))))))))

;;; ------------------------------------------------------------------
;;; The default score (01, "Files without a score"; 03, step 12)

(test-group "[scores] the default score"
  (let ((pc (read-scores+)))
    (test-equal "one score, named default" '(default)
      (map score-name (piece-scores pc)))
    (test-eq "piece-score finds it" (car (piece-scores pc))
      (piece-score pc 'default))
    (test-equal "its location is #f" #f (score-location (score-named pc 'default)))
    (test-equal "every setting at its default, the title the piece's"
      (list "Parts" #f #f 0 4 #f '() #f #t 'gong-last #f #f "2em" "2em")
      (score-settings (score-named pc 'default)))
    (test-equal "one group per part, in part order, labelled with its name"
      '("ugal" "polos" "sangsih" "gong" "kempli")
      (score-group-labels (score-named pc 'default)))
    (test-equal "each group: one member, its name as row label"
      '(((ugal "ugal")) ((polos "polos")) ((sangsih "sangsih")) ((gong "gong"))
        ((kempli "kempli")))
      (map member-names (score-groups (score-named pc 'default))))
    (test-equal "each group: every option at its default"
      (map default-group-settings '("ugal" "polos" "sangsih" "gong" "kempli"))
      (map group-settings (score-groups (score-named pc 'default))))
    (test-equal "group locations #f" '(#f #f #f #f #f)
      (map group-location (score-groups (score-named pc 'default))))
    (test-assert "members are the piece's part records"
      (every (lambda (g p) (eq? (car (car (group-members g))) p))
             (score-groups (score-named pc 'default))
             (piece-parts pc))))

  (let ((pc (read-bare+ "" "(part u 1 2 1)")))
    (test-equal "the built-in kempli is left out" '("u")
      (and pc (score-group-labels (score-named pc 'default)))))

  (let ((pc (read-colo+ ":colotomy gilak" "(part ugal 1:16)")))
    (test-equal "a colotomy's generated parts are in it"
      '("ugal" "gong" "kempli")
      (and pc (score-group-labels (score-named pc 'default))))
    (test-equal "with a colotomy: cycle-numbers? #t; to is the length" '(#t 0 16)
      (and pc (let ((sc (score-named pc 'default)))
                (list (score-cycle-numbers? sc) (score-from sc) (score-to sc))))))

  (let ((pc (try-read-string "(piece \"Empty\")")))
    (test-equal "a piece with no parts: a default score with no groups"
      '((default) () "Empty" 0)
      (and pc (list (map score-name (piece-scores pc))
                    (score-groups (score-named pc 'default))
                    (score-title (score-named pc 'default))
                    (score-to (score-named pc 'default)))))))

;;; ------------------------------------------------------------------
;;; Error cases

(test-group "[scores] bad-form"
  (table-tests 'bad-form
   (list
    (list "a score with nothing in it" 14 (scores+ "(score)"))
    (list "a score name that is a string" 14
          (scores+ "(score \"full\" (group \"U\" ugal))"))
    (list "a score name that is a number" 14 (scores+ "(score 3 (group \"U\" ugal))"))
    (list "a score with options and no name" 14
          (scores+ "(score :title \"x\" (group \"U\" ugal))"))
    (list "a body item that is not a group: a number" 14
          (scores+ "(score full (group \"U\" ugal) 3)"))
    (list "a body item that is not a group: a symbol" 14
          (scores+ "(score full (group \"U\" ugal) foo)"))
    (list "a body item that is not a group: a part form" 14
          (scores+ "(score full (part ugal 1 2 3 4))"))
    (list "a group label that is a symbol: the group's line" 15
          (one-group "(group ugal ugal)"))
    (list "a group label that is a number" 15 (one-group "(group 3 ugal)"))
    (list "an empty group" 15 (one-group "(group)"))
    (list "a group with no parts" 15 (one-group "(group \"U\")"))
    (list "a group with options and no parts" 15
          (one-group "(group \"U\" :note-names yes)"))
    (list "a member that is a string" 15 (one-group "(group \"U\" \"ugal\")"))
    (list "a member that is a number" 15 (one-group "(group \"U\" ugal 3)"))
    (list "a member's :label that is not a string" 15
          (one-group "(group \"U\" (ugal :label 3))"))
    (list "a member list whose part is not a name" 15
          (one-group "(group \"U\" (\"ugal\" :label \"U\"))"))
    (list "the second group of a score" 16
          (scores+ "(score s" "  (group \"U\" ugal)" "  (group \"G\"))")))))

(test-group "[scores] duplicate-definition"
  (table-tests 'duplicate-definition
   (list (list "two scores with one name: the second" 15
               (scores+ "(score a (group \"U\" ugal))" "(score a (group \"G\" gong))"))
         (list "the first and the third" 16
               (scores+ "(score a (group \"U\" ugal))" "(score b (group \"G\" gong))"
                        "(score a (group \"P\" polos))")))))

(test-group "[scores] option kinds on a score"
  (for-each
   (match-lambda
     ((name expected options)
      (test-equal name expected
        (score-error (string-append "(score s " options " (group \"U\" ugal))")))))
   (list
    (list "unknown-option" '(unknown-option 14) ":tempo 60")
    (list "a part's key is not a score option: :name" '(unknown-option 14)
          ":name x")
    (list "duplicate-option" '(duplicate-option 14) ":note-names yes :note-names no")
    (list "duplicate-option: :palette" '(duplicate-option 14)
          ":palette set1 :palette set2")
    (list "a key with no value, followed by another key" '(bad-option 14)
          ":title :note-names yes")
    (list ":title not a string: a symbol" '(bad-option 14) ":title full")
    (list ":title not a string: a number" '(bad-option 14) ":title 3")
    (list ":system-length 0" '(bad-option 14) ":system-length 0")
    (list ":system-length negative" '(bad-option 14) ":system-length -2")
    (list ":system-length a decimal" '(bad-option 14) ":system-length 1.5")
    (list ":system-length a string" '(bad-option 14) ":system-length \"4\"")
    (list ":system-length a symbol" '(bad-option 14) ":system-length four")
    (list ":note-names not yes or no" '(bad-option 14) ":note-names maybe")
    (list ":note-names a string" '(bad-option 14) ":note-names \"yes\"")
    (list ":note-names #t" '(bad-option 14) ":note-names #t")
    (list ":palette an unknown name" '(bad-option 14) ":palette rainbow")
    (list ":palette a string" '(bad-option 14) ":palette \"set1\"")
    (list ":palette a number" '(bad-option 14) ":palette 3")
    (list ":palette an empty list" '(bad-option 14) ":palette ()")
    (list ":palette a colour of five digits" '(bad-option 14) ":palette (\"#12345\")")
    (list ":palette a colour without #" '(bad-option 14) ":palette (\"123456\")")
    (list ":palette a colour that is not hex" '(bad-option 14) ":palette (\"#gggggg\")")
    (list ":palette a list holding a symbol" '(bad-option 14) ":palette (red)")
    (list ":palette one bad colour among good ones" '(bad-option 14)
          ":palette (\"#111111\" \"#2222\")")
    (list ":scheme an unknown name" '(bad-option 14) ":scheme rainbow")
    (list ":scheme a string" '(bad-option 14) ":scheme \"by-degree\"")
    (list ":colors a colour name" '(bad-option 14) ":colors ((ding \"black\"))")
    (list ":colors a short colour" '(bad-option 14) ":colors ((ding \"#00000\"))")
    (list ":colors a symbol" '(bad-option 14) ":colors ding")
    (list ":colors one entry, not a list of entries" '(bad-option 14)
          ":colors (ding \"#000000\")")
    (list ":colors a degree written as a string" '(bad-option 14)
          ":colors ((\"ding\" \"#000000\"))")
    (list ":colors an entry without a colour" '(bad-option 14) ":colors ((ding))")
    (list ":cell-width without a unit" '(bad-option 14) ":cell-width \"3\"")
    (list ":cell-width a unit only" '(bad-option 14) ":cell-width \"em\"")
    (list ":cell-width words" '(bad-option 14) ":cell-width \"three em\"")
    (list ":cell-width a number" '(bad-option 14) ":cell-width 3")
    (list ":cell-width a symbol" '(bad-option 14) ":cell-width em")
    (list ":cell-height without a unit" '(bad-option 14) ":cell-height \"3\"")))
  (test-equal "option-after-body: a key after the first group" '(option-after-body 14)
    (score-error "(score s (group \"U\" ugal) :title \"T\")"))
  (test-equal "an option on its own line: the score's line" '(bad-option 14)
    (score-error "(score s" "  :palette rainbow" "  (group \"U\" ugal))")))

(test-group "[scores] option kinds on a group"
  (for-each
   (match-lambda
     ((name expected group)
      (test-equal name expected (string-error (one-group group)))))
   (list
    (list "unknown-option" '(unknown-option 15) "(group \"U\" :tempo 60 ugal)")
    (list "duplicate-option" '(duplicate-option 15)
          "(group \"U\" :note-names yes :note-names no ugal)")
    (list "a key with no value, followed by another key" '(bad-option 15)
          "(group \"U\" :subtitle :note-names yes ugal)")
    (list ":subtitle a symbol" '(bad-option 15) "(group \"U\" :subtitle norot ugal)")
    (list ":subtitle a number" '(bad-option 15) "(group \"U\" :subtitle 3 ugal)")
    (list ":note-names not yes or no" '(bad-option 15)
          "(group \"U\" :note-names maybe ugal)")
    (list ":palette an unknown name" '(bad-option 15) "(group \"U\" :palette rainbow ugal)")
    (list ":palette a bad colour" '(bad-option 15) "(group \"U\" :palette (\"#12\") ugal)")
    (list ":scheme an unknown name" '(bad-option 15) "(group \"U\" :scheme rainbow ugal)")
    (list ":colors a bad colour" '(bad-option 15)
          "(group \"U\" :colors ((ding \"black\")) ugal)")
    (list "option-after-body: a key after a member" '(option-after-body 15)
          "(group \"U\" ugal :note-names yes)")))
  (test-equal "the group's line, not the score's" '(unknown-option 16)
    (score-error "(score s" "  (group \"U\" ugal)" "  (group \"G\" :tempo 1 gong))")))

(test-group "[scores] option-wrong-level"
  (for-each
   (match-lambda
     ((option)
      (test-equal (string-append "a score-only option on a group: " option)
        '(option-wrong-level 15)
        (string-error (one-group (string-append "(group \"U\" " option " ugal)"))))))
   '((":title \"T\"") (":system-length 4") (":cell-width \"3em\"")
     (":cell-height \"3em\"")))
  (test-equal "fields: part and time #f" '(option-wrong-level 15 #f #f)
    (error-fields (one-group "(group \"U\" :title \"T\" ugal)"))))

;;; The options later slices build (04, slice 1's decided bullets).
(define later-score-options
  '(":pattern-names long" ":pattern-level 1" ":labels short" ":from 1"
    ":to 4" ":breaks (3)"))

(define later-group-options
  '(":pattern-names short" ":pattern-level 1" ":labels long"
    ":short \"U.\""))

(test-group "[scores] not-implemented: options of later slices"
  (for-each
   (lambda (option)
     (test-equal (string-append "on a score: " option) '(not-implemented 14)
       (score-error (string-append "(score s " option " (group \"U\" ugal))"))))
   later-score-options)
  (for-each
   (lambda (option)
     (test-equal (string-append "on a group: " option) '(not-implemented 15)
       (string-error (one-group (string-append "(group \"U\" " option " ugal)")))))
   later-group-options)
  (test-equal "on a group: at the group's line, not the score's" '(not-implemented 16)
    (score-error "(score s" "  (group \"U\" ugal)" "  (group \"G\" :labels long gong))"))
  (test-equal "fields: part and time #f" '(not-implemented 14 #f #f)
    (error-fields (scores+ "(score s :labels short (group \"U\" ugal))"))))

(test-group "[scores] the options of slice feat/scores-contract"
  (let ((pc (read-scores+
             "(score full :subtitle \"pangecet\" :caption \"From Tenzer\""   ; 14
             "  :cycle-numbers no :pulse-numbers no :numbering gong-first"
             "  :pulse-label \"Beats\" :font-size \"10pt\""
             "  (group \"U\" ugal))")))
    (test-equal "every option read, in 02's order"
      (list "Parts" "pangecet" "From Tenzer" 0 4 #f '() #f #f 'gong-first
            "Beats" "10pt" "2em" "2em")
      (and pc (score-settings (score-named pc 'full)))))
  (let ((pc (read-scores+ "(score s :pulse-numbers yes :numbering gong-last"
                          "  (group \"U\" ugal))")))
    (test-equal "the defaults written out"
      '(#t gong-last)
      (and pc (let ((sc (score-named pc 's)))
                (list (score-pulse-numbers? sc) (score-numbering sc))))))
  (let ((pc (read-colo+ ":colotomy gilak" "(part ugal 1:16)"           ; 12
                        "(score s :cycle-numbers no (group \"U\" ugal))")))
    (test-equal "with a colotomy, :cycle-numbers no: #f" '(#f)
      (and pc (list (score-cycle-numbers? (score-named pc 's))))))
  (let ((pc (read-colo+ ":colotomy gilak" "(part ugal 1:16)"
                        "(score s (group \"U\" ugal))")))
    (test-equal "with a colotomy, by default: #t" #t
      (and pc (score-cycle-numbers? (score-named pc 's)))))
  (test-assert "without a colotomy, :cycle-numbers yes reads"
    (piece? (read-scores+ "(score s :cycle-numbers yes (group \"U\" ugal))")))
  (let ((pc (read-scores+ "(score s :subtitle \"\" :caption \"\" :pulse-label \"\""
                          "  (group \"U\" ugal))")))
    (test-equal "empty strings are kept as written" '("" "" "")
      (and pc (let ((sc (score-named pc 's)))
                (list (score-subtitle sc) (score-caption sc)
                      (score-pulse-label sc))))))
  (let ((pc (read-scores+ "(score s :subtitle \"S\" (group \"U\" :subtitle \"g\" ugal))")))
    (test-equal "a score's and a group's :subtitle together" '("S" "g")
      (and pc (let ((sc (score-named pc 's)))
                (list (score-subtitle sc)
                      (group-subtitle (car (score-groups sc))))))))
  (for-each
   (lambda (len)
     (test-equal (string-append ":font-size " len " reads, as written") len
       (let ((pc (read-scores+ (string-append "(score s :font-size \"" len
                                              "\" (group \"U\" ugal))"))))
         (and pc (score-font-size (score-named pc 's))))))
   '("8pt" "10pt" "3.5mm" "1.2em"))
  (for-each
   (match-lambda
     ((name options)
      (test-equal name '(bad-option 14)
        (score-error (string-append "(score s " options " (group \"U\" ugal))")))))
   (list
    (list ":cycle-numbers not yes or no" ":cycle-numbers maybe")
    (list ":cycle-numbers a string" ":cycle-numbers \"yes\"")
    (list ":pulse-numbers not yes or no" ":pulse-numbers 1")
    (list ":pulse-numbers #f" ":pulse-numbers #f")
    (list ":numbering an unknown choice" ":numbering gong-middle")
    (list ":numbering a string" ":numbering \"gong-last\"")
    (list ":pulse-label a symbol" ":pulse-label beats")
    (list ":pulse-label a number" ":pulse-label 3")
    (list ":subtitle a symbol" ":subtitle pangecet")
    (list ":caption a number" ":caption 3")
    (list ":font-size without a unit" ":font-size \"8\"")
    (list ":font-size a unit only" ":font-size \"pt\"")
    (list ":font-size a number" ":font-size 8")
    (list ":font-size a symbol" ":font-size 8pt")
    (list "a key with no value: :caption" ":caption :font-size \"8pt\"")))
  (test-equal "duplicate-option: :caption" '(duplicate-option 14)
    (score-error "(score s :caption \"a\" :caption \"b\" (group \"U\" ugal))"))
  (for-each
   (lambda (option)
     (test-equal (string-append "score-only, on a group: " option)
       '(option-wrong-level 15)
       (string-error (one-group (string-append "(group \"U\" " option " ugal)")))))
   '(":cycle-numbers no" ":pulse-numbers no" ":numbering gong-first"
     ":pulse-label \"Beats\"" ":caption \"c\"" ":font-size \"8pt\""))
  (test-equal "on a group, at the group's line" '(option-wrong-level 16)
    (score-error "(score s" "  (group \"U\" ugal)"
                 "  (group \"G\" :font-size \"8pt\" gong))")))

(test-group "[scores] undefined-part"
  (for-each
   (match-lambda
     ((name expected . more)
      (test-equal name expected (apply score-error+part more))))
   (list
    (list "a name that is no part" '(undefined-part 15 nope)
          "(score s" "  (group \"U\" nope))")
    (list "the second member" '(undefined-part 15 nope)
          "(score s" "  (group \"U\" ugal nope))")
    (list "a member with a :label" '(undefined-part 15 nope)
          "(score s" "  (group \"U\" (nope :label \"N\")))")
    (list "an instrument whose parts have other names" '(undefined-part 15 reyong)
          "(score s" "  (group \"R\" reyong))")
    (list "a scale's name" '(undefined-part 15 selisir)
          "(score s" "  (group \"S\" selisir))")
    (list "in the second group" '(undefined-part 16 nope)
          "(score s" "  (group \"U\" ugal)" "  (group \"N\" nope))")))
  (test-equal "the built-in kempli is never printed: undefined-part"
    '(undefined-part 8 kempli)
    (error-kind+line+part (bare+ "" "(part u 1 2 1)"            ; 7
                                 "(score s (group \"K\" kempli))")))  ; 8
  (test-equal "the piece's kempli may be printed"
    '(("kempli"))
    (let ((pc (read-scores+ "(score s (group \"K\" kempli))")))
      (and pc (map (lambda (g) (map cadr (member-names g)))
                   (score-groups (score-named pc 's))))))
  (test-equal "fields: time #f" '(undefined-part 15 nope #f)
    (error-fields (scores+ "(score s" "  (group \"U\" nope))"))))

(test-group "[scores] part-in-two-groups"
  (for-each
   (match-lambda
     ((name expected . more)
      (test-equal name expected (apply score-error more))))
   (list
    (list "in two groups: the second group's line" '(part-in-two-groups 16)
          "(score s" "  (group \"A\" ugal)" "  (group \"B\" ugal))")
    (list "twice in one group" '(part-in-two-groups 15)
          "(score s" "  (group \"A\" polos polos))")
    (list "with a row label the first time" '(part-in-two-groups 16)
          "(score s" "  (group \"A\" (polos :label \"P\"))" "  (group \"B\" polos))")
    (list "in the first and third groups" '(part-in-two-groups 17)
          "(score s" "  (group \"A\" gong)" "  (group \"B\" ugal)"
          "  (group \"C\" gong))")))
  (test-assert "the same part in two scores is not an error"
    (piece? (read-scores+ "(score a (group \"A\" ugal))"
                          "(score b (group \"B\" ugal))"))))

(test-group "[scores] mixed-pitched-group"
  (for-each
   (match-lambda
     ((name expected group)
      (test-equal name expected (error-kind+line+part (one-group group)))))
   (list
    (list "ugal and a reyong part" '(mixed-pitched-group 15 polos)
          "(group \"X\" ugal polos)")
    (list "the first part on a second instrument" '(mixed-pitched-group 15 polos)
          "(group \"X\" ugal polos sangsih)")
    (list "two reyong parts, then the ugal" '(mixed-pitched-group 15 ugal)
          "(group \"X\" polos sangsih ugal)")))
  (test-equal "fields: time #f" '(mixed-pitched-group 15 polos #f)
    (error-fields (one-group "(group \"X\" ugal polos)"))))

(test-group "[scores] pitched-with-strokes (ADR 0034)"
  (for-each
   (match-lambda
     ((name expected group)
      (test-equal name expected (error-kind+line+part (one-group group)))))
   (list
    (list "pitched, then a stroke" '(pitched-with-strokes 15 gong)
          "(group \"X\" ugal gong)")
    (list "a stroke, then pitched" '(pitched-with-strokes 15 ugal)
          "(group \"X\" gong ugal)")
    (list "two strokes, then pitched" '(pitched-with-strokes 15 polos)
          "(group \"X\" gong kempli polos)")
    (list "two pitched parts, then the kempli" '(pitched-with-strokes 15 kempli)
          "(group \"X\" polos sangsih kempli)")))
  (test-equal "fields: time #f" '(pitched-with-strokes 15 gong #f)
    (error-fields (one-group "(group \"X\" ugal gong)"))))

(test-group "[scores] errors read from a file"
  (let* ((path (write-temp-file "score-error.nts"
                                (scores+ "(score s" "  (group \"U\" nope))")))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "kind, file, line and part"
      (list 'undefined-part path 15 'nope)
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-kind c) (notasi-syntax-error-file c)
                 (notasi-syntax-error-line c) (notasi-syntax-error-part c))))))

;;; ------------------------------------------------------------------
;;; Check order (03, "Error reporting", checks 6, 7, 13, 14 and 16)

(test-group "[scores] check order"
  (for-each
   (match-lambda
     ((name expected . more)
      (test-equal name expected (apply score-error more))))
   (list
    (list "6 before 13: a score's shape before a part's tokens" '(bad-form 15)
          "(part reyong :name bad 99 1 1 1)" "(score)")
    (list "7 before 16: a duplicate score before a group's part"
          '(duplicate-definition 15)
          "(score a (group \"A\" nope))" "(score a (group \"B\" ugal))")
    (list "13 before 16: a part's tokens before a score written first"
          '(note-out-of-range 15)
          "(score a (group \"A\" nope))" "(part reyong :name bad 99 1 1 1)")
    (list "14 before 16: lengths before a score written first"
          '(unequal-length 15)
          "(score a (group \"A\" nope))" "(part reyong :name short 1)")
    (list "16: a score's options before its groups" '(unknown-option 14)
          "(score a :tempo 1 (group \"A\" nope))")
    (list "16: a score's not-implemented option before its groups" '(not-implemented 14)
          "(score a :labels short (group \"A\" nope))")
    (list "16: groups in order: the first group's member" '(undefined-part 15)
          "(score a" "  (group \"A\" nope)" "  (group \"B\" ugal polos))")
    (list "16: groups in order: the first group's instruments" '(mixed-pitched-group 15)
          "(score a" "  (group \"A\" ugal polos)" "  (group \"B\" nope))")
    (list "16: a group's options before its members" '(unknown-option 15)
          "(score a" "  (group \"A\" :tempo 1 nope))")
    (list "16: a group's not-implemented option before its members" '(not-implemented 15)
          "(score a" "  (group \"A\" :labels long nope))")
    (list "16: option-wrong-level before members" '(option-wrong-level 15)
          "(score a" "  (group \"A\" :title \"T\" nope))")
    (list "16: members before instruments: undefined-part" '(undefined-part 15)
          "(score a" "  (group \"A\" ugal gong nope))")
    (list "16: members before instruments: part-in-two-groups" '(part-in-two-groups 15)
          "(score a" "  (group \"A\" ugal gong ugal))")
    (list "16: scores in file order" '(undefined-part 14)
          "(score a (group \"A\" nope))" "(score b (group \"B\" ugal polos))")
    (list "16: scores in file order, the other way" '(mixed-pitched-group 14)
          "(score b (group \"B\" ugal polos))" "(score a (group \"A\" nope))"))))

;;; ==================================================================
;;; [scores] Rows, fill and holds (slice feat/scores-rows)
;;; ==================================================================

(define (rows-settings g)
  "G's rows, note-names?, fill and holds."
  (list (group-rows g) (group-note-names? g) (group-fill g) (group-holds g)))

(define (groups-rows-settings pc name)
  (map rows-settings (score-groups (score-named pc name))))

(test-group "[scores] reading :rows, :fill and :holds"
  (let ((pc (read-scores+ "(score s :rows parts :fill none :holds dash :note-names yes"
                          "  (group \"U\" ugal)"
                          "  (group \"R\" polos sangsih))")))
    (test-equal "on a score: every group takes them"
      '((parts #t none dash) (parts #t none dash))
      (and pc (groups-rows-settings pc 's))))
  (let ((pc (read-scores+ "(score s :rows single :fill none :holds dash :note-names yes"
                          "  (group \"U\" :rows notes :fill colour :holds none ugal)"
                          "  (group \"R\" :rows parts polos sangsih)"
                          "  (group \"G\" gong))")))
    (test-equal "a group's own values override the score's"
      '((notes #t colour none) (parts #t none dash) (single #t none dash))
      (and pc (groups-rows-settings pc 's))))
  (let ((pc (read-scores+ "(score s :note-names yes"
                          "  (group \"U\" :rows single ugal)"
                          "  (group \"R\" :rows parts :fill none polos sangsih)"
                          "  (group \"G\" :holds dash gong))")))
    (test-equal "on groups only: the others keep the defaults"
      '((single #t colour none) (parts #t none none) (notes #t colour dash))
      (and pc (groups-rows-settings pc 's))))
  (let ((pc (read-scores+ "(score s :rows notes :fill colour :holds none"
                          "  (group \"U\" ugal))")))
    (test-equal "the defaults written out"
      '((notes #f colour none))
      (and pc (groups-rows-settings pc 's))))
  (let ((pc (read-scores+ "(score s (group \"U\" ugal))")))
    (test-equal "not written: notes, colour, none"
      '((notes #f colour none))
      (and pc (groups-rows-settings pc 's))))
  (let ((pc (read-scores+ "(score s :rows parts :note-names yes"
                          "  (group \"R\" (polos :label \"Pol.\") (sangsih :label \"\")))")))
    (test-equal "row labels with :rows parts, an empty one kept"
      '(((polos "Pol.") (sangsih "")))
      (and pc (map member-names (score-groups (score-named pc 's)))))
    (test-equal "every other setting as before"
      (list (list "R" "R" #f 'first-long 'parts #t 'colour 'none 'none 0
                  'by-degree 'pastel1 '()))
      (and pc (map group-settings (score-groups (score-named pc 's))))))
  (let ((pc (read-scores+ "(score s :note-names yes"
                          "  (group \"K\" :rows single gong))")))
    (test-equal "stroke parts on a single row"
      '((single #t colour none))
      (and pc (groups-rows-settings pc 's))))
  (test-assert ":holds dash needs no note names"
    (piece? (read-scores+ "(score s :holds dash (group \"U\" ugal))")))
  (test-assert ":holds dash on a group, without note names"
    (piece? (read-scores+ "(score s (group \"U\" :holds dash ugal))"))))

(test-group "[scores] :rows, :fill and :holds: bad-option"
  (for-each
   (match-lambda
     ((name options)
      (test-equal (string-append "on a score: " name) '(bad-option 14)
        (score-error (string-append "(score s :note-names yes " options
                                    " (group \"U\" ugal))")))
      (test-equal (string-append "on a group: " name) '(bad-option 15)
        (string-error
         (one-group (string-append "(group \"U\" :note-names yes " options
                                   " ugal)"))))))
   (list
    (list ":rows not a choice" ":rows lanes")
    (list ":rows plural of nothing: part" ":rows part")
    (list ":rows a string" ":rows \"parts\"")
    (list ":rows a number" ":rows 2")
    (list ":rows with no value" ":rows :fill none")
    (list ":fill not a choice" ":fill white")
    (list ":fill the American spelling" ":fill color")
    (list ":fill no" ":fill no")
    (list ":fill a string" ":fill \"none\"")
    (list ":holds not a choice" ":holds dashes")
    (list ":holds yes" ":holds yes")
    (list ":holds a string" ":holds \"dash\"")
    (list ":holds with no value" ":holds :rows parts")))
  (test-equal "duplicate-option: :rows" '(duplicate-option 14)
    (score-error "(score s :note-names yes :rows parts :rows single (group \"U\" ugal))"))
  (test-equal "duplicate-option on a group: :fill" '(duplicate-option 15)
    (string-error (one-group "(group \"U\" :note-names yes :fill none :fill none ugal)"))))

(test-group "[scores] needs-note-names"
  (for-each
   (match-lambda
     ((name expected . more)
      (test-equal name expected (apply score-error more))))
   (list
    (list "a group with :rows parts" '(needs-note-names 15)
          "(score s" "  (group \"R\" :rows parts polos sangsih))")
    (list "a group with :rows single" '(needs-note-names 15)
          "(score s" "  (group \"U\" :rows single ugal))")
    (list "a group with :fill none" '(needs-note-names 15)
          "(score s" "  (group \"U\" :fill none ugal))")
    (list "a group with :fill none, strokes" '(needs-note-names 15)
          "(score s" "  (group \"G\" :fill none gong))")
    (list "the score's :rows parts: at the group's line" '(needs-note-names 15)
          "(score s :rows parts" "  (group \"U\" ugal))")
    (list "the score's :fill none: at the group's line" '(needs-note-names 15)
          "(score s :fill none" "  (group \"U\" ugal))")
    (list "the second group, the first naming its notes" '(needs-note-names 16)
          "(score s :rows single" "  (group \"U\" :note-names yes ugal)"
          "  (group \"G\" gong))")
    (list "a group's :note-names no over the score's yes" '(needs-note-names 16)
          "(score s :rows parts :note-names yes" "  (group \"U\" ugal)"
          "  (group \"G\" :note-names no gong))")
    (list ":note-names no written on the group" '(needs-note-names 15)
          "(score s" "  (group \"U\" :rows single :note-names no ugal))")
    (list "the first group in order" '(needs-note-names 15)
          "(score s" "  (group \"U\" :fill none ugal)"
          "  (group \"G\" :rows parts gong))")))
  (for-each
   (match-lambda
     ((name . more)
      (test-assert name (piece? (apply read-scores+ more)))))
   (list
    (list "the score's :note-names yes covers a group's :rows parts"
          "(score s :note-names yes" "  (group \"R\" :rows parts polos sangsih))")
    (list "a group's own :note-names yes"
          "(score s :rows single :fill none" "  (group \"U\" :note-names yes ugal))")
    (list ":rows notes and :fill colour need no names"
          "(score s :rows notes :fill colour" "  (group \"U\" ugal))"))))

;;; Parts for notes-collide, on lines 14 to 16 (each 4 pulses long, on
;;; reyong, so a group of them is one pitched instrument); the score
;;; follows. polos and sangsih (lines 11, 12) strike every pulse.
(define (collide-error . more)
  "(KIND LINE PART TIME) for reading scores+ with the lines MORE."
  (error-fields (apply scores+ more)))

(test-group "[scores] notes-collide"
  (for-each
   (match-lambda
     ((name expected . more)
      (test-equal name expected (apply collide-error more))))
   (list
    (list "two parts striking together: the later part, the first time"
          '(notes-collide 15 sangsih 0)
          "(score s :note-names yes" "  (group \"R\" :rows single polos sangsih))")
    (list "a note struck while another is held"
          '(notes-collide 17 b 1)
          "(part reyong :name a 1 _ - -)"                         ; 14
          "(part reyong :name b - 2 - -)"                         ; 15
          "(score s :note-names yes" "  (group \"R\" :rows single a b))") ; 16, 17
    (list "two held notes overlapping: the first shared column"
          '(notes-collide 17 b 2)
          "(part reyong :name a 1 _ _ -)"
          "(part reyong :name b - - 2 _)"
          "(score s :note-names yes" "  (group \"R\" :rows single a b))")
    (list "half pulses: the time of the shared column"
          '(notes-collide 17 b 1/2)
          "(part reyong :name a 1:1/2 _ - - - - - -)"
          "(part reyong :name b -:1/2 2 - - - - - -)"
          "(score s :note-names yes" "  (group \"R\" :rows single a b))")
    (list "three parts: the earliest collision decides"
          '(notes-collide 18 c 1)
          "(part reyong :name a - - 1 -)"                         ; 14
          "(part reyong :name b - 2 _ -)"                         ; 15
          "(part reyong :name c 3 _ _ -)"                         ; 16
          "(score s :note-names yes" "  (group \"R\" :rows single a b c))") ; 17, 18
    (list "the score's :rows single" '(notes-collide 18 b 1)
          "(part reyong :name a 1 _ - -)"
          "(part reyong :name b - 2 - -)"
          "(score s :rows single :note-names yes"                 ; 16
          "  (group \"U\" ugal)"                                  ; 17
          "  (group \"R\" a b))")                                 ; 18
    (list "the second group's line" '(notes-collide 16 sangsih 0)
          "(score s :note-names yes"
          "  (group \"U\" :rows single ugal)"
          "  (group \"R\" :rows single polos sangsih))")))
  (for-each
   (match-lambda
     ((name . more)
      (test-assert name (piece? (apply read-scores+ more)))))
   (list
    (list "notes one after the other do not collide"
          "(part reyong :name a 1 - - -)"
          "(part reyong :name b - 2 - 3)"
          "(score s :note-names yes" "  (group \"R\" :rows single a b))")
    (list "a held note ending where the next starts"
          "(part reyong :name a 1 _ - -)"
          "(part reyong :name b - - 2 _)"
          "(score s :note-names yes" "  (group \"R\" :rows single a b))")
    (list "half pulses that interleave"
          "(part reyong :name a 1:1/2 - 1 - 1 - 1 -)"
          "(part reyong :name b -:1/2 2 - 2 - 2 - 2)"
          "(score s :note-names yes" "  (group \"R\" :rows single a b))")
    (list "a chord in one part is one event on its row"
          "(part reyong :name a (1 3) - - -)"
          "(score s :note-names yes" "  (group \"R\" :rows single a))")
    (list "the same parts on :rows parts"
          "(score s :note-names yes" "  (group \"R\" :rows parts polos sangsih))")
    (list "the same parts on :rows notes"
          "(score s" "  (group \"R\" polos sangsih))")
    (list "one part alone on a single row"
          "(score s :note-names yes" "  (group \"U\" :rows single ugal))")
    (list "colliding parts in a score where they are on separate rows"
          "(score a :note-names yes" "  (group \"R\" :rows single polos)"
          "  (group \"S\" :rows single sangsih))")))
  (test-assert "notes-collide is a &notasi-syntax-error with file #f"
    (let ((c (catch-syntax-error
              (lambda ()
                (read-piece-string
                 (scores+ "(score s :note-names yes"
                          "  (group \"R\" :rows single polos sangsih))"))))))
      (and (notasi-syntax-error? c)
           (eq? 'notes-collide (notasi-syntax-error-kind c))
           (not (notasi-syntax-error-file c))
           (null? (notasi-syntax-error-uses c)))))
  (let ((t (let ((c (catch-syntax-error
                     (lambda ()
                       (read-piece-string
                        (scores+ "(part reyong :name a 1:1/2 _ - - - - - -)"
                                 "(part reyong :name b -:1/2 2 - - - - - -)"
                                 "(score s :note-names yes"
                                 "  (group \"R\" :rows single a b))"))))))
             (and (notasi-syntax-error? c) (notasi-syntax-error-time c)))))
    (test-assert "the time is an exact rational"
      (and (rational? t) (exact? t))))
  (let* ((path (write-temp-file "collide.nts"
                                (scores+ "(score s :note-names yes"
                                         "  (group \"R\" :rows single polos sangsih))")))
         (c (catch-syntax-error (lambda () (read-piece-file path)))))
    (test-equal "from a file: kind, file, line, part and time"
      (list 'notes-collide path 15 'sangsih 0)
      (and (notasi-syntax-error? c)
           (list (notasi-syntax-error-kind c) (notasi-syntax-error-file c)
                 (notasi-syntax-error-line c) (notasi-syntax-error-part c)
                 (notasi-syntax-error-time c))))))

(test-group "[scores] check order: rows"
  (for-each
   (match-lambda
     ((name expected . more)
      (test-equal name expected (apply score-error more))))
   (list
    (list "needs-note-names before notes-collide, in one group"
          '(needs-note-names 15)
          "(score s" "  (group \"R\" :rows single polos sangsih))")
    (list "a bad :rows value before the members" '(bad-option 15)
          "(score s :note-names yes" "  (group \"R\" :rows lanes nope))")
    (list "a later group's needs-note-names before an earlier collision"
          '(needs-note-names 16)
          "(score s :note-names yes"
          "  (group \"R\" :rows single polos sangsih)"
          "  (group \"U\" :fill none :note-names no ugal))")
    (list "a later group's member before an earlier collision"
          '(undefined-part 16)
          "(score s :note-names yes"
          "  (group \"R\" :rows single polos sangsih)"
          "  (group \"U\" nope))")
    (list "a score's collision before a later score's errors"
          '(notes-collide 15)
          "(score a :note-names yes"
          "  (group \"R\" :rows single polos sangsih))"
          "(score b (group \"U\" nope))"))))

(define runner (test-runner-current))
(test-end "reader")

(remove-temp-files)
(remove-tpl-root)

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
