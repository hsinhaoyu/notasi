# 03 — Reader and validation

Status: implemented (iterations 2 and 3): iteration 2's milestone 1 (`feat/music`), all
five slices (see "Slices (iteration 2)"), and the **[scores]** cases
and step 12 with milestone 2 (`feat/scores`, 04 "Slices (iteration
2)"). No form or option raises `not-implemented` any more; the kind is
kept for later iterations. Tests in `tests/reader.scm`. The **[parts]**
cases (ADR 0038) since iteration 3's `feat/syntax`, tests in
`tests/syntax.scm`. The **[score-options]** cases and step 12's new
settings since `feat/drawing-header`, `feat/drawing-lines` and
`feat/drawing-rows` and `feat/drawing-output`.

Everything in this document is **Implemented** unless it says
otherwise. Since slices 1 and 2: steps 1, 2, 3 to 7, step 9 for
tokens, `rep` and patterns (durations, `_`, `-`, `/`, `|`, `||`,
fragments with lead holds, pattern uses with `:step`, spans) in
`(notasi expand)`; step 8 (`check-pattern`: a pattern's notes, and the
instrument of each known pattern it uses, which is expanded only to
measure it; unknown patterns and cycles are found where it is used);
steps 10 and 11; the condition's `time` and `uses`; and every
**[syntax]**, **[durations]**, **[rep]**, **[colotomy]** and
**[patterns]** case.

## Responsibility

Turn a `.nts` file into a valid `piece` record, with its scores, or fail
with a clear error message. Nothing else in the system validates input.

## Modules

The reader is two modules (ADR 0035):

```
(notasi reader)  forms, templates, definitions, scores, errors
      │
      ├──▶ (notasi expand)  part tokens ─▶ timed events, pattern spans
      │          │
      ├──────────┴──▶ (notasi piece)
      │
      └──▶ (notasi style)   palette names, to check scores
```

- `(notasi expand)` turns tokens into events: durations, holds and
  rests, `rep`, patterns and their operators, and the `|` and `||`
  checks. It knows instruments and patterns, not files or forms, and
  depends only on `(notasi piece)`. Its errors carry a time and a chain
  of pattern uses; the reader adds the file and line.
- `(notasi style)` gives the reader its palette and scheme names, so an
  unknown palette is reported at its line.
- Layout still depends only on `(notasi piece)` (and `style`).

## Public interface

**Implemented**, unchanged:

```
(read-piece-file path)   → piece       ; raises on error
(read-piece-port port #:key directory)   → piece
(read-piece-string str #:key directory)  → piece   ; convenient for tests
```

Finding templates (**Implemented**):
- `(use "file.nts")` is relative to the folder of the file containing
  the `use`. For `read-piece-file` that is the piece file's folder; for
  a port or string there is no file, so `directory` is used instead
  (default: the current directory).
- `(use NAME)` searches Guile's `%load-path` for `templates/NAME.nts`.
  Running from the repo root with `-L .`, as the tests do, finds the
  repo's `templates/` folder; an installed package finds its own.
- A template's `file` (in errors) is the path it was found at: the
  `%load-path` entry joined with `templates/NAME.nts`, or the folder
  joined with the string (just the string when the folder is the
  current directory, so messages show `my-gamelan.nts`, not
  `./my-gamelan.nts`). Two `use`s reach the same template when the
  canonical paths are equal.

## Steps

1. **Read forms.** Call `read` repeatedly until EOF, with Guile's
   `r7rs-symbols` and `keywords` read options off (and restored
   afterwards), so that `|`, `||` and `:key` read as ordinary symbols.
   Guile's read errors (unbalanced parentheses, `. .`) are caught and
   re-raised as reader errors with the file and line.
2. **Dispatch** on the head symbol: `piece`, `use`, `scale`, `strokes`,
   `instrument`, `colotomy`, `pattern`, `part`, `score`. Unknown heads
   are errors; a top-level `group` gets its own error, pointing to
   `score`. A form that is an improper list is an error.
