# Design idea: notes have a grey border

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## Now

Each note is a rectangle filling its cells, in its colour, with a thin
white border (ADR 0020; `_note` in `typst/notasi.typ`:
`stroke: 0.5pt + white`). The white border keeps neighbouring notes
apart, so repeated strokes don't merge into what looks like one held
note. Against the white background, though, a note has no edge: pale
pastel notes are hard to see, and a note's size is hard to judge.

## Agreed (2026-11-23)

- Each note's rectangle has a **grey border** instead of a white one.
- It still keeps neighbouring notes apart (the purpose in ADR 0020), and
  now also outlines each note against the background.
- Notes still fill their cells exactly, with no margin (ADR 0020).
- **Every edge has the same weight**, between two notes as at the
  outside of a note. (Agreed later the same day.) How: each border is
  centred on its rectangle's edge, as Typst draws a stroke by default,
  and touching rectangles share the edge exactly, so the two borders
  there fall on the same line and show as one. A border drawn wholly
  inside each rectangle would not do it: two touching notes would show
  two lines side by side, twice as heavy as the outside edges.
- **Stroke cells are a lighter grey** than now, so the grey border
  shows against them. Today strokes are filled `#cccccc`
  (`stroke-grey` in `notasi/style.scm`, 04-layout "Note style"); the
  new grey is lighter, e.g. `#e6e6e6`, to be judged by eye. Text on
  them stays near-black (`text-color-for`). (Agreed later the same
  day.)

## Open

- Which grey and how thick. Starting point: 0.5pt, a mid grey a little
  lighter than the group lines (`luma(120)`), e.g. `luma(150)`; judged
  by eye on `make preview`.
- A note cut across two systems: border on all four sides of each
  piece, or no border on the cut edge, to show it continues? ADR 0020
  says a continuation is shown only by having no text. Leaning: keep
  that; border all round.
- Centred borders reach half their width outside the note, over the
  pulse line or a neighbouring empty cell. Check by eye that this
  doesn't blur the pulse lines.
- The exact stroke grey. It must stay clearly grey, not white, and not
  match any palette colour a degree could get (`pastel1`'s ninth colour
  is `#f2f2f2`; `pastel2`'s eighth is today's `#cccccc`).
- Notes with `:fill none` (names only) have no rectangle and no border.
- Should the colour be an option (`:note-border`)? Leaning: no.

## Notes for promotion

- New ADR: changes ADR 0020's "thin white border"; the rest of 0020
  stands. The stroke grey is from ADRs 0019 and 0021; the ADR says it
  changes.
- 05-typst-backend (the note's drawing). The border is the
  template's, but the stroke grey is layout's (`fill` in the JSON), so
  golden files with strokes change. 04-layout, "Note style".
- Manual: every figure changes; the drawing page if it describes the
  white border.
