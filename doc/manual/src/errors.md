# Error messages

When notasi can't read a file, it stops at the first problem and tells
you where it is and what is wrong:

```text
{{#include ../../../examples/manual/mistakes/not-a-number.txt}}
```

This says: in the file `not-a-number.nts`, on line 4, in the part
`ugal` at pulse 1, the length `four` is not a number.

Fix that one problem and try again. If there is another, notasi will
tell you about it next.

## The piece needs a title

```scheme
{{#include ../../../examples/manual/mistakes/no-title.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/no-title.txt}}
```

The title must be in double quotes: `(piece "Gilak")`.

## Unknown form

```scheme
{{#include ../../../examples/manual/mistakes/misspelt-form.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/misspelt-form.txt}}
```

The first word inside each pair of brackets says what the line is.
notasi doesn't know `pice`; check the spelling.

## Unknown piece option

```scheme
{{#include ../../../examples/manual/mistakes/unknown-option.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/unknown-option.txt}}
```

The `piece` line takes no settings yet, only its title. Check for a
stray word starting with `:`.

## A length that isn't a number

```scheme
{{#include ../../../examples/manual/mistakes/not-a-number.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/not-a-number.txt}}
```

Write a length in digits, as a whole number or a fraction above zero:
`dang1:4`, `dang1:1/4` (see [Pulses and durations](pulses-and-durations.md)).

## Missing bracket

```scheme
{{#include ../../../examples/manual/mistakes/missing-bracket.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/missing-bracket.txt}}
```

Every `(` needs a matching `)`. Here the `piece` line is never closed,
so notasi reaches the end of the file still looking for the `)`. The
line number points to where it gave up, at the end of the file. The
missing bracket is somewhere before that.

## Mistakes in scales and instruments

### No scale with that name

```scheme
{{#include ../../../examples/manual/mistakes/undefined-scale.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/undefined-scale.txt}}
```

The instrument names a scale that isn't defined. Here `selisir` is
misspelt.

### Not a note of the scale

```scheme
{{#include ../../../examples/manual/mistakes/wrong-note-name.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/wrong-note-name.txt}}
```

Each note must be a pitch (or alias) of the instrument's scale. Here
`dang1` is misspelt.

### No octave number

```scheme
{{#include ../../../examples/manual/mistakes/missing-octave.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/missing-octave.txt}}
```

Notes on a pitched instrument need an octave: write `dong1`, not `dong`.

### Notes out of order

```scheme
{{#include ../../../examples/manual/mistakes/notes-out-of-order.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/notes-out-of-order.txt}}
```

List an instrument's notes from lowest to highest, in the order of the
scale: `ding1 dong1 deng1`.

## Mistakes in parts

### Hold after a rest

```scheme
{{#include ../../../examples/manual/mistakes/hold-after-rest.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/hold-after-rest.txt}}
```

`_` holds the note before it, so it can't come after a rest or at the
start of a part. The pulse number counts from the start of the part,
from 1.

### Note number too high

```scheme
{{#include ../../../examples/manual/mistakes/note-out-of-range.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/note-out-of-range.txt}}
```

Numbers count the instrument's notes from its lowest, starting at 1.
This ugal has five keys, so 6 is too high.

### Note not on the instrument

```scheme
{{#include ../../../examples/manual/mistakes/note-not-on-instrument.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/note-not-on-instrument.txt}}
```

`dong2` is a note of the scale, but this ugal stops at ding2. Check the
instrument's range, or the octave.

### Parts of different lengths

```scheme
{{#include ../../../examples/manual/mistakes/unequal-length.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/unequal-length.txt}}
```

Every part lasts the same number of pulses. Count the notes, `_` and
`-` in each at their lengths (not `/` or `|`), and add rests to the
shorter part.

### A repeat without its number

```scheme
{{#include ../../../examples/manual/mistakes/bad-rep.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/bad-rep.txt}}
```

A `rep` needs the number of times first, then the notes:
`(rep 2 dang1 ding2)`. The line is the line of the `rep` itself.

### A cycle check out of place

```scheme
{{#include ../../../examples/manual/mistakes/cycle-check.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/cycle-check.txt}}
```

`||` must fall at the end of a gong cycle. Here the cycle has eight
pulses, but the first `||` comes after four. Move it, or check the notes
before it (see [Gong cycles](gong-cycles.md)).

### A piece that isn't whole cycles

```scheme
{{#include ../../../examples/manual/mistakes/incomplete-cycle.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/incomplete-cycle.txt}}
```

With a colotomy, a piece is its pickup plus whole cycles. This ugal part
lasts 7 pulses, one short of the eight-pulse cycle.

### A part in two groups

```scheme
{{#include ../../../examples/manual/mistakes/part-in-two-groups.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/part-in-two-groups.txt}}
```

In one score, each part can be in only one group (see
[Scores](scores.md)). Remove it from one of them.

### A group naming a part that doesn't exist

```scheme
{{#include ../../../examples/manual/mistakes/undefined-part.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/undefined-part.txt}}
```

Check the spelling of the part's name in the group.

### A position that isn't in the piece

```scheme
{{#include ../../../examples/manual/mistakes/bad-position.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/bad-position.txt}}
```

