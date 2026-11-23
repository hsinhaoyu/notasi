# 02 — Piece

Status: partly implemented (iteration 2). `degree` (with `damped`) and
`instrument` (without `show-names?`) are as below since
`feat/music-syntax`; times are exact rationals in pulses, with
`part-end` and `events-at` taking a time, since `feat/music-durations`;
`pickup`, `colotomies`, `part-origin`, the `colotomy` record,
`time->position` and `position->time` since `feat/music-colotomy`;
`patterns`, `part-spans`, the `pattern` and `pattern-span` records since
`feat/music-patterns`.
`scores` in place of `groups`, the `score` and `group` records and
`piece-score` since `feat/scores-form`.
The other records are agreed and not yet built:
`(notasi piece)` still implements their v1 form, summarised under "What
the code implements today". Tests in `tests/piece.scm`.

Everything in this document is **Planned** unless it says otherwise.

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
  messages: scales, degrees, instruments, colotomies, patterns, parts,
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

scale                                  (implemented, unchanged) also stroke sets
  name     : symbol
  degrees  : list of degree            scale: ascending, one octave;
                                       stroke set: the strokes, unordered
  pitched? : boolean                   #f for a stroke set (`strokes` form)
  location : source location

degree
  name     : symbol                    e.g. ding
  aliases  : list of symbol            e.g. (i); may be empty
  display  : string                    the form drawn in the grid, e.g. "i"
  damped   : string | #f               the form for a note cut short, e.g.
                                       "na'"; #f: the display form is used
  location : source location

instrument
  name     : symbol
  scale    : scale                     a scale or a stroke set
  notes    : vector of note            pitched: ascending pitch order;
                                       strokes: the order the instrument lists
  location : source location

note                                   (implemented, unchanged)
  name   : symbol                      e.g. ding2, dag (never an alias)
  degree : integer                     index into the scale's degrees (or strokes)
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
  location   : source location

part
  name       : symbol
  instrument : instrument
  events     : list of event           sorted by start
  origin     : symbol                  written | timekeeper | colotomy
  spans      : list of pattern-span    the pattern uses, sorted by start
  location   : source location

event
  start    : rational                  pulses from the start of the piece
  duration : rational                  > 0
  notes    : list of integer           note indices; length > 1 means chord

pattern-span
  pattern  : pattern
  short    : string                    the names in force at this use: the
  long     : string                    pattern's, unless the use gave others
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
  pulse-label    : string | #f
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
  rows          : symbol               notes | parts | single
  members       : list of (part . row-label)
                                       row-label: a string, the part's
                                       name unless `:label` gave one
  note-names?   : boolean
  fill          : symbol               colour | none
  holds         : symbol               none | dash
  pattern-names : symbol               none | short | long
  pattern-level : integer
  scheme        : symbol               e.g. by-degree
  palette       : symbol | list of string   a palette name or "#rrggbb"s
  colors        : list of (symbol . string) degree name and "#rrggbb"
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
  `octave × scale-size + degree`, a total order across all pitched
  instruments sharing a scale. Used to sort lanes. It takes the
  instrument because a note does not know its scale. For a stroke, which
  has no pitch, raises an `&error` whose irritants are the note name and
  instrument name.
- `(note-display instrument note #:key damped?)`: the degree's display
  form, e.g. `"i"` for `ding2`; with `damped?` true, its damped form,
  or the display form if it has none. Used for the text in note cells.
- `(note-label instrument note)` (**Implemented**): the display form plus
  the octave, e.g. `"i2"`; for a stroke, just its display form. Used for
  row labels.
- `(group-lanes group)` (**Implemented**): the notes actually used by the
  group's member parts, as a list of note records, each once. Determines
  the rows of a group with `rows` `notes`. Pitched notes come from one
  instrument (invariant 6) and are sorted highest first. Strokes follow
  the instrument's order. With several stroke instruments, each
  instrument's lanes come as a block, in the order its first part
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
  is cycle 0. Without a colotomy, the pulse number `TIME + 1`. Used by
  error messages and by layout's cycle and pulse numbers.
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
7. A group with `rows` `parts` or `single`, or `fill` `none`, has
   `note-names?` true.
8. Part names are unique in the piece, generated parts included, and
   score names are unique.

## What the code implements today

**Implemented** (v1): `(notasi piece)` builds an earlier form of these
records. It differs as follows, and this section goes when iteration 2
is built:

- (`piece`, `score`, `group` and `piece-score` are as above since
  milestone 2, slice 1.)
- (`degree` has `damped` and `instrument` has no `show-names?` since
  iteration 2, slice 1: those two records are **Implemented** as
  above.)
- `note-display` has no `damped?`.

## Open questions

- Two stroke instruments in one group may have strokes with the same
  name (e.g. two kendang both playing `dag`). Do they share a lane or
  get one each? The prototype's kendang group draws one lane per drum,
  and the code gives each instrument its own lanes.
- Is a chord one event with several notes (the current choice) or
  several simultaneous events? One event is simpler for layout.

How a note ends (an `ending` field on events) and sections are in the
[backlog](../iterations/backlog.md).
