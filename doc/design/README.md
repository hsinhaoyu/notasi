# Design overview

This project notates Balinese (and other) gamelan music in a small text
language, reads it into a `piece` record with Guile, renders it as a
coloured, piano-roll-style grid via Typst. It does not analyse pieces
(ADR 0015).

## Pipeline

```
piece.nts ──reader──▶ piece ──layout──▶ figure.json ──Typst template──▶ PDF / PNG / SVG
```

Scores can also live inside a Typst document (06). `notasi` finds them
with a Typst query (`typst eval --in`), runs the same pipeline on each, and writes the
figures to a side file that the document loads:

```
book.typ ──typst eval──▶ snippets ──reader, layout──▶ book.notasi.json
book.typ + book.notasi.json ──typst compile──▶ PDF
```

| Stage | Module | Document |
|---|---|---|
| Notation language | — | [01-notation.md](01-notation.md) |
| Piece (internal data) | `(notasi piece)` | [02-piece.md](02-piece.md) |
| Reader + validation | `(notasi reader)`, `(notasi expand)` (planned) | [03-reader.md](03-reader.md) |
| Layout, note style | `(notasi layout)`, `(notasi style)` | [04-layout.md](04-layout.md) |
| Typst backend | `(notasi typst)`, `typst/notasi.typ` | [05-typst-backend.md](05-typst-backend.md) |
| Scores in Typst documents | `scripts/notasi`, `typst/` package | [06-documents.md](06-documents.md) |
| Environment, installation, testing (open questions) | — | [07-environment.md](07-environment.md) |

## Build order

Work is organised in iterations (ADR 0023): each has a folder in
[`../iterations/`](../iterations/) with its goal, acceptance test,
status and milestones. Each milestone is one feature branch with tests,
or, when its design doc has a "Slices" section, one branch per slice
(see CLAUDE.md for the workflow).

### Iteration 1: first drawings (done, v0.1.x)

See [its README](../iterations/01-first-drawings/README.md).

