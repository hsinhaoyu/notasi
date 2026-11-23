# 0038 A part names its instrument with :instrument, in a colotomy too

Status: accepted (2026-11-23)

Context: A part is `(part INSTRUMENT :name NAME TOKEN ...)` (ADR 0027), and a colotomy's parts are `(PART INSTRUMENT TOKEN ...)` (ADR 0030). The instrument is a bare positional symbol, so nothing on the line says what it is, and a colotomy part reads `(gong gong ...)`, which looks like a typo. The two forms also differ: ADR 0027 dropped the repeated name for top-level parts, but colotomy parts kept it.

Decision: A part is `(part :instrument INSTRUMENT :name NAME TOKEN ...)`, the same key a pattern uses (ADR 0029). `:instrument` is required; `part` has no positional arguments, only options (in any order) and then tokens. Without `:name` the part is named after its instrument, and two parts on one instrument without names are an error, as before. A colotomy's parts are written as exactly this form, `(colotomy gilak 8 (part :instrument gong -:3 GL:1 P - P G))`; only `part` forms are allowed inside `colotomy`. The old forms become errors whose messages show the new form; there is no transition.

Consequences: Every part says what its instrument is, and there is one part form to learn, at the top level and in a colotomy. Each part is about 12 characters longer. Every `.nts` file (examples, targets, templates' colotomies, the manual, tests) is rewritten. Everything else in ADR 0030 stands: colotomies generate their parts for the whole piece and keep their names, the timekeeper is always generated, a piece is its pickup plus whole cycles, and positions are cycle and pulse.

Supersedes: 0027 (the form of a part), 0030 (the form of a colotomy's parts)
