# 04 — Layout

Status: implemented (iterations 2 and 3): iteration 2's milestone 2, all five slices
(`feat/scores-form`, `feat/scores-contract`, `feat/scores-rows`,
`feat/scores-overlays`, `feat/scores-range`, see "Slices (iteration
2)"). `layout-score` lays out a score as contract version 3. "Note
style" is built from a score's options. Modules: `(notasi style)`, `(notasi layout)`; tests
in `tests/style.scm`, `tests/layout.scm` and `tests/golden.scm`.
Contract version 3 (ADR 0043) with the header labels and the pickup's
cycle mark since `feat/drawing-header`; each group's lines and the
lighter stroke grey (ADR 0041) since `feat/drawing-lines`; strokes one
column wide (ADR 0042), `:keys`, `:octave-numbers`, `:display`, key
numbers and row labels left out (ADR 0047) since `feat/drawing-rows`;
golden files named `NAME_SCORE` (ADR 0040) since `feat/drawing-output`.
Iteration 3's layout is implemented. `by-pitch` and `pitch-colors`
since iteration 5's `feat/collapsed-terms`. Contract version 4 opened,
with `rows`, `row` and `row_label_width` (ADR 0059), and the note label
and the pitch column's forms (ADR 0054), since `feat/collapsed-labels`.
Compact rows in place of `single` (ADRs 0055, 0060) since
`feat/collapsed-compact`. Part markers and each voice's `marker` (ADR
0056) since `feat/collapsed-markers`. The annotation row in place of
the overlays (ADR 0057), completing contract version 4 (ADR 0059),
since `feat/collapsed-annotation`: iteration 5's layout is
implemented.

Everything in this document is **Implemented** unless it says otherwise.

## Responsibility

Make every *musical* layout decision and produce a figure description
(the JSON contract in 05-typst-backend.md), for one score of a piece.
`(notasi style)` is part of layout, split out only to keep modules
small, so layout depends only on `(notasi piece)` and `(notasi style)`
(ADRs 0008, 0035): it never looks at the reader or at Typst. Layout
knows music, not Typst; the Typst template knows drawing, not music
(ADR 0005). The template does no counting: every number, line and
label it draws is in the figure.

## Public interface

```
(layout-score piece score) → figure
```

`score` is one of `(piece-scores piece)`, e.g. `(piece-score piece
'full)`. Its groups already carry their effective settings (ADR 0033),
so layout reads plain values. `layout-score` replaces `layout-piece`.

The figure is the JSON value of 05's contract itself, version 4 (ADR
0059), as `(notasi json)` writes it: alists with symbol keys for
objects, vectors for arrays, the symbol `null` for null. Writing it out
is then just `write-json`, and layout is tested with `equal?`. Keys come
in this order:

| Object | Keys |
|---|---|
| figure | `version` (4, ADR 0059), `title`, `subtitle`, `steps_per_pulse`, `sizes`, `systems`, `caption` |
| sizes | `font_size`, `label_width`, `key_width`, `row_label_width`, `cell_width`, `cell_height` |
| system | `start`, `steps`, `header`, `lines`, `groups` |
| header | `cycle_label`, `pulse_label`, `cycles`, `pulses`, `pulse_lines` |
| cycle mark | `column`, `text` |
| group | `label`, `subtitle`, `rows`, `key_numbers`, `voices`, `annotation`, `pulse_lines`, `row_lines` |
| voice | `name`, `marker`, `events` |
| marker | `symbol`, `symbol_size`, `symbol_color`, `border`, `border_width` |
| event | `start`, `dur`, `row`, `text`, `fill`, `text_color`, `continued` |
| annotation | `position`, `label`, `items` |
| annotation item | `start`, `dur`, `text`, `align`, `continued` |

Version 3's `lanes`, `lane` and `lane_width` are `rows`, `row` and
`row_label_width` (since `feat/collapsed-labels`), and its overlays are
gone (since `feat/collapsed-annotation`). `marker` and `annotation` are `null` when the
group asks for none.

- `title`, `subtitle` and `caption` are the score's (`null` when it has
  none).
