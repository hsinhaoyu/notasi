# Iteration 5: collapsed scores and the gallery

Status: deciding

## Goal

See Jaya Semara and Baris drawn in collapsed form, with annotation
rows, and the gallery working: their drawings made and kept in
`examples/gallery/images/`.

## Acceptance test

Agreed (2026-11-26):

1. `examples/gallery/jaya-semara.nts` and `examples/gallery/baris.nts`
   each have a score in collapsed form (`:rows parts` or `compact`),
   with the gong and kempli on two rows, and at least one group with an
   annotation row naming its patterns.
2. `make images` draws every score of both into
   `examples/gallery/images/` as PNG, named `NAME_SCORE.png`, and
   they are committed.
3. CI fails when an image is out of date with its `.nts`.
4. The README shows a gallery picture.

## Agreed across the design ideas (2026-11-25)

- **One JSON contract version for the iteration.** Part markers, the
  annotation row and removing `:pattern-names` all change the figure
  JSON. They share **contract version 4**: the first milestone that
  changes the JSON opens it and writes its ADR; later milestones add to
  it (as ADR 0047 did for version 3). It is fixed when the iteration is
  released. Its group rows are `rows`/`row`, not `lanes`/`lane`
  ([glossary](design_ideas/2026-11-25-glossary.md)).
- **Removed options get no migration.** `:pattern-names` and
  `:pattern-level` become unknown keys (`unknown-option`), like any other.
- **The examples move is promoted first**, so the other ideas cite the
  new paths under `examples/`.

## Design ideas

Thinking, not the design (ADRs 0023, 0024), in
[`design_ideas/`](design_ideas/):

- [Bapang in two lengths, and what a colotomy is](design_ideas/2026-11-24-bapang-and-colotomy.md):
  the template gets an 8-pulse and a 16-pulse bapang; the
  documentation describes colotomies and their examples correctly.
- [Saving the piece from the command line](design_ideas/2026-11-24-saving-the-piece.md):
  an option to save the internal representation as an s-expression or
  as JSON.
- [Information about a piece](design_ideas/2026-11-24-piece-information.md):
  optional composer, transcriber, source, contributor, performer,
  notes, and their years.
- [Collapsed rows](design_ideas/2026-11-25-collapsed-rows.md):
  `:rows notes/parts/compact`: `parts` one row per part, `compact`
  (replacing `single`) the parts merged into one line, with a row
  added where keys sound together.
- [Telling parts apart in one group](design_ideas/2026-11-25-parts-in-one-group.md):
  polos and sangsih in one group are drawn alike; when asked
  (`:part-marker`), a part gets a small symbol (dot, ring, cross)
  and a coloured border.
- [An annotation row](design_ideas/2026-11-25-annotation-row.md):
  a text-only row above or below a group, showing one part's pattern
  names, or annotations written on its patterns. It replaces
  `:pattern-names`, which is removed.
- [Drawing every score of a file](design_ideas/2026-11-25-render-all-scores.md):
  `notasi render --all` draws all the scores in a `.nts`, each to its
  own `NAME_SCORE` file or, with `--one-file`, one PDF with a page per
  score; `--format` and `--list` too.
- [The collection of examples](design_ideas/2026-11-25-examples-collection.md):
  `examples/` holds `gallery/` and `manual/` (drawings committed),
  `demos/` (tested) and `contrib/` (not tested).
- [What a note shows](design_ideas/2026-11-25-note-label.md):
  `:note-label none/pitch-name/pitch-display-name/key-number` replaces
  `:note-names`.
- [One glossary, used everywhere](design_ideas/2026-11-25-glossary.md):
  one list of terms, the words not to use, and their names in code.

## Promotion

Agreed (2026-11-26). In dependency order (ADR 0023), with two docs
first: the glossary, whose terms every later doc uses, and the
examples move, so the later docs cite the new paths under `examples/`.
No change to 06 or 08:

1. `glossary.md`, a new design document: one list of terms, replacing
   the design README's "Glossary" and 01's "Concepts".
2. `07-environment.md`: `examples/` as `gallery/`, `manual/`, `demos/`
   and `contrib/`; `make images`; CI failing on an out-of-date image.
3. `01-notation.md`: `:rows`, `:part-marker`, the annotation row,
   `:note-label`, the piece information keys, `bapang-8`, `bapang-16`
   and `gegaboran`.
4. `02-piece.md` and `03-reader.md`: the piece information fields;
   the removed options and their errors.
5. `04-layout.md` and `05-typst-backend.md`: collapsed rows, part
   markers, the annotation row, contract version 4 (`rows`/`row`);
   `render --all`, `--one-file`, `--list`, `--format`, `--ppi` and
   `--save-piece`.
6. The build order in `doc/design/README.md`.

Settled before promotion (2026-11-26): the piece's free-text key is
`:remarks`; PNG resolution is `--ppi N`; the glossary is promoted as
drafted.

Promoted so far: `glossary.md` (ADR 0051; its rule in CLAUDE.md and `/doc-audit` in #112), `07-environment.md` (ADR 0052), `01-notation.md` (ADRs 0053–0057), `02-piece.md` (ADR 0058), `03-reader.md`, `04-layout.md` (ADRs 0059, 0060).
