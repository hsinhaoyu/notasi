# 01 — Notation language

Status: implemented (iteration 2); iteration 3's changes are planned.
The music below is read since milestone 1 (`feat/music`): options,
`part`, degrees, strokes and instruments, durations, `rep`, colotomies
and patterns; scores, groups and every printing option since
milestone 2 (`feat/scores`). Planned for iteration 3: parts written
with `:instrument`, also inside a colotomy (ADR 0038); labelled number
rows (ADR 0039); `:keys`, `:octave-numbers`, `:background` (ADR 0041)
and a group's own stroke names (`:display`); no `_` in score names
(ADR 0040).

Everything in this document is **Implemented** unless it says otherwise.
Where iteration 3 changes a form, the section shows the planned form
and says what the reader reads until it is built.

## Goals

- As concise as possible to type.
- Readable by Guile's built-in `read`, with no custom tokenizer (ADR 0001).
- Time is counted in pulses, and notes have durations (ADR 0025).
- Instruments are lists of symbolic notes, and octaves are told apart
  (ADR 0003).
- The music and how it is printed are kept apart: the music says what
  sounds and when, and scores say how it is printed (ADR 0031).

## Scope: no playback yet

This package is a visualisation tool. It does not play pieces back:
there is no MIDI or audio output. Playback may be added later, so the
notation and the `piece` records must not throw away anything a player
would need. In particular:

- **Every token has a musical meaning, and display is kept separate.**
  Tokens say what sounds and when. How the music looks (display forms,
  colours, scores, system breaks) never changes what sounds, and nothing
  that matters for sound is expressed only through display.
- **Notes stay symbolic.** Playback would turn notes into pitches with
  a tuning table looked up by note name (ADR 0003), not by storing
  frequencies on notes.
- **Durations are exact.** Times are exact rationals in pulses, so a
  player can tell when each note starts and stops.
- **A rest damps.** `-` means the previous note is damped, and `_` that
  it keeps sounding (ADR 0028), as a player needs to know.
- **Time is in pulses, not seconds.** Playback would also need a tempo
  (and tempo changes, which gamelan uses a lot). That would be added as
  new options or forms, without changing what a pulse is.

## Concepts

