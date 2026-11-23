# Templates

Writing out the scale and every instrument at the top of each piece
gets tiring. A **template** is a file of scales, stroke sets and
instruments that any piece can load with one line: `use`.

## Using gong kebyar

notasi comes with a `gong-kebyar` template:

```scheme
{{#include examples/use-gong-kebyar.nts}}
```

`(use gong-kebyar)` gives the piece:

- the `selisir` scale, with the vowel names `i o e u a`, which are
  also how its notes are shown in the score
  (see [Scales and stroke sets](scales-and-strokes.md));
- the instruments of a gong kebyar, with the ranges Lisa Gold gives
  in *Music in Bali* (figure 2.7):

  | Instrument | Keys |
  |---|---|
  | `jegogan` | `i1` to `a1` (5) |
  | `jublag`, `calung` | `i2` to `a2` (5) |
  | `panyacah` | `i3` to `a3` (5) |
  | `ugal` | `o1` to `i3` (10) |
  | `pemade` (gangsa pemade) | `o2` to `i4` (10) |
  | `kantilan` (gangsa kantilan) | `o3` to `i5` (10) |
  | `trompong` | `a1` to `u3` (10) |
  | `reyong` | `e2` to `u4` (12) |

- a **kempli** that plays `K`;
- a **gong** that plays `G` (gong wadon), `GL` (gong lanang), `P`
  (kempur) and `T` (klentong);
- a **kendang** that plays `dag`, `dug` and `du`;
- the gong cycles `gilak` and `bapang` (see
  [Gong cycles](gong-cycles.md)).

You can read the whole template on
[GitHub](https://github.com/hsinhaoyu/notasi/blob/dev/templates/gong-kebyar.nts).
It loads a smaller template, `selisir`, which holds just the scale, so
`(use selisir)` works too.

## Your own template

Write a template for your own gamelan in a file of its own. It holds
only `scale`, `strokes`, `instrument`, `colotomy`, `pattern` and `use`
lines, with no `piece` line:

```scheme
{{#include examples/templates/my-gamelan.nts}}
```

Then load it by its file name, in double quotes:

```scheme
{{#include examples/use-my-gamelan.nts}}
```

The file name is looked up from the folder of the piece, so this
template sits in a `templates` folder next to the piece. A name without
quotes, like `gong-kebyar`, means a template that comes with notasi.

## Changing an instrument

If your gamelan differs from the template in one place, define just
that one in your piece. Your own definition replaces the template's,
and everything else still comes from the template:

```scheme
{{#include examples/replace-an-instrument.nts}}
```

The same works for a scale: if you redefine `selisir`, the template's
instruments use your version.

## The rules

- `use` lines come right after the `piece` line, before anything else.
  A piece may have several.
- A template may `use` other templates.
- Two templates used by one file can't both define the same name; see
  [Error messages](errors.md#mistakes-with-templates).

## What you get

The piece reads as if the template's scales and instruments were
written at the top of your file. If something in a template is wrong,
the error message names the template file and its line.
