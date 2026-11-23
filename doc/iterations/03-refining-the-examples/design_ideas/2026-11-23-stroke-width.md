# Design idea: strokes are drawn one column wide

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## The problem

A stroke on an unpitched instrument is drawn as wide as its written
duration, like a pitched note. In `examples/jaya-semara.nts` the score's
step is a quarter pulse (the kotekan), so the gong's `P:1`, `T:1`, `G:1`
and every kempli `K` are four columns wide, and the kempli row is one
unbroken grey bar. In `gilak` the step is a pulse, so it doesn't show.

For gongs, kempli and drums the written duration mostly places the next
stroke; what matters to the reader is where each stroke falls. Gongs are
never damped (Gold), so the length of a gong box says nothing anyway.

## Agreed (2026-11-23)

- In the drawing, every stroke on a stroke instrument (any instrument
  with a stroke set: gong, kempli, kendang) is **one column wide**, the
  score's step, starting where it starts now.
- Only the drawing changes. The music keeps its durations (`-:3 P:1`
  still puts the kempur on pulse 4, and a later player still has them).
- "One column" was chosen over "the shortest note in the piece" or "in
  the score": it is always the smallest cell of the drawing, so a
  stroke reads as a point, and it is simple to predict. In most scores
  they are the same; they differ when the grid is finer than any note
  (mixed triplets and quarters give a 1/12 step) or an excerpt has a
  coarser grid than the piece.
- Pitched instruments are unchanged: a note is as wide as it sounds.

## Open

- With `:note-names yes` the stroke's name is written in its one
  column, not centred over the old duration. Check Tenzer's Baris
  (`baris.nts`, `:rows parts`, `:cell-width "3em"`) still matches the
  source, where the step is a pulse anyway.
- `:holds dash` writes `-` in every step a note is held. For strokes,
  is the time after a stroke "held"? Leaning: no dashes after strokes;
  only pitched notes are held. Check the kendang composite score.
- Name shown for a stroke lasting one column: the damped form
  (`:damped`) is chosen when a note lasts no longer than one column.
  Should that test use the written duration (as now) or the drawn one
  (always one column, so always damped)? Leaning: the written duration,
  so `du` and `du'` still differ.
- An option to turn it off (draw strokes at their durations)? Leaning:
  not until someone needs it.

## Notes for promotion

- 04-layout, "Groups and rows" / events: a stroke event's `dur` is 1
  column. 02-piece unchanged.
- Golden JSON for every score with gongs, kempli or kendang changes.
- Manual, "Drawing": "Gongs and drums are grey squares", with the new
  width; figures change.

## Settled (2026-11-23)

The open questions above, answered before promotion:

- No dashes after strokes with `:holds dash`; only pitched notes are
  held.
- The damped form is chosen by the written duration, so `du` and `du'`
  still differ.
- No option to turn it off.
- Tenzer's Baris is checked by eye that it still matches the source.
