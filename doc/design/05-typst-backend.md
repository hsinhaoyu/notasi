# 05 — Typst backend and JSON contract

Status: implemented (iteration 2). Implemented (v1, all three
slices, see "Slices"): the JSON writer, figure files, the entry file,
running Typst, `render-piece`, the template and the `notasi render`
command; contract version 2 (ADR 0036) with the template's header rows
and lines and the entry file's font size, subtitle and caption since
iteration 2's `feat/scores-contract`, and overlays since
`feat/scores-overlays`, and choosing a score (`--score`, `render-piece
#:score`) since `feat/scores-range`. Modules: `(notasi json)`,
`(notasi typst)`, `(notasi command)` (Guile), `typst/notasi.typ` (Typst
template), `scripts/notasi` (the command). Planned for iteration 3:
contract version 3 (ADR 0043); the template's labels, centred header
and frame (ADR 0044), row lines, pulse lines by group and grey note
borders (ADR 0041); a sans-serif font for standalone figures (ADR
0045); file names `NAME_SCORE` (ADR 0040).

## Responsibility

- Guile side: serialise the layout `figure` to JSON, write a small `.typ`
  entry file, and optionally run `typst compile`.
- Typst side: draw exactly what the JSON says. No musical logic.

The same template draws scores inside Typst documents, where the figure
JSON arrives inside a side file instead (06, ADR 0016, proposed). So the template
must work in both places; see "Typst template design", points 6 and 7.

## JSON contract (version 3)

**Planned** (ADR 0043). Version 2 below, with these changes (04 lists the
keys in order):

- `version` is 3.
- `header.label` becomes `header.cycle_label` and `header.pulse_label`,
  each a string or `null`; `header.pulse_lines` (boolean) says whether
  pulse lines run through the header rows.
- Each group gets `pulse_lines` and `row_lines` (booleans): whether its
  rows show pulse lines, and lines between its rows.
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
`examples/tenzer1.nts` (the first group, with its first event shown):

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
`(notasi json)` instead of depending on guile-json. It keeps CI to a
plain `apt install guile-3.0`, and its output order is deterministic,
which golden tests need. Its tests are in `tests/json.scm`.

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
   bold text in its `text_color` when `text` isn't `null` (ADR 0019);
   an event whose `fill` is `null` is just its text, centred in the
   cell.
5. **Header row** with bold pulse numbers and `·` for other steps, numbered
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
  (lane labels), then `steps` columns of `step_width`. **Rows:** a
  header row, then one row per lane of each group, all `row_height`.
- **Header:** at each step whose absolute number (`system.start` + i)
  is a multiple of `steps_per_pulse`, the pulse number
  ((`start` + i) / `steps_per_pulse` + 1) in bold; at other steps a
  grey `·`. A system that doesn't start on a pulse starts with `·`.
- **Background:** always white, with no shading (ADR 0020). Pulse
  lines (background layer) follow the same absolute steps: a thin
  vertical line (`0.5pt`, `luma(170)`) runs down the left of every step
  that starts a pulse.
- **Groups:** a horizontal rule (`0.8pt`, `luma(120)`) above each group
  and below the last. The group label in bold, slightly larger
  (`1.1em`), with its subtitle under it in grey italics when not
  `null` (after it, on the same line, for a group of one row, which
  has no room for two lines; `feat/targets`), spanning the group's
  rows. Lane labels right-aligned, small
  (`0.85em`) and grey (`luma(140)`).
- **Notes** (ADRs 0019, 0020): a block filling its cells exactly, with
  no margin, in `fill`, with a thin white border (`0.5pt`) so that
  neighbouring notes stay apart (repeated strokes don't merge into what
  looks like one held note). The `text`, when not `null`, is centred in
  bold in `text_color`. When `continued` is true the block has no text:
  it is the same note carrying on from the previous system. When `fill`
  is `null`, no block: just the text, centred and bold, in
  `text_color`.
- Sizes relative to the text (`em`, `luma` greys), never absolute font
  sizes or fonts: the surrounding document or entry file sets those.

**Implemented** for version 2 (ADRs 0036, 0037); version 1's header
and pulse lines below are replaced by these. The overlays are drawn in a
third layer over the notes, since a grid can't overlap its cells:

- **Columns and rows** use `cell_width` and `cell_height` for the grid
  cells, and the label columns as before.
- **Header rows**, from `header`, top to bottom: a cycle row when
  `cycles` isn't `null`, with each cycle's number in bold at its column;
  then a pulse row when `pulses` isn't `null`, with each number in bold
  and a grey `·` in columns whose entry is `null`. `header.label`, when
  not `null`, is printed at the left of the pulse row, in the label
  column. The template does no counting.
- **Lines**, from `lines`, in the background layer: `pulse` as now
  (`0.5pt`, `luma(170)`), `cycle` heavier (`1pt`, `luma(90)`), down the
  left of the column, through the header and the groups.
- **Overlays**, in the foreground layer, drawn after the notes so they
  sit on top: one cell spanning the overlay's columns and rows, with
  its text centred, near-black (`#222222`), on a small white box at 80%
  opacity with a little padding, so it can be read over notes of any
  colour. A continued overlay is drawn the same way: its text is
  written again.
- Notes, labels, rules and the white background as in version 1. An
  event whose `fill` is `null` (`:fill none`) is its text alone, which
  also draws the `"-"` of `:holds dash`.

**Planned** for version 3 (ADRs 0039, 0041, 0043, 0044), changing the
above:

- **Header labels:** `cycle_label` at the left of the cycle row and
  `pulse_label` at the left of the pulse row, each in the group-label
  column, when not `null`.
- **Header numbers** are centred over their pulse: a pulse number spans
  `steps_per_pulse` columns from its entry, and a cycle number spans the
  first pulse of its cycle, so the two line up. No `·` in the other
  columns.
