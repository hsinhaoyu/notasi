# Design idea: a part names its instrument with `:instrument`

Status: agreed in discussion (2026-11-23). Not the design until
promoted; the current notation is in `doc/design/01-notation.md`.

Follows `2026-11-23-colotomy-parts.md`, which makes a colotomy's parts
`part` forms, so this change covers them too.

## The problem

A part is `(part INSTRUMENT :key value ... TOKEN ...)` (ADR 0027):

```scheme
(part gong  -:3 GL:1 P - P G)
(part pemade :name polos  o3:1/4 - o3 - || ...)
```

The instrument is a bare positional symbol. Nothing on the line says
that `gong` is an instrument rather than a name or the first token,
and inside a colotomy, next to the colotomy's own name, it is easy to
misread.

## Options considered

- **`inst: gong`**, as first proposed. A colon at the end would be a
  third use of `:` after options (`:name`, colon first, ADR 0026) and
  durations (`o3:1/4`, colon in the middle), and a new rule for the
  reader. Not taken.
- **`:inst gong`**. Shorter, but patterns already say `:instrument`,
  and they would have to change to match.
- **`:instrument gong`**. Taken.

## Agreed (2026-11-23)

```scheme
(part :instrument gong  -:3 GL:1 P - P G)
(part :instrument pemade :name polos  o3:1/4 - o3 - || ...)

(colotomy gilak 8
  (part :instrument gong  -:3 GL:1 P - P G))
```

- A part's instrument is the option `:instrument`, the same key a
  `pattern` uses (ADR 0029).
- It is required. A part without `:instrument` is an error.
- The name still defaults to the instrument; `:name` gives another.
  Two parts on one instrument without names are still an error.
- `part` then has no positional arguments: only options, then tokens
  (ADR 0026's order). Options can come in any order.
- The same form inside `colotomy` and at the top level.

## Consequences

- Every part gets longer by 12 characters. Pieces have up to a dozen
  parts (`baris.nts` has 8), so this is acceptable for being explicit.
- The reader no longer has to guess whether a part's first symbol is an
  instrument (the concern of ADR 0027): the option says it.
- An old-style part, `(part gong ...)`, would read `gong` as the first
  token. The reader should catch this case and say to write
  `:instrument gong`, rather than report a strange note.

## Notes for promotion

- Supersedes ADR 0027's form (its decision that the name defaults to
  the instrument stays); one new ADR can cover this and the colotomy
  change, or two.
- Rewrite every `part` in `examples/`, the iteration 2 targets, the
  manual and its examples, tests that build pieces from text, and
  `01-notation.md`.
