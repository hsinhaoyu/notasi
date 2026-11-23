# Design idea: common colotomies come from the template

Status: agreed in discussion (2026-11-23); see "Settled". Not the
design until promoted.

## Now

The `gong-kebyar` template has no colotomies (01, "instrument"; decided
in iteration 2's `feat/targets`): every piece defines its own, so
`examples/gilak.nts`, `tenzer1.nts` and `baris.nts` each repeat

```scheme
(colotomy gilak 8
  (part :instrument gong  -:3 GL:1 P - P G))
```

and Jaya Semara defines `pangecet-16`. A template may already contain
`colotomy` forms (01, "use"); the template just doesn't.

## The idea

Colotomies used in many pieces, such as gilak, are defined once, in a
template, and a piece uses them by name: `(piece "Baris" :colotomy gilak
:pickup 1)` after `(use gong-kebyar)`, with no `colotomy` form of its
own. A piece can still define its own, or replace the template's with
its own definition of the same name, as for any definition (01, "use").

This reverses iteration 2's "Colotomies are not in the template".

## Open

1. **Which template.** In `gong-kebyar`, beside the `gong` instrument
   its parts play, or in a template of their own (`(use colotomies)`)
   that `gong-kebyar` loads, as it loads `selisir`? Leaning:
   `gong-kebyar`; a colotomy needs its gong instrument, and one `use`
   gives a piece everything.
2. **Which colotomies.** At least `gilak` (8 pulses: gong lanang on 4,
   kempur on 5 and 7, gong on 8, as in 01 and Tenzer's Baris). Others
   only when an example needs them? Jaya Semara's 16-pulse meter (Gold
   calls it bapang: kempur, klentong, kempur, gong) is the other one the
   examples use. Leaning: `gilak` and that meter, named after the form
   (`bapang`?) rather than the piece (`pangecet-16`); more later.
3. **Variants.** Gilak is sometimes written with the kempur on 4 and 6
   and no gong lanang (the manual's `gong-cycle.nts`). The template has
   one; a piece that differs defines its own. Leaning: yes, the 01 /
   Tenzer form.
4. **The manual.** The gong-cycles page then shows using `gilak` from
   the template first, and defining a colotomy as the way to write a
   new one. Leaning: yes.

## Notes for promotion

- 01-notation: the template's contents (the paragraph after the
  instrument ranges), and the colotomy examples. A new ADR, reversing
  the iteration 2 decision (recorded in 01, not in an ADR); ADR 0038
  stands (colotomy parts are `part` forms).
- No change to the reader: templates already hold colotomies.
- `templates/gong-kebyar.nts`, the examples (`gilak`, `tenzer1`,
  `baris`, `jaya-semara`), the manual's gong-cycles page and its
  examples, and the template tests in `tests/reader.scm` ("no colotomy
  comes from the template").

## Settled (2026-11-23)

The open questions above, answered:

1. In `gong-kebyar`, beside the `gong` instrument.
2. `gilak` and Jaya Semara's 16-pulse meter, named after the form:
   `bapang` (kempur on 4 and 12, klentong on 8, gong on 16). Others are
   added when a piece needs them.
3. Gilak as in 01 and Tenzer's Baris: gong lanang on 4, kempur on 5 and
   7, gong on 8. A piece that differs defines its own.
4. The gong-cycles page shows using `gilak` from the template first,
   then defining a colotomy as the way to write a new one.
