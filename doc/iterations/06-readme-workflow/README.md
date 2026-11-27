# Iteration 6: a workflow for the README

Status: deciding

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
