# 05 — Typst backend and JSON contract

Status: implemented (iterations 2 to 5). Implemented (v1, all three
slices, see "Slices"): the JSON writer, figure files, the entry file,
running Typst, `render-piece`, the template and the `notasi render`
command; contract version 2 (ADR 0036) with the template's header rows
and lines and the entry file's font size, subtitle and caption since
iteration 2's `feat/scores-contract`, and overlays since
`feat/scores-overlays`, and choosing a score (`--score`, `render-piece
#:score`) since `feat/scores-range`. Modules: `(notasi json-writer)`,
`(notasi typst)`, `(notasi command)` (Guile), `typst/notasi.typ` (Typst
template), `scripts/notasi` (the command). Contract version 3 (ADR
0043) with the template's header labels and centred numbers (ADR 0044)
since iteration 3's `feat/drawing-header`; the frame (ADR 0044), row
lines, pulse lines by group and grey note borders (ADR 0041) since
`feat/drawing-lines`; the key-number column and row labels left out
(ADR 0047) since `feat/drawing-rows`; a sans-serif font for standalone
figures (ADR 0045) and file names `NAME_SCORE` (ADR 0040) since
`feat/drawing-output`. The command line as a contract for editors,
and `notasi --version` (ADR 0048), since iteration 4's
`feat/emacs-preview-draw`; see "The command line as a contract".

