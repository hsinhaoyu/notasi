# 02 — Piece

Status: implemented (iterations 2, 3 and 5). `degree` (with `damped`) and
`instrument` (without `show-names?`) since `feat/music-syntax`; times as
exact rationals in pulses, with `part-end` and `events-at` taking a
time, since `feat/music-durations`; `pickup`, `colotomies`,
`part-origin`, the `colotomy` record, `time->position` and
`position->time` since `feat/music-colotomy`; `patterns`, `part-spans`,
the `pattern` and `pattern-span` records since `feat/music-patterns`;
`scores`, the `score` and `group` records and `piece-score` since
`feat/scores-form`, and `note-display #:damped?` since
`feat/scores-rows`, and the score's `cycle-label` and the "Pulse"
default since `feat/drawing-header`, and the score's and group's
`background` since `feat/drawing-lines`, and the group's `keys`,
`octave-numbers?`, `key-numbers?`, `row-labels?` and `display`,
`note-label`'s `#:octave?` and invariant 10 since `feat/drawing-rows`,
and invariant 9 since `feat/drawing-output`. The glossary's names
(`pitch`, `scale-pitches`, `note-pitch`) and the piece's `info` since
iteration 5's `feat/collapsed-terms`; the group's label settings,
`group-row-keys` and `note-row-label` since `feat/collapsed-labels`;
`rows` `compact` since `feat/collapsed-compact`; the `marker` record
and the group's `part-marker` since `feat/collapsed-markers`; pattern
and span annotations, a part's `texts`, the `free-text` and
`annotation-row` records and the group's `annotation` since
`feat/collapsed-annotation`, so every record change of "Iteration 5"
is built. Saving the piece (ADR 0058) since `feat/save-piece`, in
`(notasi export-piece)`. Tests in `tests/piece.scm` and `tests/export-piece.scm`.

Everything in this document is **Implemented** unless it says otherwise.

A `piece` record is the single source of truth after reading. Layout
consumes it, with one of its scores; nothing downstream looks at the
source text.

## Principles

- Plain immutable SRFI-9 records. No mutation after construction.
- Time is in pulses, as exact rationals, starting at 0 (ADR 0025). The
  piece has no step: layout chooses one per score.
- The music and how it is printed are kept apart (ADR 0031). Parts and
  events carry no printing settings; scores, stored on the piece, carry
  them all.
- Notes are referred to by their index within their instrument (0-based
  internally; the notation is 1-based, and the reader converts).
- No pitch or tuning data on notes.
- Every definition keeps a source location (file and line), for error
  messages: scales, pitches, instruments, colotomies, patterns, parts,
  scores and groups. The file matters because definitions can come from
  templates. `note`, `event` and `pattern-span` have none: they come
  from atoms, which carry no position (see 03-reader.md). `piece` has
  none either: errors about the piece form are found while reading,
  before the record exists. A generated part has its colotomy's location.
- The piece holds the definitions after templates are merged: a
  definition the piece replaced is gone, and template definitions the
  piece never uses are kept. They are harmless, because layout only
  draws parts that a score names.
- Positions (cycle and pulse) are derived from time, never stored.

## Records

Each record has the usual SRFI-9 interface: a constructor
`make-<record>` that takes the fields positionally in the order listed
below, a predicate `<record>?`, and an accessor `<record>-<field>` for
each field (e.g. `make-event`, `event?`, `event-start`).

