# 04 — Layout

Status: implemented (iteration 2): milestone 2, all five slices
(`feat/scores-form`, `feat/scores-contract`, `feat/scores-rows`,
`feat/scores-overlays`, `feat/scores-range`, see "Slices (iteration
2)"). `layout-score` lays out a score as contract version 2. "Note
style" is built from a score's options. Modules: `(notasi style)`, `(notasi layout)`; tests
in `tests/style.scm`, `tests/layout.scm` and `tests/golden.scm`.
Planned for iteration 3: contract version 3 (ADR 0043) with the header
labels, the pickup's cycle mark and each group's lines; strokes one
column wide (ADR 0042); a lighter stroke grey (ADR 0041); `:keys`,
`:octave-numbers` and `:display`; golden files named `NAME_SCORE`
(ADR 0040).

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

The figure is the JSON value of 05's contract itself, version 2 (ADR
0036), as `(notasi json)` writes it: alists with symbol keys for
objects, vectors for arrays, the symbol `null` for null. Writing it out
is then just `write-json`, and layout is tested with `equal?`. Keys come
in this order:

| Object | Keys |
|---|---|
| figure | `version` (2; **Planned**: 3, ADR 0043), `title`, `subtitle`, `steps_per_pulse`, `sizes`, `systems`, `caption` |
| sizes | `font_size`, `label_width`, `lane_width`, `cell_width`, `cell_height` |
| system | `start`, `steps`, `header`, `lines`, `groups` |
| header | `label`, `cycles`, `pulses` (**Planned**, version 3: `cycle_label`, `pulse_label`, `cycles`, `pulses`, `pulse_lines`) |
| cycle mark | `column`, `text` |
| group | `label`, `subtitle`, `lanes`, `voices`, `overlays` (**Planned**, version 3: then `pulse_lines`, `row_lines`) |
| voice | `name`, `events` |
| event | `start`, `dur`, `lane`, `text`, `fill`, `text_color`, `continued` |
| overlay | `start`, `dur`, `row`, `rows`, `text`, `continued` |

- `title`, `subtitle` and `caption` are the score's (`null` when it has
  none).
- `steps_per_pulse` is the number of columns in a pulse (see "The
  step").
- `font_size` is the score's `:font-size`, or `null` to leave it to the
  document; `cell_width` and `cell_height` are the score's lengths as
  written.
- A group's `subtitle` is `null` when it has none; a voice's `name` is
  its part's name as a string.
- An event's `text` is `null` unless its group has `note-names?`; its
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
every start and end of an event in the range, every pattern-span edge
at the chosen level, `from`, `to`, every break and the system length.
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
  `cycle-numbers?` is false. **Planned** (ADR 0043): the pickup is cycle
  0, so a system that starts in the pickup, or with it, also has a mark
  `0` at the pickup's first column it shows.
- `header.label`: the score's `pulse-label`, or `null`. **Planned** (ADRs
  0039, 0043): replaced by `header.cycle_label` and `header.pulse_label`,
  the score's labels ("Cycle" and "Pulse" by default), each `null` when
  it is `""` or its row is not shown.
- **Planned** (ADR 0043): `header.pulse_lines`, from the score's
  `background`: whether pulse lines run through the header rows.
- `lines`: one entry per column, for the line at its left edge: `cycle`
  where a cycle starts (just after the gong), `pulse` where another
  pulse starts, `none` elsewhere. Without a colotomy there are no
  `cycle` lines. Cycle lines are always drawn; whether a group draws
  its pulse lines is the group's `pulse_lines` (**Planned**, below).

### Groups and rows

- One block of rows per group, in the score's order. Every group appears
  in every system, with one voice per member part in the group's order,
  even when it has no events in that system.
- A group's label in each system is the long or short label, as its
  `labels` says: `first-long` gives the long label in the first system
  and the short one after.
- **`rows` `notes`**: `lanes` is the group's lane labels, top first,
  the same in every system. An event's `lane` is the 0-based index of
  its note in that list. Lanes are the notes the group actually plays
  in the score's range (`from` to `to`), in `group-lanes` order: highest
  pitch at the top; stroke instruments give one lane per stroke, in
  instrument order, so an excerpt shows only the keys it uses.
  **Planned** (iteration 3), by the group's `keys`: `used` is the rule
  above; `all` is every key of the instrument (every stroke of each
  stroke instrument, in instrument order, as blocks in the order their
  first part appears); a range is the instrument's keys from LOW to
  HIGH, both included, highest at the top. The reader has checked that
  every note played is among them. A group's parts are all pitched on one instrument or all on
  stroke instruments (02-piece.md, invariant 6), so its lanes never mix
  ranges or pitches with strokes.
