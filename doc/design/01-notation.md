# 01 — Notation language

Status: implemented (iterations 2 and 3).
The music below is read since milestone 1 (`feat/music`): options,
`part`, pitches, strokes and instruments, durations, `rep`, colotomies
and patterns; scores, groups and every printing option since
milestone 2 (`feat/scores`); parts written with `:instrument`, also
inside a colotomy (ADR 0038), and `gilak` and `bapang` in the
`gong-kebyar` template (ADR 0046) since iteration 3's `feat/syntax`.
Labelled number rows (ADR 0039) and the pickup shown as cycle 0 since
`feat/drawing-header`; `:background` (ADR 0041) since
`feat/drawing-lines`; `:keys`, `:octave-numbers`, `:display`,
`:key-numbers` and `:row-labels` since `feat/drawing-rows`; no `_` in
score names (ADR 0040) since `feat/drawing-output`.

**Planned** for iteration 5 (ADRs 0053–0057): information about a
piece; `bapang-8`, `bapang-16` and `gegaboran` in the template, in
place of `bapang`; `:note-label`, a widened `:row-labels`, and
`:row-label-octave` and `:note-label-octave`, in place of
`:note-names` and `:octave-numbers`; `:rows compact` in place of
`single`; `:part-marker`; the annotation row, pattern annotations and
`(text ...)`, in place of `:pattern-names` and `:pattern-level`;
`:scheme by-pitch` in place of `by-degree`; the glossary's terms
(ADR 0051): pitch, pitch name and pitch display name, not degree.
Until they are built, the reader takes the old options and names. The
removed ones get no migration: once the new ones are built, they are
unknown keys or values, errors like any other.

Everything in this document is **Implemented** unless it says otherwise.

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
  Tokens say what sounds and when. How the music looks (display names,
  colours, scores, system breaks) never changes what sounds, and nothing
  that matters for sound is expressed only through display.
- **Notes stay symbolic.** Playback would turn notes into pitches with
  a tuning table looked up by pitch name (ADR 0003), not by storing
  frequencies on notes.
- **Durations are exact.** Times are exact rationals in pulses, so a
  player can tell when each note starts and stops.
- **A rest damps.** `-` means the previous note is damped, and `_` that
  it keeps sounding (ADR 0028), as a player needs to know.
- **Time is in pulses, not seconds.** Playback would also need a tempo
  (and tempo changes, which gamelan uses a lot). That would be added as
  new options or forms, without changing what a pulse is.

## Concepts

The terms used here (pulse, duration, pace, step, part, colotomy,
cycle, position, pickup, pattern, score, and the rest) are defined in
the [glossary](glossary.md) (ADR 0051).

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
  (group "Gong, kempli" :note-label pitch-display-name  gong kempli))
```

The gong and kempli parts are generated from the colotomy `gilak`,
which comes from the template (ADR 0046).

## Options

Optional settings are written as `:key value` pairs (ADR 0026):

```scheme
(piece "Jaya Semara: pangecet" :colotomy bapang-16 :pickup 1)
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

**Planned** (iteration 5): information
about the piece, all optional, every value a string:

| Option | Meaning |
|---|---|
| `:composer STRING` | Who composed the music. |
| `:composition-year STRING` | When it was composed. |
| `:transcriber STRING` | Who wrote it down in notasi, or in the source notasi follows. |
| `:transcription-year STRING` | When it was transcribed. |
| `:source STRING` | Where the transcription comes from: a book, a recording, a teacher. |
| `:contributor STRING` | Who contributed the file, e.g. to `examples/contrib/` (07). |
| `:contribution-year STRING` | When it was contributed. |
| `:performer STRING` | Who plays the music the transcription follows: `"Sanggar Çudamani, 2005"`. |
| `:remarks STRING` | Free text about the piece: its history, what is left out. |

```scheme
(piece "Jaya Semara: pangecet" :colotomy bapang-16 :pickup 1
  :composer "I Wayan Beratha" :composition-year "1964"
  :source "Lisa Gold, Music in Bali (2005), figure 3.1 and activities 3.1-3.2"
  :performer "Sanggar Çudamani")
```