1. `feat/piece`: records and derived functions
2. `feat/reader`: four slices, see [03-reader.md](03-reader.md#slices)
3. `feat/json` + `feat/layout`: four slices, see [04-layout.md](04-layout.md#slices)
4. `feat/typst-backend`: three slices, see
   [05-typst-backend.md](05-typst-backend.md#slices)

### Iteration 2: Gold's Jaya Semara and Tenzer's Baris (done, tagged v0.2.0-dev)

See [its README](../iterations/02-gold-and-tenzer/README.md).

1. **Implemented.** `feat/music`: the music; five slices, see
   [03-reader.md](03-reader.md#slices-iteration-2)
2. **Implemented.** `feat/scores`: scores; five slices, see
   [04-layout.md](04-layout.md#slices-iteration-2)
3. **Implemented.** `feat/targets`: the acceptance test: Jaya Semara and Baris as
   examples

### Iteration 3: refining the examples (building)

See [its README](../iterations/03-refining-the-examples/README.md).

1. **Implemented.** `feat/syntax`: parts with `:instrument`, colotomy parts as `part`
   forms, `gilak` and `bapang` in the template
2. `feat/drawing`: the drawing; four slices, see
   [04-layout.md](04-layout.md#slices-iteration-3)
3. `feat/examples`: the acceptance test: Jaya Semara and Baris refined,
   and Baris's colour score

### Deferred

Scores in Typst documents (06) and the old "v2 features" are in the
[backlog](../iterations/backlog.md).

## Core decisions

Each decision's context and consequences are in its record in
[`../decisions/`](../decisions/README.md).

1. The notation is s-expressions: [0001](../decisions/0001-notation-is-s-expressions.md)
2. Time is measured in pulses, with durations: [0025](../decisions/0025-time-is-measured-in-pulses.md) (planned; replaces [0002](../decisions/0002-time-is-a-grid-of-equal-steps.md))
3. Notes are symbolic: [0003](../decisions/0003-notes-are-symbolic.md)
4. The piece is the centre: [0008](../decisions/0008-the-piece-is-the-centre.md)
5. Guile decides, Typst draws: [0005](../decisions/0005-guile-decides-typst-draws.md)
6. The JSON file is the contract with Typst: [0006](../decisions/0006-json-is-the-contract-with-typst.md)
7. Guile 3.0, standard library first: [0007](../decisions/0007-guile-3-standard-library-first.md)
8. One pitched instrument per group: [0011](../decisions/0011-one-pitched-instrument-per-group.md)
9. No analysis: [0015](../decisions/0015-no-analysis.md)
10. Notes are coloured by pitch: [0017](../decisions/0017-notes-are-coloured-by-pitch.md)
11. One `notasi` command with subcommands: [0018](../decisions/0018-one-notasi-command.md)
12. Notes are square blocks; note names are optional: [0019](../decisions/0019-square-notes-optional-names.md)
13. A plain white grid; notes fill their cells: [0020](../decisions/0020-plain-grid-notes-fill-cells.md)
14. pastel1 is the default palette: [0021](../decisions/0021-pastel1-is-the-default-palette.md)
15. Notation files end in `.nts`: [0022](../decisions/0022-notation-files-end-in-nts.md)
16. Options are written `:key value`: [0026](../decisions/0026-options-are-key-value.md) (planned)
17. A part names its instrument first: [0027](../decisions/0027-a-part-names-its-instrument-first.md) (planned)
18. `_` holds, `-` damps: [0028](../decisions/0028-hold-sustains-rest-damps.md) (planned)
19. Patterns belong to one instrument: [0029](../decisions/0029-patterns-belong-to-one-instrument.md) (planned)
20. Colotomies generate the gong and kempli parts: [0030](../decisions/0030-colotomies-generate-gong-and-kempli-parts.md) (planned)
21. Printing belongs to scores: [0031](../decisions/0031-printing-belongs-to-scores.md) (planned)
22. The palette is chosen in the score: [0032](../decisions/0032-the-palette-is-chosen-in-the-score.md) (planned)
23. Pitched and stroke instruments are grouped apart: [0034](../decisions/0034-pitched-and-stroke-instruments-are-grouped-apart.md) (planned)
24. Expansion is its own module: [0035](../decisions/0035-expansion-is-its-own-module.md) (planned)
25. The JSON contract is version 2: [0036](../decisions/0036-json-contract-version-2.md) (planned)
26. Cycle lines are heavier than pulse lines: [0037](../decisions/0037-cycle-lines-are-heavier.md) (planned)

Proposed, not yet agreed:

- Typst documents load scores from a side file: [0016](../decisions/0016-documents-load-scores-from-a-side-file.md)
  (06 and the deferred "Scores in Typst documents" work depend on it; see the backlog)

## Maintaining these documents

- These documents always describe the current design. When it changes,
  edit the text in place; git history keeps the old versions.
- Each document has a `Status:` line under its title, and content is
  labelled **Implemented** (what the code does now), **Planned** (agreed,
  not built) or **Open questions** (undecided). Move items between these
  as they happen.
- Any change to behaviour, notation, the piece records or the JSON contract
  updates these documents in the same PR.
- Reversing or narrowing a core decision, or anything else documented
  here, needs a new record in `../decisions/` (see its README).
- Exact behaviour (e.g. every reader error case) belongs in tests and
  examples; documents can point to them instead of repeating them.
- Run `/doc-audit` in Claude Code at each milestone to find drift
  between these documents and the code.
- These documents change only by promoting an iteration's design
  ideas
  (`/promote-design`) or by building a milestone. Design ideas
  under `../iterations/` are never the design.

## Glossary

| Term | Meaning |
|---|---|
| pulse | The steady stroke of the kempli/kajar; the unit of time. Durations are counted in pulses |
| step | One column of a printed grid: the largest duration dividing every time a score prints, derived by layout. (v1: one token in a part, `steps-per-pulse` to a pulse) |
| cycle | One repetition of a colotomy; positions are a cycle and a pulse |
| colotomy | A named cycle of pulses and the gong parts that mark it |
| pattern | A named figure for one instrument, played in parts with `@NAME` |
| system | One horizontal block of the figure, e.g. one gong cycle |
| scale | Ordered set of degree names, e.g. `ding dong deng dung dang` |
| stroke set | Named set of unpitched strokes, e.g. kendang `dag dug du` |
| instrument | Ordered list of the notes (keys/pots) an instrument has |
| part | A line of music played on one instrument |
| score | How the music is printed: groups of parts and printing options; a file may have several |
| group | Parts drawn together in one block of rows, e.g. polos + sangsih; part of a score (v1: a top-level form) |
| lane | One row inside a group, one per note (pitch) or stroke type |
| polos / sangsih | The two interlocking parts of a kotekan |
| colotomic | Gong, kempur, kempli etc., which mark the structure of the cycle |

## Prototype

`../prototypes/score.typ` and `../prototypes/piece.json` are a hand-made mockup,
transcribed from a textbook excerpt (reyong kotekan, ugal, calung,
kempli, gong, kendang), from before the template existed. The template
keeps its structure (groups of lanes, a step grid, pulse numbers and
lines) but no longer its look. notasi colours each pitch rather than
each part (ADR 0017); draws square notes that fill their cells, with
names only where an instrument asks for them, and strokes as grey boxes
(ADRs 0019, 0020); and leaves the background white. The two examples'
drawings (`make preview`) are the reference now.
