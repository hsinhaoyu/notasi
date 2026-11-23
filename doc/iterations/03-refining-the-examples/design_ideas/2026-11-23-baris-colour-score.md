# Design idea: Baris gets a full score in colour

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## The idea

`examples/baris.nts` (Tenzer's Baris, iteration 2's second target)
has only scores in Tenzer's style: names in cells, no colour, one row
per part, the gong numbered 1. Jaya Semara's `full` score shows the
other style notasi offers: colours for pitch, one row per key or
stroke, the gong last.

The Baris example should also have a full score in the Jaya Semara
style, so the same piece can be compared in both, and Baris's
interlocking reyong and drums can be read as coloured cells.

## What the score should be

- The whole cycle, every part: reyong (polos, sangsih), ugal, calung,
  gongs and kempli, kendang.
- Jaya Semara's settings: colour fill, no note names, `:rows notes`,
  `:numbering gong-last`.

An uncommitted draft, score `full-colour`, is already in
`examples/baris.nts` and reads without errors. It is a starting point,
not the decision.

## Open

- Name: `full-colour`, or `colour`. With `_` in file names
  (`2026-11-23-output-file-names.md`) it would be drawn as
  `baris_full-colour.png`.
- The gongs: Baris shows gong lanang and gong wadon both as "G", as
  Tenzer does. In a colour score with one row per stroke, that gives
  two rows labelled `G`. The colour score needs to tell them apart
  (`GL`), which means display names that differ by score, or the piece
  keeping the template's names and the Tenzer scores renaming them.
- The kendang: one group with all four hand parts merges both drums'
  strokes into one set of rows. Two groups, "Kendang lanang" and
  "Kendang wadon", as in the Tenzer score, keep them apart.
- Part of iteration 3's acceptance test: the iteration's goal is to
  refine the Jaya Semara and Baris examples (see the README).
- It will show other ideas from today: one-column strokes
  (`2026-11-23-stroke-width.md`), number-row labels, background lines.
