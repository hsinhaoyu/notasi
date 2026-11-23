# Scores

The music says what is played. A **score** says how it is printed:
which parts, in which blocks, with which labels and colours. Without a
score, notasi draws every part in a block of its own. With one, you
choose:

```scheme
{{#include examples/scores.nts}}
```

![The kotekan above, drawn from its score](figures/scores.svg)

- `(score full …)` names the score. A file can have more than one; notasi
  draws the first.
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
| `:system-length N` | score | N pulses on each line of the score. Without it, the whole piece is one line. |
| `:note-names yes` | score or group | Write each note's name in its square. The gongs above show `G`, `P` and `K`. |
| `:palette NAME` | score or group | The colours of the notes: `pastel1` (the default), `set2`, `dark2` and others, or a list of colours such as `("#e41a1c" "#377eb8")`. |
| `:colors ((ding "#000000"))` | score or group | A colour for one degree, in every octave. |
| `:cell-width "2em"`, `:cell-height "2em"` | score | The size of a square. |

## The rules

- A group holds parts on one pitched instrument, or gongs and drums, not
  both. To compare the ugal and the reyong, give each a group.
- A part can be in only one group of a score.
- Every part a group names must exist.

The full rules are in the
[notation reference](https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md).