- **`rows` `parts`**: one row per member, labelled with its row label;
  an event's `lane` is its part's row. Notes are told apart by their
  names (`note-names?` is true, invariant 7).
- **`rows` `single`**: one row for all the members, labelled `""`; every
  event's `lane` is 0. The reader has checked that no two notes share a
  cell.
- On `notes` rows, a unison (two parts striking one key at the same
  start, for the same length) is written once, under the first member
  that plays it; the reader has refused any other sharing of a cell
  (`notes-collide`). Decided in iteration 2's `feat/targets`: the norot
  kotekan of Jaya Semara opens each figure in unison.
- A chord gives one event per note, with the same start and duration,
  in `notes` rows. In `parts` and `single` rows it is one event: its
  notes' names joined by a space, with the look of its lowest note. A voice's events
  are sorted by start, then by lane.

### Note text, fill and holds

- Each event's `text`, `fill` and `text_color` come from
  `(note-look style instrument note)` (see "Note style"), with the
  group's style.
- With `note-names?`, the text is the note's damped form when the event
  lasts no longer than one column, and its display form otherwise
  (`note-display` with `#:damped?`). Without it, `text` is `null`.
- With `fill` `none`, `fill` is `null`: the template draws the name
  alone.
- With `holds` `dash`, every column a note is held after its first gets
  an event of one column with text `"-"`, `fill` `null`, in the note's
  row, so a sung line reads `nang - - ni'`. **Planned** (ADR 0042): only
  pitched notes are held; a stroke gets no dashes.
- **Planned** (ADR 0042): an event of a stroke instrument is one column
  wide (`dur` 1), starting where the stroke starts, whatever its
  written duration; its text is still chosen by the written duration
  (`du` or `du'`). Pitched notes keep their widths.
- **Planned** (iteration 3): a stroke in a group's `display` shows that
  form instead of its own, as text and in its lane label.
- **Planned** (ADRs 0041, 0043): each group carries `pulse_lines` and
  `row_lines` from its `background`: `grid` both, `vertical` pulse
  lines only, `horizontal` row lines only, `empty` neither. Row lines
  are drawn between the rows of every kind of group.

### Pattern names (overlays)

With `pattern-names` `short` or `long`, layout names each pattern use at
the group's `pattern-level`:

- It takes the spans of that depth from the group's member parts, with
  their short or long names, and merges identical ones (the same start,
  end and text). The reader has checked that different names don't
  overlap in one group.
