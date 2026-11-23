# Design idea: a pickup on a system of its own

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## The problem

`examples/gilak.nts` has `:pickup 1` and its score `full` has
`:breaks ((1 1) (2 1) (3 1))`. Drawn, it has four systems: the pickup
alone (one column, numbered `8`), then cycles 1, 2 and 3.

The pickup's system has no cycle number. Cycle numbers are printed only
where a cycle starts (`cycle-start?` in `notasi/layout.scm` skips times
before the pickup ends), so the reader sees a lone `8` with nothing
above it, while every other system has its cycle number.

This was decided in iteration 2: 04-layout, slice 2, says "the pickup
has no mark". The change below reverses that.

## Agreed (2026-11-23)

- **The pickup does not join the first system by default.** Systems
  stay where `:breaks` and `:system-length` put them. A score that
  wants the pickup on the first cycle's line leaves out the `(1 1)`
  break. No change.
- **A pickup on a system of its own shows cycle number `0`** above its
  first column, where other systems show theirs. The pickup is cycle 0
  everywhere else (positions, error messages, `:from (0 8)`), so the
  drawing agrees.

## Open

- A pickup at the start of a longer system (no `(1 1)` break): does it
  get a `0` too, or only the `1` over cycle 1's first pulse, as now?
  The agreement covers only a pickup on its own system.
- With `:numbering gong-first`, the pickup is the gong and is numbered
  `1`. The cycle number is still `0`.
- A score excerpt that starts inside the pickup (`:from (0 8)`) gets the
  same `0`.

## Notes for promotion

- 04-layout, "Header and lines": the cycle number rule.
- Golden JSON for `gilak_full` changes (the header's `cycles`).
- The manual's gong-cycles page describes the numbering: "the pickup
  as the last pulse of cycle 0".

## Settled (2026-11-23)

The open questions above, answered before promotion:

- A pickup at the start of a longer system (no `(1 1)` break) also gets
  cycle number `0`: wherever a pickup is shown, it is cycle 0.
- With `:numbering gong-first` the pickup is numbered pulse `1`, cycle
  `0`; an excerpt starting inside the pickup also shows `0` (as the
  Open section says).
