# Design idea: an annotation row

Status: agreed in discussion (2026-11-25). Not the design until
promoted.

## The idea

A group can have an **annotation row**: one extra row, above or below
the group's rows, that holds text only. It has no coloured background
and no notes. Its text is taken from **one part of the group**, chosen
by the writer, and by default it is the **names of that part's
patterns**, each written across the columns of the pattern's use.

A pattern can also carry an **annotation**: a text written with the
pattern, such as "norot on 1, sangsih answers on the off-beat". When a
pattern has one, the annotation row shows it instead of the name.

The writer chooses how the text is aligned in its span: left, centre
or right.

## It replaces pattern names over the notes

`:pattern-names short/long` (01; 04, "Pattern names") already writes
pattern names, but **over the notes**, as overlays across all the
group's rows, merged from every part of the group. The annotation
annotation row:

- puts the text **in its own row**, so it never covers notes;
- takes it from **one part**, so there is nothing to merge and no
  clash between parts;
- can show **a pattern's annotation**, not only its name;
- lets the writer **align** it.

Overlays over the notes are not a good idea: they cover the music they
name. So **`:pattern-names` is removed**, with its overlays, and the
annotation row is the one way to print pattern names.

## Agreed (2026-11-25)

- Optional, per group: one annotation row, above or below the group's rows.
- No background colour; text only.
- Alignment: `left`, `center`, `right`.
- The text comes from one part of the group, which the writer names.
- By default, the annotation row shows pattern names; a pattern can carry an
  annotation, which is shown instead.
- **`:pattern-names` is removed**, and with it the overlays: the
  figure JSON's `overlays`, the template's drawing of them, and the
  reader's error for different names overlapping in one group (the
  annotation row takes one part, so names can't clash).
- **The level is the annotation row's own setting.** Patterns nest, so the annotation row
  must choose which layer to name: 0 for the patterns the part uses
  directly, 1 for the patterns inside those, and so on. It is set with
  the annotation row, as `:annotation-level N` (default 0), and `:pattern-level`
  is removed with `:pattern-names`. In Jaya Semara, level 0 names
  polos's two 8-pulse "norot" sections, level 1 its 2-pulse figures
  "1", "6", "3", "2".
- **Written as flat options on the group** (ADR 0026):
  ```scheme
  (group "Gangsa pemade" :annotation-part polos
         :annotation-position below :annotation-align left
         :annotation-level 1 :annotation-text short
    polos sangsih)
  ```
  `:annotation-part PART` turns the annotation row on and names its part, a member of
  the group.

  | Option | Values | Default |
  |---|---|---|
  | `:annotation-part PART` | a part of the group | no annotation row |
  | `:annotation-position` | `above`, `below` | `below` |
  | `:annotation-align` | `left`, `center`, `right` | `left` |
  | `:annotation-level N` | 0, 1, ... | `0` |
  | `:annotation-text` | `short`, `long`, `annotation` | `annotation` |
  | `:annotation-label STRING` | the annotation row's label, in the pitch column | `""` |

  With `annotation`, a pattern without an annotation shows its long
  name. The `kotekan` score sets `short` for its figure names.
- **A pattern's annotation is `:annotation STRING`**, on `pattern`, and
  a use can replace it, as `:short` and `:long`:
  ```scheme
  (pattern polos-1 :instrument pemade :short "1"
           :annotation "norot on 1"
    o3:1/4 i3 i3 - | i3 - i3 -)
  (@ polos-1 :step -1 :short "6" :annotation "norot on 6")
  ```
- **Text longer than its span is cut** at the span's end. The annotation row is
  always one line.
- **Spans without a pattern** at the chosen level leave the annotation row empty
  there.
- **At a system break** a span is split, and its text is written again
  on the next system (as overlays were, 04).
- **Lines**: cycle lines run through the annotation row; pulse lines don't. The
  group's frame encloses it.
- **Label**: none by default; `:annotation-label` sets one.

- **Group only.** None of the annotation row's options can be set on a score;
  each group with an annotation row writes its own.