```
source-location                        (implemented, unchanged)
  file     : string | #f               the file the form came from; #f for
                                       a piece read from a string or port
                                       (its templates still have files)
  line     : integer                   1-based

piece
  title       : string
  length      : rational               pulses, including the pickup
  pickup      : rational               0 without a colotomy
  colotomies  : list of (start . colotomy)
                                       the colotomy in force from each start;
                                       one entry, or '() without a colotomy
  scales      : list of scale          includes stroke sets
  instruments : list of instrument
  patterns    : list of pattern
  parts       : list of part           written parts, then generated ones
  scores      : list of score          at least one (the default score)
  info        : list of (symbol . string)
                                       the piece information (01), in the
                                       order written; '() for none. The
                                       last argument of make-piece

scale                                  also stroke sets
  name     : symbol
  pitches  : list of pitch             scale: ascending, one octave;
                                       stroke set: the strokes, unordered
  pitched? : boolean                   #f for a stroke set (`strokes` form)
  location : source location

pitch                                  also a stroke
  name     : symbol                    e.g. ding
  aliases  : list of symbol            e.g. (i); may be empty
  display  : string                    the pitch display name, e.g. "i"
  damped   : string | #f               the damped form, for a note cut
                                       short, e.g. "na'"; #f: the display
                                       name is used
  location : source location

instrument
  name     : symbol
  scale    : scale                     a scale or a stroke set
  notes    : vector of note            pitched: ascending pitch order;
                                       strokes: the order the instrument lists
  location : source location

note
  name   : symbol                      e.g. ding2, dag (never an alias)
  pitch  : integer                     index into the scale's pitches (or strokes)
  octave : integer | #f                #f for strokes

colotomy
  name       : symbol
  length     : integer                 pulses in one cycle
  timekeeper : symbol                  the timekeeper's instrument: kempli
  parts      : list of part            the colotomic parts over one cycle
  location   : source location

pattern
  name       : symbol
  instrument : instrument              the instrument it is written for
  short      : string
  long       : string
  annotation : string | #f             `:annotation`
  location   : source location

part
  name       : symbol
  instrument : instrument
  events     : list of event           sorted by start
  origin     : symbol                  written | timekeeper | colotomy
  spans      : list of pattern-span    the pattern uses, sorted by start
  texts      : list of free-text       `(text ...)`, sorted by start
  location   : source location

event
  start    : rational                  pulses from the start of the piece
  duration : rational                  > 0
  notes    : list of integer           note indices; length > 1 means chord

pattern-span
  pattern  : pattern
  short    : string                    the names in force at this use: the
  long     : string                    pattern's, unless the use gave others
  annotation : string | #f             likewise: the use's, else the pattern's
  start    : rational                  pulses
  end      : rational
  depth    : integer                   0 for a pattern used in the part,
                                       1 for one inside it, ...

score
  name           : symbol
  title          : string              the piece's title unless `:title`
  subtitle       : string | #f
  caption        : string | #f
  from           : rational            start of the range printed (0: start)
  to             : rational            end of the range (the piece's length)
  system-length  : rational | #f       pulses per system; #f: whole range
  breaks         : list of rational    times where a new system starts
  cycle-numbers? : boolean
  pulse-numbers? : boolean
  numbering      : symbol              gong-last | gong-first
  background     : symbol              the score's own
                                       `:background`, else grid; the
                                       header's pulse lines (04)
  cycle-label    : string | #f         "Cycle" unless `:cycle-label`;
                                       #f for ""
  pulse-label    : string | #f         "Pulse" unless `:pulse-label`;
                                       #f for ""
  font-size      : string | #f         a Typst length; #f: the document's
  cell-width     : string              a Typst length
  cell-height    : string
  groups         : list of group       top to bottom
  location       : source location | #f   #f for the default score

group                                  every setting filled in (ADR 0033)
  label         : string               the long label; may be ""
  short         : string               the short label
  subtitle      : string | #f
  labels        : symbol               long | short | first-long
  rows          : symbol               notes | parts | compact
  members       : list of (part . row-label)
                                       row-label: a string, the part's
                                       name unless `:label` gave one
  note-label    : symbol               none | pitch-name |
                                       pitch-display-name | key-number
  note-label-octave? : boolean         octave numbers in note labels
  fill          : symbol               colour | none
  holds         : symbol               none | dash
  annotation    : annotation-row | #f  the annotation row; #f for none
  keys          : symbol | (note . note)   used | all, or the
                                       lowest and highest note shown
                                       (`:keys (LOW HIGH)`); `used`
                                       for `parts` and compact rows
  row-label-octave? : boolean          octave numbers on
                                       row labels
  key-numbers?  : boolean              a column of key
                                       numbers; #f for strokes, `parts`
                                       and compact rows
  row-labels    : symbol               none | pitch-name |
                                       pitch-display-name: the pitch
                                       column
  display       : list of (symbol . string)   stroke name
                                       and the form shown for it in this
                                       score (`:display`); '() for none
  part-marker   : list of (part . marker)   the marked parts; '() for none
  background    : symbol               grid | vertical |
                                       horizontal | empty
  scheme        : symbol               e.g. by-pitch
  palette       : symbol | list of string   a palette name or "#rrggbb"s
  colors        : list of (symbol . string) pitch name and "#rrggbb"
  location      : source location | #f
```

- The reader turns positions written in a score (`:from`, `:to`,
  `:breaks`) into times, so a score holds times only. `to` is the end of
  the range: a `:to` of cycle 1, pulse 8 is the end of that pulse.
- Rests are not stored. They are the gaps between events, so layout
  only ever iterates over sounding events.
- A pattern's body is used up by expansion: the piece keeps the pattern's
  names and instrument, for its spans, but not its tokens.