- notasi checks only that each value is a string, and keeps it exactly
  as written, line breaks included. A year can be `"1964"`, `"1930s"`
  or `"c. 1964"`; two people, "traditional" or "unknown" are written
  however the writer likes.
- The information is data, never printed: no score option draws it,
  and the figure doesn't change. It is kept in the piece (02) and in
  the saved piece (05).
- Other roles (an arranger, a performance year apart) are added when a
  piece needs them.

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

### `(scale NAME PITCH ...)`

Names the pitches of a scale, in ascending order within one octave.
Used to validate instrument notes and to order them by pitch. Unpitched
instruments use a stroke set instead (see `strokes` below).

Each PITCH is a bare name (`ding`) or a list of a name and options.
In the glossary's terms (ADR 0051), `selisir` is the scale name, `ding`
a pitch name, and its `:display`, `i`, its pitch display name:

```scheme
(scale selisir
  (ding :alias i) (dong :alias o) (deng :alias e)
  (dung :alias u) (dang :alias a))
```

| Option | Default | Meaning |
|---|---|---|
| `:alias NAME` or `:alias (NAME ...)` | none | Other names for the pitch. An alias can be used anywhere the pitch name can: `i2` means `ding2` in instrument definitions, parts and patterns. |
| `:display STRING` | the pitch name | The pitch display name: how the pitch is drawn. Any text, including Unicode symbols. |
| `:damped STRING` | the pitch display name | The damped form, drawn for a note that is cut short (see "What a note shows"). |

Tenzer writes Baris in syllables, `nang` for a ringing note and `na'`
for a damped one:

```scheme
(dang :alias (a nang) :display "nang" :damped "na'")
```

Rules:
- Pitch names and aliases must be unique within the scale.
- Names and aliases must not end in a digit, so that the octave number
  in `ding2` is unambiguous.
- No pitch may be called `rep`, `@` or (**Planned**) `text`, which are
  reserved list heads.
- The reader resolves aliases: the piece always stores the pitch's own
  name, so `i2` and `ding2` are the same note.

### `(strokes NAME STROKE ...)`

Names the strokes of unpitched instruments (gongs, drums, kempli). It
works like `scale`, but strokes have no pitch and no octave, so they are
not in any order.

Each STROKE uses the same syntax and options as a pitch: a bare
name (`G`) or a name with options (`(GL :display "G")`); its
`:display` is its stroke display name. Following
Gold's symbols, the gongs of the `gong-kebyar` template are one
instrument with strokes `G` (gong wadon), `GL` (gong lanang), `P`
(kempur) and `T` (klentong).

Rules:
- Stroke names and aliases must be unique within the stroke set.
- A stroke set and a scale cannot share a name, because an instrument
  refers to either by name.
- Stroke names may end in a digit, since there is no octave number.
- No stroke may be called `rep`, `@` or (**Planned**) `text`.

### `(instrument NAME SCALE-OR-STROKES NOTE ...)`

An instrument is its keys (or strokes) in ascending order, and nothing
about how it is played or printed. It has no options.