- Each becomes an overlay: its columns (`start`, `dur`), the rows it
  covers (`row` 0, `rows` the group's row count) and its text.
- An overlay cut by a system boundary, or by the range, is split like a
  note: the later piece has `continued: true`, and its text is written
  again.

### Lane labels

Lane labels show the display form followed by the octave number
(`i2`) in small grey text; a stroke's label is its display form
(**Implemented**, `note-label`). With `parts` rows the labels are the
row labels. **Planned** (iteration 3): with `octave-numbers?` false, a
pitched lane is labelled with its display form alone (`i`), even when
two lanes then read alike; a stroke in the group's `display` is
labelled with that form.

### Note style

**Implemented** (v1 slice 2, `feat/layout-style`). Module
`(notasi style)`, which depends only on `(notasi piece)`; tests in
`tests/style.scm`.

**Implemented** (`feat/scores-form`): layout builds one style per group, from the group's
`scheme`, `palette` and `colors` (ADR 0032), with
`(make-style #:scheme #:palette #:degree-colors)`. The reader has
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

**v1 has one scheme, `by-degree`** (ADR 0017):

- **Pitched notes are coloured by scale degree.** Degree *k* of the
  scale (0-based, in scale order: ding 0, dong 1, …) gets colour *k* of
  the palette, in every octave and on every instrument, so a pitch has
  the same colour on the ugal and the reyong. With more degrees than
  colours, the palette repeats.
- The note's text is the degree's display form (`"i"` for `ding`, or
  the degree name if the scale sets none), without the octave number,
  since the lane already shows the octave.
- The text colour is `(text-color-for fill)`: white (`#ffffff`) if its
  WCAG contrast ratio with the fill is at least 3:1 (the minimum for
  bold text, which note text is), otherwise near-black (`#222222`).
  Contrast uses WCAG relative luminance of sRGB:
  each channel c/255 is linearised as c/12.92 if ≤ 0.04045, else
  ((c + 0.055)/1.055)^2.4; L = 0.2126 R + 0.7152 G + 0.0722 B; and the
  ratio of two luminances is (L1 + 0.05)/(L2 + 0.05), lighter over
  darker. So strong colours get white text and light ones dark text.
- **Strokes are grey boxes** (`fill` `#cccccc`, ADRs 0019 and 0021;
  **Planned**, ADR 0041: a lighter grey, so the note border shows
  against it, chosen by eye, clearly grey and no palette's colour),
  with the stroke's display form (or its name) as text, in the colour
  `text-color-for` gives (near-black on this grey). The text is shown
  when the group has `note-names?` (ADR 0031).
- Parts are not told apart: polos and sangsih in one group are drawn in
  the same pitch colours, so the group shows the composite melody.
  The group's label and subtitle say which parts it holds.

**The style** is an immutable record made with
`(make-style #:key scheme palette degree-colors)`; `(default-style)` is
`(make-style)`. Predicate `style?`; accessors `style-scheme`,
`style-palette`, `style-degree-colors`.

| Field | Default | Meaning |
|---|---|---|
| `scheme` | `'by-degree` | a scheme name, or a procedure `(style instrument note) → look` |
| `palette` | `'pastel1` | a palette name (below), or a list of colours |
| `degree-colors` | `'()` | overrides by degree name, e.g. `((ding . "#000000"))` |

`make-style` checks its arguments and raises an `&error` whose
irritants include the bad value for: an unknown scheme name (anything
that is neither `by-degree` nor a procedure), an unknown palette name,
an empty colour list, a colour that is not a string `#rrggbb` (hex
digits in either case), or a `degree-colors` entry that is not
`(SYMBOL . COLOUR)`, and for a `palette` or `degree-colors` of the
wrong type (`#:palette 42`, `#:degree-colors 'x`). For a malformed
entry, the irritants include the entry or its bad part. A degree name
that no scale has is allowed; it is just never used. Keys are degree
names, not aliases: `(i . "#000000")` overrides nothing, even where
`i` is an alias of `ding`. Overrides apply to pitched notes only;
strokes are always grey. The accessors return resolved values:
`style-scheme` a procedure (`by-degree` for the name), `style-palette`
the list of colours, all colours in lowercase. `by-degree` is exported,
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
  - `lane_width` (lane and row labels): 0.52em × the longest label +
    1em.
  - Lengths are strings in `em` with one decimal, even when whole,
    rounded to the nearest, ties upward: `"10.5em"`, `"3.6em"`. With no
    groups the longest label counts as 0. Sizes come from the score's
    groups, whether or not there are systems.
- `cell_width` and `cell_height` are the score's `:cell-width` and
  `:cell-height` (`"2em"` by default, so a one-column note is a square),
  and `font_size` its `:font-size`.

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
   - A `notes` group's lanes are the notes it plays in the range, not
     in the whole piece.
   - `examples/gilak.nts` has two scores, so its golden files are
     `gilak.full.json` and `gilak.second-cycle.json`.

## Golden tests

Each example has one saved figure per score, in `tests/golden/`: a file
with only the default score keeps its plain name (`NAME.json`); a file
with scores has `NAME.SCORE.json` for each (**Planned**, ADR 0040:
`NAME_SCORE.json`). `make golden` rewrites them
(**Implemented**), and `make check` fails on
any difference, on a figure with no saved copy, and on a saved copy with
no figure.

## Not layout's job

- Drawing, fonts, page size: Typst template.
- Validation, including the checks that need the music
  (`notes-collide`, `pattern-names-overlap`): reader.

## Open questions

- A legend: one swatch per degree, beside the figure or in the caption.
- Drawing the full range of an instrument (all its keys as lanes),
  rather than only the notes used.

More colour schemes and systems one cycle long are in the
[backlog](../iterations/backlog.md).