3. **Load templates** (**Implemented** rules, with more forms). For each
   `use`, read the template's forms (recursively for its own `use`
   forms, each file once) and merge its definitions:
   - Each definition remembers the file it came from.
   - A file's own definitions replace those from its templates.
   - Two templates of one file defining the same name is an error,
     unless both are the same definition from the same file, reached
     through two `use` paths.
   - A name defined twice in one file is an error.
   - These rules apply in every file: a template's own definitions
     replace those of the templates it uses, too.
   - "Defined by a template" includes what that template gets from its
     own templates. If the file itself defines the name, the two
     templates don't conflict, because the file's definition replaces
     both.
   - Using the same template twice in one file is allowed and has no
     extra effect. A template reached through two paths is loaded once.
   - Order of the merged definitions (`piece-scales`,
     `piece-instruments`, `piece-patterns`): depth-first load order. A
     template's definitions come after those of the templates it uses,
     in `use` order; the piece's own come last. A replaced definition is
     removed from its earlier place; the replacement is where its own
     file puts it. A template reached twice contributes once, at its
     first place.
   - A template may hold `scale`, `strokes`, `instrument`, `colotomy`,
     `pattern` and `use` forms.

   Errors in a template report the template's file and line.
4. **Split options.** For each form, take its positional arguments,
   then the `:key value` pairs (ADR 0026), then the body. `part` has no
   positional arguments, at the top level and inside a `colotomy`,
   whose parts are read by the same code (ADR 0038). A key is a
   symbol of `:` followed by a letter. Each form has its own keys; an
   unknown key, a key twice, a key with no value, or a key after the
   body has started is an error.
5. **Build scales and stroke sets.** Each degree or stroke is a bare
   name or `(NAME :key value ...)` with `:alias`, `:display` and
   `:damped`. Fill in defaults (no aliases; `display` is the name as a
   string; `damped` `#f`) and build a table from every name and alias to
   its degree.
6. **Resolve names** in order: scales and stroke sets → instruments →
   colotomies → patterns → parts → scores. All files are merged by now,
   so a template's instrument uses the piece's scale if the piece
   replaced it.
7. **Resolve note names** (**Implemented** rule), in instruments,
   colotomies, patterns and parts:
   - Pitched scale: split the symbol into a degree and trailing octave
     digits (`i2` → `i`, `2`), look the degree up by name or alias, and
     check the instrument has that note.
   - Stroke set: match the whole symbol against stroke names and
     aliases, since stroke names may end in a digit.
   - A duration suffix is split off first: `e2:1/4` is `e2` and `1/4`,
     `5:2` is key 5 and 2 pulses, `-:3` a rest of 3 pulses.
   - Always store the canonical name (`ding2`, never `i2`).
8. **Check patterns** where they are defined: resolve every token of a
   pattern's body against its `:instrument`, so a pattern is checked
   even if it is never used.
9. **Expand parts** (`(notasi expand)`). Expansion builds **fragments**:
   a list of items timed from 0, and a length in pulses. An item is an
   event (start, duration, notes), a check (time, `pulse` or `cycle`),
   or a lead hold (a leading `_`, which extends the event before the
   fragment when it is placed).
   - **Tokens to a fragment**: one pass, keeping the current duration
     (1 pulse at the start) and the current time. A note, key number or
     chord adds an event for the current duration; a duration suffix
     changes the current duration first. `_` extends the last event, or
     becomes the lead hold if there is none yet. `-` advances the time.
     `|` and `||` add checks. `/` is skipped.
   - **`rep`**: the body is expanded once into a fragment, with the
     duration in force before the `rep`, and placed N times; after the
     `rep`, the current duration is the body's last.
   - **A pattern use**: the pattern's body is expanded into a fragment,
     starting at 1 pulse; `:step N` moves each event's notes N degrees
     (or N keys) and checks them against the instrument again. After the
     use, the part's current duration is what it was before.
   - **Placing** a fragment shifts its items by the current time,
     applies its lead hold to the part's last event, and checks each
     check against the piece's time: `|` on a whole pulse, `||` on a
     cycle boundary.
   - **Spans**: each pattern use is recorded on the part as a
     `pattern-span`, with its depth and the names in force at that use.