- With a scale, each NOTE is a key: a pitch name followed by an octave
  number, `ding2`. The pitch must be in the scale. Notes must be listed in
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
  redefines the strokes. The template defines the common colotomies
  (ADR 0046), `gilak` (8 pulses: gong
  lanang on 4, kempur on 5 and 7, gong on 8) and `gilak-2` (the same with
  the gong on 4 instead of the gong lanang, as Baris uses); a piece names one
  with `:colotomy` and writes no `colotomy` form, or defines its own,
  or replaces the template's with one of the same name.

  Bapang (ADR 0053): **Implemented** today as `bapang` (16 pulses:
  kempur on 4 and 12, klentong on 8, gong on 16). **Planned**: `bapang`
  is replaced by two colotomies named for their length, and the
  template gets `gegaboran`. Pulses are Gold's kempli beats:

  | Colotomy | Pulses | Strokes | Source |
  |---|---|---|---|
  | `bapang-8` | 8 | kempur on 2 and 6, klentong on 4, gong on 8 | Gold, figure 5.11, p. 110 |
  | `bapang-16` | 16 | kempur on 4 and 12, klentong on 8, gong on 16 | Gold, p. 58 (Jaya Semara), p. 142 |
  | `gegaboran` | 16 | the strokes of `bapang-16` | Gold, figure 5.11, p. 110 |

  Plain `bapang` then is an unknown colotomy. `gegaboran` is in the
  template though no example uses it, an exception to ADR 0046's rule,
  so a writer can name the meter they mean. Other lengths (Gold's
  32-pulse bapang, p. 142) are written in the piece as a `colotomy`;
  notasi has no operation that stretches one.

- With a stroke set, each NOTE is a stroke from that set (`G`, `dag`),
  in any order. The order sets the note indices and the order of the
  rows.
- Note indices (key numbers) are 1-based in list order.

### `(colotomy NAME LENGTH :key value ... (part ...) ...)`

A colotomic meter (ADRs 0030, 0038): a cycle of LENGTH pulses and the
gong parts that mark it.