- **Lines:** cycle lines and the rules between groups are always drawn.
  Pulse lines are drawn through the header when `header.pulse_lines` is
  true, and through a group's rows when its `pulse_lines` is. When a
  group's `row_lines` is true, a thin line (`0.5pt`, `luma(170)`, like
  a pulse line) runs between each two of its rows.
- **Frame:** a vertical line at the left edge of the grid, between the
  lane labels and the first column, like the rules between groups
  (`0.8pt`, `luma(120)`), from the first group's rule to the last, in
  every system. The template draws it; `lines[0]` stays `none`.
- **Note borders:** each block has a thin grey border (starting point
  `0.5pt`, `luma(150)`, judged by eye), the same on every edge: drawn
  centred on the block's edge, as Typst draws a stroke, so two touching
  blocks share one line. A cut note's pieces have a border all round;
  a continuation is still shown only by having no text. An event whose
  `fill` is `null` has no block and no border. There is no option for
  the border.

Tests (slice 1): `tests/template.scm` compiles every
`tests/golden/*.json` with `score` (from an entry file made in a
temporary folder) and fails if `typst compile` fails or prints a
warning. If `typst` isn't installed it says so and fails, since CI
always installs it. `make preview` draws each example to
`build/preview/NAME.png` (not committed) with `render-piece`, for a
person to check by eye; every PR that changes how figures look is
checked that way.

## The entry file and running Typst

**Implemented** for version 2: the entry file sets the text size from
`data.sizes.font_size` (it is always set for a standalone figure),
prints the `subtitle` under the title when not `null`, and the `caption`
under the score when not `null`, in italics. The rest is as below.

**Implemented** (slice 2, `feat/typst-render`), in `(notasi typst)`,
tests in `tests/typst.scm`. `(notasi typst)` comes after the reader and
layout in the pipeline and uses both; they never use it, so ADRs 0004
and 0008 still hold. `make preview` draws each example with
`render-piece`.

A standalone figure is drawn from three files in one folder: the figure
JSON, the template `notasi.typ`, and an **entry file** that Typst
compiles. `(write-entry-file path json-name)` writes the entry file to
PATH, reading the figure from JSON-NAME (relative to the entry file's
folder), exactly:

```typst
#import "notasi.typ": score
#set page(width: auto, height: auto, margin: 14pt, fill: white)
#set text(font: "Libertinus Serif", size: 8pt)   // Planned: FONT, see below
#let data = json("JSON-NAME")
#if data.title != "" {
  block(below: 1em, text(weight: "bold", size: 1.2em, data.title))
}
#score(data)
```

- The title is shown in bold above the score, without "Figure 1:"
  numbering: a piece on its own page isn't a numbered figure. An empty
  title shows nothing. (`caption`, `null` for now, is not used.)
- **Planned** (ADR 0045): the font is a sans serif found on the machine,
  the first of Helvetica, Arial, DejaVu Sans and Liberation Sans (the
  list is settled by eye), or Libertinus Serif when none is installed.
  `(notasi typst)` asks `typst fonts` once and passes the family found
  to `write-entry-file` (`#:font`, default Libertinus Serif), which
  writes only that family, so Typst never warns about a missing one.
  A figure may look a little different from machine to machine.
  Until then:
- The font is Libertinus Serif, which is built into Typst, so a figure
  looks the same on every machine; 8pt keeps labels small next to the
  2em squares.

`(compile-typst typ-path out-path)` runs `typst compile` on TYP-PATH,
writing OUT-PATH, and returns OUT-PATH. The format comes from
OUT-PATH's extension: `.pdf`, `.png` (at 144 ppi) or `.svg`; any other
raises an `&error`. It runs with `--root` set to TYP-PATH's folder, so
everything the entry file reads must be in that folder. Errors are
plain `&error`s with a readable message:

- `typst` not on the PATH: the message says Typst 0.15.1 is needed and
  where to get it (https://github.com/typst/typst/releases).
- Typst fails: the message itself includes Typst's own output (so a
  musician sees what went wrong, not only a program reading the
  irritants); the irritants include TYP-PATH.

**Implemented** (`feat/scores-range`): `(render-piece nts-path out-path #:key score keep-in)`
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
`PIECE.pdf` for the first score and `PIECE.NAME.pdf` with `--score`
(**Planned**, ADR 0040: `PIECE_NAME.pdf`), so drawing several scores of
one file doesn't overwrite one picture with another.

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

The user manual shows drawn scores: `make manual` first draws each
`doc/manual/src/examples/NAME.nts` that a page shows as an image
(`![…](figures/NAME.svg)`) to `doc/manual/src/figures/NAME.svg` with
`notasi render`, then builds the book. `figures/` is generated, not
committed, so pictures never go stale. A page can show
another score of the example as `figures/NAME.SCORE.svg` (**Planned**,
ADR 0040: `figures/NAME_SCORE.svg`), drawn with `--score SCORE`. The manual's CI job installs
Guile and Typst 0.15.1 for this; `tests/manual.scm` checks that every
image a page shows has an example to draw it from.

## Version pinning

Typst is pre-1.0. Record the tested version in CLAUDE.md and the README;
the template needs positioned grid cells (Typst ≥ 0.11). The tested
version is **0.15.1**. CI installs exactly that version, so every PR
compiles the examples with it; upgrading Typst is a deliberate change
to the pin, with the golden figures and template checked again.

`make preview` (`scripts/preview.scm`) draws each example's every score
to `build/preview/NAME.png`, or `NAME.SCORE.png` for a file with scores
(**Planned**, ADR 0040: `NAME_SCORE.png`), matching the golden files
(04).

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
