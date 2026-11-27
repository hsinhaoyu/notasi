# Design idea: colouring notes by key

Status: agreed in discussion (2026-11-27). Not the design until
promoted.

## The idea

Today notes are coloured by pitch (`:scheme by-pitch`, ADRs 0017,
0021, 0056): `o2` and `o4` are the same colour, so a score's colours
say which pitch sounds but not in which octave. The writer wants to see
register across the whole score: which notes are low and which are
high, on every instrument at once.

A note's colour should come from its **key**, the pitch in an octave
(`o2`; glossary), rather than its pitch alone. The same pitch keeps its
hue in every octave and gets lighter as the octave rises. Brightness
carries the octave, and hue still carries the pitch.

## Agreed (2026-11-27)

- **A new scheme, `by-key`**, alongside `by-pitch`: `:scheme by-key`
  on a score or a group (ADR 0032). It colours each pitched note by its
  key. `by-pitch` is unchanged, and stays the default with `pastel1`:
  existing scores, and their golden files, don't change.
- **Octaves are absolute, numbered as keys already are.** The octave
  number is the digit of the key (`o2` is in octave 2). Octave 1 is the
  jegogan's lowest octave (`i1 o1 e1 u1 a1` in `gong-kebyar`), and each
  octave starts at ding. One number holds across every instrument, so
  `o2` is the same colour on the jublag, the ugal and the reyong.
- **Four octaves.** The default octave palette covers octaves 1–4, the
  register of a gong kebyar from the jegogan to the kantilan.
- **An octave palette**, named `pastel1-octaves`
  ([its colours](2026-11-27-pastel1-octaves.md)), gives one colour per
  key. It is chosen with `:palette`, as other palettes are.
- **The octave palette is one colour ramp per scale position.** As
  `pastel1` gives the first pitch of the scale (ding) its first colour,
  the octave palette gives the first pitch its first ramp, a colour for
  each octave from low to high. A scale with more pitches than the
  palette has ramps reuses them from the first, as palettes do now.
- **`:colors` takes pitches and keys under `by-key`:**
  `:colors ((ding "#000000"))` sets ding in every octave;
  `:colors ((i2 "#000000"))` sets `i2` only. A key wins over its
  pitch. Under `by-pitch`, `:colors` stays as it is.
- **Keys outside the palette's octaves take the nearest octave's
  colour.** The kantilan's top key, `i5`, is drawn in `i4`'s colour.
  This is documented. The reader has no warnings today, so there is
  no warning; one can come if warnings are added.
- **Strokes stay grey**, as under `by-pitch`. They have no pitch.
- **Text colour is unchanged**: white or near-black by contrast with
  the fill (`text-color-for`, 4.5:1), so dark low-octave notes get
  white text.
- **No change to the figure JSON or the Typst template.** Each event
  already carries its `fill`, `text` and `text_color`. Guile decides
  the colours and Typst only draws them (ADRs 0005, 0006).

## Later

- **Custom scales written in Guile.** A colour for each key worked out
  by the writer's own procedure. `make-style #:scheme` already takes a
  procedure from Guile, so there is a place for this, but a score
  can't name one yet.
- **A legend or swatch sheet** drawing a palette's colours as a grid of
  pitches and octaves, for tuning palettes and checking custom ones. At
  most a page in the manual for now.

## Open, then decided (2026-11-27)

1. **`:scheme by-key` with a palette that has no octaves** (`pastel1`,
   or `:palette ("#..." ...)`): `by-key`'s default palette is
   `pastel1-octaves`, and a plain palette with `by-key` is a reader
   error naming `by-key`. It fails loudly, rather than quietly
   colouring by pitch.
2. **Writing an octave palette as a list:** one list per scale
   position, lowest octave first:
   `:palette (("#944a4b" "#c36d6b" "#ea9892" "#ffcdc9") ...)`.
3. **Key names in `:colors`:** both forms are accepted, `i2` and
   `ding2`, as keys are written elsewhere.

## Notes for promotion

- 01: `by-key` in the `:scheme` row; `pastel1-octaves` and the
  octave-palette list form in the `:palette` row; `:colors` taking keys;
  the nearest-octave rule.
- 03: reading `by-key`, the octave palette and keys in `:colors`; their
  errors.
- 04, "Note style": the `by-key` scheme, the octave palette, the
  nearest-octave rule; `make-style`'s palette taking ramps.
- `glossary.md`: `by-key` and octave palette.
- A new ADR: notes can be coloured by key. ADR 0056 stands; `by-pitch`
  stays the default.
- Code: `(notasi style)`, its tests; a golden file for the new score.
- The manual: the page on colours, with an example and its drawing.
- The Emacs mode's completion: `by-key`, `pastel1-octaves`.
- `backlog.md`: "More colour schemes (by part, by octave)" keeps only
  "by part".
