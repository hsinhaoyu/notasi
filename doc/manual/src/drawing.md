# Drawing a score

Once your piece reads without errors, notasi can draw it as a score: a
grid with one row for each note an instrument plays and one column for
each step of time, as fine as the shortest note.

## What you need

- **Guile 3.0**, which runs notasi.
- **Typst 0.15.1**, which notasi uses to draw. Download it from
  <https://github.com/typst/typst/releases> and make sure the `typst`
  program is on your PATH.

## Draw a piece

Here is a short piece. Save it as `gilak.nts`:

```scheme
{{#include examples/drawing.nts}}
```

From the notasi folder, run:

```text
scripts/notasi render gilak.nts
```

notasi writes `gilak.pdf` next to `gilak.nts` and prints its name. If
you put the `scripts` folder on your PATH, you can type just
`notasi render gilak.nts` from any folder.

This is what you get:

![The piece above, drawn as a score](figures/drawing.svg)

## Reading the drawing

- The **title** is at the top.
- Each **group** is a block of rows, with its label on the left. Without
  a [score](scores.md), each part is a group of its own, labelled with
  its name. Each row is one note of the instrument, highest at the top,
  labelled with the note's name.
- Each **column** is one step of time: a whole pulse, or a part of one
  when the piece has shorter notes. The numbers along the top count
  pulses, within each gong cycle when the piece has one, and a thin line
  marks where each pulse begins. With a colotomy, a row above them
  numbers the cycles, and a heavier line marks where each cycle begins,
  just after the gong (see
  [Pulses and durations](pulses-and-durations.md)).
- A **note** is a coloured square in its row. A held note (`_`) is a
  longer block. Each pitch has its own colour, the same in every
  octave and on every instrument, so you can follow a melody by colour.
- **Gongs and drums** are grey squares. Their row labels say which
  stroke each row is.
- The **kempli** block is added by notasi, one stroke on every pulse
  (see [Gong cycles](gong-cycles.md)).

## PNG and SVG

To get a picture instead of a PDF, choose the file name with `-o`:

```text
scripts/notasi render gilak.nts -o gilak.png
scripts/notasi render gilak.nts -o gilak.svg
```

The ending of the name (`.pdf`, `.png` or `.svg`) chooses the kind of
file.

## When something goes wrong

If the piece has a mistake, notasi prints the same messages as in
[Error messages](errors.md) and draws nothing. Fix the mistake and run
it again.

If Typst isn't installed, notasi says so and tells you where to get it.