What a colotomy is (**Planned** wording for the manual and the
template's comments, ADR 0053):

- "Colotomic" is a word from Western writing about gamelan; there is no
  single Balinese term, and each meter has its own name, such as gilak
  or bapang (Gold, p. 42). `colotomy` is notasi's word for one named
  meter at one length.
- The same meter can be played at more than one length (bapang at 8, 16
  and 32 pulses). Each length is its own colotomy.
- The gongs alone don't tell meters apart: 16-pulse bapang and
  gegaboran share their strokes and differ in drumming, mood and genre,
  which a `colotomy` doesn't record. Its name is the writer's label for
  the meter.
- A length from a source says whose count it is: notasi's pulses are
  kempli strokes (ADR 0009), Gold's beats.

The rest of this section is **Implemented**. The common ones come from the `gong-kebyar`
template (ADR 0046); a piece writes a `colotomy` form for a
meter the template lacks, or to change one. The template's `gilak`:

```scheme
(colotomy gilak 8
  (part :instrument gong  -:3 GL:1 P - P G))
```

- Each part is a `part` form, exactly as at the top level (see `part`
  below): named after its instrument unless `:name` gives another, and
  two parts on one instrument without names are an error. Only `part`
  forms are allowed inside `colotomy`; the old form,
  `(gong gong -:3 GL:1 P - P G)`, is an error whose message shows the
  new one.
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

The old form of ADR 0027, `(part INSTRUMENT :name NAME TOKEN ...)`, is
an error: a part without `:instrument` is reported with a message that
shows how to write it (`(part :instrument gong ...)`), rather than as a
strange first note.

Rules:
- A part without `:instrument` is an error.
- Two parts on one instrument without names are an error: "instrument
  `pemade` has two parts; give them names with `:name`".
- Part names are unique in the piece, generated parts included.

#### Tokens

| Token | Meaning |
|---|---|
| `e2`, `ding2` | Strike a key by name (pitch name or alias, then octave number). |
| `5` | Strike key number 5 of the instrument (1-based). Not a cipher digit. |
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
| `(text STRING)`, `(text STRING LENGTH)` | **Planned** (ADR 0057). Free text, shown in an annotation row: at this point, or across LENGTH pulses from it. Takes no time. |

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

Free text (**Planned**, ADR 0057):
- It is written where it happens, so it moves with the music. It may be
  written inside a pattern, so that every use carries it, and `rep`
  repeats it.
- It is shown only in the annotation row of a group whose
  `:annotation-part` is this part (see `score`), whatever that row's
  `:annotation-level`; elsewhere it is ignored, without a warning.
- `(text STRING)` runs from its point to the next text in the
  annotation row, or to the end of the system, and starts at its point
  whatever the alignment.
- Where free text overlaps a pattern's text, the free text is drawn and
  the pattern's text is cut where it starts.
- STRING must be a string, and LENGTH a duration greater than 0.

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
| `:annotation STRING` | none | **Planned** (ADR 0057). A text about the pattern ("norot on 1"), which an annotation row can show instead of its name. |

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
| `:step N` | Move every note N pitches along the scale (i o e u a, then i in the next octave); key numbers move N keys. The figure keeps its shape on the keys. |
| `:short S`, `:long L` | Names for this use, replacing the pattern's, so that a moved figure can be named after what it now plays. |
| `:annotation A` | **Planned** (ADR 0057). The annotation for this use, replacing the pattern's. |

```scheme
(@ polos-1 :step -1 :short "6")    ; a pitch lower, named "6" here
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
  level, and the names in force at that use (and, **Planned**, its
  annotation), so that a score can name it in an annotation row.

Errors where the pattern is defined: no `:instrument`, or an unknown
one; a note, key number or stroke the instrument does not have; a
pattern for another instrument used inside it.

Errors where the pattern is used: an unknown pattern; a pattern that
contains itself; a pattern used on another instrument; a moved note
outside the instrument's range.

### `(score NAME :key value ... GROUP ...)`

How the music is printed (ADR 0031). A file may have several scores:

```scheme
(score full
  (group "Gangsa pemade" :short "Pem." :subtitle "norot"
         :annotation-part polos  polos sangsih)
  (group "Jublag"        :short "Jub."  :rows compact  jublag)
  (group "Gong, kempli"  :rows compact :note-label pitch-display-name
    gong kempli))
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
| `:cycle-numbers yes/no` | score | `yes` with a colotomy | A row with the cycle number, once at the start of each cycle. A pickup is cycle 0: a system that starts with the pickup shows `0`. |
| `:pulse-numbers yes/no` | score | `yes` | A row with the pulse number within the cycle (within the piece, without a colotomy). |
| `:numbering gong-last/gong-first` | score | `gong-last` | Number the pulses 1 to N with the gong on N (Gold), or with the gong on 1 (Tenzer): pulse k of an N-pulse cycle is printed (k mod N) + 1. Only the printed numbers change. |
| `:cycle-label STRING` | score | `"Cycle"` | A label at the left of the cycle row (ADR 0039). |
| `:pulse-label STRING` | score | `"Pulse"` | A label at the left of the pulse row, e.g. "Beats" (ADR 0039). |

`""` removes a label, and a label is printed only when its row is.

In the grid:

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:note-label none/pitch-name/pitch-display-name/key-number` | score, group | `none` | **Planned** (ADR 0054). What is written in each note: nothing (colour only), its pitch name (`dong2`), its pitch display name (`o2`), or its key number (`2` on the jublag, from 1 at the lowest key). See "What a note shows". |
| `:note-label-octave yes/no` | score, group | `yes` | **Planned** (ADR 0054). With `pitch-name` or `pitch-display-name`, whether a note's label ends in its octave number (`o2`) or not (`o`). |
| `:fill colour/none` | score, group | `colour` | `none` draws the labels alone, without a coloured box. |
| `:holds none/dash` | score, group | `none` | `dash` writes "-" in every step a note is held, as in a sung line. |
| `:rows notes/parts/compact` | score, group | `notes` | What a row stands for. `notes`: one row per key or stroke used. `parts`: one row per part, labelled. `compact` (**Planned**, ADR 0055): the group's parts merged into one line, with a row added where keys sound together. |
| `:keys used/all/(LOW HIGH)` | score, group | `used` | With `:rows notes`, which rows a group has: the keys or strokes played in the score's range, every key or stroke of the instrument, or the keys from LOW up to HIGH, both included (`:keys (a1 u2)`). |
| `:row-labels none/pitch-name/pitch-display-name` | score, group | `pitch-display-name` | **Planned** (ADR 0054). The pitch column on `notes` rows: each row's pitch name (`dong2`) or pitch display name (`o2`); on `parts` rows the part's label, on `compact` rows nothing. `none` leaves the column out on every kind of row. |
| `:row-label-octave yes/no` | score, group | `yes` | **Planned** (ADR 0054). Whether the pitch column's labels end in the octave number (`i2`) or not (`i`). Only rows of pitched keys change. |
| `:key-numbers yes/no` | score, group | `no` | A column of key numbers to the left of the pitch column: each row's key on its instrument, from 1 (on the ugal, `a1` is key 4). Pitched keys on `notes` rows only. |
| `:display ((STROKE STRING) ...)` | score, group | none | Show these strokes with these stroke display names in this score, in row labels and note labels: `:display ((GL "G"))`. |
| `:background grid/vertical/horizontal/empty` | score, group | `grid` | The lines behind the notes: pulse lines and a line between every two rows (`grid`), pulse lines only (`vertical`), row lines only (`horizontal`), or neither (`empty`). The lines between groups and the cycle lines are always drawn (ADR 0041). |
| `:part-marker ((PART :key value ...) ...)` | group | none | **Planned** (ADR 0056). Tells the group's parts apart: each entry gives a part of the group a symbol, a border, or both (see "Telling parts apart"). |

**Implemented** until the planned options above are built, and then
removed, with no migration:

- `:note-names yes/no` (default `no`): write each note's or stroke's
  name in its cell. Replaced by `:note-label`.
- `:octave-numbers yes/no` (default `yes`): the octave number after
  each row label and note label. Replaced by `:row-label-octave` and
  `:note-label-octave`.
- `:row-labels yes/no` (default `yes`): `yes` is today's
  `pitch-display-name`, `no` is `none`.
- `:rows single`: all the group's parts on one row, an error where two
  notes fall in one cell. Replaced by `compact`.
- `:pattern-names none/short/long` (default `none`) and
  `:pattern-level N` (default `0`): pattern names written over the
  notes, across each use of a pattern, at one level of nesting.
  Replaced by the annotation row.

The annotation row (**Planned**, ADR 0057): one row of text only, with
no background and no notes, above or below a group's rows. Its options
are set on a group, never on a score:

| Option | Default | Meaning |
|---|---|---|
| `:annotation-part PART` | no annotation row | Turns the annotation row on, taking its text from PART, a part of the group. |
| `:annotation-position above/below` | `below` | Where the row goes. |
| `:annotation-align left/center/right` | `left` | How text is aligned in its span. |
| `:annotation-level N` | `0` | Which level of nested patterns to name: 0 for the patterns the part uses directly, 1 for the patterns inside those, and so on. |
| `:annotation-text short/long/annotation` | `annotation` | What a pattern shows: its short name, its long name, or its annotation (its long name when it has none). |
| `:annotation-label STRING` | `""` | The row's label, in the pitch column. |

- Each use of a pattern at the chosen level writes its text across the
  use's columns. Where there is no pattern at that level, the row is
  empty; free text (`(text ...)`) in the part is shown too.
- The row is always one line. Text longer than its span is cut at the
  span's end, and is then left-aligned whatever `:annotation-align`
  says, so its start shows.
- At a system break a span is split, and its text is written again on
  the next system.
- Cycle lines run through the annotation row; pulse lines don't. The
  group's frame encloses it.
- With `:row-labels none` there is no pitch column, and the annotation
  row has no label.

Colour and size (ADR 0032):

| Option | Level | Default | Meaning |
|---|---|---|---|
| `:scheme NAME` | score, group | `by-degree`; **Planned**: `by-pitch` | How notes are coloured (04, "Note style"). `by-pitch` (ADR 0056, `by-degree` renamed, with no migration) colours each note by its pitch, the same in every octave. |
| `:palette NAME` or `:palette (COLOUR ...)` | score, group | `pastel1` | The colours, by name or as a list of `"#rrggbb"`. |
| `:colors ((PITCH COLOUR) ...)` | score, group | none | Colours for particular pitches, by pitch name, e.g. `((ding "#000000"))`. |
| `:font-size LENGTH` | score | `"8pt"` on its own page; the document's size in a document | The base text size. |
| `:cell-width LENGTH`, `:cell-height LENGTH` | score | `"2em"`, `"2em"` | The grid cell. Equal sizes make square notes. |

A LENGTH is a string holding a Typst length, a number and a unit
(`"8pt"`, `"2em"`, `"4mm"`). Sizes in `em` scale with `:font-size`.

#### What a note shows

**Implemented**, with `:note-names yes`: a note shows its damped form
(`:damped`) when it lasts no longer than one column of the grid, and
its pitch display name otherwise. Without a damped form, the pitch
display name is used for both. The test uses the note's written
duration: strokes, which are to be drawn one column wide (04,
ADR 0042), still show `du` or `du'` as written.

**Planned** (ADR 0054), with `:note-label`:

| `:note-label` | A jublag `o2` | Kendang `du` | Gong lanang `GL` |
|---|---|---|---|
| `none` | nothing | nothing | nothing |
| `pitch-name` | `dong2` | `du` | `GL` |
| `pitch-display-name` | `o2` | `du'` | `GL`, or `G` with `:display ((GL "G"))` |
| `key-number` | `2` | `du'` | `GL` (or `G`) |

- `pitch-display-name` shows the damped form on a one-column note, as
  above; `pitch-name` and `key-number` always show the plain form.
- Strokes have no keys, so `key-number` shows a stroke's display name,
  as `pitch-display-name` does, and a score set to `key-number` keeps
  its gongs and kempli readable. The octave options don't apply to
  strokes.
- The pitch column and the notes are set apart, so a group can write
  `o` in the column and `dong2` in the notes:

  ```scheme
  (group "Jublag"
         :row-labels pitch-display-name  :row-label-octave no
         :note-label pitch-name          :note-label-octave yes
    jublag)
  ```

- On collapsed rows (`parts`, `compact`) a row stands for no pitch, so
  a note shows which it is by its colour and, if asked, its label:

  | | `notes` rows | `parts` rows | `compact` rows |
  |---|---|---|---|
  | Pitch column (`:row-labels`) | the pitch, in the chosen form | the part's label | blank |
  | Key-number column (`:key-numbers`) | the key | error on the group; ignored from the score | error on the group; ignored from the score |

#### Compact rows

**Planned** (ADR 0055). `:rows compact` merges the group's parts into
one line, and adds a row only where different keys sound together:

- Two notes sound together when their boxes, as drawn, would overlap:
  from a note's start to its start plus its drawn length. A held note
  counts for its whole length, a stroke for its one column (ADR 0042).
- Each key or stroke keeps one row for the whole score. Rows are filled
  in the order of the group's keys (highest pitch first; strokes in
  instrument order), each key going to the first row where it never
  sounds with a key already there. So the gong and kempli take two
  rows, G, P and T on one and K on the other, every time; where no two
  keys ever sound together, all share one row.
