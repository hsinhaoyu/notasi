# Iteration 3: refining the examples

Status: building

## Goal

Refine the two examples of iteration 2, Jaya Semara
(`examples/jaya-semara.nts`) and Baris (`examples/baris.nts`): make
their notation easier to read and write, and their drawings clearer,
and give Baris a full score in colour alongside Tenzer's style.

## Acceptance test

Both files are rewritten in the iteration's notation and read without
errors. Every score in them, including Baris's new colour score, is
drawn by `notasi render FILE --score NAME`, and the drawings show the
changes agreed in the design ideas (checked by eye, and by golden tests
from then on).

## Design ideas

Thinking, not the design (ADRs 0023, 0024). All from the discussion of
2026-11-23, in [`design_ideas/`](design_ideas/):

Notation:

- [Colotomy parts are `part` forms](design_ideas/2026-11-23-colotomy-parts.md):
  `(colotomy gilak 8 (part ...))`, no more `(gong gong ...)`.
- [A part names its instrument with `:instrument`](design_ideas/2026-11-23-part-syntax.md):
  `(part :instrument gong ...)`, required.
- [Common colotomies come from the template](design_ideas/2026-11-23-template-colotomies.md):
  `gilak` in `gong-kebyar`, used by name.

Files:

- [Score file names use `_`](design_ideas/2026-11-23-output-file-names.md):
  `gilak_full.png`, not `gilak.full.png`.

Drawing:

- [A pickup on a system of its own](design_ideas/2026-11-23-pickup-system.md):
  shows cycle number `0`; the pickup doesn't join the first system.
- [Lane labels](design_ideas/2026-11-23-lane-labels.md): `:octave-numbers`,
  and a line between the labels and the notes.
- [Key numbers beside the row labels](design_ideas/2026-11-23-key-numbers.md):
  `:key-numbers`, and `:row-labels` to hide the row labels.
- [The cycle and pulse rows are labelled](design_ideas/2026-11-23-header-labels.md):
  `:cycle-label`, `:pulse-label`, "Cycle" and "Pulse" by default.
- [Cycle and pulse numbers are centred over their pulse](design_ideas/2026-11-23-header-alignment.md).
- [Sans-serif font](design_ideas/2026-11-23-sans-serif.md) for
  standalone figures, from the fonts installed.
- [Choosing which keys a group shows](design_ideas/2026-11-23-keys-shown.md):
  `:keys used/all/(LOW HIGH)`.
- [Strokes are drawn one column wide](design_ideas/2026-11-23-stroke-width.md).
- [Notes have a grey border](design_ideas/2026-11-23-note-border.md),
  every edge the same weight; stroke cells a lighter grey.
- [The lines behind the notes](design_ideas/2026-11-23-background-lines.md):
  `:background grid/vertical/horizontal/empty`, default `grid`.

Examples:

- [Baris gets a full score in colour](design_ideas/2026-11-23-baris-colour-score.md).

Several ideas left questions open; they were settled on 2026-11-23,
before promotion, in each idea's "Settled" section. The greys, widths
and fonts are left to be judged by eye while building. Several also reverse iteration 2
decisions (ADRs 0020, 0027, 0030, and choices recorded in 04-layout
and 05-typst-backend), so promotion adds new ADRs.

## Promotion

In dependency order (ADR 0023): `01-notation.md`; then `02-piece.md`
and `03-reader.md`; then `04-layout.md` and `05-typst-backend.md`; then
`06-documents.md` and the build order.

Promoted so far: `01-notation.md` (ADRs 0038–0041; again with key numbers and template colotomies, ADR 0046), `02-piece.md` (again with key numbers), `03-reader.md` (again with key numbers), `04-layout.md` (ADRs 0042–0043; again with key numbers, ADR 0047), `05-typst-backend.md` (ADRs 0044–0045; again with key numbers), `06-documents.md` and the build order. Promotion is complete.

## Milestones

Each milestone, or each slice of one, is its own branch and PR into
`dev`, started with `/start-milestone <branch>`. After each one,
`make check` passes and the manual describes what the code does.

1. **`feat/syntax`** (done) (01, 02, 03), with no slices:
   - parts written `(part :instrument I :name N ...)`, and colotomy
     parts as `part` forms (ADR 0038); the old forms are errors whose
     messages show the new one;
   - `gilak` and `bapang` in the `gong-kebyar` template (ADR 0046);
   - every `.nts` rewritten: examples, the manual's examples and
     mistakes, test fixtures.

   Decided when it started:
   - Iteration 2's `targets/` keep the old syntax, as that iteration's
     record; `examples/` holds the living copies.
   - Existing test fixtures are rewritten by a script during
     implementation; the tests written first cover only the new cases
     (03, **[parts]**) and the template's `gilak` and `bapang`.
   - An old-form error is tested by its kind and by its message
     containing the new form with the user's instrument
     (`(part :instrument gong ...)`); the wording is the code's, and
     the manual shows it as a mistake.
2. **`feat/drawing`** (done) (01–05), in four slices, see
   [04-layout.md](../../design/04-layout.md#slices-iteration-3):
   1. `feat/drawing-header`
   2. `feat/drawing-lines`
   3. `feat/drawing-rows`
   4. `feat/drawing-output`
3. **`feat/examples`** (done), the acceptance test, with no slices: Jaya
   Semara and Baris refined in the new notation, Baris's `colour` score
   (two kendang groups, `:display` for Tenzer's gongs), golden files,
   and the drawings checked by eye.

   Decided when it started:
   - Baris keeps the template's gong strokes (`GL` for the gong
     lanang); its four Tenzer-style scores show both gongs as "G" with
     `:display ((GL "G"))`. They keep the cycle row and its "Cycle"
     label as drawn.
   - Baris's `colour` score has the Jaya Semara score's look: every new
     option at its default, `:numbering gong-last`, one system, and two
     kendang groups, "Kendang lanang" and "Kendang wadon".
