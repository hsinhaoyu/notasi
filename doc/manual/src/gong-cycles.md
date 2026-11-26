# Gong cycles

Gamelan music goes round in **gong cycles**: the gong, kempur and
kempli mark the same pattern of pulses again and again, and the gong
falls on the last pulse of each cycle. In notasi this pattern is a
**colotomy**. Name one on the `piece` line, and notasi plays the gong
parts and the kempli for the whole piece:

```scheme
{{#include ../../../examples/manual/gong-cycle.nts}}
```

- `:colotomy gilak` on the `piece` line uses the gilak cycle for the
  piece. The `gong-kebyar` template defines it: eight pulses, with the
  gong lanang on pulse 4, the kempur on 5 and 7, and the gong on 8.
- notasi writes out the `gong` part for every cycle.
- The **kempli** is added for you, one stroke on every pulse. If the
  piece has no kempli instrument, notasi still keeps the pulse but
  doesn't draw it.

## What a colotomy is

"Colotomic" is a word from Western writing about gamelan, for the
gongs, kempur and kempli that mark off the cycle. There is no single
Balinese word for it: each meter has its own name, such as gilak or
bapang. In notasi, a **colotomy** is one named meter at one length.

- The same meter can be played at more than one length, and each
  length is its own colotomy: bapang is played over 8, 16 and 32
  pulses.
- The gongs alone don't tell meters apart. A 16-pulse bapang and
  gegaboran have the same gong strokes, and differ in their drumming,
  mood and kind of piece. A colotomy's name is your label for the
  meter you mean.
- A pulse is one kempli stroke, what Lisa Gold calls a beat, so a
  length from her book is a length in pulses.

The `gong-kebyar` template has these colotomies:

| Name | Pulses | Gong strokes |
|---|---|---|
| `gilak` | 8 | gong lanang on 4, kempur on 5 and 7, gong on 8 |
| `gilak-2` | 8 | gong on 4 and 8, kempur on 5 and 7 |
| `bapang-8` | 8 | kempur on 2 and 6, klentong on 4, gong on 8 |
| `bapang-16` | 16 | kempur on 4 and 12, klentong on 8, gong on 16 |
| `gegaboran` | 16 | the same strokes as `bapang-16` |

## A cycle of your own

For a cycle the template doesn't have, or a different version of one,
write a `colotomy`. Lisa Gold's "Jagra Parwata" (*Music in Bali*,
p. 142) plays bapang over 32 pulses:

```scheme
{{#include ../../../examples/manual/bapang-32.nts}}
```

- `(colotomy bapang-32 32 …)` names a cycle of 32 pulses.
- Inside it, `(part :instrument gong …)` is the gong's part over one
  cycle, written like any [part](notes-rests-and-holds.md): rests, the
  kempur on pulses 8 and 24, the klentong on 16, and the gong on 32. It
  is called `gong`, after its instrument; give it another name with
  `:name`.
- A colotomy in your piece with the same name as the template's, such
  as `gilak`, replaces the template's.

## Starting on the gong

Many pieces start on a gong stroke, which is the last pulse of a cycle.
`:pickup 1` says the piece starts one pulse before the first whole
cycle. The ugal plays `a1` on that pulse, together with the gong, and
then plays one cycle.

A piece is its pickup plus whole cycles: here 1 + 8 = 9 pulses. Every
part you write must last that long.

## Checking the cycle with `||`

`||` marks the end of a cycle, as `|` marks a pulse. It takes no time,
and notasi checks that it really falls where a cycle ends. In the ugal
part, the first `||` comes after the pickup, and the second after the
eight pulses of the cycle.

When notasi tells you about a mistake, it says where it is as a cycle
and a pulse: "cycle 1, pulse 3". The pickup is cycle 0.

In the drawing, the pulses are numbered within each cycle, the pickup
as the last pulse of cycle 0. Each cycle's number is above its first
pulse, the pickup's `0` above it, and a heavier line marks where a
cycle begins, just after the gong. The two rows are labelled "Cycle"
and "Pulse".
A score can number the gong as pulse 1 instead (`:numbering
gong-first`; see [Scores](scores.md)).

## The rules

- A colotomy's length is a whole number of pulses. Each of its parts
  lasts the whole cycle, or a part of it that fits a whole number of
  times: a two-pulse kempur part plays four times in an eight-pulse
  cycle.
- `:pickup` is a whole number of pulses, at most one cycle, and needs a
  `:colotomy`.
- A part you write can't be called `kempli`, or have the name of a part
  of the colotomy: notasi makes those.
- Inside a `colotomy`, every part is a `part` form.
- Colotomies can go in a template too, like scales and instruments
  (see [Templates](templates.md)).

The full rules are in the
[notation reference](https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md).