- A chord is one note, its labels joined (`i o`), with the look of its
  lowest note, as on `parts` rows. A unison (two parts on the same key,
  start and length) is one note, drawn once, as on `notes` rows.
- Its rows have no labels.

#### Telling parts apart

**Planned** (ADR 0056). By default a group's parts are drawn alike:
each note takes its pitch's colour, whichever part plays it. A group
can mark its parts with `:part-marker`, on every kind of rows and for
pitched and stroke groups alike:

```scheme
(group "Gangsa pemade"
       :part-marker ((sangsih :symbol dot :border "#d62728"))
  polos sangsih)
```

| Key | Value | Default |
|---|---|---|
| `:symbol` | `none`, `dot`, `ring`, `cross`: small, centred in the note's cell | `none` |
| `:symbol-size` | a fraction of the cell's narrower side, e.g. `0.3` | chosen by eye when built |
| `:symbol-color` | `"#rrggbb"` | near-black, as note labels |
| `:border` | `"#rrggbb"`: a border of that colour, thicker than the normal one | none (the normal border) |
| `:border-width` | a LENGTH, e.g. `"1pt"` | thicker than the normal border, chosen by eye when built |

- A part with no entry is drawn as without `:part-marker`. Colour
  stays the pitch colour.
- A symbol and a note label in one note are both drawn, in the middle
  of the cell, even if they overlap; the writer chooses a combination
  that reads well.
