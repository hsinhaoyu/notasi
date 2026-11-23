# Notes, rests and holds

A **part** is the line of music one player plays. It names the
instrument, then gives the music, note by note. Here two parts
play the ugal, so each also has a name, given with `:name` (see
[Several parts on one instrument](parts.md)):

```scheme
{{#include examples/notes-by-name-and-number.nts}}
```

Both parts play the same melody. A note can be written two ways:

- **by name**: `a1` (dang1), using the scale's names or aliases, with
  the octave
- **by number**: `4`, the instrument's fourth note, counting from its
  lowest

For a gong or drum, a note is one of its strokes, such as `G`, or its
number.

## Rests and holds

Not every pulse strikes a new note:

```scheme
{{#include examples/holds-and-rests.nts}}
```

| You write | It means |
|---|---|
| a note | Strike that note. It lasts one pulse, or the length you give it (see [Pulses and durations](pulses-and-durations.md)). |
| `_` | Hold: the note before keeps sounding for as long again. |
| `-` | Rest: silence for as long as a note. The note before is damped. |
| `/` | Nothing: a separator to make the line easier to read. It takes no time. |
| `\|` | A pulse check: it takes no time, and must fall at the start of a pulse. |

So in the example, `a1` sounds for pulses 1 to 3, pulse 4 is silent,
`i2` sounds for pulses 5 and 6, and `o2` for pulse 7.

Use `/` to mark the pulses or the halves of a phrase, so you can check
the line by eye. A note can be held across a `/`.

## The rules

- `_` must follow a note (or another `_`). A part can't start with `_`,
  and a rest can't be held.
- **Every part lasts the same number of pulses.** Count notes, `_` and
  `-` at their lengths; `/` and `|` take no time. If the gong only plays at the start, fill the
  rest of its line with `-`.
- A full stop `.` can't be used for a rest; write `-`.

Next: playing two notes at once, with [chords](chords.md).
