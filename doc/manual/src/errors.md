# Error messages

When notasi can't read a file, it stops at the first problem and tells
you where it is and what is wrong:

```text
{{#include mistakes/not-a-number.txt}}
```

This says: in the file `not-a-number.nts`, on line 4, in the part
`ugal` at pulse 1, the length `four` is not a number.

Fix that one problem and try again. If there is another, notasi will
tell you about it next.

## The piece needs a title

```scheme
{{#include mistakes/no-title.nts}}
```

```text
{{#include mistakes/no-title.txt}}
```

The title must be in double quotes: `(piece "Gilak")`.

## Unknown form

```scheme
{{#include mistakes/misspelt-form.nts}}
```

```text
{{#include mistakes/misspelt-form.txt}}
```

The first word inside each pair of brackets says what the line is.
notasi doesn't know `pice`; check the spelling.

## Unknown piece option

```scheme
{{#include mistakes/unknown-option.nts}}
```

```text
{{#include mistakes/unknown-option.txt}}
```

The `piece` line takes no settings yet, only its title. Check for a
stray word starting with `:`.

## A length that isn't a number

```scheme
{{#include mistakes/not-a-number.nts}}
```

```text
{{#include mistakes/not-a-number.txt}}
```

Write a length in digits, as a whole number or a fraction above zero:
`dang1:4`, `dang1:1/4` (see [Pulses and durations](pulses-and-durations.md)).

## Missing bracket

```scheme
{{#include mistakes/missing-bracket.nts}}
```

```text
{{#include mistakes/missing-bracket.txt}}
```

Every `(` needs a matching `)`. Here the `piece` line is never closed,
so notasi reaches the end of the file still looking for the `)`. The
line number points to where it gave up, at the end of the file. The
missing bracket is somewhere before that.

## Not supported yet

```scheme
{{#include mistakes/not-yet.nts}}
```

```text
{{#include mistakes/not-yet.txt}}
```

A few settings in the notation reference, such as a score's
`:font-size`, aren't ready yet. Everything in this manual works.

## Mistakes in scales and instruments

### No scale with that name

```scheme
{{#include mistakes/undefined-scale.nts}}
```

```text
{{#include mistakes/undefined-scale.txt}}
```

The instrument names a scale that isn't defined. Here `selisir` is
misspelt.

### Not a note of the scale

```scheme
{{#include mistakes/wrong-note-name.nts}}
```

```text
{{#include mistakes/wrong-note-name.txt}}
```

Each note must be a degree (or alias) of the instrument's scale. Here
`dang1` is misspelt.

### No octave number

```scheme
{{#include mistakes/missing-octave.nts}}
```

```text
{{#include mistakes/missing-octave.txt}}
```

Notes on a pitched instrument need an octave: write `dong1`, not `dong`.

### Notes out of order

```scheme
{{#include mistakes/notes-out-of-order.nts}}
```

```text
{{#include mistakes/notes-out-of-order.txt}}
```

List an instrument's notes from lowest to highest, in the order of the
scale: `ding1 dong1 deng1`.

## Mistakes in parts

### Hold after a rest

```scheme
{{#include mistakes/hold-after-rest.nts}}
```

```text
{{#include mistakes/hold-after-rest.txt}}
```

`_` holds the note before it, so it can't come after a rest or at the
start of a part. The pulse number counts from the start of the part,
from 1.

### Note number too high

```scheme
{{#include mistakes/note-out-of-range.nts}}
```

```text
{{#include mistakes/note-out-of-range.txt}}
```

Numbers count the instrument's notes from its lowest, starting at 1.
This ugal has five keys, so 6 is too high.

### Note not on the instrument

```scheme
{{#include mistakes/note-not-on-instrument.nts}}
```

```text
{{#include mistakes/note-not-on-instrument.txt}}
```

`dong2` is a note of the scale, but this ugal stops at ding2. Check the
instrument's range, or the octave.

### Parts of different lengths

```scheme
{{#include mistakes/unequal-length.nts}}
```

```text
{{#include mistakes/unequal-length.txt}}
```

Every part lasts the same number of pulses. Count the notes, `_` and
`-` in each at their lengths (not `/` or `|`), and add rests to the
shorter part.

### A repeat without its number

```scheme
{{#include mistakes/bad-rep.nts}}
```

```text
{{#include mistakes/bad-rep.txt}}
```

A `rep` needs the number of times first, then the notes:
`(rep 2 dang1 ding2)`. The line is the line of the `rep` itself.

### A cycle check out of place

```scheme
{{#include mistakes/cycle-check.nts}}
```

