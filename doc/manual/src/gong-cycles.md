# Gong cycles

Gamelan music goes round in **gong cycles**: the gong, kempur and
kempli mark the same pattern of pulses again and again, and the gong
falls on the last pulse of each cycle. In notasi this pattern is a
**colotomy**. Name one on the `piece` line, and notasi plays the gong
parts and the kempli for the whole piece:

```scheme
{{#include examples/gong-cycle.nts}}
```

- `:colotomy gilak` on the `piece` line uses the gilak cycle for the
  piece. The `gong-kebyar` template defines it: eight pulses, with the
  gong lanang on pulse 4, the kempur on 5 and 7, and the gong on 8. It
  also defines `bapang`, sixteen pulses with the kempur on 4 and 12,
  the klentong on 8 and the gong on 16.
- notasi writes out the `gong` part for every cycle.
- The **kempli** is added for you, one stroke on every pulse. If the
  piece has no kempli instrument, notasi still keeps the beat but
  doesn't draw it.

## A cycle of your own

For a cycle the template doesn't have, or a different version of one,
write a `colotomy`:

```scheme
{{#include examples/own-colotomy.nts}}
```

- `(colotomy gilak-kempur 8 …)` names a cycle of eight pulses.
- Inside it, `(part :instrument gong …)` is the gong's part over one
  cycle, written like any [part](notes-rests-and-holds.md): rests, the
  kempur on pulses 4 and 6, and the gong on pulse 8. It is called
  `gong`, after its instrument; give it another name with `:name`.
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
