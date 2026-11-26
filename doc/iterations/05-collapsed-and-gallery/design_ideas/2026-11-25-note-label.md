# Design idea: what a note shows

Status: agreed in discussion (2026-11-25). Not the design until
promoted.

## The idea

A note is drawn as a coloured box. Today it can also show its name,
with `:note-names yes/no` (default `no`: colour only). Collapsed rows
([collapsed rows](2026-11-25-collapsed-rows.md)) rely on what is
written in the box, and the writer wants a choice of three:

- **nothing**: colour only;
- **the note's name**: `o2` or `o`, `dong2` or `dong`; a stroke's
  display name (`K`);
- **the key's number**: the key's place on its instrument, counting
  from 1 at the lowest key (on the ugal, `a1` is key 4), as key
  numbers are counted already (`:key-numbers`, ADR 0047; key numbers
  in parts, 01).

Today key numbers can only be shown as a column beside the row labels
(`:key-numbers yes`, `notes` rows only), never in the notes.

## Terms

From the scale definition (`templates/selisir.nts`):

```scheme
(scale selisir
  (ding :alias i :display "i")
  (dong :alias o :display "o")
  ...)
```

- `selisir` is the **scale name**;
- `ding` is a **pitch name**;
- `i` (its `:display`) is its **pitch display name**.

These are the terms to use in options and documentation. **They
replace "degree", "degree name" and "display form" throughout**: the
design docs (01, 02, 04), the manual, the templates' comments, and
error messages that say "degree". "Bare numbers are keys, not degrees"
becomes "bare numbers are key numbers, not pitch names". Done when this
idea is promoted. The colour scheme `by-degree` (ADR 0017, `:scheme`)
becomes **`by-pitch`**, with no migration: it colours each note by its
pitch, the same in every octave.

## Agreed (2026-11-25)

- **One option, `:note-label`, replaces `:note-names yes/no`.** It
  chooses what is written in each note. `:note-names` is removed with
  no migration, like `:pattern-names`.
- **Its values:**

  | Value | A Jublag o2 shows |
  |---|---|
  | `none` | nothing (colour only) |
  | `pitch-name` | `dong2` |
  | `pitch-display-name` | `o2` |
  | `key-number` | `2` (its place on the jublag, `i2 o2 e2 u2 a2`, from 1 at the lowest key) |

- **The octave number** is added or not by `:note-label-octave yes/no`
  (below): `pitch-display-name` with `:note-label-octave no` shows `o`;
  `pitch-name` with it shows `dong`. It doesn't apply to `key-number`.
- Set on a score or a group, a group's setting overriding the score's.