10. **Lengths.** Every written part must have the same length as the
    first; with a colotomy, that length must be the pickup plus whole
    cycles. It is the piece's length (0 with no written parts).
11. **Generate parts**: the colotomy's parts, each laid end to end over
    the piece, and the timekeeper `kempli`, one stroke per pulse. They
    come after the written parts, with `origin` `colotomy` or
    `timekeeper` and the colotomy's location.
12. **Read scores**: check each score and its groups, fill every group
    in with its effective settings, its own, else the score's, else the
    default (ADR 0033), and turn the positions in `:from`, `:to` and
    `:breaks` into times. A file with no score gets the default score:
    every part in its own group, in part order, labelled with its name,
    location `#f`. Iteration 3 adds the settings `keys`,
    `octave-numbers?`, `key-numbers?`, `row-labels?`, `display`,
    `background`, `cycle-label` and the
    `"Pulse"` default (02), checked as they are filled in; then, with
    the music, every note against a group's `keys` range, like
    `notes-collide`.
13. **Check the piece invariants** (02-piece.md).

## Error reporting

Errors say where and what, in musician terms:

```
jaya.nts:72: part `polos`, cycle 1, pulse 3 1/2, in pattern `polos-1`
  (line 74), used in pattern `polos` (line 82): note `u4` is not on
  instrument `pemade`
```

- Guile attaches source lines to list forms read from a port, so each
  top-level form has a line, and so does each list inside it (a degree,
  a group, a group member, a `rep`, a pattern use). Atoms (notes,
  numbers, `:key`s) carry none: a token error is reported at its part's
  line with its time, and an option error at the line of the list that
  holds the option. Every location includes the file.
- A time is printed as a position: `cycle C, pulse P` with a colotomy
  (the pickup is cycle 0), or `pulse P` without one. A fraction is
  written as a mixed number, `4 1/2`. Inside a pattern, the message
  names every use on the way, innermost first, with each form's line.
- Every reader error is a `&notasi-syntax-error`, a subtype of `&error`,
  exported from `(notasi reader)`:

  | Field | Accessor | Value |
  |---|---|---|
  | kind | `notasi-syntax-error-kind` | a symbol naming the error case (below) |
  | file | `notasi-syntax-error-file` | string, or `#f` when read from a string or port |
  | line | `notasi-syntax-error-line` | 1-based, or `#f` when no form is to blame (e.g. `missing-piece`) |
  | part | `notasi-syntax-error-part` | part name (symbol), or `#f` |
  | time | `notasi-syntax-error-time` | exact rational in pulses, or `#f` |
  | uses | `notasi-syntax-error-uses` | the pattern uses, innermost first, as `(PATTERN . LINE)` pairs; `'()` outside patterns |

  The predicate is `notasi-syntax-error?`. The condition also carries a
  `&message` with the readable text. Tests check `kind` and the
  location fields, never the message. Inside a pattern's definition
  (step 8), `part` is `#f` and `time` is the time within the pattern.
