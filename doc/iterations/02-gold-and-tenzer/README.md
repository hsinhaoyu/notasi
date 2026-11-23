# Iteration 2: Gold's Jaya Semara and Tenzer's Baris

Status: building

## Goal

Typeset two published examples, faithfully in content and close in
layout:

| Target | Source | File |
|---|---|---|
| Jaya Semara, pangecet: one gong cycle | Lisa Gold, *Music in Bali* (2005), activities 2.4, 3.1, 3.2, figure 3.1 | [`targets/2026-11-21-jaya-semara-pangecet.nts`](targets/2026-11-21-jaya-semara-pangecet.nts) |
| Baris (gilak): one gong cycle, with sung lines | Michael Tenzer's notation of reyong and kendang parts | [`targets/2026-11-21-baris.nts`](targets/2026-11-21-baris.nts) |

The two stress different things. Jaya Semara tests the music: many
layers at different densities, quarter-pulse kotekan built from
patterns, a 16-pulse colotomy with a pickup, our coloured grid.
Baris tests the score: syllables instead of colours, one row per part,
the drums by hand, beats numbered with the gong as 1, sung lines and a
composite line.

## Acceptance test

Both files read without errors, every score in them is drawn by
`notasi render FILE --score NAME`, and the drawings show what the
sources show (checked by eye against the books, and by golden tests
from then on).

## Design ideas

The design ideas in [`design_ideas/`](design_ideas/) are thinking, not the design. Start with
[`design_ideas/2026-11-21-iteration-2.md`](design_ideas/2026-11-21-iteration-2.md): it
sets the scope, settles the questions the others leave open, and
wins where they disagree. The reference material is in
[Gold 2005](../../references/2026-11-21-reference-gold-2005.md).
Anything neither target needs is in the [backlog](../backlog.md).

## Promotion

The design ideas become the design one design doc at a time, one PR each, in
this order (ADRs 0023, 0024):

1. `01-notation.md`
2. `02-piece.md` and `03-reader.md`
3. `04-layout.md` and `05-typst-backend.md`
4. `06-documents.md` and the build order in `doc/design/README.md`

Promoted so far: `01-notation.md` (ADRs 0025–0032), `02-piece.md` (ADRs 0033–0034), `03-reader.md` (ADR 0035), `04-layout.md` (ADR 0036), `05-typst-backend.md` (ADR 0037), `06-documents.md` and the build order. Promotion is complete.

## Milestones

Each slice is its own branch and PR into `dev`, started with
`/start-milestone <branch>`. After each one, `make check` passes and
the manual describes what the code does.

1. **`feat/music`** (done): the music (01, 02, 03), in five slices, see
   [03-reader.md](../../design/03-reader.md#slices-iteration-2):
   1. `feat/music-syntax`
   2. `feat/music-durations`
   3. `feat/music-rep`
   4. `feat/music-colotomy`
   5. `feat/music-patterns`
2. **`feat/scores`** (done): scores (01, 02, 04, 05), in five slices, see
   [04-layout.md](../../design/04-layout.md#slices-iteration-2):
   1. `feat/scores-form`
   2. `feat/scores-contract`
   3. `feat/scores-rows`
   4. `feat/scores-overlays`
   5. `feat/scores-range`
3. **`feat/targets`** (done): the acceptance test, with no slices. The
   `gong-kebyar` template's reyong becomes e2 to u4 and its gongs one
   instrument with strokes `G GL P T`; `examples/tenzer1.nts` is
   rewritten; the two targets are added to `examples/` as
   `jaya-semara.nts` and `baris.nts`, with golden files per score; the
   manual is brought up to date. Done when both draw as the books show,
   checked by eye. Decided when it started:
   - The template gets every instrument of Gold's figure 2.7 (01,
     "instrument"), the reyong e2 to u4, and the gongs `G GL P T`, each
     shown by its name; colotomies stay in the pieces.
   - `examples/tenzer1.nts` is rewritten with `:colotomy gilak :pickup
     1`, so its gongs come from the colotomy.
   - The targets are copied to `examples/jaya-semara.nts` and
     `examples/baris.nts`, without the notes that the reader can't read
     them and without the definitions the template now gives;
     `targets/` stays as the iteration's record.
