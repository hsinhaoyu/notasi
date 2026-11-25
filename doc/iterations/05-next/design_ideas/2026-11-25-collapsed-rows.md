# Design idea: collapsed rows

Status: agreed in discussion (2026-11-25); two things to check by eye.
Not the design until promoted.

## The idea

With `:rows notes` (the default), a group has one row per key or
stroke it plays. For an instrument that plays one note at a time this
spends a lot of height. In the `full` score of
`examples/jaya-semara.nts`, Jublag takes four rows (a2, e2, o2, i2)
and the gong and kempli four (G, P, T, K), though at most two strokes
sound together.

A **collapsed** display uses fewer rows than keys. A row no longer
stands for a pitch, so a note shows which note it is by its **colour**
(the pitch colour, ADR 0017) and, if the writer asks, by its **note
label** (`:note-label`, [what a note shows](2026-11-25-note-label.md));
colour only is allowed. It can be set on a
group or on the score, a group's setting overriding the score's (ADR
0033).

## What `:rows` does

`:rows` says what a row in a group stands for. Two collapsed values
cover the two ways of collapsing; both are useful, and Baris uses both.

| Value | A row stands for | Rows | Label |
|---|---|---|---|
| `notes` (default) | a key or stroke | one per key or stroke played | the key (`i3`, `K`) |
| `parts` | a part | one per part, in the group's order | the part's label |
| `compact` | nothing: the group's parts merged into one line | one, plus one more wherever different keys sound together | none |

Drawn with the music of the gallery pieces:

| | `parts` | `compact` |
|---|---|---|
| Jaya Semara, polos and sangsih | 2 rows, polos and sangsih | 1 row, the combined norot line (`:part-marker` tells the parts apart) |
| Jaya Semara, gong and kempli | 2 rows, `gong` and `kempli` | 2 rows (G P T, and K), unlabelled |
| Jublag | 1 row, `jublag` | 1 row |
| Baris `kendang-composite` | 4 rows, one per hand | 1 row, the composite line, as today |
| Baris `full`, kendang LH and RH | LH and RH, as today | 1 row per drum |

## Agreed (2026-11-25)

- **`:rows` has three values: `notes`, `parts`, `compact`.**
- **`parts` is unchanged**: one row per part, labelled with the part's
  row label. A part never overlaps itself (its notes follow one
  another; a chord is one event), so one row per part is always
  enough.
- **`compact` replaces `single`.** It is `single` renamed and widened:
  the group's parts merged into one line, as `single` draws today;
  where two different keys sound at the same moment, a row is added
  instead of failing (`notes-collide` today). `single` is removed with
  no migration: `:rows single` becomes an unknown value, like
  `:pattern-names`.
- **Rows in `compact` are assigned by key.** Each key or stroke keeps
  one row for the whole score; keys that never sound together share a
  row. Rows are filled in the order of the group's keys (highest pitch first;
  strokes in instrument order), each key going to the first row where
  it never sounds with a key already there. For the gong and kempli:
  G, P and T on one row and K on the other, every time, so the kempli
  can be followed by eye. Where no two keys ever sound together, all
  share one row. This can need more rows than the most notes sounding
  at once (three keys, each pair overlapping somewhere but never all
  three); accepted as rare.
- **A chord is one note** in `parts` and `compact`, as today: one
  event, its names joined (`i o`), with the look of its lowest note.
- **A unison in `compact`** (two parts on the same key at the same
  time, same length) is one note, drawn once, under the first part, as
  on `notes` rows.
- **Set on a group or on the score**, as every `:rows` value already is.

- **Two notes sound together when their boxes, as drawn, would
  overlap**: from a note's start to its start plus its drawn length. A
  held note counts for its whole length; a stroke for its one column
  (ADR 0042), so strokes collide only when they start in the same
  column. So a box is never drawn over another: an ugal o2 held two
  pulses and a calung e2 struck on its second pulse take two rows.

## Open

1. *(Settled: boxes overlap.)* What "sound together" means.
2. *(Settled: none.)* Labels of `compact` rows: blank, as `single`
   today; the pitch column shows nothing there.
3. *(To check by eye.)* Same colour, different octave: o2 and o3 share
   a colour under `by-pitch`, so in a collapsed row only the note label
   tells them apart, and with `:note-label none` nothing does (the
   writer's choice). Check with the gangsa, which span two octaves.
4. *(To check by eye.)* Short notes: gangsa notes are a quarter-pulse
   wide, and a note label may not fit. This applies to labels today;
   nothing new is planned.
5. *(Settled.)* `:keys` and `:key-numbers` on `parts` and `compact`
   groups: an error on the group, ignored when they come from the
   score, as for `single` today ([what a note
   shows](2026-11-25-note-label.md)).

## Notes for promotion

- 01: `:rows notes/parts/compact`; `compact`'s rows; `single` removed;
  the rule "with `:rows single`, two notes may not fall in one cell"
  removed; `parts` and `compact` no longer need note labels ([what a
  note shows](2026-11-25-note-label.md)).
- 03: `notes-collide` keeps only its `notes`-rows case; reading
  `compact`; `single` is an unknown value.
- 04: "Groups and rows": `compact`'s row assignment; an event's `row`
  is its row.
- The JSON needs nothing new for this: a group's rows and an event's
  row describe any number of rows (renamed from `lanes`/`lane` in
  contract version 4, [glossary](2026-11-25-glossary.md)).
- A new ADR: `compact` replaces `single`, adds rows by key where parts
  collide; it narrows the decision that introduced `:rows single`.
- Code and tests: the reader's `single` check and its tests
  (`tests/reader.scm`); layout's `single` case becomes `compact` with
  row assignment (`tests/layout.scm`).
- Examples: Baris's `kendang-composite` changes `single` to `compact`;
  Jaya Semara's `full` score uses `parts` or `compact` for Jublag and
  the gong and kempli (the iteration's goal); golden files change.
- Manual: the page on rows (`scores.md`, `scores-rows.nts`);
  `mistakes/notes-collide.nts` shows the `single` case, which now
  draws: rewritten to show the `notes`-rows case.
- 08: the Emacs mode's completion and highlighting know `compact`, not
  `single`.
