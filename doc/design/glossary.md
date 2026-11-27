# Glossary

Status: agreed (iteration 5, ADR 0051). The terms are the design's;
the documents and the code are brought to them as they change. Terms
marked **Planned** name things not built yet. Where the code or the
JSON still uses an older name, the "In code / JSON" column says so.

This is the one list of notasi's terms. The design documents, the
manual, the code (procedures, record fields, JSON keys), error
messages and commit messages use these words for these things. The
manual has no glossary of its own: it uses the terms below that a
musician meets, without listing them.

"Not" lists words not to use for the same thing. `/doc-audit` looks
for them at the end of each milestone.

Code is renamed to these terms when a milestone next touches it, not
in one sweep.

## Time

| Term | Meaning | In code / JSON | Not |
|---|---|---|---|
| **pulse** | One kempli stroke: the unit of time (ADR 0009). Gold's "beat" | `pulse` | beat |
| **duration** | A length of time in pulses: a whole number or a fraction (`2`, `1/4`) | `dur` | |
| **pace** | A part's current duration: the duration a note gets when none is written | | |
| **step** | One column of a score's grid: the largest duration dividing every time the score prints. Layout derives it (04) | `step` | tick |
| **colotomy** | notasi's name for one named colotomic meter: a length in pulses and the gong parts that mark it (Gold's "colotomic meter"). The word is ours, not Balinese; each length of a meter is its own colotomy | `colotomy` | meter |
| **colotomic** | Of the gongs, kempur, kempli and the like, which mark off the cycle. A word from Western writing about gamelan | | |
| **cycle** | One repetition of the colotomy. Cycle 1 is the first complete one | `cycle` | gongan |
| **pickup** | Pulses before the first complete cycle, when a piece opens on the gong. Shown as cycle 0 | `pickup` | |
| **position** | A place in time: a cycle and a pulse ("cycle 2, pulse 4"), or a pulse number without a colotomy | | |

## Pitches, keys and strokes

| Term | Meaning | In code / JSON | Not |
|---|---|---|---|
| **scale** | A named, ordered set of pitches within one octave | `scale` | |
| **scale name** | A scale's name: `selisir` | | |
| **pitch** | One member of a scale: `(dong :alias o :display "o")` | `pitch` | degree |
| **pitch name** | A pitch's name: `dong` | | degree name, note name |
| **pitch display name** | How a pitch is drawn: `o` (its `:display`) | | display form |
| **octave number** | The digit after a pitch in a key: the `2` of `o2` | | |
| **key** | One playable note of a pitched instrument: a pitch in an octave, `o2` | `key` | pot, bar |
| **key number** | A key's place on its instrument, from 1 at the lowest | `key-number` | index |
| **stroke** | One kind of sound of an unpitched instrument: `K`, `GL`, `du` | `stroke` | |
| **stroke set** | A named set of strokes | `strokes` | |
| **stroke display name** | How a stroke is drawn: `du'` (its `:display`) | | display form |
| **damped form** | The form drawn for a note one column long: `na'` (`:damped`) | `damped` | |
| **instrument** | A named list of keys, or of strokes | `instrument` | |
| **by-pitch** | The colour scheme that colours each note by its pitch, the same in every octave (`:scheme by-pitch`) | `by-pitch` | by-degree |
| **by-key** | The colour scheme that colours each note by its key: the pitch's hue, lighter as the octave rises (`:scheme by-key`, ADR 0062; planned) | `by-key` | by-octave, by-register |
| **octave palette** | A palette for `by-key`: one colour ramp per scale position, a colour per octave, lowest first (`pastel1-octaves`) | | octave ramps, gradient |

## Music

| Term | Meaning | In code / JSON | Not |
|---|---|---|---|
| **note** | One sounding event in a part: a key or stroke, a time and a duration | `event` (JSON) | |
| **part** | One line of music on one instrument | `part` | voice (except the JSON's `voices`) |
| **polos / sangsih** | The two interlocking parts of a kotekan | | |
| **pattern** | A named figure for one instrument, played in parts with `@NAME` | `pattern` | motif |
| **pattern use** | One `@NAME` or `(@ NAME ...)` in a part | `span` | |
| **annotation** | Text written on a pattern, shown in the annotation row | `annotation` | remark, comment |
| **free text** | `(text ...)` in a part, shown in the annotation row | `free-text`, `part-texts` | |

## Scores and drawing

| Term | Meaning | In code / JSON | Not |
|---|---|---|---|
| **score** | How the music is printed: which parts, in which groups, with which options. A file may have several | `score` | |
| **group** | Parts drawn together in one block of rows, e.g. polos and sangsih | `group` | staff |
| **row** | One horizontal line of cells in a group | `row` (JSON `rows`, `row`, `row_label_width`; contract version 4) | lane |
| **row label** | The pitch column's text for a row | | lane label |
| **pitch column** | The column of row labels (`:row-labels`) | | |
| **key-number column** | The column of key numbers (`:key-numbers`) | | |
| **note label** | What is written in a note, chosen with `:note-label` | `text` (JSON) | note name |
| **collapsed** | A group drawn with fewer rows than keys: `:rows parts` or `compact` | | |
| **part marker** | A symbol and border telling a part's notes apart in a group (`:part-marker`) | `marker` (record and JSON) | |
| **annotation row** | A text-only row above or below a group | `annotation-row`; JSON `annotation` | annotation lane |
| **system** | One horizontal block of the figure, e.g. one gong cycle | `system` | line |
| **figure** | Layout's output for one score: the JSON Typst draws | `figure` | |

## The repository

| Term | Meaning | In code / JSON | Not |
|---|---|---|---|
| **gallery / manual / demos / contrib** | The folders of `examples/` (07) | | |