- A unison drawn once (on `notes` and `compact` rows) is drawn under
  the first part that plays it, with that part's marks only. On `parts`
  rows each part shows it, with its own marks.

#### Rules

- Score names are unique in a file. Group labels need not be.
- A score name may not contain `_`, so that a file drawn from it,
  `NAME_SCORE` (ADR 0040), can be split.
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
  **Planned** (ADR 0054): only `:fill none` needs a label (a
  `:note-label` other than `none`), since it draws no box; `parts` and
  `compact` rows may be colour only.
- `:keys`: LOW and HIGH are keys of the group's
  instrument, written as in a part, LOW not above HIGH; a range is an
  error on a group of strokes, which has only `used` and `all`; `:keys`
  on a `:rows parts` or `single` (**Planned**: `compact`) group is an
  error, and ignored when it comes from the score. A note outside the keys shown is an error
  naming the part, the note, its position and the range.
- `:key-numbers yes` written on a group of strokes, or on
  a `:rows parts` or `single` (**Planned**: `compact`) group, is an error; coming from the score,
  it is ignored there.
- `:display`: each STROKE is a stroke of an instrument in
  the group (on a score, of an instrument in one of its groups); it
  changes only how the stroke is shown in that score.
- With `:rows single`, two notes may not fall in one cell (**Planned**:
  removed with `single`; `compact` adds a row instead). With `:rows
  notes` (**Planned**: and `compact`), two parts may share a cell only
  as a unison: the same key, start and length, which is drawn once.