- **The label columns are set apart from the notes.** A row can be
  labelled by two columns, as now: the key-number column
  (`:key-numbers yes/no`, unchanged) and the pitch column
  (`:row-labels`). `:row-labels` is widened from `yes/no` to choose the
  pitch column's form:

  | Option | Values | Default |
  |---|---|---|
  | `:key-numbers` | `yes`, `no` | `no` |
  | `:row-labels` | `none`, `pitch-name`, `pitch-display-name` | `pitch-display-name` |
  | `:note-label` | `none`, `pitch-name`, `pitch-display-name`, `key-number` | `none` |

  `none` leaves the pitch column out (today's `:row-labels no`);
  `pitch-display-name` is today's `yes`. The pitch forms affect
  `notes` rows only: on `parts` rows the column shows the part's label,
  and on `compact` rows it is blank; `none` leaves it out on every kind
  of row. So a score can write `o2` in the column and `dong2` in the
  notes, or `o2` and `3`.

- **The default `:note-label` is `none`**: notes are colour only
  unless the writer asks, as today. Existing scores on `notes` rows
  don't change.
- **The octave number is controlled separately for the column and the
  notes**, by two options that replace `:octave-numbers` (removed, no
  migration):

  | Option | Values | Default | Applies to |
  |---|---|---|---|
  | `:row-label-octave` | `yes`, `no` | `yes` | the pitch column, when it shows `pitch-name` or `pitch-display-name` |
  | `:note-label-octave` | `yes`, `no` | `yes` | the notes, when they show `pitch-name` or `pitch-display-name` |

  So `o` in the column and `dong2` in the notes:
  ```scheme
  (group "Jublag"
         :row-labels pitch-display-name  :row-label-octave no
         :note-label pitch-name          :note-label-octave yes
    jublag)
  ```

- **Collapsed rows and the columns** (as today, `compact` taking
  `single`'s place):

  | | `notes` rows | `parts` rows | `compact` rows |
  |---|---|---|---|
  | Pitch column (`:row-labels`) | the pitch, in the chosen form | the part's label | blank |
  | Key-number column (`:key-numbers`) | the key | error on the group; ignored from the score | error on the group; ignored from the score |

  `:row-labels none` leaves the pitch column out on every kind of row;
  `:row-label-octave` has nothing to act on in `parts` and `compact`
  rows. In collapsed rows, pitch and key number can be shown only in
  the notes, by `:note-label`.

- **Strokes** (gong, kempli, kendang) have a name (`GL`, `du`) and a
  stroke display name (`du'`; the name when none is given; a score's
  `:display` can change it). They are labelled like pitches, in the
  notes and in the pitch column:

  | Value | Kendang `du` | Gong lanang `GL` |
  |---|---|---|
  | `none` | nothing | nothing |
  | `pitch-name` | `du` | `GL` |
  | `pitch-display-name` | `du'` | `GL`, or `G` with `:display ((GL "G"))` |
  | `key-number` | `du'` | `GL` (or `G`) |

  Strokes have no keys, so `key-number` shows a stroke's display name,
  as `pitch-display-name` does; a score set to `key-number` keeps its
  gongs and kempli readable. The octave options don't apply to strokes.

- **Only `:fill none` needs a label.** `:fill none` draws no box, so
  with `:note-label none` nothing would be drawn: still an error
  (`needs-note-names`, its message naming `:note-label`). Collapsed
  rows (`parts`, `compact`) with `:note-label none` are allowed: colour
  only, the writer's choice, even where strokes or octaves then can't
  be told apart.

## Open

1. *(Settled: `none`.)* The default.
2. *(Settled: its own setting.)* The row-label column.
3. *(Settled.)* Strokes.
4. *(Settled: only `:fill none` needs a label.)* The "needs note names" rule.
5. *(Not dealt with now.)* Damped notes. Damped forms stay as they
   are: `pitch-display-name` (and strokes) show the scale's `:damped`
   form on a one-column note, as today; `pitch-name` and `key-number`
   always show the plain form. Revisit only if a piece needs it.
6. *(Settled: unchanged.)* `:key-numbers`.
7. *(Settled: rename throughout.)* Terms in the documentation.
8. *(Settled: two matching options.)* Writing the two octave settings.

## Notes for promotion

- 01: `:note-label` in the options table, replacing `:note-names`;
  `:row-labels` widened (`yes`/`no` become `pitch-display-name`/`none`,
  no migration); `:octave-numbers` replaced by `:row-label-octave` and
  `:note-label-octave`; the
  `needs-note-names` rule now only for `:fill none`; every example and template that
  writes `:note-names`; the terms pitch name and pitch display name.
- The terms throughout: 01, 02, 04, the manual, `templates/*.nts`
  comments, error messages (and their `.txt` files in the manual's
  mistakes); `:scheme by-degree` becomes `by-pitch` (01, 04, `(notasi
  style)`, its tests, a new ADR narrowing 0017).
- 03: reading `:note-label`; `:note-names` an unknown key.
- 04: "Note text": each event's `text` by the group's `:note-label`.
- 05: the figure JSON needn't change if `text` carries the number as a
  string; check.
- A new ADR: `:note-label` replaces `:note-names`, and key numbers can
  be written in notes.
- Examples (Jaya Semara and Baris use `:note-names yes`), golden files,
  the manual's examples and pages, the Emacs mode's completion.