This cycle has 8 pulses, so there is no pulse 9. A position is
`(CYCLE PULSE)` with a colotomy, or a pulse number without one (see
[Scores](scores.md#excerpts-and-lines)).

### An excerpt that ends before it starts

```scheme
{{#include ../../../examples/manual/mistakes/bad-range.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/bad-range.txt}}
```

`:from` must come before `:to`. Here they are the wrong way round.

### A group of names without names

```scheme
{{#include ../../../examples/manual/mistakes/needs-note-names.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/needs-note-names.txt}}
```

Rows of parts, one row, and `:fill none` show the notes only by their
names. Add `:note-names yes` to the group or the score (see
[Scores](scores.md#rows-of-names)).

### Two notes in one place on a single row

```scheme
{{#include ../../../examples/manual/mistakes/notes-collide.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/notes-collide.txt}}
```

On a single row, only one note can sound in each column. Here polos is
still holding its note when sangsih strikes. Give the parts their own
rows, or change the music.

### Two parts on one key

```scheme
{{#include ../../../examples/manual/mistakes/notes-collide-key.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/notes-collide-key.txt}}
```

When parts share a group's rows, two of them can play the same key only
by striking it together, for the same length: that is drawn once, as a
single note. Here sangsih strikes i3 while polos is still holding it, so
the two notes would be drawn in the same place. Give the parts groups
of their own, or `:rows parts`.

### Pattern names written over each other

```scheme
{{#include ../../../examples/manual/mistakes/pattern-names-overlap.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/pattern-names-overlap.txt}}
```

In one group, the names of the patterns must either match exactly (the
same name over the same pulses, written once) or not overlap. Here
sangsih's figures start a pulse later than polos's. Give them groups of
their own, or choose another `:pattern-level` (see
[Patterns](patterns.md#printing-pattern-names)).

### A note outside the keys shown

```scheme
{{#include ../../../examples/manual/mistakes/outside-keys.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/outside-keys.txt}}
```

The group shows only the keys from `i2` to `e2`, but the ugal plays
`a1`. Widen the range, or use `:keys used` or `:keys all` (see
[Scores](scores.md#which-rows-and-their-labels)).

### A pattern that doesn't exist

```scheme
{{#include ../../../examples/manual/mistakes/undefined-pattern.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/undefined-pattern.txt}}
```

Check the spelling after the `@` (see [Patterns](patterns.md)).

### A pattern for another instrument

```scheme
{{#include ../../../examples/manual/mistakes/wrong-instrument.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/wrong-instrument.txt}}
```

A pattern can only be played on the instrument named by its
`:instrument`. Write another pattern for this instrument.

### A pulse check out of place

```scheme
{{#include ../../../examples/manual/mistakes/pulse-check.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/pulse-check.txt}}
```

`|` must fall at the start of a pulse. Here half a pulse and two whole
pulses come before it, so it falls at pulse 2½. A note is too long or
too short, or one is missing, somewhere before the `|`.

### Two parts on one instrument

```scheme
{{#include ../../../examples/manual/mistakes/parts-need-names.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/parts-need-names.txt}}
```

When an instrument has two parts, give each a name with `:name`, as in
`(part :instrument reyong :name sangsih 4 3 2 1)` (see
[Several parts on one instrument](parts.md)).

### A setting after the music

```scheme
{{#include ../../../examples/manual/mistakes/option-after-music.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/option-after-music.txt}}
```

Settings such as `:name` come before the first note:
`(part :instrument ugal :name melody 1 2 3 4)`.

### A part without its instrument

```scheme
{{#include ../../../examples/manual/mistakes/part-without-instrument.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/part-without-instrument.txt}}
```

A part names its instrument with `:instrument`. The same goes for the
parts inside a `colotomy`.

## Mistakes with templates

### No template with that name

```scheme
{{#include ../../../examples/manual/mistakes/template-not-found.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/template-not-found.txt}}
```

Check the spelling: here it should be `gong-kebyar`. A name in double
quotes is a file, looked up from the folder of the piece.

### `use` too late

```scheme
{{#include ../../../examples/manual/mistakes/use-not-first.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/use-not-first.txt}}
```

Move the `use` line up, right after the `piece` line.

### Two templates define the same name

```scheme
{{#include ../../../examples/manual/mistakes/template-conflict.nts}}
```

```scheme
{{#include ../../../examples/manual/mistakes/templates/my-reyong.nts}}
```

```scheme
{{#include ../../../examples/manual/mistakes/templates/my-ugal.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/template-conflict.txt}}
```

Both templates have a `ugal`, and notasi can't tell which one you
mean. Remove it from one of them, or define `ugal` in the piece itself:
the piece's own definition replaces both.

### Music in a template

```scheme
{{#include ../../../examples/manual/mistakes/part-in-template.nts}}
```

```scheme
{{#include ../../../examples/manual/mistakes/templates/with-a-part.nts}}
```

```text
{{#include ../../../examples/manual/mistakes/part-in-template.txt}}
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
  pitch or alias so it doesn't end in a number.
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
- **a group is written inside a score**: put the `group` line inside a
  `(score NAME …)` (see [Scores](scores.md)).
- **… is set on the score, not on a group**: move the setting to the
  `score` line.
