# Backlog

Work that is deferred: not part of any iteration yet. Each item links to
where it is discussed. An iteration takes items from here when its goal
needs them.

## Milestones

- **Scores in Typst documents**: milestone 5 of iteration 1's build
  order, designed in [06-documents.md](../design/06-documents.md), with
  [ADR 0016](../decisions/0016-documents-load-scores-from-a-side-file.md)
  still proposed. Not part of iteration 1 or 2.

## The old "v2 features"

Item 6 of the old build order:

| Feature | Where it stands |
|---|---|
| Repeats | Covered by iteration 2: `(rep N ...)` ([notation language](02-gold-and-tenzer/design_ideas/2026-11-21-notation-language.md)) |
| Syllables | Covered by iteration 2: names instead of colours, open and damped forms (Baris; [score](02-gold-and-tenzer/design_ideas/2026-11-21-score.md)) |
| Looping parts | Partly: in iteration 2 a colotomic part shorter than its cycle repeats ([notation language](02-gold-and-tenzer/design_ideas/2026-11-21-notation-language.md), `colotomy`). Other parts don't loop. |
| Sections | Later: see "Colotomy and form" below |

## Later, from iteration 2

From the "Later" list and the decisions marked "later" in
[`design_ideas/2026-11-21-iteration-2.md`](02-gold-and-tenzer/design_ideas/2026-11-21-iteration-2.md).
Neither target needs them; the design leaves room for them.

### Notation ([notation language](02-gold-and-tenzer/design_ideas/2026-11-21-notation-language.md))

- `(relative ...)` octaves
- Duration scaling `(* M ...)` and chord durations
- Pattern operators `:octave`, `:drop-first`, `:drop-last`
- Patterns with parameters; patterns written in degrees only
- Patterns written for a scale (`:scale`) and shared between instruments,
  with `:octave` to change register
- A surface syntax: a line-based text format without parentheses, as a
  second front end (ADR 0001; formerly a planned extension in 01)
- Stroke `n` (kelenang)
- Tagged versions of the music

### Colotomy and form ([colotomy](02-gold-and-tenzer/design_ideas/2026-11-21-colotomy.md), [notation language](02-gold-and-tenzer/design_ideas/2026-11-21-notation-language.md))

- `:lines N`: lines inside long cycles
- Departing from the colotomy, changing colotomies, sections
- A pickup longer than a cycle
- Longgor forms and other meters
- Another timekeeper (`:timekeeper`, e.g. the kajar) or its own pattern
- Gongs never damped (`:damped no`)

### Internal representation ([internal representation](02-gold-and-tenzer/design_ideas/2026-11-21-internal-representation.md))

- An `ending` field on events (damped, ringing)
- `rep` blocks kept as spans in the piece

### Score ([score](02-gold-and-tenzer/design_ideas/2026-11-21-score.md))

- Systems one cycle long: `:system-length (cycles 1)`
- Marking damping in the music, instead of deriving the name form from
  the grid
- Instrument pictures, "etc." at line ends, colons after labels, systems
  side by side
- A level above groups (brackets)
- More colour schemes (by part, by octave)

## Later, from iteration 3

- **Strokes drawn at their durations**, as an option against ADR 0042's
  one column: not until someone needs it
  ([stroke width](03-refining-the-examples/design_ideas/2026-11-23-stroke-width.md)).
- **Choosing the font** of a standalone figure (`:font` on a score, or
  `notasi render --font`), beyond ADR 0045's list: later, if asked for
  ([sans-serif](03-refining-the-examples/design_ideas/2026-11-23-sans-serif.md)).

## Later, from iteration 4

Changes to notasi itself that the Emacs package could use, not needed
for iteration 4's goal:

- **`notasi describe FILE`**: the instruments, notes, patterns and
  scores of a piece as data, for completion, Eldoc and Imenu, which
  come in a later iteration
  ([help while writing](04-emacs-mode/design_ideas/2026-11-24-editing-help.md)).
- **A faster check** that finds mistakes without drawing (skipping
  Typst), and **a Guile process kept running** between drawings
  (`notasi serve`): not needed while a drawing takes about 0.6 s
  ([how a drawing is made](04-emacs-mode/design_ideas/2026-11-24-drawing.md),
  [live preview](04-emacs-mode/design_ideas/2026-11-24-live-preview.md)).
- **Several mistakes at once**, collected by the reader instead of
  stopping at the first
  ([mistakes shown in the text](04-emacs-mode/design_ideas/2026-11-24-errors.md)).

In the Emacs package (08):

- **Completion, Eldoc and Imenu**, and where completion gets its facts
  (`notasi describe` above, or reading the forms in Emacs Lisp)
  ([help while writing](04-emacs-mode/design_ideas/2026-11-24-editing-help.md)).
- **A preview that scrolls with the cursor** in a long piece, and
  **highlighting a pattern's notes** in the picture
  ([live preview](04-emacs-mode/design_ideas/2026-11-24-live-preview.md)).
- **MELPA**, once the package has been used for a while
  ([the package](04-emacs-mode/design_ideas/2026-11-24-package.md)).
