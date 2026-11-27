# Iteration 6: colouring notes by key

Status: deciding

## Goal

See the register of every note across a whole score: notes coloured by
their key (pitch and octave), so the same pitch is the same colour in
every octave, lighter as it goes higher, and the jegogan's notes are
told apart from the kantilan's at a glance.

## Acceptance test

Agreed (2026-11-27):

1. A score of a gallery piece (Jaya Semara) is drawn with
   `:scheme by-key`, and its colours are checked by eye, then by golden
   tests.
2. Every existing golden test passes unchanged: `by-pitch` with
   `pastel1` stays the default, and its drawings don't change.

## Design ideas

Thinking, not the design (ADRs 0023, 0024). All from the discussion of
2026-11-27, in [`design_ideas/`](design_ideas/):

- [Colouring notes by key](design_ideas/2026-11-27-colour-by-key.md):
  a new scheme, `:scheme by-key`, colouring each note by its pitch and
  octave; octaves numbered as keys are, with octave 1 the jegogan's
  lowest; `:colors` by pitch or by key; keys outside the palette's
  octaves; other scales.
- [The `pastel1-octaves` palette](design_ideas/2026-11-27-pastel1-octaves.md):
  `pastel1`'s five colours in four octaves, darkest at octave 1, with
  even lightness in each octave.

## Promotion

Agreed (2026-11-27), in this order. 02 and 05 don't change: no record
and no figure JSON changes.

1. `01-notation.md`, with the new ADR (notes can be coloured by key)
   and `glossary.md` (`by-key`, octave palette)
2. `03-reader.md`
3. `04-layout.md`

Then the milestones and the build order are set, and the status
becomes `building`.

## Milestones

Not yet agreed.
