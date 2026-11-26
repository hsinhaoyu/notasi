# Pulses and durations

notasi counts time in **pulses**. A pulse is one stroke of the kempli
(or kajar): the steady beat that everyone feels.

Each note lasts one pulse unless you say otherwise. To give a note
another length, write it after a colon:

```scheme
{{#include ../../../examples/manual/durations.nts}}
```

- The ugal plays one note to each pulse, so it needs no lengths.
- The reyong plays four notes to each pulse. `i3:1/4` is a quarter of a
  pulse, and the notes after it are quarter pulses too: **a length
  carries on** until you write another.
- The gong strikes once, `G:1`, and then rests for three pulses with
  `-:3`.

A length is a whole number of pulses (`2`) or a fraction (`1/4`,
`1/2`, `3/2`). It goes after a key (`i2:1/4`), a key number
(`5:1/4`) or a rest (`-:3`). A hold `_` lasts as long as the note
before it, at the current length.

## Checking the pulses with `|`

`|` marks where a pulse begins. It takes no time; notasi checks that it
really falls at the start of a pulse, and tells you if it doesn't. In
the reyong part above, each `|` comes after four quarter pulses. If a
note were missing, notasi would say where the line drifted.

## In the drawing

notasi draws the score on a grid fine enough for the shortest note:
with quarter pulses, each pulse has four columns. The numbers along the
top count pulses (see [Drawing a score](drawing.md)).

## The rules

- A length is written straight after the note, with no spaces:
  `i2:1/4`, not `i2 :1/4`.
- A length is above zero, and written in digits: `2`, `1/4`. Words
  (`four`) and decimals (`0.5`) aren't allowed.
- `_` and `/` take no length of their own.
- Every part lasts the same number of pulses.

The full rules are in the
[notation reference](https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md).
