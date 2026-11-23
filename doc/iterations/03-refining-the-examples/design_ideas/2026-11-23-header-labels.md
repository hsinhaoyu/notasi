# Design idea: the cycle and pulse rows are labelled

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## The problem

Above the groups a score prints up to two rows of numbers: the cycle
number (`:cycle-numbers`, once above the first pulse of each cycle) and
the pulse number within the cycle (`:pulse-numbers`). In
`examples/gilak.nts` neither row has a label, so a reader has to guess
what `1` above `1 2 3 … 8` means.

Today only the pulse row can be labelled, with `:pulse-label STRING`
(score level, no default); `header.label` in the JSON carries it. The
cycle row can't be labelled at all.

## Agreed (2026-11-23)

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:cycle-label STRING` | score | `"Cycle"` | The label at the left of the cycle-number row. |
| `:pulse-label STRING` | score | `"Pulse"` | The label at the left of the pulse-number row. Now has a default. |

- Both rows are labelled by default, with the words notasi uses
  everywhere else (positions, error messages, the manual).
- `""` removes a label.
- A label is printed only when its row is: no `Cycle` with
  `:cycle-numbers no`, or without a colotomy.
- With `:numbering gong-first` the labels don't change; only the
  numbers do.

## Open

- Long and short forms, like group labels (`:labels first-long`):
  `Cycle`/`Pulse` on the first system, something shorter after?
  Leaning: no; the words are short, and one form keeps it simple.
- Where the labels sit: in the group-label column, the lane-label
  column, or right-aligned against the grid. Today's `:pulse-label`
  placement is the starting point.

## Consequences

- Every score with a colotomy gains two labels by default, so every
  golden file and figure changes.
- `examples/baris.nts` (Tenzer's layout) sets `:pulse-label "Beats"`
  and shows cycle numbers; it would now also print `Cycle`. If Tenzer's
  page has no cycle label, the file sets `:cycle-label ""` (check
  against the source).

## Notes for promotion

- 01-notation, "Above the grid": the new option and the new default.
  04-layout: `header` gains the cycle label (`header.label` becomes
  two fields, e.g. `cycle_label` and `pulse_label`), so the JSON
  contract changes (ADR 0036, version 2 → 3).
- 05-typst-backend: drawing the second label.
- Manual: the scores page options table, and the figures.
