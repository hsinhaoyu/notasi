# Design idea: key numbers beside the row labels, and row labels that can be hidden

Status: agreed in discussion (2026-11-23); see "Settled". Not the
design until promoted.

## Now

From left to right a system shows: the group label (`Ugal`), a narrow
column of row labels, one per row (the note's name, `a1 i2 o2 e2 u2`,
or with `:rows parts` the part's label), then the grid. There is no way
to see a key's number, and no way to hide the row labels.

A key's number is its place on the instrument, counted from 1, the same
number a part can use instead of the note's name (01, "Tokens": `5`
strikes key 5). On the ugal (`o1 … i3`), `a1` is key 4.

## The idea

- **Key numbers, optional, off by default.** A new narrow column of
  numbers, one per row, to the left of the row labels: each row's key
  number on its instrument. With it on, a row reads `4  a1`.
- **Row labels, optional, on by default.** The column of note names can
  be turned off.

Both are score or group options, like `:octave-numbers`.

## Proposed

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:key-numbers yes/no` | score, group | `no` | A column of key numbers to the left of the row labels: each row's key on its instrument, from 1. |
| `:row-labels yes/no` | score, group | `yes` | The column of row labels (note names, stroke names or parts' labels). |

- The name `:row-labels` is chosen over `:note-names`, which already
  means the names written in the cells.
- A group whose two columns are both off shows its group label next to
  the grid. The frame line (ADR 0044) stays at the grid's edge.
- With `:keys used` the numbers skip the keys that aren't shown
  (`2 4 5 7`); with `:keys all` they run 1 to N.

## Open

1. **Strokes.** A stroke instrument's strokes are numbered too, in the
   instrument's order (`G` 1, `GL` 2, `P` 3, `T` 4 on the template's
   gong), and a part can write a stroke by its number. Show them, or
   number pitched keys only? Leaning: show them; the rule is the same.
2. **`:rows parts` and `single`.** Their rows are parts, not keys, so
   they have no key numbers. As with `:keys`: `:key-numbers yes` written
   on such a group is an error, and ignored when it comes from the
   score. Leaning: yes. `:row-labels no` does apply to them.
3. **Group label without row labels.** With `:row-labels no`, should the
   width of the row-label column disappear (the group label moves next
   to the key numbers or the grid), or stay as an empty column so
   systems line up? Leaning: disappear; all systems of one score use the
   same widths anyway.
4. **Look.** Key numbers small and grey like the row labels, or lighter
   still, so they read as secondary? Starting point: the same size, a
   lighter grey (`luma(170)`), right-aligned; judged by eye.
5. **Two instruments in one stroke group.** Each stroke's number is on
   its own instrument, so two rows can both read `1` (kendang lanang's
   `pak` and kendang wadon's `kap`). Accept it? Leaning: yes; the row
   labels tell them apart, and with `:row-labels no` the colours and
   groups do.

## Notes for promotion

- 01-notation, "In the grid": the two options and their rules.
- 02-piece: the group's settings (ADR 0033), `key-numbers?` and
  `row-labels?`.
- 03-reader: `bad-option` for bad values, and for `:key-numbers` on a
  `parts` or `single` group.
- 04-layout: each group's key numbers (from the note index), and the
  sizes: a new column width, `key_width` (0 when no group shows them),
  and `lane_width` 0 when no group shows row labels. Contract version 3
  is not built yet, so it can carry the new fields (`keys` per group,
  `key_width` in `sizes`), with a new ADR that adds them to ADR 0043's
  version 3.
- 05-typst-backend: the new column, its look, and the columns that can
  be empty.
- Manual: the scores page.

## Settled (2026-11-23)

The open questions above, answered:

1. **Pitched keys only.** Strokes have no key numbers: a group of gongs,
   kempli or drums shows none.
2. As with `:keys`: `:key-numbers yes` written on a `:rows parts` or
   `single` group is an error, and ignored when it comes from the
   score. `:row-labels no` applies to every kind of group.
3. With `:row-labels no` the column disappears; the group label sits
   next to the key numbers or the grid.
4. The same size as the row labels, a lighter grey (`luma(170)`),
   right-aligned; judged by eye.
5. Does not arise: drums and other stroke instruments have no key
   numbers (1). Following 2, `:key-numbers yes` written on a stroke
   group is an error, and ignored when it comes from the score.
