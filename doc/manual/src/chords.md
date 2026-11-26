# Chords

To strike two or more notes at once, put them in round brackets. The
whole chord lasts as long as one note:

```scheme
{{#include ../../../examples/manual/chords.nts}}
```

- `(e2 a2)` strikes deng2 and dang2 together.
- `(6 8)` is the same chord by number: the reyong's sixth and eighth
  pots.
- A chord can be held with `_`, like any note.

You can mix names and numbers in one chord. Each note can appear only
once in a chord, and a chord needs at least two notes. For one note,
leave out the brackets.
