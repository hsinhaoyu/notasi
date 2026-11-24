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
  when the piece has shorter notes. The numbers along the top, in the
  row labelled "Pulse", count pulses, within each gong cycle when the
  piece has one; each number sits over the middle of its pulse, and a
  thin line marks where each pulse begins. With a colotomy, a row above
  them, labelled "Cycle", numbers the cycles (the pickup is `0`), and a
  heavier line marks where each cycle begins,
  just after the gong (see
  [Pulses and durations](pulses-and-durations.md)).
- A **note** is a coloured square in its row, with a thin grey edge. A
  held note (`_`) is a longer block. Each pitch has its own colour, the
  same in every octave and on every instrument, so you can follow a
  melody by colour.
- Thin lines run between the rows, and a darker line separates the row
  labels from the music. A score can choose which lines it draws (see
  `:background` in [Scores](scores.md)).
- **Gongs and drums** are light grey squares, one column wide wherever
  they fall: a stroke marks a moment. Their row labels say which
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

## Choosing a score

When a file has several [scores](scores.md#several-scores), notasi draws
the first. To draw another, name it with `--score`:

```text
scripts/notasi render gilak.nts --score second
```

This writes `gilak_second.pdf`.

Standalone drawings use a plain sans-serif font found on your computer
(Helvetica, Arial, DejaVu Sans or Liberation Sans), so they may look a
little different from one computer to another.

## When something goes wrong

If the piece has a mistake, notasi prints the same messages as in
[Error messages](errors.md) and draws nothing. Fix the mistake and run
it again.

If Typst isn't installed, notasi says so and tells you where to get it.
