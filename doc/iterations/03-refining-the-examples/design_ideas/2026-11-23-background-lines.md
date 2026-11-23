# Design idea: choosing the lines behind the notes

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## Now

Behind the notes a system draws:

- vertical lines: thin at each pulse, heavier where a cycle starts
  (ADR 0037; `lines` in the JSON, `_line` in `typst/notasi.typ`);
- horizontal lines between groups only (0.8pt, `luma(120)`), none
  between the rows of a group.

There's no way to change this.

## Agreed (2026-11-23)

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:background grid` | score, group | `grid` | Pulse lines and a line between every two rows. |
| `:background vertical` | score, group | | Pulse lines only (today's look). |
| `:background horizontal` | score, group | | Row lines only. |
| `:background empty` | score, group | | Neither. |

- **Row lines** are new: a thin line between each two rows (lanes) of a
  group, drawn like a pulse line (0.5pt, `luma(170)`).
- **Always drawn, whatever the setting:** the lines between groups, and
  the heavier cycle lines (where a cycle starts). Only pulse lines and
  row lines are switched. So `empty` still shows the groups and the
  cycles.
- **The default becomes `grid`.** Every drawing gains row lines.

## Open

- Group level: vertical lines run through the whole system. With
  different settings per group, each group's block gets its own
  vertical lines (Typst's grid stroke can depend on the row). Leaning:
  allow it; the score sets the default.
- Row lines with `:rows parts` and `single`: same rule (a line between
  parts' rows). Leaning: yes.
- The name: `:background` vs `:lines`. `:background` was the word used
  in discussion, but they are lines; `:lines` would clash with the
  JSON's `lines` (per column). Leaning: `:background`.
- With grey note borders (`2026-11-23-note-border.md`) and the frame
  line after the labels (`2026-11-23-lane-labels.md`), check by eye that
  `grid` doesn't get busy.

## Notes for promotion

- 01-notation, "In the grid": the option. 04-layout: the group's
  setting (ADR 0033) and how the JSON tells the template which lines to
  draw: either `lines` already reflects the setting (`none` where pulse
  lines are off) and a group carries `row_lines: true/false`, or the
  template is told the setting. Leaning: layout decides (ADR 0005,
  Guile decides, Typst draws), so the JSON changes: contract version.
- 05-typst-backend: drawing row lines.
- Golden JSON and every figure change, since the default draws row
  lines.

## Settled (2026-11-23)

The open questions above, answered before promotion:

- `:background` is allowed on a group; the score sets the default, and
  each group's block gets its own vertical lines.
- Row lines are drawn between the rows of `:rows parts` and `single`
  groups too.
- The name is `:background`.
- Whether `grid` gets busy with grey note borders and the frame line is
  judged by eye with `make preview` while building.
