# Design idea: octave numbers on lane labels, and a line after the labels

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## What a system shows now

From left to right: the group label (`Ugal`, `U.`), the lane labels
(`a1 i2 o2 e2 u2`, bottom to top), then the grid of notes (see
`build/preview/gilak.full.png`). Lane labels are the display form
followed by the octave number, in small grey text (04-layout, "Lane
labels"; `note-label`). Stroke lanes show the stroke's display form
(`G`, `GL`, `P`).

## 1. An option to hide the octave number

The octave number is useful, especially on instruments that span two
or more octaves, but not always wanted: a melody inside one octave
reads more cleanly as `a i o e u`.

Agreed:

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:octave-numbers yes/no` | score, group | `yes` | Write the octave number after each lane label (`i2`), or the display form alone (`i`). |

- Named to match `:pulse-numbers` and `:cycle-numbers`.
- The default keeps today's drawing.
- It changes lane labels only. Names written in the cells
  (`:note-names`) already have no octave number.
- It has no effect on stroke lanes (no octaves) or on `:rows parts`
  and `single` (their labels are row labels).

Open:

- An instrument whose lanes in the score repeat a degree in two
  octaves (the ugal's `o1` and `o2`) gets two lanes labelled `o` with
  `no`. Allow it (position and colour still tell them apart), or warn?
  Leaning: allow.

## 2. A vertical line between the labels and the notes

Each system's `lines` (one per column, for the line at its left edge)
starts with `none`, so nothing separates the lane labels from the
first column. This also hides the heavier cycle line where a system
starts on a new cycle (systems 2–4 of `gilak_full`).

This was decided in iteration 2: 04-layout, slice 2, says "The line
at a system's first column is always `none`: its left edge is the edge
of the grid". The change below reverses that drawing choice.

Agreed:

- A vertical line at the left edge of the grid, between the lane
  labels and the first column, in every system.
- Drawn like the horizontal lines between groups: 0.8pt, `luma(120)`
  in `typst/notasi.typ`. With those, it frames the grid.

Open:

- How far it runs: the groups only (from the first group line to the
  last), or up through the cycle and pulse number rows too. Leaning:
  groups only, like the horizontal lines.
- Whether it is drawn by the template alone (it doesn't depend on the
  music) or comes from the figure as a new `lines` value. ADR 0036 says
  the template does no counting, but a fixed frame line isn't counting.
  Leaning: the template draws it; `lines[0]` stays as it is.
- Same line for `:rows parts` and `single`, whose row labels sit in
  the same column. Leaning: yes.

## Notes for promotion

- 01-notation: the new option in the "Above the grid / In the grid"
  tables. 04-layout: "Lane labels"; the group's settings (ADR 0033) and
  the JSON lane labels. 05-typst-backend: the frame line.
- Golden JSON is unchanged for `:octave-numbers yes`; every drawing
  gains the line.
- The manual's page on scores (options table) and its figures.
