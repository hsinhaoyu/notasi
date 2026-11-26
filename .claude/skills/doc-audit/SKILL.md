---
name: doc-audit
description: Compare the design documents in doc/design/ and the decision log in doc/decisions/ with the code, and list every discrepancy. Use at milestones or when the user asks whether the docs are up to date.
disable-model-invocation: true
---

# Audit design docs against the code

Find drift between the design documents and the code. Report it; don't fix
anything until the user says so.

## Steps

1. Read `doc/design/README.md`, `doc/design/glossary.md`, every
   `doc/design/0*.md`, `doc/manual/`, every ADR in
   `doc/decisions/` whose status is `accepted`, and the repository layout
   in CLAUDE.md.

2. Read the code and its executable spec: `notasi/*.scm`, `tests/*.scm`,
   `examples/`, `tests/golden/` (if present), `typst/` (if present) and the
   Makefile.

3. For each design document, compare it with the code:
   - Interfaces: exported procedures, records and fields, CLI commands.
   - Behaviour: notation tokens and rules, reader error cases, layout
     decisions, the JSON contract and its `version`.
   - Structure: the repository layout and module dependencies (ADR 0004:
     reader and layout depend only on `(notasi piece)`; see ADRs 0008, 0015).
   - Status labels: the `Status:` line and any Implemented / Planned /
     Open questions sections. Something marked planned that now exists,
     or marked implemented that doesn't, is drift.

4. Compare the user manual (`doc/manual/src/`) with the code: a page
   describing behaviour the code doesn't have (or no longer has), error
   messages quoted differently from what the reader raises, or
   user-visible behaviour with no page yet. Use "manual" as the doc side
   in the report.

5. Check the terms against the glossary (`doc/design/glossary.md`,
   ADR 0051). Search the design docs, the manual, the templates'
   comments, the code's names (procedures, record fields, JSON keys)
   and its error messages for the words in the glossary's "Not"
   column, used for the thing the glossary names. Use "glossary" as the
   doc side in the report. Don't report:
   - an older name the glossary's "In code / JSON" column says the code
     still uses, unless the milestone just built touched that code and
     left it (CLAUDE.md says to rename it then);
   - a source quoted in its own words (Gold's "beat", a "meter");
   - the word used for something else (a text "line" that isn't a
     system).

6. Check that the code doesn't contradict an accepted ADR. A contradiction
   means either the code is wrong or a superseding ADR is missing.

7. Report a table with one row per discrepancy:
   - where in the docs (`file:line`)
   - where in the code (`file:line`), or "missing"
   - what differs, in one sentence
   - which side looks out of date: **doc**, **code**, or **unclear**
     (needs a decision; say what the decision is)

   Then list any open questions in the docs that the code has already
   answered. If nothing differs, say so plainly.

8. Offer to fix the doc-side items on a `doc/sync` branch from `dev`. Code
   fixes and unclear items need the user's decision first. Any fix that
   reverses a documented decision needs a new ADR (see
   `doc/decisions/README.md`).