- `steps_per_pulse` is the number of columns in a pulse (see "The
  step").
- `font_size` is the score's `:font-size`, or `null` to leave it to the
  document; `cell_width` and `cell_height` are the score's lengths as
  written.
- A group's `subtitle` is `null` when it has none; a voice's `name` is
  its part's name as a string.
- An event's `text` is `null` when its group's `note-label` is `none`; its
  `fill` is `null` when the group's `fill` is `none`, or when a custom
  scheme's look has no fill.

## Decisions layout makes

### The step

**Implemented** for the whole piece (`step-columns`, from every event's
start and end and the piece's length); per score, with its range and
pattern spans, **Implemented** (`feat/scores-range`).

The piece's times are rationals in pulses (ADR 0025); the figure counts
in columns. For each score, layout takes the **step**: the largest
duration that divides 1 pulse and every time the score prints, which is
every start and end of an event in the range, `from`, `to`, every
break and the system length, and, for each annotation row, its part's
pattern-span edges at its level and every free text's start (and end,
with a length) in the range (since `feat/collapsed-annotation`; before,
the pattern-name spans at the chosen level).
Since it divides a pulse, the step is 1/k of a pulse, and
`steps_per_pulse` is k. Every time is then converted to a whole number
of columns. `(notasi json)` refuses rationals, so a time left
unconverted fails loudly.

When the fastest notes are quarter pulses, k is 4; an excerpt without
them may get a coarser grid than the whole piece.

### The range and systems

- The score prints the piece from `from` to `to`. A note that started
  before `from` arrives cut, with `continued: true`, as at a system
  break; one that runs past `to` is cut there.
- The range is split into systems at every break and every
  `system-length` pulses from `from` (default: one system for the whole
  range). The last system may be shorter. An empty range has no systems.
- Events crossing a system boundary are cut at every boundary they
  cross. The first piece has `continued: false`; every later piece has
  `continued: true`; the template draws it without its name (05,
  ADR 0020).
- Each system carries its absolute start column (counted from the start
  of the piece), so numbers continue across systems and excerpts keep
  the piece's numbering; an event's `start` is relative to its system.
- With a pickup, the first system starts with it.

### Header and lines

Layout works out every header number and every line, for every column:

- `header.pulses`: one entry per column of the system, the pulse number
  at the first column of each pulse and `null` elsewhere. The number is
  the pulse within the cycle (within the piece, without a colotomy),
  printed as the score's `numbering` says: with `gong-last` pulse k of
  an N-pulse cycle is printed k, with `gong-first` (k mod N) + 1. The
  pickup is numbered as the last pulses of a cycle. `null` when
  `pulse-numbers?` is false.
- `header.cycles`: a list of `{column, text}`, the cycle number at the
  first column of each cycle in the system, once per cycle. `null` when
  `cycle-numbers?` is false. The pickup is cycle 0 (ADR 0043), so a
  system that starts in the pickup, or with it, also has a mark `0` at
  the pickup's first column it shows, first in the list.
- `header.cycle_label` and `header.pulse_label` (ADRs 0039, 0043; they
  replace version 2's `header.label`): the score's labels ("Cycle" and
  "Pulse" by default), each `null` when it is `""` or its row is not
  shown.
- (ADR 0043) `header.pulse_lines`, from the score's
  `background`: whether pulse lines run through the header rows.
- `lines`: one entry per column, for the line at its left edge: `cycle`
  where a cycle starts (just after the gong), `pulse` where another
  pulse starts, `none` elsewhere. Without a colotomy there are no
  `cycle` lines. Cycle lines are always drawn; whether a group draws
  its pulse lines is the group's `pulse_lines` (below).

### Groups and rows

- One block of rows per group, in the score's order. Every group appears
  in every system, with one voice per member part in the group's order,
  even when it has no events in that system.
- A group's label in each system is the long or short label, as its
  `labels` says: `first-long` gives the long label in the first system
  and the short one after.
- **`rows` `notes`**: `rows` is the group's row labels, top first,
  the same in every system. An event's `row` is the 0-based index of
  its row in that list. The rows are the keys the group actually plays
  in the score's range (`from` to `to`), in `group-row-keys` order: highest
  pitch at the top; stroke instruments give one row per stroke, in
  instrument order, so an excerpt shows only the keys it uses.
  By the group's `keys` (iteration 3): `used` is the rule
  above; `all` is every key of the instrument (every stroke of each
  stroke instrument, in instrument order, as blocks in the order their
  first part appears); a range is the instrument's keys from LOW to
  HIGH, both included, highest at the top. The reader has checked that
  every note played is among them. A group's parts are all pitched on one instrument or all on
  stroke instruments (02-piece.md, invariant 6), so its rows never mix
  ranges or pitches with strokes.
- **`rows` `parts`**: one row per member, labelled with its row label;
  an event's `row` is its part's row. Notes are told apart by their
  colour, and by their note labels when the group has them.
- **`rows` `compact`** (ADR 0055, since `feat/collapsed-compact`, in
  place of `single`): the members merged, with rows assigned by key;
  see "Compact rows" under "Iteration 5".
- On `notes` and compact rows, a unison (two parts striking one key at the same
  start, for the same length) is written once, under the first member
  that plays it; the reader has refused any other sharing of a cell
  (`notes-collide`). Decided in iteration 2's `feat/targets`: the norot
  kotekan of Jaya Semara opens each figure in unison.
- A chord gives one event per note, with the same start and duration,
  in `notes` rows. In `parts` and compact rows it is one event: its notes' labels joined by a space, with the
  look of its lowest note. A voice's events are sorted by start, then
  by row.

### Note text, fill and holds

- Each event's `fill` and `text_color` come from
  `(note-look style instrument note)` (see "Note style"), with the
  group's style; its `text` is the note label, chosen by the group's
  `note-label` (see "What a note shows" under "Iteration 5", built
  since `feat/collapsed-labels`).
- With `fill` `none`, `fill` is `null`: the template draws the name
  alone.
- With `holds` `dash`, every column a note is held after its first gets
  an event of one column with text `"-"`, `fill` `null`, in the note's
  row, so a sung line reads `nang - - ni'`. (ADR 0042) Only
  pitched notes are held; a stroke gets no dashes.
- (ADR 0042) An event of a stroke instrument is one column
  wide (`dur` 1), starting where the stroke starts, whatever its
  written duration; its text is still chosen by the written duration
  (`du` or `du'`). Pitched notes keep their widths.
- A stroke in a group's `display` shows that
  display name instead of its own, as text and in its row label.
- (ADRs 0041, 0043) Each group carries `pulse_lines` and
  `row_lines` from its `background`: `grid` both, `vertical` pulse
  lines only, `horizontal` row lines only, `empty` neither. Row lines
  are drawn between the rows of every kind of group.

### Pattern names (overlays)

Removed in `feat/collapsed-annotation` with `:pattern-names` (ADR
0057): the annotation row takes their place (see "The annotation row"
under "Iteration 5").

### Row labels

Row labels are chosen by the group's `row-labels` and
`row-label-octave?` (see "The pitch column" under "Iteration 5", built
since `feat/collapsed-labels`), in small grey text. By default a row
shows the pitch display name followed by the octave number (`i2`,
`note-row-label`); a stroke's label is its stroke display name, or
the one the group's `display` gives. With `parts` rows the labels are
the parts' row labels.

(ADR 0047) With `row-labels` `none`, every entry of the
group's `rows` is `""`. With `key-numbers?` true (pitched `notes` rows
only), the group's `key_numbers` holds each row's key number on its
instrument, counted from 1, as a string (`"4"` for the ugal's `a1`);
otherwise it is `null`. With `keys` `used` the numbers skip the keys not
shown; with `all` they run from 1.

### Note style

**Implemented** (v1 slice 2, `feat/layout-style`). Module
`(notasi style)`, which depends only on `(notasi piece)`; tests in
`tests/style.scm`.

**Implemented** (`feat/scores-form`): layout builds one style per group, from the group's
`scheme`, `palette` and `colors` (ADR 0032), with
`(make-style #:scheme #:palette #:pitch-colors)`. The reader has
checked the names and colours, so `make-style` does not fail here.
`(palette-names)` is what the reader checks palette names against
(ADR 0035).

How each note looks is decided by a **colour scheme**: a procedure
`(scheme style instrument note) → look`. A **look** is an immutable
record whose fields go straight into the JSON event:

| Field | Accessor | Meaning |
|---|---|---|
| fill | `look-fill` | the note's colour as a hex string, or `#f` for no box |
| text | `look-text` | the text in the note |
| text color | `look-text-color` | the text's colour as a hex string |

with `make-look` and `look?`. `(note-look style instrument note)`
calls the style's scheme and returns the look.

Layout calls the scheme for every event and knows nothing about
colours itself. Adding a way of colouring (by part, by octave, …) means
adding a scheme; the JSON and the Typst template don't change. Colours
are chosen in Guile and written as hex strings; the Typst side never
picks colours (ADR 0005).

**There is one scheme, `by-pitch`** (ADRs 0017, 0056; called
`by-degree` until `feat/collapsed-terms`, now an unknown name):

- **Pitched notes are coloured by pitch.** Pitch *k* of the
  scale (0-based, in scale order: ding 0, dong 1, …) gets colour *k* of
  the palette, in every octave and on every instrument, so a pitch has
  the same colour on the ugal and the reyong. With more pitches than
  colours, the palette repeats.
- The note's text is the pitch display name (`"i"` for `ding`, or
  the pitch name if the scale sets none), without the octave number,
  since the row already shows the octave. Layout replaces a look's
  text with the note label (ADR 0054, since `feat/collapsed-labels`),
  so a scheme chooses only the fill and the text colour.
- The text colour is `(text-color-for fill)`: white (`#ffffff`) if its
  WCAG contrast ratio with the fill is at least 4.5:1 (the minimum for
  normal text, which note text is: it isn't bold since `feat/gallery`;
  the threshold was 3:1, bold text's minimum, before), otherwise
  near-black (`#222222`).
  Contrast uses WCAG relative luminance of sRGB:
  each channel c/255 is linearised as c/12.92 if ≤ 0.04045, else
  ((c + 0.055)/1.055)^2.4; L = 0.2126 R + 0.7152 G + 0.0722 B; and the
  ratio of two luminances is (L1 + 0.05)/(L2 + 0.05), lighter over
  darker. So strong colours get white text and light ones dark text.
- **Strokes are grey boxes** (`fill` `#e6e6e6`, ADRs 0019, 0021 and
  0041: lighter than before, so the note border shows against it;
  clearly grey and no palette's colour),
  with the stroke display name (or its name) as text, in the colour
  `text-color-for` gives (near-black on this grey). The text shown is
  the note label (ADR 0054).
- Parts are not told apart by colour: polos and sangsih in one group
  are drawn in the same pitch colours, so the group shows the composite
  melody. The group's label and subtitle say which parts it holds. A
  group can mark its parts with `:part-marker` (ADR 0056, see "Part
  markers" under "Iteration 5").

**The style** is an immutable record made with
`(make-style #:key scheme palette pitch-colors)`; `(default-style)` is
`(make-style)`. Predicate `style?`; accessors `style-scheme`,
`style-palette`, `style-pitch-colors`.

| Field | Default | Meaning |
|---|---|---|
| `scheme` | `'by-pitch` | a scheme name, or a procedure `(style instrument note) → look` |
| `palette` | `'pastel1` | a palette name (below), or a list of colours |
| `pitch-colors` | `'()` | overrides by pitch name, e.g. `((ding . "#000000"))` |

`make-style` checks its arguments and raises an `&error` whose
irritants include the bad value for: an unknown scheme name (anything
that is neither `by-pitch` nor a procedure), an unknown palette name,
an empty colour list, a colour that is not a string `#rrggbb` (hex
digits in either case), or a `pitch-colors` entry that is not
`(SYMBOL . COLOUR)`, and for a `palette` or `pitch-colors` of the
wrong type (`#:palette 42`, `#:pitch-colors 'x`). For a malformed
entry, the irritants include the entry or its bad part. A pitch name
that no scale has is allowed; it is just never used. Keys are pitch
names, not aliases: `(i . "#000000")` overrides nothing, even where
`i` is an alias of `ding`. Overrides apply to pitched notes only;
strokes are always grey. The accessors return resolved values:
`style-scheme` a procedure (`by-pitch` for the name), `style-palette`
the list of colours, all colours in lowercase. `by-pitch` is exported,
so a custom scheme can fall back on it.


The colours notasi makes (palettes, overrides, text colours) are
lowercase `#rrggbb` strings; strokes are `#cccccc`. A custom
scheme's look is used as it is.

**Palettes.** The eight qualitative palettes of ColorBrewer (Cynthia
Brewer, colorbrewer2.org), at their largest size. `(palette-names)`
lists them in this order; `(palette-colors NAME)` returns a palette's
colours as a list (an `&error` for an unknown name).

| Name | Colours |
|---|---|
| `dark2` | `#1b9e77 #d95f02 #7570b3 #e7298a #66a61e #e6ab02 #a6761d #666666` |
| `set1` | `#e41a1c #377eb8 #4daf4a #984ea3 #ff7f00 #ffff33 #a65628 #f781bf #999999` |
| `set2` | `#66c2a5 #fc8d62 #8da0cb #e78ac3 #a6d854 #ffd92f #e5c494 #b3b3b3` |
| `set3` | `#8dd3c7 #ffffb3 #bebada #fb8072 #80b1d3 #fdb462 #b3de69 #fccde5 #d9d9d9 #bc80bd #ccebc5 #ffed6f` |
| `paired` | `#a6cee3 #1f78b4 #b2df8a #33a02c #fb9a99 #e31a1c #fdbf6f #ff7f00 #cab2d6 #6a3d9a #ffff99 #b15928` |
| `accent` | `#7fc97f #beaed4 #fdc086 #ffff99 #386cb0 #f0027f #bf5b17 #666666` |
| `pastel1` | `#fbb4ae #b3cde3 #ccebc5 #decbe4 #fed9a6 #ffffcc #e5d8bd #fddaec #f2f2f2` |
| `pastel2` | `#b3e2cd #fdcdac #cbd5e8 #f4cae4 #e6f5c9 #fff2ae #f1e2cc #cccccc` |

The values are copied into the code with ColorBrewer's attribution, as
its licence (Apache 2.0) requires. `pastel1` is the default (ADR 0021):
soft colours that leave the score calm, all of which take near-black
text. `dark2` gives strong colours with mostly white text.

### Sizes

- Label column widths are layout outputs, because the background and
  note layers in Typst must use identical fixed column widths (see 05).
  They are estimated from the number of characters, for the whole
  figure (all systems):
  - `label_width` (group labels and subtitles): 0.6em × the longest
    label or subtitle printed (long or short, as each system prints
    it) + 1.5em. A group of one row prints its subtitle after its label
    (05), so there the subtitle counts as the longer of its labels, two
    spaces and the subtitle (decided in `feat/targets`, for Baris).
    The header labels printed (`cycle_label`, `pulse_label`) count too,
    since they sit in the same column (`feat/drawing-header`).
  - `row_label_width` (row labels; `lane_width` before version 4,
    ADR 0059): 0.52em × the longest label + 1em; `"0.0em"` when no
    group shows row labels (ADR 0047). An annotation row's label
    counts, since it sits in that column.
  - (ADR 0047) `key_width` (key numbers): 0.52em × the
    longest number + 1em, or `"0.0em"` when no group shows key numbers.
  - Lengths are strings in `em` with one decimal, even when whole,
    rounded to the nearest, ties upward: `"10.5em"`, `"3.6em"`. With no
    groups the longest label counts as 0. Sizes come from the score's
    groups, whether or not there are systems.
- `cell_width` and `cell_height` are the score's `:cell-width` and
  `:cell-height` (`"2em"` by default, so a one-column note is a square),
  and `font_size` its `:font-size`.

## Iteration 5

**Implemented** (ADRs 0051, 0054–0057, 0059), over `feat/collapsed`'s
five slices. The group settings are 02's ("Iteration 5").

### The figure, version 4

**Implemented**: `version` 4, `rows`, `row` and `row_label_width`
since `feat/collapsed-labels`; each voice's `marker` since
`feat/collapsed-markers`; each group's `annotation` since
`feat/collapsed-annotation`.

Layout writes contract version 4 (ADR 0059; keys in "Public
interface"). `lanes`, `lane` and `lane_width` become `rows`, `row` and
`row_label_width`, with the same meanings. Each group has `annotation`
(below) where it had `overlays`, and each voice has `marker` (below).

### What a note shows

**Implemented** since `feat/collapsed-labels`.

Each event's `text` comes from the group's `note-label` (ADR 0054):

| `note-label` | A pitched note (jublag `o2`) | A stroke (kendang `du`) |
|---|---|---|
| `none` | `null` | `null` |
| `pitch-name` | `dong2` | `du` |
| `pitch-display-name` | `o2`; the damped form (`o'2`) on an event one column long | `du`, or `du'` on one column |
| `key-number` | `2`: its key number on the instrument, from 1 | as `pitch-display-name` |

- With `note-label-octave?` false, a pitched label has no octave
  number (`dong`, `o`). It never applies to key numbers or strokes.
- A stroke in the group's `display` shows that display name, as now.
- A chord on `parts` or `compact` rows is one event, its notes' labels
  joined by a space; with `none` its `text` is `null`.
- The scheme still gives each event's `fill` and `text_color`; layout
  replaces its look's text with the note label.
- With `fill` `none` the note label is drawn alone, as now; the reader
  has checked it isn't `none`.

### The pitch column

**Implemented** since `feat/collapsed-labels`, and for compact rows
since `feat/collapsed-compact`.

Each entry of a group's `rows` comes from its `row-labels` and
`row-label-octave?`:

| | `notes` rows | `parts` rows | `compact` rows |
|---|---|---|---|
| `pitch-name` | `dong2` (`dong` without the octave); a stroke's name | the part's row label | `""` |
| `pitch-display-name` | `o2` (`o`); a stroke display name | the part's row label | `""` |
| `none` | `""` | `""` | `""` |

With `none` on every group, `row_label_width` is `"0.0em"`, as
`lane_width` is now. `key_numbers` is `null` on `parts` and `compact`
rows.

### Compact rows

**Implemented** since `feat/collapsed-compact`.

`rows` `compact` (ADR 0055) replaces `single`: the group's parts merged
into one line, with a row added where different keys sound together.

- Two notes **sound together** when their boxes, as drawn, overlap: a
  pitched note from its start to its end, a stroke for its one column
  (ADR 0042). Only notes in the score's range count.
- **Rows are assigned by key**, once for the whole score: the keys the
  group plays in the score's range are taken in row order (highest
  pitch first; strokes in instrument order, as `group-row-keys` gives
  them), and each goes to the first row where it never sounds with a
  key already there, or to a new row below. So every key has one row
  in every system, and with no two keys ever sounding together the
  group has one row.
- A chord is one event, placed in the row of its lowest key, and
  counts as that key alone when rows are assigned.
- A unison (two parts on one key, with the same start and length) is
  one event, under the first part that plays it, as on `notes` rows.
  Any other overlap of one key's notes has been refused by the reader
  (`notes-collide`, ADR 0060).
- Every entry of `rows` is `""`.

### Part markers

**Implemented** since `feat/collapsed-markers`.

A group's `part-marker` (ADR 0056) gives each voice its `marker`:
`null` for a part with no entry, otherwise the entry's `symbol` (a
string, `"none"` when the entry gives none), `symbol_size`,
`symbol_color`, `border` and `border_width`. A key the entry leaves out
is `null`, the template's default. Layout chooses no defaults: the
default size and width are the template's, chosen by eye when built.

A unison drawn once is an event of the first part's voice only, so it
carries that part's marks. The template draws a voice's marks on each
of its notes, the later pieces of a note cut by a system break
included; a `-` of `:holds dash` gets none (decided for
`feat/collapsed-markers`).

### The annotation row

**Implemented** since `feat/collapsed-annotation`. A point's text runs
to the next text starting after it, and never into the next system:
it is cut at the end of the system it starts in, with no continued
piece.

A group with `annotation` (ADR 0057) gets the figure's `annotation` in
every system: its `position`, its `label` (`null` when it is `""` or
the group's `row-labels` is `none`) and its `items`. A group without
one has `annotation` `null`.

The items of the row, from its `part`:

1. **Pattern text**: the part's pattern spans of depth `level`. Each
   span's text is its short name, its long name or its annotation, as
   the row's `text` says; with `annotation`, a span whose annotation is
   `#f` shows its long name. Its `align` is the row's.
2. **Free text**: the part's `texts`. One with a length covers that
   many pulses from its start. A point covers from its start to the
   start of the next text in the row (free text or a pattern's), or to
   the end of the system; its `align` is always `"left"`.
3. **Free text wins**: a pattern item ends where a free text starts
   inside it. A pattern item whose start is covered by free text starts
   where that free text ends, if any of it is left.
4. Items are cut by the range and at system breaks, like events: a
   later piece has `continued: true`, and its text is written again.
5. Items are sorted by start. Where a pattern has no span at the
   level, the row is empty.

Layout doesn't measure text. The template aligns an item's text in its
span when it fits, and otherwise left-aligns it and cuts it at the
span's end; the row is always one line. Cycle lines run through the
row, pulse lines don't, and the group's frame encloses it (05).

## Slices (iteration 2)

**Implemented.** Milestone 2 of iteration 2 (`feat/scores`) is built in five
slices, each its own branch and PR into `dev`, started with
`/start-milestone <branch>`, after milestone 1 (03, "Slices"). Each
changes the reader's score checks (03, **[scores]**), the records (02),
layout, and the template and commands (05) as far as it needs, with the
examples, golden files and manual pages it affects.

1. **Implemented.** `feat/scores-form`: the `score` and `group` forms; the default
   score; groups with their effective settings (ADR 0033);
   `layout-score` with `notes` rows, `:note-names`, the colour options
   (one style per group) and the size options; `:system-length`; ADR
   0034's group check. Decided for this slice:
   - The reader reads, on a score, `:title`, `:system-length`,
     `:note-names`, `:scheme`, `:palette`, `:colors`, `:cell-width` and
     `:cell-height`; on a group, `:subtitle`, `:note-names`, `:scheme`,
     `:palette` and `:colors`. The options later slices build (`:rows`,
     `:fill`, `:holds`, `:pattern-names`, `:pattern-level`, `:labels`,
     `:short`, `:from`, `:to`, `:breaks`, `:cycle-numbers`,
     `:pulse-numbers`, `:numbering`, `:pulse-label`, a score's
     `:subtitle` and `:caption`, `:font-size`) raise `not-implemented`
     at the score's or group's line. The `score` and `group` records
     have every field of 02, the unbuilt ones at their defaults.
   - `layout-piece` is removed: `(layout-score piece score)` replaces
     it. `render-piece`, `notasi render` and the golden tests lay out a
     piece's first score (or its default score) until `--score`
     (slice 5).
   - The default score is named `default`.
   - The figure stays contract version 1: `:cell-width` and
     `:cell-height` go into `step_width` and `row_height` as written
     (default `"2em"`).
2. **Implemented.** `feat/scores-contract`: contract version 2 (ADR 0036): header rows,
   `:cycle-numbers`, `:pulse-numbers`, `:numbering`, `:pulse-label`,
   `lines` with heavier cycle lines (ADR 0037), `subtitle`, `caption`,
   `sizes`; the template and the entry file to match. Decided for this slice:
   - The reader now reads `:cycle-numbers`, `:pulse-numbers`,
     `:numbering`, `:pulse-label`, a score's `:subtitle` and `:caption`,
     and `:font-size`; the rest of the later options stay
     `not-implemented`.
   - Every group carries `overlays`, an empty list until slice 4, so the
     shape of contract version 2 is final here.
   - `font_size` is the score's `:font-size`, or `null` when it sets
     none; the entry file then uses 8pt, and a document (06) its own
     size.
   - `:cycle-numbers yes` on a piece without a colotomy has no cycles to
     number: `header.cycles` is `null`.
   - The line at a system's first column is always `none`: its left edge
     is the edge of the grid.
   - A cycle mark's `column` is counted from its system's start, like an
     event's `start`; a system in which no cycle starts has an empty
     `cycles` list, and the pickup has no mark (reversed by ADR 0043:
     the pickup's mark is `0`). Hiding one header row
     leaves the other and the lines.
3. **Implemented.** `feat/scores-rows`: `:rows parts` and `single`, row labels, `:fill
   none`, `:holds dash`, the damped and open names, and
   `needs-note-names` and `notes-collide`. Decided for this slice:
   - The reader now reads `:rows`, `:fill` and `:holds` on a score and
     on a group.
   - On a `parts` or `single` row a chord is one event: its notes'
     names joined by a space, with the look of its lowest note.
   - With `:holds dash`, a note's event takes only its first column;
     each column it is held after that gets a one-column `"-"` event.
   - On a `single` row two notes collide when any column has both
     sounding, held columns included, whatever parts they come from
     (`notes-collide`, at the group's line, at the time of the first
     shared column).
   - A note shows its damped form when it lasts no longer than one
     column, counting its whole length even if a system break cuts it.
4. **Implemented.** `feat/scores-overlays`: `:pattern-names` and `:pattern-level`,
   merged overlays, `pattern-names-overlap`, and the template's
   overlays. Decided for this slice:
   - The reader reads `:pattern-names` (`none`, `short`, `long`) and
     `:pattern-level` (a whole number from 0) on a score and a group.
   - Two spans at the chosen level that share some time and are not
     identical (the same start, end and text) are
     `pattern-names-overlap`, whatever their texts: at the group's line,
     `part` the later part, `time` the first shared time. Identical ones
     are merged.
   - Pattern-span edges at the chosen level count towards the step.
   - The template draws overlays in a layer of their own over the notes
     (a grid can't overlap its cells): a white box at 80% opacity with
     near-black text, centred over the overlay's columns and rows; a
     continued overlay shows its text again.
5. **Implemented.** `feat/scores-range`: `:from` and `:to`, `:breaks`, `:labels`;
   `render-piece #:score` and `notasi render --score`; golden files,
   previews and manual figures per score. Decided for this slice:
   - A position `(CYCLE PULSE)` names the pulse as this score prints
     it: the column under cycle CYCLE's number marked PULSE, in the
     score's `numbering`. With `gong-first`, cycle 2's stretch is
     printed 2, …, N, 1, so the whole cycle is `:from (2 2) :to (2 1)`.
   - The pickup is cycle 0, its pulses numbered as printed (the last
     pulses of a cycle): a one-pulse pickup in eight is `(0 8)`.
   - A break outside the score's range but inside the piece is ignored;
     outside the piece it is `bad-position`. A break at `from` changes
     nothing.
   - With `:labels first-long` the label column is as wide as the
     longest label printed in any system.
   - A `notes` group's rows are the notes it plays in the range, not
     in the whole piece.
   - `examples/gilak.nts` has two scores, so its golden files are
     `gilak.full.json` and `gilak.second-cycle.json`.

## Slices (iteration 3)

**Implemented.** Milestone 2 of iteration 3 (`feat/drawing`) is built in
four slices, each its own branch and PR into `dev`, started with
`/start-milestone <branch>`, after milestone 1 (`feat/syntax`). Each
changes the reader's checks (03, **[score-options]**), the records
(02), layout, and the template and commands (05) as far as it needs,
with the examples, golden files and manual pages it affects.

1. **Implemented.** `feat/drawing-header`: contract version 3 (ADR 0043);
   `:cycle-label` and the `"Pulse"` default (ADR 0039); the pickup's
   cycle mark `0`; header numbers centred over their pulse, without the
   `·` (ADR 0044). Decided for this slice: `version` becomes 3 and
   `header.label` becomes `cycle_label` and `pulse_label`; each later
   slice adds its own version 3 fields (`pulse_lines`, `row_lines` with
   `feat/drawing-lines`; `key_numbers`, `key_width` with
   `feat/drawing-rows`), since version 3 isn't released until the
   iteration ends.
2. **Implemented.** `feat/drawing-lines`: `:background` (row lines, pulse lines by
   group, ADR 0041); the frame line (ADR 0044); grey note borders and
   the lighter stroke grey (ADR 0041). Decided for this slice: the stroke grey is
   `#e6e6e6` (no palette's colour; text near-black), checked by eye; the
   border's width and grey are the template's, judged by eye. Each
   group's `pulse_lines` and `row_lines` come after `overlays`, and
   `header.pulse_lines` after `pulses`. The score record gets
   `background` (its own `:background`, else `grid`; 02), from which
   the header's `pulse_lines` comes.
3. **Implemented.** `feat/drawing-rows`: `:keys` and `outside-keys`; `:octave-numbers`;
   `:display`; `:key-numbers` and `:row-labels` (ADR 0047); strokes one
   column wide (ADR 0042). Decided for this slice: a `:keys` range on a score applies to
   its pitched `notes` groups, each of which must have LOW and HIGH
   among its keys (`bad-option` at the score's line otherwise); stroke,
   `parts` and `single` groups ignore an inherited range and show the
   keys they play, while a range written on such a group is an error.
   LOW and HIGH are written as in a part: a note's name, an alias name,
   or a key number (`(a1 u2)`, `(dang1 dung2)`, `(4 8)`).
4. **Implemented.** `feat/drawing-output`: `NAME_SCORE` file names and no `_` in score
   names (ADR 0040); the sans-serif font (ADR 0045). Decided for this slice:
   `(choose-font families)` in `(notasi typst)` returns the first of
   Helvetica, Arial, DejaVu Sans and Liberation Sans among FAMILIES, or
   "Libertinus Serif"; `(installed-fonts)` lists the families `typst
   fonts` prints; `write-entry-file` takes `#:font` (default
   "Libertinus Serif"); `render-piece` passes it the font chosen.

## Golden tests

Each example has one saved figure per score, in `tests/golden/`: a file
with only the default score keeps its plain name (`NAME.json`); a file
with scores has `NAME_SCORE.json` for each (ADR 0040). `make golden`
rewrites them
(**Implemented**), and `make check` fails on
any difference, on a figure with no saved copy, and on a saved copy with
no figure.

## Not layout's job

- Drawing, fonts, page size: Typst template.
- Validation, including the checks that need the music
  (`notes-collide`): reader.
- Fitting text: whether an annotation item fits its span, and cutting
  it: the template.

## Open questions

- A legend: one swatch per pitch, beside the figure or in the caption.

More colour schemes and systems one cycle long are in the
[backlog](../iterations/backlog.md).