- Checks run in this order, so a file with several problems always
  reports the same one:
  1. Read all forms (`read-error`).
  2. Each form, in file order, must be a proper list with a known head
     symbol (`improper-form`, `unknown-form`, `group-outside-score`).
  3. The `piece` form: present, first and only once (`missing-piece`,
     `piece-not-first`, `duplicate-piece`).
  4. The `piece` form's title and options (`bad-title`, the option
     kinds).
  5. Templates, as in v1: the `use` forms of the piece file
     (`use-not-first`, `bad-form`), then each template in `use` order,
     depth-first (`template-cycle`, `template-not-found`, items 1 and 2,
     `not-in-template`, its own `use` forms, then items 6 and 7 for its
     definitions), then `template-conflict`. Items 6 and 7 then check
     the piece's own forms, and items 8 to 11 run over the merged
     definitions, in merged order.
  6. The shape and options of each form, in file order (`bad-form`, the
     option kinds).
  7. Duplicate definitions, in file order (`duplicate-definition`).
     Scales and stroke sets share one set of names; instruments,
     colotomies, patterns, parts and scores each have their own. Two
     parts on one instrument where either has no `:name` are not a
     duplicate here: check 13 reports them as `parts-need-names`.
  8. Each scale and stroke set, and each degree or stroke in order
     (`bad-degree`, `degree-ends-in-digit`, `duplicate-degree`,
     `reserved-name`).
  9. Each instrument: its scale (`undefined-scale`), then each note
     (`unknown-note`, `notes-not-ascending`, `duplicate-note`).
  10. Each colotomy: its parts' instruments (`undefined-instrument`),
      tokens (the token kinds) and lengths (`colotomy-part-length`).
  11. Each pattern: its instrument (`missing-option`,
      `undefined-instrument`), then its tokens left to right (the token
      kinds, and `wrong-instrument` for a pattern used inside it).
  12. The piece's colotomy and pickup (`undefined-colotomy`,
      `bad-pickup`, `no-colotomy`).
  13. Each part, in file order: its instrument (`undefined-instrument`),
      `parts-need-names`, then its tokens left to right, expanding
      patterns as they come (the token kinds and the pattern-use kinds).
  14. Lengths (`unequal-length`, `incomplete-cycle`).
  15. Generated parts' names (`duplicate-definition`).
  16. Each score, in file order: its options, then each group in order
      (its options, its members, its instruments), then the checks that
      need the music (`notes-collide`, `pattern-names-overlap`).
- Which line an error reports:
  - The line of the list to blame: the form, or the list inside it
    (a degree, a group, a member, a `rep`, a pattern use).
  - `piece-not-first`: the first form in the file.
  - An atom on its own at the top level (e.g. `foo`), which has no
    position: the line where reading it stopped, i.e. where it ends.
  - `read-error`: the line where Guile stopped reading.
- Report the first error and stop.

## Error cases to cover (each needs a test)

Each case is tagged with the feature it belongs to, which iteration 2's
build order maps to a slice: **[v1]** for cases that are implemented and
keep their meaning, **[syntax]** (the `:key value` forms, `part`,
degrees), **[durations]**, **[rep]**, **[colotomy]**, **[patterns]** and
**[scores]**; iteration 3 adds **[parts]** (the forms of ADR 0038,
**Implemented**) and **[score-options]** (the score options of ADRs
0039–0041, `:keys` and `:display`, **Implemented**). Each case is followed by its `kind`.

### Files and forms

- [v1] Missing or duplicate `piece` form: `missing-piece` (line `#f`),
  `duplicate-piece` (line of the second `piece` form).
- [v1] `piece` not the first form: `piece-not-first` (line of the first
  form in the file).
- [v1] `piece` title not a string: `bad-title`.
- [v1] A form that is not a list, or whose head is not a known symbol
  (including the v1 form `text`): `unknown-form`.
- [syntax] A top-level `group`: `group-outside-score`, at its line. The
  message says groups are written inside a `score`.
- [v1] A lone `.` in a form (an improper list): `improper-form`; Guile
  read errors such as unbalanced parentheses or `. .`: `read-error`, at
  the line where Guile stopped.

### Options

- [syntax] A key with no value (at the end, or followed by another key),
  or a value of the wrong kind (`:pickup 1.5`, `:name "polos"`):
  `bad-option`. A wrong value for a degree's `:alias`, `:display` or
  `:damped` is `bad-degree` (see "Definitions").
- [syntax] A key the form doesn't take: `unknown-option`; a key given
  twice: `duplicate-option`.
- [syntax] A key after the body has started (e.g. after a part's first
  token): `option-after-body`.