- **Free text is written in the part**, where it happens, as a token
  that takes no time:
  ```scheme
  (part :instrument pemade :name polos
    o3:1/4 - o3 - || (rep 2 @polos) (text "angsel") o3 - - - ||)
  ```
  `(text STRING)` marks a point; `(text STRING LENGTH)` covers a
  stretch of LENGTH pulses from that point. It moves with the music
  when the music is edited, and it can be written inside a pattern, so
  every use of the pattern carries it (and `rep` repeats it). It is
  shown in the annotation row of a group whose `:annotation-part` is that part, at
  every level; `:annotation-level` chooses only which patterns are
  named.

- **A point's text runs to the next text.** `(text STRING)` runs from
  its point until the next text in the annotation row starts (free text or a
  pattern's text), or to the end of the system if nothing comes first,
  and is cut there like other annotation row text.
- **Free text wins over pattern text.** Where free text overlaps a
  pattern's name or annotation, the free text is drawn and the
  pattern's text is cut where the free text starts.
- **The token is `(text ...)`.** As a list form it can't be mistaken
  for a note or a pattern.
- **Free text in a part with no annotation row is ignored**, without a warning:
  a part can be printed with an annotation row in one score and without one in
  another.

- **Alignment applies only when the text fits.** Text longer than its
  span is always left-aligned and cut at the right, so its start shows,
  whatever `:annotation-align` says.
- **Point text starts at its point.** `(text STRING)` is always
  left-aligned at the point it is written; `:annotation-align` applies
  to pattern text and to free text with a length.

- **The group's option is `:annotation-part`.** `:annotation` means
  only a pattern's text (`:annotation "..."` on `pattern` and `(@ ...)`).
  On a group, every annotation row option starts `:annotation-`: `-part`,
  `-position`, `-align`, `-level`, `-text`, `-label`.

- **Without a pitch column, no label.** `:annotation-label` sits in
  the pitch column; with `:row-labels none` that column is left out,
  and the annotation row has no label either.

## Notes for promotion

- 01: the group options, the pattern's `:annotation` key and the
  operator on `(@ ...)`, and the `(text ...)` token in parts and
  patterns.
- 02: a pattern and a pattern use carry an annotation; a part's
  expanded events include text events (time, length, string) that take
  no time.
- 03: reading them: the part must be a member of the group; an
  unknown position or alignment is an error, as is any annotation row option on a
  score; `(text ...)` with a non-string or a bad length.
- `(notasi expand)`: `(text ...)` in parts and patterns, inside `rep`
  and pattern uses.
- 04: the annotation row: where it goes, its spans from the chosen part at the
  chosen level, the text chosen, splitting at systems.
- 05: the group in the figure JSON gets the annotation row (position, alignment,
  label, items with `start`, `dur`, `text`, `continued`): contract version 4, shared
  across the iteration (see the iteration README) (ADR 0006). The template draws it.
- A new ADR: the annotation row, and annotations on patterns; it
  removes `:pattern-names`, `:pattern-level` and the overlays (from
  contract version 4), and narrows ADRs 0036 and 0043, which put
  overlays in the JSON contract.
- Removing `:pattern-names` and `:pattern-level`: 01 (the options; the
  rule on overlapping names), 03 (`pattern-names-overlap`), 04 ("Pattern names
  (overlays)"), 05 (`overlays` in the group, the template's drawing);
  `notasi/reader.scm`, `layout.scm`, `piece.scm` and `typst/notasi.typ`;
  their tests; the Emacs mode's tests; every golden file (each group
  carries `overlays`). Manual: `patterns.md`, `errors.md`,
  `examples/pattern-names.nts`, `mistakes/pattern-names-overlap.*`.
- Jaya Semara's `kotekan` score uses `:pattern-names short
  :pattern-level 1`; it moves to an annotation row below the pemade, from polos,
  with short names at `:annotation-level 1`.
- Manual: the page on patterns (annotations) and on groups (the annotation row).
- 08: the Emacs mode knows the new keys.