- A colotomy's parts are over one cycle, with the repeats of a part
  shorter than the cycle written out. The piece's generated parts are
  them laid end to end over the whole piece.

## Derived values (functions, not stored)

- `(note-pitch-index instrument note)` (**Implemented**):
  `octave × scale-size + pitch index`, a total order across all pitched
  instruments sharing a scale. Used to sort rows. It takes the
  instrument because a note does not know its scale. For a stroke, which
  has no pitch, raises an `&error` whose irritants are the note name and
  instrument name.
- `(note-display instrument note #:key damped?)` (**Implemented**): the
  pitch display name, e.g. `"i"` for `ding2`; with `damped?` true, its
  damped form, or the pitch display name if it has none. Used for the
  text in note cells.
- `(note-row-label instrument note)` (`note-label` until
  `feat/collapsed-labels`): the pitch display name plus the octave
  number, e.g. `"i2"`; for a stroke, just its stroke display name. Used
  for row labels. `#:octave?` (default `#t`); with `#f`, the pitch
  display name alone (`"i"`), for `:row-label-octave no`. A group's
  `display` is applied by layout, which looks a stroke up there first.
- `(group-row-keys group)` (`group-lanes` until `feat/collapsed-labels`):
  the notes actually used by the
  group's member parts, as a list of note records, each once. Determines
  the rows of a group with `rows` `notes` and `keys` `used`; with `all`
  or a range, layout takes the instrument's keys instead (04). Pitched notes come from one
  instrument (invariant 6) and are sorted highest first. Strokes follow
  the instrument's order. With several stroke instruments, each
  instrument's rows come as a block, in the order its first part
  appears in the group.
- `(part-end part)` (**Implemented**): the end of the last event (`start + duration`), or
  0 for a part with no events. The reader uses it to check invariant 1.
  It is not a part's written length: trailing rests are not events, so
  the reader checks that parts have equal length while it expands them
  (ADR 0012). Replaces `part-steps`.
- `(events-at piece time)` (**Implemented**): everything sounding at TIME, a list of
  `(part . event)` pairs, one for each event with
  `start ≤ time < start + duration`, in the piece's part order.
- `(time->position piece time)` (**Implemented**): `(CYCLE PULSE)`, PULSE a rational from
  1. With a pickup P and a cycle of N pulses, TIME is cycle
  `floor((TIME − P) / N) + 1`, pulse `(TIME − P) mod N + 1`; the pickup
  is cycle 0. Without a colotomy, the pulse number `TIME + 1`, always
  counted gong-last. Layout prints its own numbers, in the score's
  `numbering`, and the reader reads a score's positions in that
  numbering too (03, step 12), so neither calls these.
- `(position->time piece cycle pulse)`, or `(position->time piece pulse)`
  without a colotomy: the inverse (**Implemented**).
- `(piece-score piece name)`: the score called NAME, or `#f`.

## Invariants (checked by the reader, assumed by everyone else)

The reader checks these; the records do not. 1 to 3 hold by
construction, since events are built from the tokens.

1. Every event lies within `[0, piece-length)`.
2. Events in one part do not overlap.
3. Every note index is valid for the part's instrument.
4. Every part has the piece's length: with a colotomy, the pickup plus
   whole cycles.
5. Notes of a pitched instrument are in ascending pitch order.
6. Within each score: every part is in at most one group; all the
   pitched parts in a group play the same instrument (ADR 0011); and a
   group's parts are either all pitched or all on stroke instruments
   (ADR 0034).
7. A group with `fill` `none` has a `note-label` other than `none`
   (ADR 0054); `parts` and compact rows need none.
8. Part names are unique in the piece, generated parts included, and
   score names are unique.
9. Score names contain no `_` (ADR 0040).
10. In a group whose `keys` is a range, every note its parts
    play in the score's range is within it; the range's notes are keys
    of the group's instrument, the lower first. A group whose `keys` is
    a range is pitched, with `rows` `notes`. Every stroke in a group's
    `display` is a stroke of an instrument in the group. A group with
    `key-numbers?` is pitched, with `rows` `notes`.
11. The parts in a group's `part-marker` are members of the group,
    each in one entry (since `feat/collapsed-markers`), and so is its
    annotation row's part (since `feat/collapsed-annotation`).

## Iteration 5

**Implemented** (ADRs 0051, 0054–0057), slice by slice in
`feat/collapsed`. The records above changed as follows; the reader
fills every new field, so layout never sees a missing one.

Renamed to the glossary's terms (ADR 0051), when a milestone next
touches them, in the slice named:

| Before | Now | Slice |
|---|---|---|
| record `degree` (`make-degree`, `degree?`, `degree-…`) | `pitch` (`make-pitch`, `pitch?`, `pitch-…`) | **Implemented** (`feat/collapsed-terms`) |
| `scale-degrees` | `scale-pitches` | **Implemented** (`feat/collapsed-terms`) |
| `note-degree` (index into the scale) | `note-pitch` | **Implemented** (`feat/collapsed-terms`) |
| `group-lanes` | `group-row-keys`, the keys or strokes its rows stand for (`group-rows` is the `:rows` setting) | **Implemented** (`feat/collapsed-labels`) |
| `note-label` (the row label) | `note-row-label`, since `note-label` is now an option's name | **Implemented** (`feat/collapsed-labels`) |

New and changed fields:

The piece's `info` (accessor `piece-info`, the last argument of
`make-piece`) is **Implemented** since `feat/collapsed-terms`: the
piece information keys without the colon (`composer`, `remarks`, ...),
kept as written, never printed. The rest, since
`feat/collapsed-annotation` unless marked:

```
pattern
  annotation  : string | #f            `:annotation`

pattern-span
  annotation  : string | #f            in force at this use: the
                                       pattern's, unless the use gave one

part
  texts       : list of free-text      `(text ...)` in the part, sorted
                                       by start, written or reached
                                       through patterns and `rep`

free-text                              takes no time
  start       : rational               pulses
  length      : rational | #f          `(text STRING LENGTH)`; #f for a
                                       point, which runs to the next text
  text        : string

group (note-label, note-label-octave?, row-labels and
row-label-octave? since feat/collapsed-labels; see the group record
above)
  rows              : symbol           notes | parts | compact
  part-marker       : list of (part . marker)   '() for none
                                       (since feat/collapsed-markers)
  annotation        : annotation-row | #f       #f: no annotation row
  scheme            : symbol           e.g. by-pitch
  colors            : list of (symbol . string) pitch name and "#rrggbb"
  (pattern-names and pattern-level are removed)

  Constructor places (feat/collapsed-annotation): make-pattern takes
  annotation after long; make-pattern-span, annotation after long;
  make-part, texts after spans; make-group, one field annotation where
  pattern-names and pattern-level were. The new records are
  (make-free-text start length text) and (make-annotation-row part
  position align level text label).

  part-marker goes in make-group just after display, before scheme
  (feat/collapsed-markers); marker is (make-marker symbol symbol-size
  symbol-color border border-width), accessors marker-symbol, ...

  In make-group (feat/collapsed-labels), each new label field took its
  old one's place: note-label and then note-label-octave? where
  note-names? was, row-label-octave? where octave-numbers? was, and
  row-labels where row-labels? was.

marker                                 a part's marks (since
                                       feat/collapsed-markers)
  symbol       : symbol                none | dot | ring | cross
  symbol-size  : number | #f           fraction of the cell's narrower
                                       side; #f: the default
  symbol-color : string | #f           "#rrggbb"; #f: the default
  border       : string | #f           "#rrggbb"; #f: the normal border
  border-width : string | #f           a Typst length; #f: the default

annotation-row
  part      : part                     a member of the group
  position  : symbol                   above | below
  align     : symbol                   left | center | right
  level     : integer                  0, 1, ...
  text      : symbol                   short | long | annotation
  label     : string | #f              #f for ""
```

- Free text is not an event: it doesn't sound, so it has no notes and
  isn't checked by invariant 2. Expansion places it like a note, so a
  `(text ...)` inside a pattern appears at every use.
- The piece information is data only: nothing downstream of the reader
  reads `info` except saving the piece.

## Saving the piece

**Implemented** (ADR 0058) since `feat/save-piece`, in `(notasi
save)`, with golden files `tests/golden/NAME.piece.json`. `notasi
render PIECE.nts --save-piece FILE`
(05) writes the piece record, after reading, to FILE: JSON for
`.json`, an s-expression for `.scm`, JSON on standard output for `-`.
It is the piece, not a figure (the figure JSON is layout's output for
one score, 05):

- **Everything**, field for field as in the records above: the title,
  length, pickup and information; the colotomy, scales, stroke sets and
  instruments with their keys; the patterns; every part, written and
  generated (with `origin`), with its events, pattern spans and free
  text; and every score with its groups and settings.
- **Always the whole piece.** `--score` and `--all` choose only what is
  drawn; the saved file is the same whatever is drawn. Each score
  records its parts and range, so a tool can work out one score's view.
- **Source locations** on each definition (part, pattern, score,
  colotomy, instrument, scale, stroke set): `"source": {"file": "...",
  "line": 88}` in JSON. Events, notes and spans have none, as above.
