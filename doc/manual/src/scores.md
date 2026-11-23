# Scores

The music says what is played. A **score** says how it is printed:
which parts, in which blocks, with which labels and colours. Without a
score, notasi draws every part in a block of its own. With one, you
choose:

```scheme
{{#include examples/scores.nts}}
```

![The kotekan above, drawn from its score](figures/scores.svg)

- `(score full …)` names the score. A file can have more than one;
  notasi draws the first, or the one you choose (see
  [Several scores](#several-scores)).
- Each `(group "Reyong" … polos sangsih)` is one block of rows, with its
  label on the left. Here polos and sangsih share the reyong's rows, so
  you see how they interlock. `:subtitle` adds a line under the label.
- A part that is in no group isn't printed. The kempli is added for you
  (see [Gong cycles](gong-cycles.md)); name it in a group to print it.

## Settings

Settings on the `score` line apply to every group; a group can set its
own instead.

| Setting | Where | What it does |
|---|---|---|
| `:title "…"` | score | The title, instead of the piece's. |
| `:subtitle "…"` | score or group | A line under the title, or under a group's label. |
| `:caption "…"` | score | A line under the score. |
| `:cycle-numbers yes` / `no` | score | Number each gong cycle above its first pulse. On by default when the piece has a [colotomy](gong-cycles.md). |
| `:pulse-numbers yes` / `no` | score | The row of pulse numbers. On by default. |
| `:numbering gong-last` / `gong-first` | score | Count the pulses of a cycle with the gong last (1 to 8, the gong on 8; the default) or first (the gong on 1). |
| `:pulse-label "…"` | score | A label at the left of the pulse numbers, such as `"Beats"`. |
| `:font-size "8pt"` | score | The size of the text (8pt unless you say). |
| `:system-length N` | score | N pulses on each line of the score. Without it (or [breaks](#excerpts-and-lines)), the whole piece, or the whole excerpt, is one line. |
| `:short "…"` | group | A short label, such as `"U."` for `"Ugal"`. |
| `:labels first-long` / `long` / `short` | score or group | Which label to print: the long one on the first line and the short one after (the default), always the long one, or always the short one. |
| `:note-names yes` | score or group | Write each note's name in its square. The gongs above show `G`, `P` and `K`. |
| `:palette NAME` | score or group | The colours of the notes: `pastel1` (the default), `set2`, `dark2` and others, or a list of colours such as `("#e41a1c" "#377eb8")`. |
| `:colors ((ding "#000000"))` | score or group | A colour for one degree, in every octave. |
| `:cell-width "2em"`, `:cell-height "2em"` | score | The size of a square. |

## Rows of names

A score can also print music the way it is sung, with names instead of
colours:

```scheme
{{#include examples/scores-rows.nts}}
```

![The sung lines above](figures/scores-rows.svg)

| Setting | Where | What it does |
|---|---|---|
| `:rows parts` | score or group | One row for each part, instead of one for each note. Give a row its label with `(polos :label "Polos")`. |
| `:rows single` | score or group | All the group's parts on one row, such as the strokes of two drums played by one person. Two notes can't sound in the same column. |
| `:fill none` | score or group | Names only, without coloured squares. |
| `:holds dash` | score or group | A `-` in every column a note is held, as in a sung line. |

Rows of parts or one row, and `:fill none`, show the notes only by
their names, so the group needs `:note-names yes`.

A note that lasts one column shows its **damped** name, if its degree
has one (`:damped "na'"`; see [Scales and stroke sets](scales-and-strokes.md));
a longer note shows its usual name. In the drawing above, `nang` rings
and `na'` is cut short.

## Excerpts and lines

A score can print part of a piece, and choose where its lines break:

```scheme
{{#include examples/scores-excerpt.nts}}
```

The first score, `whole`, starts a new line at each cycle:

![The whole piece, a cycle on each line](figures/scores-excerpt.whole.svg)

The second, `second`, prints one cycle, counted with the gong on 1:

![The second cycle alone](figures/scores-excerpt.second.svg)

| Setting | Where | What it does |
|---|---|---|
| `:from POS`, `:to POS` | score | Print from the pulse at `:from` to the end of the pulse at `:to`. |
| `:breaks (POS …)` | score | Start a new line at each of these pulses. With `:system-length` too, both apply. |

A position POS is written the way the score numbers its pulses:

- With a [colotomy](gong-cycles.md), it is `(CYCLE PULSE)`: the pulse
  numbered PULSE under the cycle numbered CYCLE. A pickup is cycle 0, so
  a one-pulse pickup in a cycle of 8 is `(0 8)`.
- With `:numbering gong-first`, the gong is numbered 1, at the end of
  each cycle. So the second cycle runs from `(2 2)` to `(2 1)`, as in
  the score above.
- Without a colotomy, a position is just the pulse's number, from 1.

A note that began before `:from` is drawn from there, without its name,
as at the start of a line. A break outside the excerpt is skipped.

## Several scores

A file can have several scores, such as the whole piece and an excerpt.
notasi draws the first unless you name another with `--score`:

```text
scripts/notasi render gilak.nts --score second
```

This writes `gilak.second.pdf`, so the pictures of different scores
don't overwrite each other.

## The rules

- A group holds parts on one pitched instrument, or gongs and drums, not
  both. To compare the ugal and the reyong, give each a group.
- A part can be in only one group of a score.
- Every part a group names must exist.
- `:from` must come before `:to`, and every position must be in the
  piece.

The full rules are in the
[notation reference](https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md).