- [syntax] A required key left out (a pattern's `:instrument`):
  `missing-option`.

All at the line of the list that holds the option.

### Templates (**[v1]**, unchanged)

- The same name from two templates used by one file, and not defined by
  the file itself: `template-conflict`, at the second definition in load
  order. The same definition reached through two paths is not a
  conflict.
- Template not found: `template-not-found`; a template already being
  loaded on the current chain of `use`s: `template-cycle`. Both at the
  `use` form.
- A `use` without exactly one argument, a symbol or a string:
  `bad-form`.
- A template containing a form other than `scale`, `strokes`,
  `instrument`, `colotomy`, `pattern` or `use`: `not-in-template` (the
  list of forms grows with [colotomy] and [patterns]).
- `use` after a definition, part or score: `use-not-first`.

### Definitions

- [v1] Duplicate definitions within one file: `duplicate-definition`
  (line of the second), in the namespaces of check 7.
- [v1] An instrument naming a scale or stroke set that isn't defined:
  `undefined-scale`.
- [v1] A `scale`, `strokes` or `instrument` form of the wrong shape (no
  name, a name that is not a symbol, no degrees or notes, a scale or
  note that is not a name): `bad-form`.
- [syntax] A degree or stroke that is not `NAME` or `(NAME :key value
  ...)`, `:display` or `:damped` that is not a string, an `:alias` that
  is not a name or a list of names: `bad-degree`, at the degree's line
  when it is a list, else its scale's.
- [v1] Duplicate degree or stroke name or alias within a set:
  `duplicate-degree`. Degree name or alias ending in a digit (scales
  only): `degree-ends-in-digit`.
- [syntax] A degree or stroke called `rep` or `@`, by name or alias:
  `reserved-name`.
- [v1] Instrument notes: `unknown-note`, `notes-not-ascending`,
  `duplicate-note`, at the instrument's line, as in v1. An instrument
  with an option (v1's `show-names`) is `bad-form`: instruments take
  none.

### Parts and tokens

All at the part's line, with `part` and `time` set.

- [parts] A `part` without `:instrument`: `missing-option`. When its
  first token names an instrument (the old form, `(part gong ...)`),
  the message shows the new one: "write `(part :instrument gong ...)`".
  `:instrument` that is not a symbol: `bad-option`. A part with no
  tokens: `bad-form`. An instrument that isn't defined:
  `undefined-instrument`.
- [syntax] Two parts on one instrument where either has no `:name`:
  `parts-need-names`, at the second part's line.
- [v1] A key number outside 1 to the number of keys:
  `note-out-of-range`; a note name that isn't on the instrument (`·`
  included): `unknown-note`.
- [durations] A duration that is not an exact positive number of pulses
  (`e2:0`, `e2:-1`, `e2:x`, `e2:0.5`), or a suffix on anything but a
  note, key number or `-` (`_:2`): `bad-duration`.
- [durations] `_` at the start of a part or after `-`, or a pattern
  starting with `_` used where no note comes before it:
  `hold-without-note`.
- [v1] A chord with fewer than two notes, the same note twice, or a
  member that is not a number or note name: `bad-chord`.
- [v1] Anything else, e.g. a string, `#t` or `1.5`: `unknown-token`.
- [rep] A `rep` that is not `(rep N TOKEN ...)` with N an exact positive
  integer and at least one token: `bad-rep`, at the `rep`'s line.
- [durations] `|` not on a pulse boundary: `misplaced-pulse-check`.
- [colotomy] `||` not at the end of a cycle: `misplaced-cycle-check`.
- [colotomy] `||` in a piece without a colotomy: `no-colotomy`.

### Lengths

- [v1] A written part whose length differs from the first written
  part's: `unequal-length` (its line, `part` set, `time` `#f`).
- [colotomy] With a colotomy, a length that is not the pickup plus whole
  cycles: `incomplete-cycle`, at the first written part's line.

### Colotomies

- [colotomy] A `colotomy` form of the wrong shape (no name, a LENGTH
  that is not an exact positive integer, no parts): `bad-form`. A
  part's tokens give the token kinds, with `part` set to the colotomy
  part's name.
- [parts] Inside a `colotomy`, anything but a `part` form: `bad-form`;
  for the old form `(gong gong ...)` the message shows the new one,
  "write `(part :instrument gong ...)`". A colotomy part without
  `:instrument`: `missing-option`. Two colotomy parts on one instrument
  where either has no `:name`: `parts-need-names`. Errors in a
  colotomy part's form are at the part's own line.
- [colotomy] A colotomy part whose length does not divide the cycle:
  `colotomy-part-length` (the colotomy's line, `part` set).
- [colotomy] `:colotomy` naming a colotomy that isn't defined:
  `undefined-colotomy`, at the `piece` form.
- [colotomy] `:pickup` that is not a whole number of pulses from 0 to
  one cycle (`-1`, `1/2`, `3/2`, more than a cycle): `bad-pickup` (a
  decimal such as `1.5` is not exact, so it is `bad-option`); `:pickup` without `:colotomy`: `no-colotomy`.
  Both at the `piece` form.
- [colotomy] A written part with the name of a generated part
  (`kempli`, or a colotomy part's): `duplicate-definition`, at the
  written part's line.

### Patterns

- [patterns] A `pattern` form with no name, a name that is not a symbol
  or starts with `:` or `@`, or no tokens: `bad-form`.
- [patterns] An `:instrument` that isn't defined: `undefined-instrument`.
- [patterns] In a pattern's body, checked where it is defined: the token
  kinds above (`part` `#f`, `time` within the pattern), and a pattern
  for another instrument used inside it: `wrong-instrument`.
- [patterns] `@NAME` or `(@ NAME ...)` naming no pattern:
  `undefined-pattern`; a pattern that uses itself, directly or through
  others: `pattern-cycle`; a pattern used in a part (or pattern) on
  another instrument: `wrong-instrument`.
- [patterns] A pattern use that is not `(@ NAME :key value ...)`:
  `bad-pattern-use`, at its line. Its operators give the option kinds:
  `:step` takes an exact integer, `:short` and `:long` strings; the
  later operators (`:octave`, `:drop-first`, `:drop-last`) are
  `unknown-option` until they are built.
- [patterns] A note moved by `:step` off the instrument's keys:
  `moved-note-out-of-range`.

All errors at a use carry the part, the time and the chain of uses.

### Scores

- [scores] A `score` form with no name or a name that is not a symbol,
  or a body item that is not a `group`: `bad-form`. A `group` whose
  label is not a string, with no parts, or a member that is not a part
  name or `(PART :label STRING)`: `bad-form`, at the group's line.
- [scores] Duplicate score names: `duplicate-definition`.
- [score-options] A score name containing `_` (ADR 0040): `bad-form`,
  at the score's line.
- [scores] Score and group options: the option kinds above; a score-only
  option on a group: `option-wrong-level`; a bad value (an unknown
  palette or scheme, a colour that is not `"#rrggbb"`, a length that is
  not a number with a Typst unit, a symbol not among the option's
  choices): `bad-option`.
- [scores] A position (`:from`, `:to`, `:breaks`) that is not
  `(CYCLE PULSE)` with a colotomy or a pulse number without one, or that
  lies outside the piece: `bad-position`; `:from` not before `:to`:
  `bad-range`.
- [scores] A group naming a part that isn't defined, written or
  generated: `undefined-part` (`part` set to the name).
- [scores] A part in two groups of one score, or twice in one group:
  `part-in-two-groups`.
- [scores] A group with parts on two different pitched instruments:
  `mixed-pitched-group` (`part` set to the first part on a second
  pitched instrument).
- [scores] A group mixing pitched and stroke instruments (ADR 0034):
  `pitched-with-strokes` (`part` set to the first part of the other
  kind).
- [scores] `:rows parts`, `:rows single` or `:fill none` without
  `:note-names yes` on the group: `needs-note-names`.
- [scores] With `:rows single`, two notes in one cell; with `:rows
  notes`, two notes on one key that share a column without being a
  unison (the same key, start and length): `notes-collide` (`part` set
  to the second part, `time` set to the first shared column).
- [scores] Different pattern names overlapping in one group at the
  chosen level: `pattern-names-overlap` (`part` and `time` set).
- [score-options] `:cycle-label`, `:pulse-label` not a string;
  `:octave-numbers`, `:key-numbers` or `:row-labels` not `yes` or `no`; `:background` not one of `grid`,
  `vertical`, `horizontal`, `empty`: `bad-option`.
- [score-options] `:keys` not `used`, `all` or `(LOW HIGH)`; a LOW or
  HIGH that is not a key of the group's instrument, or LOW above HIGH;
  a range on a group of strokes: `bad-option`, at the line where it is
  written (on the score, checked against each group it applies to).
  `:keys` written on a `:rows parts` or `single` group: `bad-option`;
  inherited from the score, it is ignored there.
- [score-options] `:key-numbers yes` written on a group of strokes, or
  on a `:rows parts` or `single` group: `bad-option`; inherited from the
  score, it is ignored there (the group's `key-numbers?` is `#f`).
- [score-options] A note outside a group's `:keys` range:
  `outside-keys` (the group's line, `part` and `time` set). The message
  names the note and the range: "part `ugal`, cycle 2, pulse 3: `a2` is
  outside the keys shown, `a1` to `u2` (:keys)".
- [score-options] `:display` that is not a list of `(STROKE STRING)`,
  or a STROKE that is no stroke of an instrument in the group (on a
  score, in any of its groups): `bad-option`.

## Slices (iteration 2)

**Implemented.** Milestone 1 of iteration 2 (`feat/music`) is built in five
slices, each its own branch and PR into `dev`, started with
`/start-milestone <branch>`. Each slice changes the records (02), the
reader, and every layer it touches, and updates the examples, golden
files and manual pages it affects, so that after each one `make check`
passes and the manual describes what the code does. Each covers the
error cases tagged with its feature, and the steps above that they need.

1. **Implemented.** `feat/music-syntax` **[syntax]**: reading with `r7rs-symbols` and
   `keywords` off; step 4 (`:key value` options) for every form;
   `(part INSTRUMENT :name NAME ...)`; degrees and strokes with
   `:alias`, `:display` and `:damped`; instruments without options;
   `·` and the top-level `group` gone. Until milestone 2, every part is
   drawn in its own group, and no note shows its name. Decided for this
   slice:
   - Time stays in integer steps until slice 2, so `piece` takes two
     transitional options, `:steps-per-pulse N` (default 4) and
     `:steps-per-system N` (default: one system), exact positive
     integers (`bad-option` otherwise). Slice 2 removes them.
   - `colotomy`, `pattern` and `score` forms are known heads that raise
     `not-implemented` at the form's line, in a piece or a template,
     until their slices build them.
   - Tests written in the v1 syntax are translated to the new syntax,
     keeping what they check; tests of what this slice removes are
     deleted or turned into the new errors.
2. **Implemented.** `feat/music-durations` **[durations]**: `(notasi expand)` (ADR 0035)
   and step 9 for tokens: times as exact rationals in pulses (02),
   duration suffixes and the current duration, `_` and `-`, `|` checks,
   `/`; the condition's `time` and `uses` fields, with positions as
   `pulse P`; `steps-per-pulse` and `steps-per-system` gone, and layout
   deriving the step (04, "The step"), with systems one per piece until
   scores. Decided for this slice:
   - `piece` gains only what this slice needs:
     `(make-piece title length scales instruments parts groups)`, with
     `length` an exact rational in pulses; `steps-per-pulse` and
     `steps-per-system` go. Later slices add their own fields, and
     milestone 2 replaces `groups` with `scores`.
   - `(notasi expand)` resolves note names (step 7 for tokens moves
     into it) and exports `(expand-tokens tokens instrument)` →
     `(EVENTS . LENGTH)`: event records with exact rational starts and
     durations, and the written length in pulses (trailing rests
     included). Its errors are `&expansion-error`, a subtype of
     `&error`, with `expansion-error?`, `expansion-error-kind`,
     `expansion-error-time` (pulses from the start of the tokens, or
     `#f`) and `expansion-error-uses` (`'()` until patterns), and a
     `&message` without a location. The reader catches it, adds the
     file, line and part, and raises `&notasi-syntax-error` with the
     same kind, `time` and `uses`.
   - `part-steps` becomes `part-end` and `events-at` takes a time
     (02, "Derived values").
   - Without a colotomy, a time T is written `pulse P` with P = T + 1,
     a fraction as a mixed number: time 3/2 is "pulse 2 1/2", e.g.
     "part `ugal', pulse 2 1/2: …". A `time` of `#f` prints no
     position.
3. **Implemented.** `feat/music-rep` **[rep]**: `rep`. Decided for this slice:
   - `&expansion-error` gains a field `line`, accessor
     `expansion-error-line`: the 1-based line of the list to blame
     (Guile's source line of a `rep`), or `#f`. The reader reports
     that line when it is set, else the part's line. `bad-rep` sets it.
   - A `rep` body may start with `_`: it holds the note before the
     `rep` the first time, and the body's last note each time after
     (a lead hold, as for patterns); with no note there it is
     `hold-without-note` at that time.
   - `rep` may be nested. A `|` in the body is checked at every
     repetition; any other mistake in the body is reported at its time
     in the first repetition.
4. **Implemented.** `feat/music-colotomy` **[colotomy]**: `colotomy` forms, `:colotomy`
   and `:pickup`, generated parts (step 11), `||` checks, lengths
   (step 10), positions as `cycle C, pulse P`, `time->position` and
   `position->time`. Decided for this slice:
   - The timekeeper `kempli` is always generated, with or without a
     colotomy. It plays the piece's instrument `kempli` when there is
     one; otherwise a built-in one (instrument `kempli`, one stroke `K`),
     which is not in `piece-instruments` or `piece-scales`. A timekeeper
     on the built-in instrument is never printed: it gets no default
     group (and, in milestone 2, the default score leaves it out and a
     score that names it is `undefined-part`). A written part called
     `kempli` is `duplicate-definition`.
   - Records: `(make-piece title length pickup colotomies scales
     instruments parts groups)`; `(make-part name instrument events
     origin location)`, `origin` one of `written`, `timekeeper`,
     `colotomy` (slice 5 adds `spans` before `location`);
     `(make-colotomy name length timekeeper parts location)`, its parts
     over one cycle, `timekeeper` the symbol `kempli`. `(time->position
     piece time)` is `(CYCLE PULSE)`, or the pulse number `TIME + 1`
     without a colotomy; `(position->time piece cycle pulse)` and
     `(position->time piece pulse)` invert it.
   - Generated parts come after the written ones, the colotomy's parts
     first, then `kempli`. A colotomy part is laid so that every cycle
     ends on the colotomy's last pulse; with a pickup it starts partway
     through cycle 0, and a stroke starting before time 0 is cut at 0.
     The timekeeper strikes `K` at every whole pulse, one pulse long,
     the last stroke cut at the piece's end.
5. **Implemented.** `feat/music-patterns` **[patterns]**: `pattern` forms, checked where
   they are defined (step 8), `@NAME` and `(@ NAME :step :short :long)`,
   spans, and errors that name the chain of uses. Decided for this slice:
   - Records as in 02: `(make-piece title length pickup colotomies
     scales instruments patterns parts groups)`; `(make-part name
     instrument events origin spans location)`; `(make-pattern name
     instrument short long location)`; `(make-pattern-span pattern short
     long start end depth)`.
   - `(notasi expand)`: `expand-tokens` keeps its interface and result,
     and gains `#:patterns`, an alist from a pattern's name to
     `(PATTERN . TOKENS)`. `(expand-part tokens instrument #:key cycle
     pickup patterns)` returns `(values EVENTS LENGTH SPANS)`;
     `expand-tokens` is it without the spans. `(check-pattern tokens
     instrument #:key patterns)` checks a pattern's body where it is
     defined (step 8), its errors at times within the pattern.
   - An error's `uses` lists `(PATTERN-NAME . LINE)` pairs, innermost
     first, LINE the line of that pattern's `pattern` form; the error's
     own line stays the part's (or the `(@ ...)` list's, for
     `bad-pattern-use`).
   - `:step N` moves a note written by name N degrees along the scale,
     which must land on a key of the instrument; a key number or a
     stroke moves N keys.

The **[scores]** cases are built in milestone 2 (04, "Slices").

## Open questions

- Collecting several errors instead of stopping at the first.

## Not the reader's job

- Choosing the step, or deciding rows, colours or systems (layout).
