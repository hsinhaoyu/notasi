# Iteration 6: a workflow for the README

Status: building

## Goal

The README is for musicians, and it is written by two hands. The user
writes the sections that carry the project's voice; Claude keeps the
sections that state facts about notasi in step with the code, and only
suggests changes to the user's sections. The process is light: one
marker per section, one skill, a few tests.

Only the README, plus the project's licences, which the README names.
The user manual keeps its own rules (`doc/manual/STYLE.md`).

## Acceptance test

Agreed (2026-11-27):

1. `README.md` has the sections and owners in
   [who owns each section](design_ideas/2026-11-27-readme-sections.md),
   each with its `owner:` marker. "Layout" and "Running tests" have
   moved to `CONTRIBUTING.md`, and the tests that checked them check
   it.
2. `tests/readme.scm` checks the markers and the relative links, and
   runs the "Drawing a score" commands on a copy of
   `examples/gallery/jaya-semara.nts`.
3. `/readme-sync` exists and only the user can run it. Run once, its
   PR changes only `owner: claude` sections, and its suggestions for
   the user's sections are review comments on the PR.
4. `/doc-audit` reports README drift.
5. The licences are in place, as in
   [licences](design_ideas/2026-11-27-licences.md): `LICENSE` (MIT),
   `doc/manual/LICENSE` and `examples/LICENSE` (CC BY 4.0, naming the
   published transcriptions and the rule for `examples/contrib/`);
   `CONTRIBUTING.md` states the contribution rule; and the README ends
   with the user's "Licence" section. GitHub shows "MIT license" on the
   repository page.
6. `make check` passes, in CI too.

## Design ideas

Thinking, not the design (ADRs 0023, 0024). All from the discussion of
2026-11-27, in [`design_ideas/`](design_ideas/):

- [Who owns each section](design_ideas/2026-11-27-readme-sections.md):
  the README is for users; two owners, one marker, briefs; the
  sections; developer sections move to `CONTRIBUTING.md`.
- [Keeping it up to date](design_ideas/2026-11-27-readme-upkeep.md):
  `/readme-sync` when an iteration closes, suggestions as PR review
  comments, and a README step in `/doc-audit`.
- [What the tests check](design_ideas/2026-11-27-readme-checks.md):
  markers, links, and commands that run.
- [Licences](design_ideas/2026-11-27-licences.md): the code under
  MIT; the manual and examples under CC BY 4.0; contributions to
  `examples/contrib/` under CC BY 4.0, credited to their contributors.

## Promotion

In dependency order (ADR 0023). No change to the glossary or to
01–06:

1. `07-environment.md`: the README is for users, with an `owner:`
   marker on each section and `todo:` briefs (a new ADR, narrowing
   0014); `CONTRIBUTING.md` with "Layout" and "Running tests";
   what `tests/readme.scm` checks (markers, links, the "Drawing a
   score" commands); `/readme-sync` and the README step in
   `/doc-audit`; the licences and the contribution rule for
   `examples/contrib/` (a new ADR, "Code is MIT; the manual and
   examples are CC BY 4.0").
2. `08-emacs.md`: "Using notasi in Emacs" is an `owner: claude`
   section, and the `editors/emacs/` layout entry, with its check,
   moves to `CONTRIBUTING.md`.
3. The build order in `doc/design/README.md`.

The rule in CLAUDE.md ("Design documents") goes into
`feat/contributing`, which edits CLAUDE.md's README section anyway
(decided 2026-11-27, when the build order was promoted).

Promoted so far: `07-environment.md` (ADRs 0062, 0063), `08-emacs.md`,
and the build order. Promotion is complete.

## Milestones

Each milestone is its own branch and PR into `dev`, started with
`/start-milestone <branch>`, with no slices. After each one,
`make check` passes. The design is in 07 ("The README", "Licences")
and 08 ("Documentation").

1. **`feat/contributing`** (done) (07, 08, ADR 0062): `CONTRIBUTING.md` at
   the top of the repository, with "Layout" and "Running tests" moved
   from the README; `tests/readme.scm`'s checks on modules, `make`
   targets and the `editors/emacs/` entry check `CONTRIBUTING.md`;
   CLAUDE.md's "Keeping README.md current" names it, and CLAUDE.md
   gains the README rule under "Design documents" (ADR 0062). First,
   so the README can lose its developer sections.
2. **`feat/licences`** (done) (07, ADRs 0063, 0065): `LICENSE` (MIT),
   `doc/manual/LICENSE` and `examples/LICENSE` (CC BY 4.0, listing the
   published sources and the rule for `examples/contrib/`); the rule in
   `CONTRIBUTING.md`. Before the README, whose "Licence" section links
   to these files.
3. **`feat/readme-sections`** (done) (07, 08, ADR 0062): the README's eight
   sections in order, each with its `owner:` marker, at most about 150
   lines; `tests/readme.scm` checks the markers, the relative links,
   and the "Drawing a score" commands on a copy of
   `examples/gallery/jaya-semara.nts`. The milestone adds the user's
   sections (the sentence on how settled notasi is, "Why notasi" (removed, ADR 0067),
   "Licence") with their `owner: user` markers; the user writes their
   text in its PR before it merges.
4. **`feat/readme-sync`** (07, ADR 0062): the `/readme-sync` skill
   (`disable-model-invocation`), and the README step in `/doc-audit`.

Then Verify: the acceptance test, with `/readme-sync` run once, and
`/doc-audit`.