`notasi render --all`, `--one-file`, `--list`, `--format` and `--ppi`,
`compile-typst #:ppi`, `render-score` and `render-one-file`, and one
line per file drawn on success (ADR 0061) since iteration 5's
`feat/render-all`. The manual's figures committed as PNG, and `make
preview` removed (ADR 0052), since `feat/examples`. Contract version
4's `rows`, `row` and `row_label_width` since `feat/collapsed-labels`;
each voice's `marker` and the template's part marks (ADR 0056) since
`feat/collapsed-markers`; the rest of contract version 4 and the
template's annotation row (ADRs 0057, 0059), without overlays, since
`feat/collapsed-annotation`. `--save-piece` (ADR 0058) since
`feat/save-piece`. The template's look reviewed in `feat/gallery`: no
bold but the standalone title, a line between an annotation row and
its group's rows, the last pulse closed on its right, and subtler
part-marker defaults: iteration 5's backend is built.

## Responsibility

- Guile side: serialise the layout `figure` to JSON, write a small `.typ`
  entry file, and optionally run `typst compile`.
- Typst side: draw exactly what the JSON says. No musical logic.

The same template draws scores inside Typst documents, where the figure
JSON arrives inside a side file instead (06, ADR 0016, proposed). So the template
must work in both places; see "Typst template design", points 6 and 7.

## JSON contract (version 4)

**Implemented** (ADR 0059), built over iteration 5's `feat/collapsed`:
version 3 below, with these changes (04 lists the keys in order, and
says how layout fills them). The template reads them all:

- `version` is 4.
- `lanes`, `lane` and `sizes.lane_width` become `rows`, `row` and
  `sizes.row_label_width`, with the same meanings.
- Each group's `overlays` is gone. In its place, `annotation` is
  `null` or the group's annotation row: `position` (`"above"` or
  `"below"`), `label` (a string or `null`) and `items`, each with
  `start`, `dur` (columns, relative to the system, as an event's),
  `text`, `align` (`"left"`, `"center"` or `"right"`) and `continued`.
- Each voice gets `marker`: `null`, or `symbol` (`"none"`, `"dot"`,
  `"ring"` or `"cross"`), `symbol_size` (a number, a fraction of the
  cell's narrower side), `symbol_color` and `border` (`"#rrggbb"`) and
  `border_width` (a length). Every field but `symbol` may be `null`,
  for the template's default.
- An event's `text` may be a key number (`"2"`); its shape is
  unchanged.

An excerpt (one group, arrays shortened):

```json
{
  "label": "Gangsa pemade",
  "subtitle": "norot",
  "rows": ["u3", "e3", "o3", "i3", "a2"],
  "key_numbers": null,
  "voices": [
    { "name": "polos", "marker": null, "events": [ ... ] },
    { "name": "sangsih",
      "marker": { "symbol": "dot", "symbol_size": null,
                  "symbol_color": null, "border": "#d62728",
                  "border_width": null },
      "events": [ ... ] }
  ],
  "annotation": {
    "position": "below",
    "label": null,
    "items": [
      { "start": 4, "dur": 8, "text": "1", "align": "left",
        "continued": false }
    ]
  },
  "pulse_lines": true,
  "row_lines": true
}
```

## JSON contract (version 3)

**Implemented** (ADR 0043): the header (`feat/drawing-header`), the
lines (`feat/drawing-lines`), and key numbers and one-column strokes
(`feat/drawing-rows`). Version 2
below, with these changes (04 lists the keys in order):

- `version` is 3.
- `header.label` becomes `header.cycle_label` and `header.pulse_label`,
  each a string or `null`. `header.pulse_lines` (boolean) says whether
  pulse lines run through the header rows.
- Each group gets `pulse_lines` and `row_lines` (booleans): whether its
  rows show pulse lines, and lines between its rows.
- Each group gets `key_numbers`, one string per row or `null`, and
  `sizes` gets `key_width` (ADR 0047). A group whose row labels are left
  out has `""` in `lanes`; an unused column is `"0.0em"` wide.
- `header.cycles` has a mark `"0"` at the pickup's first column when a
  system shows the pickup.
- A stroke's event is one column wide (ADR 0042), and strokes are a
  lighter grey (ADR 0041); the shape of an event is unchanged.

## JSON contract (version 2)

**Implemented** (ADR 0036; superseded by version 3, ADR 0043). Layout writes it (04, where the keys are listed
in order). An excerpt, for Jaya Semara's full score (arrays shortened):

```json
{
  "version": 2,
  "title": "Jaya Semara: pangecet",
  "subtitle": null,
  "steps_per_pulse": 4,
  "sizes": { "font_size": "8pt", "label_width": "9.3em",
             "lane_width": "2.0em", "cell_width": "2em",
             "cell_height": "2em" },
  "systems": [
    {
      "start": 0,
      "steps": 68,
      "header": {
        "label": null,
        "cycles": [{ "column": 4, "text": "1" }],
        "pulses": ["16", null, null, null, "1", null, null, null, "2"]
      },
      "lines": ["none", "none", "none", "none", "cycle", "none", "none",
                "none", "pulse"],
      "groups": [
        {
          "label": "Gangsa pemade",
          "subtitle": "norot",
          "lanes": ["u3", "e3", "o3", "i3", "a2"],
          "voices": [ { "name": "polos", "events": [ ... ] } ],
          "overlays": [
            { "start": 4, "dur": 32, "row": 0, "rows": 5,
              "text": "norot", "continued": false }
          ]
        }
      ]
    }
  ],
  "caption": null
}
```

Rules, besides those of version 1 below, which still hold:
- `header.pulses` and `lines` have one entry per column of the system.
  `header.pulses` (or `header.cycles`) is `null` when the score doesn't
  show that row. The numbers are already in the score's numbering; the
  template prints them as they are.
- A line is at the left edge of its column.
- `lanes` holds the row labels, whatever the rows are (notes, parts, or
  `""` for a single row).
- An overlay covers columns `start` to `start + dur` (relative to the
  system) and rows `row` to `row + rows` of its group.
- `font_size` is `null` in a document, where the document sets the size.
- `step_width` and `row_height` are gone: `cell_width` and
  `cell_height` replace them.

## JSON contract (version 1)

Replaced by version 2; kept for the record. An excerpt of `tests/golden/tenzer1.json`, the figure for
`examples/demos/tenzer1.nts` (both removed in 2026-11), the first group with its first event shown:

```json
{
  "version": 1,
  "title": "Eight-pulse gong cycle",
  "steps_per_pulse": 1,
  "sizes": { "label_width": "9.3em", "lane_width": "2.0em",
             "step_width": "2.0em", "row_height": "2.0em" },
  "systems": [
    {
      "start": 0,
      "steps": 9,
      "groups": [
        {
          "label": "Ugal",
          "subtitle": null,
          "lanes": ["e2", "o2", "i2", "a1"],
          "voices": [
            {
              "name": "ugal",
              "events": [
                { "start": 0, "dur": 1, "lane": 3, "text": null,
                  "fill": "#fed9a6", "text_color": "#222222",
                  "continued": false }
              ]
            }
          ]
        }
      ]
    }
  ],
  "caption": null
}
```

Rules:
- `start` in events is relative to the system; `system.start` is absolute.
- `lane` is a 0-based index into `lanes` (top row = 0).
- A chord produces one event per note, same start and duration.
- `fill`, `text` and `text_color` come from layout's colour scheme
  (04, "Note style"). `text` is `null` when the note's instrument
  doesn't show names (ADR 0019); `fill` is `null` only from a custom
  scheme, for a note drawn as text alone.
- All lengths are Typst length strings.
- Any change to this format increments `version` and updates the
  template and the golden tests in the same PR.

## Writing the figure file

**Implemented** (layout slice 4, `feat/layout-golden`), in `(notasi typst)`,
tests in `tests/typst.scm`:

```
(write-figure figure path)
```

writes FIGURE (from `layout-score`) to the file PATH as pretty JSON
(`write-json`), in UTF-8, ending with a newline, replacing any file
already there. The JSON is built before the file is opened, so a figure
that can't be written raises the writer's `&error` and leaves no file
behind (an existing file at PATH is left as it was). The rest of
`(notasi typst)` (the entry file, running Typst) is milestone 4.

## JSON writing

**Implemented** (layout slice 1, `feat/json`). A small JSON writer in
`(notasi json-writer)` instead of depending on guile-json. It keeps CI to a
plain `apt install guile-3.0`, and its output order is deterministic,
which golden tests need. Its tests are in `tests/json-writer.scm`.

```
(write-json value #:optional port #:key (pretty? #t))  ; port defaults to (current-output-port)
(json-string value #:key (pretty? #t)) → string
```

Scheme values map to JSON as guile-json does, so there is no
ambiguity between objects and arrays:

| Scheme | JSON |
|---|---|
| an alist, `((key . value) ...)`; `'()` | an object, keys in the given order; `{}` |
| a vector | an array |
| a string | a string |
| an exact integer, or a finite inexact real | a number (`number->string`) |
| `#t`, `#f` | `true`, `false` |
| the symbol `null` | `null` |

- Keys are symbols or strings, written as strings. A key given twice
  in one alist is an error; the symbol `a` and the string `"a"` are
  the same key.
- Strings are written as UTF-8. Only `"`, `\` and control characters
  (below U+0020) are escaped: `\n`, `\r`, `\t`, `\b`, `\f` by their
  short forms, others as `\u00XX` with lowercase hex.
- Anything else (another symbol, a rational such as `1/2`, an infinity
  or NaN, a pair that is not part of an alist, a procedure, a bad key)
  raises an `&error` whose irritants include the offending value.

Pretty output (the default, used for figure files and golden files):

- 2-space indent; each object member on its own line as `"key": value`.
- An array whose elements are all strings, numbers, booleans or `null`
  goes on one line, elements separated by `", "`: `["neng1", "nong1"]`.
  Any other array, including one that holds `{}` or `[]`, has one
  element per line.
- `{}` and `[]` for an empty object or array.
- `write-json` ends pretty output with a newline; `json-string` does
  not, and compact output never does.
- The caller chooses the port's encoding; `write-json` writes
  characters, not bytes.

Compact output (`#:pretty? #f`) has no spaces or newlines at all:
`{"a":1,"b":[1,2]}`.

## Typst template design

Lessons from the prototype (`doc/prototypes/score.typ`):

1. **Two layers.** A background grid draws the pulse lines; a
   transparent foreground grid draws labels, header and notes, placed on
   top with `place`. A single grid does not work: a note spanning
   several columns (`colspan`) would hide the lines it crosses even
   where it doesn't sound.
2. **Fixed column widths.** Both layers must align exactly, so the label
   column cannot be `auto`. Its width comes from the JSON `sizes`.
3. **Positioned cells.** Notes use `grid.cell(x:, y:, colspan:)`; empty
   cells are filled automatically, so rests need no handling.
4. **Notes as square blocks** filled with the event's `fill`, with
   text in its `text_color` when `text` isn't `null` (ADR 0019);
   an event whose `fill` is `null` is just its text, centred in the
   cell.
5. **Header row** with pulse numbers and `·` for other steps, numbered
   from `system.start`.
6. **`score` returns plain content**, systems stacked. It does not make
   a `figure`: in a document, the caption, numbering and label are the
   author's (06). For a standalone figure, the entry file puts the
   title above the score (see "The entry file and running Typst"); a
   document ignores `title` and `caption`.
7. **No page or font settings in the template.** In a document the
   score uses the document's font and text size. Only the standalone
   entry file sets the page (`width: auto, height: auto`) and font.

**Implemented** (slice 1, `feat/typst-template`): the template
`typst/notasi.typ` exports `score(data)`, where DATA is the figure
(05's contract, e.g. from `json("piece.json")`). It returns content:

- **Systems** are drawn in order, each as its own two-layer grid with
  its own header row and group labels, so each can be read alone,
  separated by a 1em gap. No systems: empty content.
- **Columns:** `label_width` (group label and subtitle), `lane_width`
  (row labels), then `steps` columns of `step_width`. **Rows:** a
  header row, then one row per entry of each group's `lanes`, all
  `row_height`.
- **Header:** at each step whose absolute number (`system.start` + i)
  is a multiple of `steps_per_pulse`, the pulse number
  ((`start` + i) / `steps_per_pulse` + 1); at other steps a
  grey `·`. A system that doesn't start on a pulse starts with `·`.
- **Background:** always white, with no shading (ADR 0020). Pulse
  lines (background layer) follow the same absolute steps: a thin
  vertical line (`0.5pt`, `luma(170)`) runs down the left of every step
  that starts a pulse.
- **Groups:** a horizontal rule (`0.8pt`, `luma(120)`) above each group
  and below the last. The group label slightly larger
  (`1.1em`), with its subtitle under it in grey italics when not
  `null` (after it, on the same line, for a group of one row, which
  has no room for two lines; `feat/targets`), spanning the group's
  rows. Row labels right-aligned, small
  (`0.85em`) and grey (`luma(140)`).
- **Notes** (ADRs 0019, 0020): a block filling its cells exactly, with
  no margin, in `fill`, with a thin white border (`0.5pt`) so that
  neighbouring notes stay apart (repeated strokes don't merge into what
  looks like one held note). The `text`, when not `null`, is centred in
  `text_color`. When `continued` is true the block has no text:
  it is the same note carrying on from the previous system. When `fill`
  is `null`, no block: just the text, centred, in
  `text_color`.
- No bold in the score (since `feat/gallery`): notes, numbers and
  labels are in the text's normal weight. Only the standalone title,
  which the entry file draws, is bold.
- Sizes relative to the text (`em`, `luma` greys), never absolute font
  sizes or fonts: the surrounding document or entry file sets those.

**Implemented** for version 2 (ADRs 0036, 0037); version 1's header
and pulse lines below are replaced by these. The overlays are drawn in a
third layer over the notes, since a grid can't overlap its cells:

- **Columns and rows** use `cell_width` and `cell_height` for the grid
  cells, and the label columns as before.
- **Header rows**, from `header`, top to bottom: a cycle row when
  `cycles` isn't `null`, with each cycle's number at its column;
  then a pulse row when `pulses` isn't `null`, with each number
  and a grey `·` in columns whose entry is `null`. `header.label`, when
  not `null`, is printed at the left of the pulse row, in the label
  column. The template does no counting.
- **Lines**, from `lines`, in the background layer: `pulse` as now
  (`0.5pt`, `luma(170)`), `cycle` heavier (`1pt`, `luma(90)`), down the
  left of the column, through the header and the groups. The last
  column is closed on its right by a pulse line, in every row, including
  annotation rows and rows without pulse lines (since `feat/gallery`).
- **Overlays**, in the foreground layer, drawn after the notes so they
  sit on top: one cell spanning the overlay's columns and rows, with
  its text centred, near-black (`#222222`), on a small white box at 80%
  opacity with a little padding, so it can be read over notes of any
  colour. A continued overlay is drawn the same way: its text is
  written again.
- Notes, labels, rules and the white background as in version 1. An
  event whose `fill` is `null` (`:fill none`) is its text alone, which
  also draws the `"-"` of `:holds dash`.

**Implemented** for version 4 (ADRs 0056, 0057, 0059), changing
version 3's drawing, which follows:

- **No overlays**: the third layer is gone.
- **The annotation row**: one row of `cell_height`, above or below the
  group's rows as `position` says, inside the group's frame and rules.
  No fill, no notes, and no row lines or pulse lines through it; cycle
  lines run through it. A light line (`0.5pt`, `luma(170)`) across the
  grid columns parts it from the group's rows (since `feat/gallery`). Its `label`, when not `null`, is in the
  row-label column, as a row label is. Each item spans its columns,
  with its text near-black (`#222222`) on one line: aligned as `align`
  says when it fits, otherwise left-aligned and cut at the item's last
  column. A continued item's text is written again. A figure without
  `annotation` (version 3) is drawn without the row. The text is 0.9em,
  with 2pt of room at each end.
- **Part marks**: in a voice with a `marker`, each note gets its
  symbol (a small filled `dot`, an open `ring` or a `cross`), centred
  in the note's cell, sized as `symbol_size` × the cell's narrower
  side, in `symbol_color` (near-black, `#222222`, by default); and,
  when `border` isn't `null`, a border of that colour and
  `border_width` in place of the grey one. A note's text and symbol
  are both drawn, centred, even when they overlap. The defaults, chosen
  by eye to be subtle (on Gambangan's kotekan, `feat/gallery`; 0.3 and
  1.5pt before), are a size of 0.12 and a width of 0.8pt: a little
  thicker than the grey border, so the mark is seen without hiding the
  note's fill. **Implemented** since `feat/collapsed-markers`, on
  every piece of a cut note, and never on a `"-"` of `:holds dash`. A note
  drawn as text alone (`fill` `null`) gets the symbol but no border.
- `lanes`, `lane` and `lane_width` are read as `rows`, `row` and
  `row_label_width` (**Implemented** since `feat/collapsed-labels`).

**Implemented** for version 3 (ADRs 0039, 0041, 0043, 0044, 0047),
changing the above:

- **Header labels** (**Implemented**): `cycle_label` at the left of the
  cycle row and `pulse_label` at the left of the pulse row, each in the
  group-label column, when not `null`.
- **Header numbers** (**Implemented**) are centred over their pulse: a
  pulse number spans `steps_per_pulse` columns from its entry, and a
  cycle number spans the first pulse of its cycle, so the two line up.
  No `·` in the other columns.
- **Lines** (**Implemented**): cycle lines and the rules between groups are always drawn.
  Pulse lines are drawn through the header when `header.pulse_lines` is
  true, and through a group's rows when its `pulse_lines` is. When a
  group's `row_lines` is true, a thin line (`0.5pt`, `luma(170)`, like
  a pulse line) runs between each two of its rows.
- **Columns** (**Implemented**, ADR 0047): `label_width`, then `key_width` (key
  numbers), then `lane_width` (row labels), then the grid. A key number
  is right-aligned in its column, the same size as a row label, in a
  lighter grey (`luma(170)`, judged by eye); a group whose
  `key_numbers` is `null` leaves the column empty. A column of width
  `"0.0em"` takes no space, so with neither column the group label sits
  next to the grid.
- **Frame** (**Implemented**): a vertical line at the left edge of the grid, between the
  row labels and the first column, like the rules between groups
  (`0.8pt`, `luma(120)`), from the first group's rule to the last, in
  every system. The template draws it; `lines[0]` stays `none`.
- **Note borders** (**Implemented**): each block has a thin grey
  border (`0.5pt`, `luma(150)`), the same on every edge: drawn
  centred on the block's edge, as Typst draws a stroke, so two touching
  blocks share one line. A cut note's pieces have a border all round;
  a continuation is still shown only by having no text. An event whose
  `fill` is `null` has no block and no border. There is no option for
  the border.

Tests (slice 1): `tests/template.scm` compiles every
`tests/golden/*.json` with `score` (from an entry file made in a
temporary folder) and fails if `typst compile` fails or prints a
warning. If `typst` isn't installed it says so and fails, since CI
always installs it. The committed images of `examples/gallery/` and
`examples/manual/` (`make images`, ADR 0052) show every change to how
figures look, and CI fails when one is out of date (07).

## The entry file and running Typst

**Implemented** for version 2: the entry file sets the text size from
`data.sizes.font_size` (it is always set for a standalone figure),
prints the `subtitle` under the title when not `null`, and the `caption`
under the score when not `null`, in italics. The rest is as below.

**Implemented** (slice 2, `feat/typst-render`), in `(notasi typst)`,
tests in `tests/typst.scm`. `(notasi typst)` comes after the reader and
layout in the pipeline and uses both; they never use it, so ADRs 0004
and 0008 still hold.

A standalone figure is drawn from three files in one folder: the figure
JSON, the template `notasi.typ`, and an **entry file** that Typst
compiles. `(write-entry-file path json-name)` writes the entry file to
PATH, reading the figure from JSON-NAME (relative to the entry file's
folder), exactly:

```typst
#import "notasi.typ": score
#set page(width: auto, height: auto, margin: 14pt, fill: white)
#set text(font: "FONT", size: 8pt)   // FONT: see below
#let data = json("JSON-NAME")
#if data.title != "" {
  block(below: 1em, text(weight: "bold", size: 1.2em, data.title))
}
#score(data)
```

- The title is shown in bold above the score, without "Figure 1:"
  numbering: a piece on its own page isn't a numbered figure. An empty
  title shows nothing. (`caption`, `null` for now, is not used.)
- The font (ADR 0045) is a sans serif found on the machine, the first
  of Helvetica, Arial, DejaVu Sans and Liberation Sans, or Libertinus
  Serif, built into Typst, when none is installed: `(choose-font
  families)`. `render-piece` asks `typst fonts` once (`(installed-fonts)`)
  and passes the family found to `write-entry-file` (`#:font`, default
  Libertinus Serif), which writes only that family, so Typst never
  warns about a missing one. A figure may look a little different from
  machine to machine. 8pt keeps labels small next to the 2em squares.

`(compile-typst typ-path out-path #:key ppi)` runs `typst compile` on TYP-PATH,
writing OUT-PATH, and returns OUT-PATH. The format comes from
OUT-PATH's extension: `.pdf`, `.png` (at 144 ppi) or `.svg`; any other
raises an `&error`. **Implemented** (ADR 0061): `#:ppi N` sets a PNG's
resolution (default 144), passed to Typst as `--ppi`; `#:ppi` given
for a `.pdf` or `.svg` is an `&error`, as on the command line. It runs with `--root` set to TYP-PATH's folder, so
everything the entry file reads must be in that folder. Errors are
plain `&error`s with a readable message:

- `typst` not on the PATH: the message says Typst 0.15.1 is needed and
  where to get it (https://github.com/typst/typst/releases).
- Typst fails: the message itself includes Typst's own output (so a
  musician sees what went wrong, not only a program reading the
  irritants); the irritants include TYP-PATH.

**Implemented** (`feat/scores-range`): `(render-piece nts-path out-path #:key score keep-in ppi)`
draws the score named SCORE (a symbol), or the piece's first score
without it, with `layout-score`; there is no `#:style`, since colours
come from the score (ADR 0032). A SCORE the piece doesn't have is an
`&error` whose message names the score and the file. Otherwise as
below.

**Implemented**: `render-piece` goes
from a `.nts` file to a picture in one step: read the piece (reader
errors pass through unchanged), lay out its first score (its default
score if it has none) with `layout-score`, write
`piece.json` (`write-figure`), copy the template, write `piece.typ`,
and compile to OUT-PATH. The three files go in a fresh temporary
folder under `$TMPDIR` (or `/tmp` when it isn't set) that is deleted
afterwards, even on failure; with
`#:keep-in DIR` they are written to DIR instead and kept, for
debugging. OUT-PATH is relative to the current directory. Returns
OUT-PATH. The template is found as `typst/notasi.typ` along Guile's
`%load-path`, like the `.nts` templates (03), so running with `-L .`
finds the repo's; if it can't be found, that is an `&error`.

**Implemented** (ADR 0061), for `--all` and `--one-file`, which read
the piece once:

- `(render-score piece score out-path #:key ppi keep-in)` draws one
  score of a piece already read, as `render-piece` does after reading;
  `render-piece` becomes reading and then `render-score`, and takes
  `#:ppi` too.
- `(render-one-file piece scores out-path #:key keep-in)`
  writes one PDF with each of SCORES on its own page, in order, each
  page sized to its score, with its title, subtitle and caption as a
  standalone figure has them. The entry file reads one figure file per
  score and puts a page break between them.
- Writing the piece (`--save-piece`, ADR 0058) is `(notasi export-piece)`,
  beside `(notasi json-writer)`; 02 ("Saving the piece") gives its format.
  Drawing one score reads the piece once and then uses `render-score`,
  so the piece read is the one saved.

None of these procedures changes the current directory. A relative
`%load-path` entry such as the `.` from `-L .` only works while the
current directory stays put, so the `notasi` command (slice 3) puts the
project's absolute path on `%load-path`, never `.`.

## The `notasi` command

**Implemented** (slice 3, `feat/notasi-command`). One command (ADR 0018);
this slice adds its `render` subcommand. The others (`typst`, `update`,
`watch`) are for documents (06).

```
notasi render PIECE.nts [-o OUT]
notasi --help
notasi render --help
```

- `render` draws PIECE.nts with `render-piece` and the default style.
  OUT defaults to PIECE.nts's folder and name with `.pdf`
  (`songs/gilak.nts` → `songs/gilak.pdf`); its extension (`.pdf`,
  `.png`, `.svg`) chooses the format. `-o OUT` and `--output OUT` are
  the same, and may come before or after PIECE.nts.
- On success it prints the path it wrote, on one line, to standard
  output, and exits with status 0.
- A notation mistake prints the reader's message exactly as it is
  (`gilak.nts:3: …`, the text the manual quotes) to standard error;
  any other problem (Typst missing or failing, a file that can't be
  read, an unsupported output extension) prints `notasi: ` and the
  error's message. Both exit with status 1. A file that can't be read
  is not a notation mistake, even though the reader is the one that
  finds it: the message is made readable from Guile's error and names
  the file.
- Every message notasi prints (paths, errors, usage) ends with exactly
  one newline.
- Using the command wrongly (no subcommand, an unknown subcommand or
  option, no PIECE.nts or more than one, `-o` without a value) prints
  `notasi: ` and what is wrong (naming the unknown subcommand or
  option), then the usage line, to standard
  error, and exits with status 2.
- `--help` prints the usage and a short description to standard output
  and exits with status 0.

**Implemented** (`feat/scores-range`): `notasi render PIECE.nts [--score NAME] [-o OUT]` (ADR
0031). `--score NAME` chooses the score; without it, the first score in
the file (or the default score) is drawn. `--score` without a value is a
usage error (status 2); a score the piece doesn't have prints `notasi: `
and the message, and exits with status 1. OUT defaults to
`PIECE.pdf` for the first score and `PIECE_NAME.pdf` with `--score`
(ADR 0040), so drawing several scores of
one file doesn't overwrite one picture with another.

**Implemented** (ADRs 0058, 0061):

```
notasi render PIECE.nts [--score NAME | --all [--one-file]]
              [--format pdf|png|svg] [--ppi N] [-o OUT]
              [--save-piece FILE]
notasi render PIECE.nts --list [--save-piece FILE]
```

- **`--all`** draws every score, each to `NAME_SCORE.EXT`, the first
  included (`jaya-semara_full.pdf`, `jaya-semara_kotekan.pdf`); a file
  with no `score` form draws its default score to `NAME.EXT`. Without
  `-o` the files go beside the piece. `-o DIR`, an existing folder or a
  path ending in `/`, puts them in DIR, named the same; a DIR that
  doesn't exist is made, with any missing folders above it. A path is
  printed as DIR, one `/`, and the name. The piece is
  read once: a notation mistake stops everything. A score Typst fails
  on prints `notasi: ` and the message, the others are still drawn,
  and the status is 1 if any failed.
- **`--format pdf|png|svg`** (default `pdf`) chooses the format, with
  or without `--all`. With `-o FILE` and no `--format`, FILE's
  extension chooses, as now; `--format` adds the extension to an `-o
  FILE` without one.
- **`--ppi N`**, a whole number greater than 0, sets a PNG's
  resolution (default 144).
- **`--one-file`**, with `--all`, writes one PDF, each score on its own
  page, in score order, each page sized to its score: `NAME.pdf` beside
  the piece, or `-o FILE.pdf`.
- **`--list`** prints the file's score names, one per line, in the
  order written, to standard output, and draws nothing, so it needs no
  Typst. A file with no `score` form prints nothing. It reads the
  piece, so a notation mistake is reported as when drawing (status
  1); otherwise the status is 0.
- **`--save-piece FILE`** (ADR 0058) saves the piece (02, "Saving the piece"):
  JSON for `.json`, an s-expression for `.scm`, JSON to standard
  output for `-`. The piece is saved once, after it is read and before
  anything is drawn, so it is saved even when a drawing fails. Saving
  prints nothing. With `-`, nothing else goes to standard output (no
  paths, no score names). With `--list`, it lists and saves, and draws
  nothing.
- **On success**, one line per file drawn, its path, in score order;
  one line for one score or for `--one-file`. With `--save-piece -`,
  the saved piece's JSON instead, and no paths.
- **Usage errors** (status 2): `--all` with `--score`; `--all` with
  `-o` naming a file, except with `--one-file`; `--one-file` without
  `--all`, or with `--format png` or `svg`, or an `-o` that isn't
  `.pdf`; `--format` disagreeing with `-o`'s extension (`-o out.png
  --format svg`); `--ppi` when the format isn't PNG, or not a whole
  number greater than 0; `--list` with `--all`, `--score`, `-o`,
  `--format`, `--ppi` or `--one-file`; `--save-piece`
  without a value, or with an extension other than `.json` or `.scm`.
  An unknown `--format` value is one too. Each prints
  `notasi: `, what is wrong and the usage, as now.
- `notasi --help` and `notasi render --help` describe the new options.

### The command line as a contract

**Implemented** (iteration 4's `feat/emacs-preview-draw`, ADR 0048).
Editor packages (08) draw by
running `notasi render` and reading what comes back, never by loading
notasi's modules. What they read is a contract; changing any of it
changes the editor package in the same PR:

- **Invocation:** `notasi render PIECE.nts [--score NAME] -o OUT`, with
  OUT's extension `.svg`, `.png` or `.pdf`, and the options in any
  order. The new options above (ADRs 0058, 0061) are part of the
  contract; editors use none of them, so the
  Emacs package doesn't change.
- **Exit status:** 0 when the picture was written; 1 for a problem
  with the piece or the drawing; 2 when the command was used wrongly.
- **On success:** OUT's path, on one line, to standard output, and
  nothing to standard error. With `--all`, one line per file drawn
  (ADR 0061); drawing one score, as an editor does, is still one line.
  With `--save-piece -`, standard output holds the saved piece's JSON
  alone (ADR 0058).
- **A mistake in the notation:** one line to standard error,
  `FILE:LINE: message`, where FILE is the file the mistake is in (the
  piece as given on the command line, or a template it uses) and LINE
  its line, counted from 1. notasi stops at the first mistake, so
  there is one such line. The message's wording is free; its form is
  not.
- **Any other problem** (Typst missing or failing, a file that can't
  be read, a score the piece doesn't have): one line to standard
  error starting `notasi: `, saying what is wrong. Exit status 1, as
  for a mistake; the form of the line tells them apart.

A Guile that can't be found is not notasi's to report: the script
can't start, and the shell says so.

**`notasi --version`** prints `notasi VERSION` on one line to standard
output and exits with status 0, where VERSION is notasi's version
(`0.5.0`, or `0.5.0-dev` on `dev`, as the tags are written without
the `v`). It is kept in one place, in `(notasi command)`, and set when
a version is tagged. `notasi --help` lists it in the usage.

The logic is in the module `(notasi command)`:
`(run-notasi args)` takes the arguments after the program name (a list
of strings), writes to the current output and error ports, and returns
the exit status; it never calls `exit`, so it can be tested directly
(`tests/command.scm`). `scripts/notasi` is an executable Guile script
that puts the project's absolute path on `%load-path` (found from the
script's own location, never `.`), then exits with
`(run-notasi (cdr (command-line)))`. It can be run as
`scripts/notasi …` from anywhere, or as `notasi …` with `scripts/` on
the PATH; installing it properly is an open question (07).

The user manual shows drawn scores (ADR 0052, since `feat/examples`):
a page shows an example's first score as `![…](figures/NAME.png)`, or
its score SCORE as `figures/NAME_SCORE.png` (ADR 0040). `make images`
draws each with `notasi render` (`--score SCORE`) from
`examples/manual/NAME.nts` into `examples/manual/images/`, where it is
committed. `make manual` copies them into `doc/manual/src/figures/`
(generated, not committed) and draws nothing, so the manual builds
with mdBook alone (07). `tests/manual.scm` checks that every image a
page shows has an example to draw it from, and `tests/examples.scm`
that it has its image.

## Version pinning

Typst is pre-1.0. Record the tested version in CLAUDE.md and the README;
the template needs positioned grid cells (Typst ≥ 0.11). The tested
version is **0.15.1**. CI installs exactly that version, so every PR
compiles the examples with it; upgrading Typst is a deliberate change
to the pin, with the golden figures and template checked again.

`make images` draws the committed images at one fixed `--ppi`, on
Linux with the pinned Typst (07, ADR 0052).

## Slices

Milestone 4 (`feat/typst-backend` in the build order) is built in three
slices, each its own branch and PR into `dev`, started with
`/start-milestone <branch>`:

1. **Implemented.** `feat/typst-template`: `typst/notasi.typ` and its `score`, following
   "Typst template design"; CI installs Typst 0.15.1; tests compile the
   golden figures.
2. **Implemented.** `feat/typst-render`: the rest of "Running Typst" on the Guile side:
   writing the entry file, `compile-typst`, and one procedure from a
   `.nts` file to a PDF.
3. **Implemented.** `feat/notasi-command`: `scripts/notasi render PIECE.nts` (ADR 0018)
   and the manual page "Drawing a score", as "The `notasi` command"
   describes.