```text
{{#include mistakes/cycle-check.txt}}
```

`||` must fall at the end of a gong cycle. Here the cycle has eight
pulses, but the first `||` comes after four. Move it, or check the notes
before it (see [Gong cycles](gong-cycles.md)).

### A piece that isn't whole cycles

```scheme
{{#include mistakes/incomplete-cycle.nts}}
```

```text
{{#include mistakes/incomplete-cycle.txt}}
```

With a colotomy, a piece is its pickup plus whole cycles. This ugal part
lasts 7 pulses, one short of the eight-pulse cycle.

### A pattern that doesn't exist

```scheme
{{#include mistakes/undefined-pattern.nts}}
```

```text
{{#include mistakes/undefined-pattern.txt}}
```

Check the spelling after the `@` (see [Patterns](patterns.md)).

### A pattern for another instrument

```scheme
{{#include mistakes/wrong-instrument.nts}}
```

```text
{{#include mistakes/wrong-instrument.txt}}
```

A pattern can only be played on the instrument named by its
`:instrument`. Write another pattern for this instrument.

### A pulse check out of place

```scheme
{{#include mistakes/pulse-check.nts}}
```

```text
{{#include mistakes/pulse-check.txt}}
```

`|` must fall at the start of a pulse. Here half a pulse and two whole
pulses come before it, so it falls at pulse 2½. A note is too long or
too short, or one is missing, somewhere before the `|`.

### Two parts on one instrument

```scheme
{{#include mistakes/parts-need-names.nts}}
```

```text
{{#include mistakes/parts-need-names.txt}}
```

When an instrument has two parts, give each a name with `:name`, as in
`(part reyong :name sangsih 4 3 2 1)` (see
[Several parts on one instrument](parts.md)).

### A setting after the music

```scheme
{{#include mistakes/option-after-music.nts}}
```

```text
{{#include mistakes/option-after-music.txt}}
```

Settings such as `:name` come right after the instrument, before the
first note: `(part ugal :name melody 1 2 3 4)`.

## Mistakes with templates

### No template with that name

```scheme
{{#include mistakes/template-not-found.nts}}
```

```text
{{#include mistakes/template-not-found.txt}}
```

Check the spelling: here it should be `gong-kebyar`. A name in double
quotes is a file, looked up from the folder of the piece.

### `use` too late

```scheme
{{#include mistakes/use-not-first.nts}}
```

```text
{{#include mistakes/use-not-first.txt}}
```

Move the `use` line up, right after the `piece` line.

### Two templates define the same name

```scheme
{{#include mistakes/template-conflict.nts}}
```

```scheme
{{#include mistakes/templates/my-reyong.nts}}
```

```scheme
{{#include mistakes/templates/my-ugal.nts}}
```

```text
{{#include mistakes/template-conflict.txt}}
```

Both templates have a `ugal`, and notasi can't tell which one you
mean. Remove it from one of them, or define `ugal` in the piece itself:
the piece's own definition replaces both.

### Music in a template

```scheme
{{#include mistakes/part-in-template.nts}}
```

```scheme
{{#include mistakes/templates/with-a-part.nts}}
```

```text
{{#include mistakes/part-in-template.txt}}
```

A template holds only `scale`, `strokes`, `instrument` and `use` lines.
Put the `part` in the piece.

## Other messages

- **no (piece TITLE ...) form**: the file has no `piece` line. Add one
  at the top.
- **the (piece ...) form must come first**: move the `piece` line above
  everything else.
- **a second (piece ...) form**: a file holds one piece. Remove the
  extra `piece` line, or put the second piece in its own file.
- **option … given twice**: remove one of the two settings.
- **… is already defined in this file**: two scales, stroke sets,
  instruments or parts have the same name. Rename or remove one.
- **… ends in a digit, which would be read as an octave**: rename the
  scale degree or alias so it doesn't end in a number.
- **… is used twice in …**: a scale or stroke set uses the same name or
  alias twice.
- **… is listed twice**: a drum or gong lists the same stroke twice.
- **no instrument called …**: check the spelling of the instrument in a
  `part`.
- **Typst 0.15.1 is needed to draw figures**: install Typst (see
  [Drawing a score](drawing.md#what-you-need)).
- **template … uses itself, through a cycle of uses**: two templates
  load each other. Remove one of the `use` lines.
- **a chord needs two or more notes …** / **a chord has the same note
  twice**: see [Chords](chords.md).
- **a group is written inside a score**: groups aren't ready yet; leave
  the `group` line out, and each part is drawn on its own.
