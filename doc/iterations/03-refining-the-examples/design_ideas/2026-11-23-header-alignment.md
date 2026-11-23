# Design idea: cycle and pulse numbers are centred over their pulse

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## The problem

The cycle number and the pulse number under it don't line up. In
`typst/notasi.typ` (`_system`):

- a cycle mark is drawn `align: left + horizon, inset: (left: 2pt)`:
  left-aligned in its column;
- a pulse number is drawn `align: center + horizon`: centred in its
  column.

Both are in the first column of their pulse, so the cycle `1` sits a
little left of the pulse `1` below it.

With sub-pulse steps (`steps_per_pulse` > 1, e.g. Jaya Semara's quarter
pulses) a pulse spans several columns, but its number is centred in the
first one only, over the first quarter, not over the pulse. The other
columns show a grey `·`.

## Agreed (2026-11-23)

- Both numbers are centred over the whole pulse: the pulse number over
  its pulse's columns, the cycle number over the first pulse of its
  cycle. They line up, and with quarter pulses the number sits over the
  middle of the pulse.

## Open

- The grey `·` in the other columns of a pulse. A number centred over
  the whole pulse covers the space where they are drawn. Drop them, or
  keep a tick per step some other way? Leaning: drop them; the lines
  already show the steps.
- An excerpt or system that starts or ends partway through a pulse
  can't happen today (positions are whole pulses), so every pulse in a
  system is whole. Keep it that way, or centre over the part that is
  shown.

## Notes for promotion

- The JSON already has what's needed: `header.pulses` (a number at the
  first column of each pulse, `null` elsewhere), `header.cycles`
  (`column`) and `steps_per_pulse`. The template can span
  `steps_per_pulse` columns from each number. No contract change,
  unless we'd rather layout send the span.
- 05-typst-backend: the header drawing. 04-layout: what `null` entries
  in `header.pulses` mean if the `·` goes.
- Golden JSON unchanged; every drawing changes slightly.
