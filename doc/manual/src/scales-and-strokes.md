# Scales and stroke sets

Before you can write for an instrument, notasi needs to know the names
of its notes. Pitched instruments take theirs from a **scale**. Gongs,
drums and the kempli take theirs from a **stroke set**.

## Scales

A scale names its degrees, lowest first, within one octave:

```scheme
{{#include ../../../examples/manual/selisir-scale.nts}}
```

- `selisir` is the scale's name. Instruments refer to it by that name.
- `ding`, `dong`, `deng`, `dung` and `dang` are the degrees, lowest
  first.
- `:alias i` gives a degree a second name. You can then write `i2`
  instead of `ding2`, and notasi treats them as the same note.

A degree can be just its name (`ding`), or its name in round brackets
followed by settings, each a name starting with `:` and its value:
`(ding :alias i)`. A degree can have several aliases:
`(ding :alias (i nding))`.

## Stroke sets

A stroke set names the strokes of an unpitched instrument. Strokes have
no octave and no order:

```scheme
{{#include ../../../examples/manual/stroke-sets.nts}}
```

`:display "D"` sets how a stroke or degree is shown in the score's row
labels and, with `:note-names yes`, in its squares. Without it, notasi
shows the name itself.

`:damped "na'"` gives a second name, for a note that is cut short: a
score shows it for a note that lasts one column, and the usual name for
a longer one (see [Scores](scores.md#rows-of-names)).

## The rules

- Each name or alias is used once within a scale or stroke set.
- A scale degree's name and aliases must not end in a digit, because
  the digit at the end of `ding2` is the octave. Stroke names may end
  in a digit.
- A scale and a stroke set can't share a name.

Next, use them to define [instruments](instruments.md). The full
rules are in the
[notation reference](https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md).
