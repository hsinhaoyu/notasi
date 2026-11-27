# Design idea: the `pastel1-octaves` palette

Status: agreed in discussion (2026-11-27). Not the design until
promoted.

## The idea

The default octave palette for `by-key`
([colouring notes by key](2026-11-27-colour-by-key.md)). It is built
from the default palette, `pastel1` (ADR 0021), so a score coloured by
key reads as a shaded version of today's default rather than a new set
of colours.

## Agreed (2026-11-27)

- **The same hues as `pastel1`.** Each pitch keeps its colour family:
  ding red, dong blue, deng green, dung purple, dang orange. Ding and
  dang are turned a few degrees in octaves 1 and 2 (ding −4° and −2°,
  dang −5° and −3° in OKLCH hue), so they don't turn brown when dark.
- **Lightness by octave, darkest at octave 1.** In OKLCH, lightness is
  0.50, 0.63, 0.76 and 0.89 for octaves 1–4, the same for every pitch
  in an octave. Printed in grey, a score shows its four octaves as four
  clear shades.
- **Chroma** is 0.100, 0.110 and 0.100 for octaves 1–3, and up to
  0.065 in octave 4, the most each hue can have there and still be
  shown in sRGB (ding and dong 0.057).
- **Octave 4 is close to `pastel1`**, so the upper instruments look
  much as they do today.
- **The colours** (`#rrggbb`):

  | Octave | ding (i) | dong (o) | deng (e) | dung (u) | dang (a) |
  |---|---|---|---|---|---|
  | 4 | `#ffcdc9` | `#bce0fe` | `#c5e6bd` | `#edcef7` | `#f5d5ab` |
  | 3 | `#ea9892` | `#78b8ec` | `#8fc184` | `#cc9ddb` | `#d6a866` |
  | 2 | `#c36d6b` | `#4890c7` | `#649958` | `#a573b4` | `#b27d34` |
  | 1 | `#944a4b` | `#276898` | `#427138` | `#7b5088` | `#875814` |

  For comparison, `pastel1`'s first five: `#fbb4ae #b3cde3 #ccebc5
  #decbe4 #fed9a6`.
- **Text:** by `text-color-for`, octave 1 takes white and octaves 2–4
  near-black.

## Trade-offs

- **The closest pair** is ding and dang in octave 4. It is about as
  close as ding and dang are in `pastel1` today (OKLab distance 0.053
  against 0.057), so the lightest octave is no harder to read than the
  default.
- **Four octaves**, not five. The kantilan's `i5` takes octave 4's
  colour (the nearest-octave rule). A fifth, lighter level would bring
  the colours closer together.

## Open

1. **Tuning.** The colours are worked out, not yet seen in a real
   score. They are checked by eye on Jaya Semara's drawing before
   they are promoted, and may change then.
