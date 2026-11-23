# Design idea: choosing which keys a group shows

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## The problem

With `:rows notes` (the default), a group has one row (lane) per key.
Lanes are only the keys the group actually plays in the score's range
(04-layout, "Groups and rows"). The ugal has ten keys (`o1` … `i3`),
but `gilak_full` shows five (`a1 i2 o2 e2 u2`), and an excerpt may show
fewer still.

That keeps scores small, but the reader can't see where the melody sits
on the instrument, two scores of the same part can have different rows,
and an excerpt's rows change with what happens to be played in it.

## Agreed (2026-11-23)

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:keys used` | score, group | `used` | One row per key played in the score's range, as now. |
| `:keys all` | score, group | | One row per key of the instrument. |
| `:keys (LOW HIGH)` | score, group | | One row per key from LOW up to HIGH, both included: `:keys (a1 u2)`. |

- The word is "keys", as the manual already says ("key 5", "the
  instrument's keys").
- LOW and HIGH are notes of the group's instrument, written as in a
  part (`a1`, `dang1`), LOW not above HIGH. Anything else is an error
  at the score's line.
- A group's pitched parts are all on one instrument (ADR 0011), so the
  keys are always one instrument's.
- **A note outside the range is an error**, not silently added or
  dropped: the message names the part, the note, its position and the
  range, e.g. "part `ugal`, cycle 2, pulse 3: `a2` is outside the keys
  shown, `a1` to `u2` (:keys)".
- Rows stay highest at the top, as now.

## Open

- Stroke groups (gong, kempli, kendang). `all` is clear: every stroke
  of the instrument(s), in instrument order. A range of strokes is not
  (strokes have no pitch). Leaning: `used` and `all` only; a range is
  an error on a stroke group.
- `:rows parts` and `single` have no key rows. Leaning: `:keys` there is
  an error, or ignored when inherited from the score.
- Default stays `used`? Agreed for now (today's drawings don't change);
  revisit after seeing `all` on the examples.

## Notes for promotion

- 01-notation, "In the grid": the option. 04-layout, "Groups and rows":
  how lanes are chosen (`group-lanes`). 02-piece: the group's settings
  (ADR 0033).
- Where the outside-the-range check runs: it needs the expanded parts
  and the score's range, so in layout or a score check after
  expansion, like `notes-collide`.
- JSON: unchanged in shape (`lanes` is already a list).
- Manual: the scores page, and the errors page for the new message.
