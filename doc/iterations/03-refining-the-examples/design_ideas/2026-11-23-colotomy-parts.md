# Design idea: colotomy parts are `part` forms

Status: agreed in discussion (2026-11-23), option B. Not the design
until promoted; the current notation is in `doc/design/01-notation.md`.

## The problem

A colotomy's parts are written `(PART INSTRUMENT TOKEN ...)`
(ADR 0030):

```scheme
(colotomy gilak 8
  (gong gong  -:3 GL:1 P - P G))
```

`gong gong` reads like a typo. A reader has to know the form to tell
that the first `gong` is the part's name and the second the
instrument's.

It is also inconsistent with `part`. ADR 0027 changed top-level parts
from `(part NAME INSTRUMENT ...)` to `(part INSTRUMENT :name NAME ...)`
because the name nearly always repeats the instrument. Colotomy parts
were designed at the same time (ADR 0030) but kept the old order.

Every colotomy in the repository has the same name as the instrument:
`examples/` (gilak, baris, tenzer1, jaya-semara), both iteration 2
targets, the manual's examples and mistakes, and `tests/layout.scm`.

## Options

### A. Instrument first, name optional, as in `part`

```scheme
(colotomy gilak 8
  (gong  -:3 GL:1 P - P G))
```

- The part is named after its instrument, as a top-level part is.
- `:name NAME` when that isn't wanted, for example two colotomy parts
  on one instrument: `(gong :name gong-low ...)`.
- Two parts on one instrument without names are an error, as in ADR
  0027.
- One rule for every part in the language.

### B. The inner form is a `part`

```scheme
(colotomy gilak 8
  (part gong  -:3 GL:1 P - P G))
```

- Exactly the top-level `part` form, so the reader can share the code
  and a user learns one thing.
- Says plainly that the line is a part.
- A little longer than A.
- `part`'s only option is `:name` (`part-options` in
  `notasi/reader.scm`), so there is no question of which options work
  inside a colotomy: the same one, meaning the same thing.

### C. Keep `(PART INSTRUMENT ...)`

- No change for existing files.
- The repetition and the inconsistency with ADR 0027 stay.

## Agreed (2026-11-23)

B. A colotomy's parts are written as `part` forms, exactly as at the
top level:

```scheme
(colotomy gilak 8
  (part gong  -:3 GL:1 P - P G))

(colotomy pangecet-16 16
  (part gong  -:3 P:1 -:3 T:1 -:3 P:1 -:3 G:1))
```

- `(part INSTRUMENT :name NAME TOKEN ...)`, the form of ADR 0027. The
  part is named after its instrument unless `:name` is given.
- Two colotomy parts on one instrument without names are an error, as
  for top-level parts.
- Everything else about colotomy parts is unchanged: they last one
  cycle, or a length that divides it and repeats; they are generated
  for the whole piece; a written part can't share their names.
- Only `part` forms are allowed inside `colotomy`; anything else is an
  error.

Why B over A: one form to learn, and the line says what it is. The
extra word is cheap, since a colotomy is written once (often in a
template).

Later the same day, `2026-11-23-part-syntax.md` changed the `part` form
itself: the instrument is written `:instrument gong`. The colotomy
examples above then read `(part :instrument gong  -:3 GL:1 P - P G)`.

## Notes for promotion

- ADR 0030 decided `(PART INSTRUMENT TOKEN ...)`; changing it needs a
  new ADR that supersedes that part of 0030.
- The reader currently spots a colotomy part by its first two symbols
  being names (`colotomy-part-form?` in `notasi/reader.scm`). With B it
  checks for `part` and reuses the top-level part parsing
  (`split-part`, `part-form-name`).
- No transition: the old `(PART INSTRUMENT ...)` form becomes an error,
  with a message that shows the new form.
- Files to rewrite: the four examples, the two iteration 2 targets,
  the manual (`gong-cycles.md`, its examples and mistakes), the test
  in `tests/layout.scm`, `01-notation.md` and the message in
  `bad-colotomy-form`.
- Generated parts keep the rule that a written part can't share a
  colotomy part's name.
