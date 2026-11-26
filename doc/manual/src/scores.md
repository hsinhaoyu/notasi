# Scores

The music says what is played. A **score** says how it is printed:
which parts, in which blocks, with which labels and colours. Without a
score, notasi draws every part in a block of its own. With one, you
choose:

```scheme
{{#include ../../../examples/manual/scores.nts}}
```

![The kotekan above, drawn from its score](figures/scores.png)

- `(score full …)` names the score. A file can have more than one;
  notasi draws the first, or the one you choose (see
  [Several scores](#several-scores)).
- Each `(group "Reyong" … polos sangsih)` is one block of rows, with its
  label on the left. Here polos and sangsih share the reyong's rows, so
  you see how they interlock. `:subtitle` adds a line under the label (or follows it, when the
  group has only one row).
- A part that is in no group isn't printed. The kempli is added for you
  (see [Gong cycles](gong-cycles.md)); name it in a group to print it.

## Settings

Settings on the `score` line apply to every group; a group can set its
own instead.

| Setting | Where | What it does |
|---|---|---|
| `:title "…"` | score | The title, instead of the piece's. |
| `:subtitle "…"` | score or group | A line under the title, or under a group's label (after it, on a group of one row). |
| `:caption "…"` | score | A line under the score. |
| `:cycle-numbers yes` / `no` | score | Number each gong cycle above its first pulse. On by default when the piece has a [colotomy](gong-cycles.md). |
| `:pulse-numbers yes` / `no` | score | The row of pulse numbers. On by default. |
| `:numbering gong-last` / `gong-first` | score | Count the pulses of a cycle with the gong last (1 to 8, the gong on 8; the default) or first (the gong on 1). |
| `:cycle-label "…"` | score | The label at the left of the cycle numbers: `"Cycle"` unless you say. `""` leaves it out. |
| `:pulse-label "…"` | score | The label at the left of the pulse numbers, such as `"Beats"`: `"Pulse"` unless you say. `""` leaves it out. |
| `:font-size "8pt"` | score | The size of the text (8pt unless you say). |
| `:system-length N` | score | N pulses on each line of the score. Without it (or [breaks](#excerpts-and-lines)), the whole piece, or the whole excerpt, is one line. |
| `:short "…"` | group | A short label, such as `"U."` for `"Ugal"`. |
| `:labels first-long` / `long` / `short` | score or group | Which label to print: the long one on the first line and the short one after (the default), always the long one, or always the short one. |
| `:note-label NAME` | score or group | What to write in each note's square: `none` (the default: colour only), `pitch-name` (`dong2`), `pitch-display-name` (`o2`) or `key-number` (its key on the instrument, counted from 1 at the lowest). Gongs and drums show their stroke (`G`, `P`, `K`). The gongs above use `pitch-display-name`. |
| `:note-label-octave yes` / `no` | score or group | `no` leaves the octave number out of the label in each square: `o` instead of `o2`. `yes` unless you say. |
| `:palette NAME` | score or group | The colours of the notes: `pastel1` (the default), `set2`, `dark2` and others, or a list of colours such as `("#e41a1c" "#377eb8")`. |
| `:colors ((ding "#000000"))` | score or group | A colour for one pitch, in every octave. |
| `:cell-width "2em"`, `:cell-height "2em"` | score | The size of a square. |
| `:background grid` / `vertical` / `horizontal` / `empty` | score or group | The lines behind the notes: pulse lines and lines between rows (`grid`, the default), pulse lines only (`vertical`), lines between rows only (`horizontal`), or neither (`empty`). The lines between groups and at each new cycle are always drawn. |

## Which rows, and their labels

By default a group has a row for each key it plays. A score can show
every key of the instrument instead, number the keys, and choose how
the rows are labelled:

```scheme
{{#include ../../../examples/manual/scores-keys.nts}}
```

![Every key of the ugal, numbered](figures/scores-keys.png)

| Setting | Where | What it does |
|---|---|---|
| `:keys used` / `all` / `(LOW HIGH)` | score or group | The rows: the keys played (the default), every key of the instrument, or the keys from LOW up to HIGH, written as in a part (`(a1 u2)` or `(4 8)`). Gongs and drums take `used` or `all`. |
| `:key-numbers yes` / `no` | score or group | A column of key numbers to the left of the row labels, counted from the lowest key: on the ugal, `a1` is key 4. Only for pitched instruments. `no` unless you say. |
| `:row-labels NAME` | score or group | How the rows are labelled: `pitch-display-name` (`a1`, the default), `pitch-name` (`dang1`), or `none` to leave the labels out. |
| `:row-label-octave yes` / `no` | score or group | `no` labels the rows `a`, `i`, … instead of `a1`, `i2`, …. `yes` unless you say. |
| `:display ((GL "G") …)` | score or group | Show these strokes another way in this score, in their row labels and names: here both gongs as "G", as Tenzer writes them. |

With `:keys (LOW HIGH)`, every note the group plays must be among the
keys shown.

## Rows of names

A score can also print music the way it is sung, with names instead of
colours:

```scheme
{{#include ../../../examples/manual/scores-rows.nts}}
```

![The sung lines above](figures/scores-rows.png)

| Setting | Where | What it does |
|---|---|---|
| `:rows parts` | score or group | One row for each part, instead of one for each note. Give a row its label with `(polos :label "Polos")`. |
| `:rows compact` | score or group | The group's parts merged into as few rows as they need, such as the strokes of two drums played by one person, or a gong and the kempli. Each key or stroke keeps one row for the whole score; keys that never sound at the same time share one, and a row is added where they do (the gong's strokes on one row, the kempli on another). The rows have no labels. |
| `:fill none` | score or group | Names only, without coloured squares. |
| `:holds dash` | score or group | A `-` in every column a note is held, as in a sung line. |

On rows of parts or compact rows, the squares keep their colours, so a
`:note-label` is your choice. With `:fill none` there are no squares,
so the group needs a `:note-label`.

A note that lasts one column shows its **damped** name, if its pitch
has one (`:damped "na'"`; see [Scales and stroke sets](scales-and-strokes.md));
a longer note shows its usual name. In the drawing above, `nang` rings
and `na'` is cut short.

## Excerpts and lines

A score can print part of a piece, and choose where its lines break:

```scheme
{{#include ../../../examples/manual/scores-excerpt.nts}}
```

The first score, `whole`, starts a new line at each cycle:

![The whole piece, a cycle on each line](figures/scores-excerpt_whole.png)

The second, `second`, prints one cycle, counted with the gong on 1:

![The second cycle alone](figures/scores-excerpt_second.png)

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

This writes `gilak_second.pdf`, so the pictures of different scores
don't overwrite each other.

## The rules

- A group holds parts on one pitched instrument, or gongs and drums, not
  both. To compare the ugal and the reyong, give each a group.
- A part can be in only one group of a score.
- Every part a group names must exist.
- With `:keys (LOW HIGH)`, a group can't play a note outside that range.
  `:keys` and `:key-numbers` choose rows of keys, so they don't go on a
  group with `:rows parts` or `:rows compact`.
- When parts share a group's rows, two of them can play the same key at
  once only by striking it together, for the same length (a unison,
  drawn once).
- `:from` must come before `:to`, and every position must be in the
  piece.

The full rules are in the
[notation reference](https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md).