- **Exact times.** In JSON, a time or duration that is a whole number is
  a number (`"start": 2`); one that isn't is a string in lowest terms,
  as written in a `.nts` (`"start": "5/4"`, `"dur": "1/4"`). The
  s-expression keeps exact rationals (`5/4`).
- **The s-expression** is tagged lists, readable with `read`:
  `(piece (title "...") (length 16) (pickup 1) (part (name polos) ...)
  ...)`. It must not look like notation: notasi writes it and never
  reads it back, and the `.nts` is the only input.
- **Versioned, not yet promised.** The saved piece has a `version` field
  from the start, and golden files for the examples, so every change
  shows in review. The format may change between versions until it
  settles, as the manual says; until then a change needs no ADR of its
  own.
- Terms follow the glossary: `pitch`, not `degree`, in both formats.

The format, decided for `feat/save-piece`:

- **The module** is `(notasi export-piece)`: `(piece->json piece)` gives the
  JSON value as `(notasi json-writer)` writes it (alists, vectors, `null`);
  `(piece->sexp piece)` the tagged list; `(save-piece piece path)`
  writes it, `.json`, `.scm` or `-` (JSON to standard output) choosing
  the format, any other extension an `&error`.
- **References are names.** A part names its instrument, a span its
  pattern, a group its members, marked parts and annotation part, a
  colotomy its parts; a note is its key's name (`"ding2"`, `"G"`).
- **Names of fields.** The record fields above, in their order; in JSON
  with `_` (`system_length`, `note_label_octave`), in the s-expression
  with `-`; booleans without the `?`. A missing value (`#f`) is `null`
  in JSON and `#f` in the s-expression. Symbols are JSON strings.
- **The fields**, in order (each definition also has `source`, last,
  `{file, line}` with `file` null for a piece read from a string):
  - piece: `version` (1), `title`, `length`, `pickup`, `info` (an
    object, keys in the order written), `colotomies`, `scales`,
    `instruments`, `patterns`, `parts`, `scores`;
  - a colotomy entry: `start`, `name`, `length`, `timekeeper`, `parts`
    (part names), `source`;
  - scale: `name`, `pitched`, `pitches` (each `name`, `aliases`,
    `display`, `damped`), `source`;
  - instrument: `name`, `scale` (its name), `keys` (key names, in
    order), `source`;
  - pattern: `name`, `instrument`, `short`, `long`, `annotation`,
    `source`;
  - part: `name`, `instrument`, `origin`, `events` (each `start`,
    `dur`, `notes`), `spans` (each `pattern`, `short`, `long`,
    `annotation`, `start`, `end`, `depth`), `texts` (each `start`,
    `length`, `text`), `source`;
  - score: `name`, `title`, `subtitle`, `caption`, `from`, `to`,
    `system_length`, `breaks`, `cycle_numbers`, `pulse_numbers`,
    `numbering`, `background`, `cycle_label`, `pulse_label`,
    `font_size`, `cell_width`, `cell_height`, `groups`, `source`;
  - group: `label`, `short`, `subtitle`, `labels`, `rows`, `members`
    (each `part`, `label`), `note_label`, `note_label_octave`, `fill`,
    `holds`, `annotation` (null, or `part`, `position`, `align`,
    `level`, `text`, `label`), `keys` (`"used"`, `"all"`, or `[LOW,
    HIGH]` key names), `row_label_octave`, `key_numbers`, `row_labels`,
    `display` (each `stroke`, `text`), `part_marker` (each `part`,
    `symbol`, `symbol_size`, `symbol_color`, `border`, `border_width`),
    `scheme`, `palette` (a name, or a list of colours), `colors` (each
    `pitch`, `color`), `background`, `source`.
  The s-expression is `(piece (version 1) (title "...") ...)`, each
  list of records a list of tagged records (`(parts (part (name polos)
  ...) ...)`), each record `(TAG (FIELD VALUE) ...)`.
- **Golden files**: `tests/golden/NAME.piece.json`, one per example in
  `examples/gallery/` and `examples/demos/`, written by `make golden`
  with the figures and compared by `make check`.

## Decided

- Two stroke instruments in one group whose strokes share a name (two
  kendang both playing `dag`) get a row each: each instrument's rows
  come as a block (`group-row-keys`), as the prototype's kendang group
  draws one row per drum.
- A chord is one event with several notes; 04 says how each kind of
  row draws it.

## Open questions

How a note ends (an `ending` field on events) and sections are in the
[backlog](../iterations/backlog.md).