- Pattern names: identical names from several parts of a group (the
  same start, length and text) are written once; different names that
  overlap in one group are an error, naming the parts and the position.
  **Planned**: removed with `:pattern-names`; the annotation row takes
  one part, so names can't clash.
- **Planned** (ADR 0056): `:part-marker` on a score, a part not in the
  group, an unknown key or symbol, a colour not `"#rrggbb"`, a size
  outside 0 to 1, or a width that isn't a LENGTH is an error.
- **Planned** (ADR 0057): an annotation row option on a score, an
  `:annotation-part` that isn't a part of the group, an unknown
  position, alignment or text, or a level that isn't a whole number
  from 0 is an error, as is another annotation row option without
  `:annotation-part`.

#### Files without a score, and choosing one

A file with no `score` gets a default score: every part, written and
generated, in its own group, in source order, labelled with its name,
with every option at its default.

`notasi render FILE --score NAME` prints the score NAME. Without
`--score`, the first score in the file is printed. A file drawn from a
chosen score is named `FILE_NAME.pdf` (ADR 0040). **Planned**:
`--all` draws every score, and `--list` lists their names (05).

## Reading Gold's cipher in this notation

| Gold's cipher | This notation |
|---|---|
| 1 2 3 5 6 | i o e u a (pitch names, not key numbers) |
| a dot under or over a digit (low or high octave) | the octave number of the instrument's key |
| a dot between digits (an empty beat, the note sustained) | `_` |
| the last note falls on the gong | it ends a cycle: put `\|\|` after it |
| read starting from the gong stroke | a one-pulse pickup on the gong |
| one cipher per beat | one pulse per note, the default pace |

Two traps: bare numbers are key numbers, not pitch names (`3` is the
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

None for iteration 5: its design ideas' questions were settled before
promotion. To be chosen by eye when built: the default `:symbol-size`
and `:border-width` of `:part-marker`. None for iteration 3: its design ideas' questions were settled before
promotion. None for iteration 2. The three questions of v1 are answered: parts
have equal length, and only colotomy parts shorter than their cycle
repeat; a rest damps (ADR 0028); octave numbers are shared across
instruments.