| Term | Meaning |
|---|---|
| pulse | One kempli stroke: the unit of time (ADR 0009). Gold's "beat". |
| duration | A length of time in pulses: a whole number or a fraction (`2`, `1/4`). |
| step | The smallest unit of time a score prints: one column of its grid. Layout derives it (04). |
| part | One line of music on one instrument. |
| pace | A part's current duration: the duration a note gets when none is written. |
| colotomy | A named cycle: a length in pulses and the gong parts that mark it (Gold's colotomic meter). |
| cycle | One repetition of the colotomy. Cycle 1 is the first complete one. |
| position | A place in time: a cycle and a pulse ("cycle 2, pulse 4"), or a pulse number without a colotomy. |
| pickup | Pulses before the first complete cycle, when a piece opens on the gong. |
| pattern | A named list of tokens, written for one instrument, that its parts can play, join, repeat and transform. |
| score | How the music is printed: which parts, in which groups, with which options. A file may have several. |

## Files

A file (extension `.nts`, ADR 0022) is a sequence of top-level forms,
read by Guile's `read` with its `r7rs-symbols` and `keywords` options
off, so that `|`, `||` and `:key` are ordinary symbols. Comments use `;`.

```scheme
(piece TITLE :key value ...)                               ; first
(use TEMPLATE) ...                                         ; then templates
(scale ...) (strokes ...) (instrument ...) (colotomy ...)  ; definitions
(pattern ...) ...                                          ; patterns
(part ...) ...                                             ; the music
(score ...) ...                                            ; how it is printed
```

- `piece` comes first, and `use` forms come right after it.
- Otherwise the order does not matter, because names are resolved after
  all templates are loaded.
- Scales, stroke sets, instruments and colotomies rarely change from one
  piece to the next, so they usually come from a template. A piece often
  contains only `piece`, `use`, patterns, parts and scores.
- Everything except `score` describes the music.

A short piece:

```scheme
(piece "Gilak" :colotomy gilak :pickup 1)
(use gong-kebyar)

(part :instrument ugal  a1 ||  o2 i2 e2 o2 | a1 o2 i2 a1 ||)

(score full
  (group "Ugal" ugal)
  (group "Gong, kempli" :note-names yes  gong kempli))
```

The gong and kempli parts are generated from the colotomy `gilak`.

## Options

Optional settings are written as `:key value` pairs (ADR 0026):

```scheme
(piece "Jaya Semara: pangecet" :colotomy pangecet-16 :pickup 1)
(part :instrument pemade :name polos  o3:1/4 - o3 - || ...)
```

- A key is a symbol that starts with `:` followed by a letter.
- Each key takes exactly one value. A value with several items is a
  list: `:alias (i nding)`.
- Options come right after a form's positional arguments and before its
  body (tokens or sub-forms). Their order does not matter, and each key
  may appear once. An unknown key is an error.
- Durations also use a colon, but never at the start: `o3:1/4` is a note
  with a duration, `:pickup` is a key.

## Forms

### `(piece TITLE :key value ...)`

Exactly one per file, first.

| Option | Default | Meaning |
|---|---|---|
| `:colotomy NAME` | none | The piece's colotomy. Its parts and the timekeeper are generated for the whole piece. |
| `:pickup P` | 0 | The piece starts P pulses before the end of a cycle. A whole number of pulses, at most one cycle. An error without a colotomy. |

A piece with a colotomy is its pickup plus whole cycles.

### `(use TEMPLATE)`

Loads the definitions in a template. A template is a `.nts` file that
contains only `scale`, `strokes`, `instrument`, `colotomy`, `pattern`
and `use` forms.

| TEMPLATE | Loads |
|---|---|
| a name: `(use gong-kebyar)` | `templates/gong-kebyar.nts`, shipped with this package |
| a string: `(use "my-gamelan.nts")` | that file, relative to the file containing the `use` |

Rules (**Implemented** for the v1 forms):
- `use` forms come before any definition, part or score (in a piece,
  right after `piece`). A file may have several.
- A template may `use` other templates, e.g. a `gong-kebyar` template
  could `use` a `selisir` template for its scale. Each template is
  loaded once; a cycle is an error.
- A file's own definitions replace definitions of the same name from
  the templates it uses. For example, a piece can redefine `ugal` with a
  different range and keep everything else from the template.
- Two templates used by the same file must not define the same name
  (unless it is the same definition, reached through both), and one
  file must not define a name twice. Both are errors.
- Names are resolved after all templates are loaded, so if a piece
  replaces a scale, the template's instruments use the replacement.

### `(scale NAME DEGREE ...)`

Names the degrees of a scale, in ascending order within one octave.
Used to validate instrument notes and to order them by pitch. Unpitched
instruments use a stroke set instead (see `strokes` below).

Each DEGREE is a bare name (`ding`) or a list of a name and options:

```scheme
(scale selisir
  (ding :alias i) (dong :alias o) (deng :alias e)
  (dung :alias u) (dang :alias a))
```

| Option | Default | Meaning |
|---|---|---|
| `:alias NAME` or `:alias (NAME ...)` | none | Other names for the degree. An alias can be used anywhere the degree name can: `i2` means `ding2` in instrument definitions, parts and patterns. |
| `:display STRING` | the degree name | The form drawn in the grid. Any text, including Unicode symbols. |
| `:damped STRING` | the display form | The form drawn for a note that is cut short (see "Which name a note shows"). |

Tenzer writes Baris in syllables, `nang` for a ringing note and `na'`
for a damped one:

```scheme
(dang :alias (a nang) :display "nang" :damped "na'")
```

Rules:
- Degree names and aliases must be unique within the scale.
- Names and aliases must not end in a digit, so that the octave number
  in `ding2` is unambiguous.
- No degree may be called `rep` or `@`, which are reserved list heads.
- The reader resolves aliases: the piece always stores the degree's own
  name, so `i2` and `ding2` are the same note.

### `(strokes NAME STROKE ...)`

Names the strokes of unpitched instruments (gongs, drums, kempli). It
works like `scale`, but strokes have no pitch and no octave, so they are
not in any order.

Each STROKE uses the same syntax and options as a scale degree: a bare
name (`G`) or a name with options (`(GL :display "G")`). Following
Gold's symbols, the gongs of the `gong-kebyar` template are one
instrument with strokes `G` (gong wadon), `GL` (gong lanang), `P`
(kempur) and `T` (klentong).

Rules:
- Stroke names and aliases must be unique within the stroke set.
- A stroke set and a scale cannot share a name, because an instrument
  refers to either by name.
- Stroke names may end in a digit, since there is no octave number.
- No stroke may be called `rep` or `@`.

### `(instrument NAME SCALE-OR-STROKES NOTE ...)`

An instrument is its keys (or strokes) in ascending order, and nothing
about how it is played or printed. It has no options.

- With a scale, each NOTE is `DEGREE` followed by an octave number:
  `ding2`. The degree must be in the scale. Notes must be listed in
  ascending pitch order.
- Octave numbers are shared by all instruments: `o2` on the ugal and
  `o2` on the jublag are the same pitch. They are not tied to any
  absolute pitch. The ranges of Gold's figure 2.7, in this numbering:

  | Instrument | Keys |
  |---|---|
  | jegogan | i1 … a1 (5) |
  | jublag, calung | i2 … a2 (5) |
  | panyacah | i3 … a3 (5) |
  | ugal | o1 … i3 (10) |
  | gangsa pemade | o2 … i4 (10) |
  | gangsa kantilan | o3 … i5 (10) |
  | trompong | a1 … u3 (10) |
  | reyong | e2 … u4 (12) |

  The `gong-kebyar` template defines every instrument in this table
  with these keys (gangsa pemade as `pemade`, gangsa kantilan as
  `kantilan`, and `calung` with the jublag's keys), besides the gongs,
  the kempli and the kendang. Its gongs are one instrument, `gong`, with
  the strokes `G GL P T`, each shown by its name, so the two gongs are
  told apart; a piece that prints both as "G", as Tenzer does,
  redefines the strokes. Colotomies are not in the template: a piece
  defines its own (`gilak`, `pangecet-16`).

- With a stroke set, each NOTE is a stroke from that set (`G`, `dag`),
  in any order. The order sets the note indices and the order of the
  rows.
- Note indices (key numbers) are 1-based in list order.

### `(colotomy NAME LENGTH :key value ... (part ...) ...)`

A colotomic meter (ADRs 0030, 0038): a cycle of LENGTH pulses and the
gong parts that mark it.

```scheme
(colotomy gilak 8
  (part :instrument gong  -:3 GL:1 P - P G))
```

- Each part is a `part` form, exactly as at the top level (see `part`
  below): named after its instrument unless `:name` gives another, and
  two parts on one instrument without names are an error. Only `part`
  forms are allowed inside `colotomy`. **Planned** (iteration 3): until
  it is built, a colotomy part is written `(PART INSTRUMENT TOKEN ...)`,
  e.g. `(gong gong -:3 GL:1 P - P G)`; that form then becomes an error
  whose message shows the new one.
- Each part is a colotomic part over one cycle, in ordinary part
  tokens. A part shorter than LENGTH repeats; its length must divide
  LENGTH.
- Pulse k of a cycle starts at time k − 1, so the gong on pulse N starts
  at N − 1 and the cycle ends at N: the gong falls on the last pulse.
- A piece with `:colotomy NAME` gets each of its parts, generated for
  the whole piece and named as the colotomy names them (`gong`).
- The timekeeper is implied, with or without a colotomy: a part
  `kempli`, with one stroke per pulse, on the piece's instrument
  `kempli`. A piece without one gets a built-in kempli, and then the
  timekeeper is in the music but never printed.
- Generated parts are parts like any other: scores print them by name,
  and part names stay unique, so a written part cannot take a generated
  part's name.

### `(part :key value ... TOKEN ...)`

A line of music on one instrument (ADR 0038). `part` has no positional
arguments: its options, in any order, then its tokens. Most parts are
the only part on their instrument and are named after it:

```scheme
(part :instrument panyacah  o3 || (rep 2  a3 i3 u3 a3 o3 e3 i3 o3) ||)   ; part `panyacah`
```

When an instrument has several parts, each gets a name with `:name`:

```scheme
(part :instrument pemade :name polos    o3:1/4 - o3 - || ...)
(part :instrument pemade :name sangsih  -:1/4 e3 - e3 || ...)
```

| Option | Default | Meaning |
|---|---|---|
| `:instrument INSTRUMENT` | required | The instrument the part is played on, the same key a pattern uses. |
| `:name NAME` | the instrument's name | The part's name, used by scores. |

**Planned** (iteration 3): until it is built, a part is written
`(part INSTRUMENT :name NAME TOKEN ...)` (ADR 0027), with the
instrument first and no `:instrument`. That form then becomes an error:
a part without `:instrument` is reported with a message that shows how
to write it (`(part :instrument gong ...)`), rather than as a strange
first note.

Rules:
- A part without `:instrument` is an error (**Planned**).
- Two parts on one instrument without names are an error: "instrument
  `pemade` has two parts; give them names with `:name`".
- Part names are unique in the piece, generated parts included.

#### Tokens

| Token | Meaning |
|---|---|
| `e2`, `ding2` | Strike a note by name (degree or alias, then octave). |
| `5` | Strike key 5 of the instrument (1-based). Not a cipher degree. |
| `e2:2`, `5:1/4` | Strike with a duration in pulses. The duration stays in force for the following tokens until another is written. |
| `_` | Hold: the previous note keeps sounding for one more duration. Gold's cipher dot. |
| `-`, `-:3` | Rest: nothing is struck for one duration, and the previous note is damped. |
| `(2 5)` | Chord: notes struck together, for the current duration. Members may be numbers or names. |
| `(rep N TOKEN ...)` | Repeat the tokens N times. |
| `\|` | Pulse check: must fall on a pulse boundary. Takes no time. |
| `\|\|` | Cycle check: must fall on a cycle boundary. Takes no time. |
| `@NAME` | Play the pattern NAME (see `pattern`). |
| `(@ NAME :key value ...)` | Play the pattern NAME, changed by operators. |
| `/` | Visual separator for the reader of the file; ignored, takes no time. |

Durations:
- A part starts with a duration of 1 pulse, so its first note sets its
  pace: `a1:2 o1 e1 i1` is four notes of two pulses.
- Every repetition of a `rep` is identical: its body is read once, with
  the duration in force before the `rep`. After it, the duration is the
  body's last.

Rests (ADR 0028):
- `_` sustains: Gold's `. 1 . 6 . 3 . 2` is `_ i2 _ a2 _ e2 _ o2`.
- `-` damps: nothing new is struck and the player stops the previous
  note, as in kotekan, where each player damps so the partner's note
  sounds.

Rules:
- `_` at the start of a part or after `-` is an error.
- Every part adds up to the same number of pulses: with a colotomy, the
  pickup plus whole cycles. Generated parts fill that length.
- Without a colotomy, `||` and `:pickup` are errors.
- Errors give positions as `cycle C, pulse P`, a fraction written
  `4 1/2`, or as `pulse P` without a colotomy: "part `ugal`, cycle 2,
  pulse 4 1/2: `||` is not at the end of a cycle". An error inside a
  pattern names the whole chain of uses, with the line of each form.

Characters to avoid as tokens: `.` (pair syntax) and `#` (reader
extensions). A lone `.` is not a rest: Guile's `read` takes it as pair
syntax.

#### The step

The piece stores times as exact rationals in pulses. Layout finds, for
each score, the largest duration that divides every time it prints:
that is the step, one column of the grid (04). When the fastest notes
are quarter pulses, the step is 1/4 pulse.

### `(pattern NAME :key value ... TOKEN ...)`

A named figure, written for one instrument (ADR 0029):

```scheme
(pattern polos-1 :instrument pemade :short "1" :long "Norot polos on 1"
  o3:1/4 i3 i3 - | i3 - i3 -)
```

| Option | Default | Meaning |
|---|---|---|
| `:instrument INSTRUMENT` | required | The instrument the pattern is written for. |
| `:short STRING` | NAME | A short name, which a score can print over the notes. |
| `:long STRING` | the short name | A long name, likewise. |

- NAME must not start with `:` or `@`.
- The body is ordinary part tokens: notes, key numbers, durations, `_`,
  `-`, chords, `rep`, `|`, `||`, `/` and other patterns.
- Patterns are defined in a piece or in a template.

`@NAME` plays the pattern wherever a token can go. Joining patterns is
writing them one after another; repeating them uses `rep`:

```scheme
(part :instrument pemade :name polos
  o3:1/4 - o3 - ||
  (rep 2  @polos-1 @polos-6 @polos-3 @polos-2)
  ||)
```

The prefix keeps patterns apart from notes: a pattern called `a1`
cannot be mistaken for the note `a1`, and a misspelt note is not looked
up as a pattern.

The list form applies operators, written as options:

| Operator | Meaning |
|---|---|
| `:step N` | Move every note N degrees along the scale (i o e u a, then i in the next octave); key numbers move N keys. The figure keeps its shape on the keys. |
| `:short S`, `:long L` | Names for this use, replacing the pattern's, so that a moved figure can be named after what it now plays. |

```scheme
(@ polos-1 :step -1 :short "6")    ; a degree lower, named "6" here
```

Operators apply only to patterns, not to `rep` blocks or parts.

Rules:
- **A pattern belongs to its instrument.** Its notes, key numbers and
  strokes are checked against that instrument's keys where the pattern
  is defined, even if it is never used. It can only be used in a part on
  that instrument, or inside another pattern for it.
- **A pattern means the same everywhere.** Its durations start at 1
  pulse unless its first token sets one, and after the pattern the
  part's duration is what it was before.
- **`_` may start a pattern.** It holds the note before the pattern
  where it is used.
- **Patterns may contain patterns**, but not themselves, directly or
  through others.
- **Checks are optional.** A pattern need not start or end on a pulse or
  a cycle. A `|` or `||` inside it is checked where it is used, against
  the piece's time.
- **Each use is recorded** in the piece: its part, start, end, nesting
  level, and the names in force at that use, so that a score can mark
  the span.

Errors where the pattern is defined: no `:instrument`, or an unknown
one; a note, key number or stroke the instrument does not have; a
pattern for another instrument used inside it.

Errors where the pattern is used: an unknown pattern; a pattern that
contains itself; a pattern used on another instrument; a moved note
outside the instrument's range.

### `(score NAME :key value ... GROUP ...)`

How the music is printed (ADR 0031). A file may have several scores:

```scheme
(score full :pattern-names short
  (group "Gangsa pemade" :short "Pem." :subtitle "norot"  polos sangsih)
  (group "Jublag"        :short "Jub."  jublag)
  (group "Gong, kempli"  :note-names yes  gong kempli))
```

- NAME names the score.
- Each GROUP is `(group LABEL :key value ... PART ...)`: a block of rows,
  printed top to bottom in the order written. LABEL is its long label,
  and may be empty (`""`).
- A PART is a part name, or `(PART :label STRING)` to give it a row
  label (see `:rows`). The label defaults to the part's name.
- A part that is in no group of a score is not printed in that score.
  This is how a part is written but not printed.

#### Options

A score option sets the default for all its groups; a group option
overrides it for that group. Options marked "score" can only be set on
the score.

Header and range:

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:title STRING` | score | the piece's title | The title. |
| `:subtitle STRING` | score, group | none | A subtitle; a group's is printed under its label. |
| `:caption STRING` | score | none | A caption under the score. |
| `:from POS`, `:to POS` | score | the whole piece | Print an excerpt, both ends included. POS is `(CYCLE PULSE)`, or a pulse number without a colotomy. |
| `:system-length N` | score | the whole piece | Pulses per system. |
| `:breaks (POS ...)` | score | none | Start a new system at each position. With `:system-length`, both apply. |

Labels:

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:labels long/short/first-long` | score, group | `first-long` | Which label to print: always the long one, always the short one, or the long one on the first system and the short one after. |
| `:short STRING` | group | the long label | The short label. |

Above the grid:

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:cycle-numbers yes/no` | score | `yes` with a colotomy | A row with the cycle number, once at the start of each cycle. A pickup is cycle 0: a system that starts with the pickup shows `0` (**Planned**, iteration 3). |
| `:pulse-numbers yes/no` | score | `yes` | A row with the pulse number within the cycle (within the piece, without a colotomy). |
| `:numbering gong-last/gong-first` | score | `gong-last` | Number the pulses 1 to N with the gong on N (Gold), or with the gong on 1 (Tenzer): pulse k of an N-pulse cycle is printed (k mod N) + 1. Only the printed numbers change. |
| `:cycle-label STRING` | score | `"Cycle"` | A label at the left of the cycle row (**Planned**, ADR 0039). |
| `:pulse-label STRING` | score | `"Pulse"` | A label at the left of the pulse row, e.g. "Beats". Today the default is none; `"Pulse"` is **Planned** (ADR 0039). |

`""` removes a label, and a label is printed only when its row is
(**Planned**).

In the grid:

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:note-names yes/no` | score, group | `no` | Write each note's or stroke's name in its cell. By default a note is only a colour, strokes too. |
| `:pattern-names none/short/long` | score, group | `none` | Write pattern names over the notes, across each use of a pattern. |
| `:pattern-level N` | score, group | `0` | Which level of nested patterns to name: 0 for patterns used directly in the part, 1 for patterns inside those, and so on. |
| `:fill colour/none` | score, group | `colour` | `none` draws the names alone, without a coloured box. |
| `:holds none/dash` | score, group | `none` | `dash` writes "-" in every step a note is held, as in a sung line. |
| `:rows notes/parts/single` | score, group | `notes` | `notes`: one row per key or stroke used. `parts`: one row per part, labelled. `single`: all the group's parts on one row. |
| `:keys used/all/(LOW HIGH)` | score, group | `used` | With `:rows notes`, which rows a group has: the keys or strokes played in the score's range, every key or stroke of the instrument, or the keys from LOW up to HIGH, both included (`:keys (a1 u2)`). **Planned** (iteration 3). |
| `:octave-numbers yes/no` | score, group | `yes` | Write the octave number after each row label (`i2`), or the display form alone (`i`). Only rows of pitched keys change. **Planned** (iteration 3). |
| `:display ((STROKE STRING) ...)` | score, group | none | Show these strokes with these forms in this score, in row labels and note names, instead of their own display forms: `:display ((GL "G"))`. **Planned** (iteration 3). |
| `:background grid/vertical/horizontal/empty` | score, group | `grid` | The lines behind the notes: pulse lines and a line between every two rows (`grid`), pulse lines only (`vertical`), row lines only (`horizontal`), or neither (`empty`). The lines between groups and the cycle lines are always drawn. **Planned** (ADR 0041); today every score is drawn as `vertical`. |

Colour and size (ADR 0032):

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:scheme NAME` | score, group | `by-degree` | How notes are coloured (04, "Note style"). |
| `:palette NAME` or `:palette (COLOUR ...)` | score, group | `pastel1` | The colours, by name or as a list of `"#rrggbb"`. |
| `:colors ((DEGREE COLOUR) ...)` | score, group | none | Colours for particular degrees, e.g. `((ding "#000000"))`. |
| `:font-size LENGTH` | score | `"8pt"` on its own page; the document's size in a document | The base text size. |
| `:cell-width LENGTH`, `:cell-height LENGTH` | score | `"2em"`, `"2em"` | The grid cell. Equal sizes make square notes. |

A LENGTH is a string holding a Typst length, a number and a unit
(`"8pt"`, `"2em"`, `"4mm"`). Sizes in `em` scale with `:font-size`.

#### Which name a note shows

With `:note-names yes`, a note shows its damped form (`:damped`) when it
lasts no longer than one column of the grid, and its display form
otherwise. Without a damped form, the display form is used for both.
The test uses the note's written duration: strokes, which are to be
drawn one column wide (04, **Planned**), still show `du` or `du'` as
written.

#### Rules

- Score names are unique in a file. Group labels need not be.
- A score name may not contain `_`, so that a file drawn from it,
  `NAME_SCORE` (ADR 0040), can be split (**Planned**).
- Every part a group names must exist, written or generated.
- Within one score a part is in at most one group. A group's parts are
  either all pitched, on the same instrument (ADR 0011), or all on stroke
  instruments (ADR 0034). The same part may appear in several scores.
- A group with no parts, an unknown option, an option at the wrong
  level, or a bad value (an unknown palette, a colour that is not
  `"#rrggbb"`, a length without a unit) is an error.
- `:from` must come before `:to`, and both must lie in the piece.
- `:rows parts`, `:rows single` and `:fill none` need `:note-names yes`
  on the group, since without names those rows would not show pitch.
- `:keys` (**Planned**): LOW and HIGH are keys of the group's
  instrument, written as in a part, LOW not above HIGH; a range is an
  error on a group of strokes, which has only `used` and `all`; `:keys`
  on a `:rows parts` or `single` group is an error, and ignored when it
  comes from the score. A note outside the keys shown is an error
  naming the part, the note, its position and the range.
- `:display` (**Planned**): each STROKE is a stroke of an instrument in
  the group (on a score, of an instrument in one of its groups); it
  changes only how the stroke is shown in that score.
- With `:rows single`, two notes may not fall in one cell. With `:rows
  notes`, two parts may share a cell only as a unison: the same key,
  start and length, which is drawn once.
- Pattern names: identical names from several parts of a group (the
  same start, length and text) are written once; different names that
  overlap in one group are an error, naming the parts and the position.

#### Files without a score, and choosing one

A file with no `score` gets a default score: every part, written and
generated, in its own group, in source order, labelled with its name,
with every option at its default.

`notasi render FILE --score NAME` prints the score NAME. Without
`--score`, the first score in the file is printed. A file drawn from a
chosen score is named `FILE_NAME.pdf` (**Planned**, ADR 0040; today
`FILE.NAME.pdf`).

## Reading Gold's cipher in this notation

| Gold's cipher | This notation |
|---|---|
| 1 2 3 5 6 | i o e u a (degrees, not keys) |
| a dot under or over a digit (low or high octave) | the octave number of the instrument's key |
| a dot between digits (an empty beat, the note sustained) | `_` |
| the last note falls on the gong | it ends a cycle: put `\|\|` after it |
| read starting from the gong stroke | a one-pulse pickup on the gong |
| one cipher per beat | one pulse per note, the default pace |

Two traps: bare numbers are keys, not cipher degrees (`3` is the
instrument's third key, not ndeng); and Gold's dot is a hold, not a
rest.

## Not covered

Music this notation cannot express yet, from Gold:

- metrically free passages (gineman)
- the pulse doubling within a section
- a change of colotomy between sections, irregular cycles
- tempo and dynamics, cues and angsel (breaks)

Later extensions of the notation are listed in the
[backlog](../iterations/backlog.md).

## Open questions

None for iteration 3: its design ideas' questions were settled before
promotion. None for iteration 2. The three questions of v1 are answered: parts
have equal length, and only colotomy parts shorter than their cycle
repeat; a rest damps (ADR 0028); octave numbers are shared across
instruments.
