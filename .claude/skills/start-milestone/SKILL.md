---
name: start-milestone
description: Start a milestone or one slice of a milestone of the current iteration (doc/iterations/, status building) - create the feature branch, write tests from the design doc before any code, pause for the user to review them, and plan the implementation. Use when the user wants to start or work on a milestone or slice such as feat/piece or feat/reader-forms.
argument-hint: "[branch, e.g. feat/piece or feat/reader-forms]"
---

# Start a milestone or slice

**Current iteration.** Milestones come only from the current iteration
(ADR 0023). Find it first: the `doc/iterations/NN-*/README.md` whose
`Status:` is `building`.

- If the latest iteration's status is `deciding`, stop: no milestone may
  start until its design is promoted. Say which design docs its
  "Promotion" section still lists as not promoted, and that the user runs
  `/promote-design` for each.
- If no iteration is `building`, say so and stop.

Argument: the branch name. It is either a whole milestone from the
"Milestones" section of the current iteration's README (e.g.
`feat/piece`) or one slice of a milestone, as listed under "Slices" in
that milestone's design doc (e.g. `feat/reader-forms` in
`03-reader.md`). A branch that isn't a milestone or slice of the current
iteration is refused: say so and list the iteration's milestones.

If no argument is given, take the first milestone in the current
iteration's "Milestones" whose design doc's `Status:` line doesn't say
it's implemented. If its doc has a "Slices" section, take the first
slice not marked implemented. Confirm the choice with the user.

A milestone whose design doc lists slices is never started whole: one
slice per branch and per PR. If the user names such a milestone, say so
and offer its next slice.

**Scope.** Everything below (tests, plan, implementation, doc updates) is
limited to the slice's scope as its design doc describes it: its steps,
and the error cases tagged with its number. Don't build ahead into later
slices; if the slice can't work without something from a later one, stop
and ask.

## Steps

1. **Branch.** The working tree must be clean; if not, stop and ask. Then:

   ```
   git fetch --prune origin
   git switch dev && git pull --ff-only
   git switch -c <branch>
   ```

   Then make sure the milestone has its **GitHub milestone**, named
   `Iteration N · <milestone branch>` (e.g. `Iteration 2 · feat/music`,
   for every slice of `feat/music`). List them with
   `gh api repos/{owner}/{repo}/milestones --jq '.[].title'`; if it is
   missing, create it with
   `gh api repos/{owner}/{repo}/milestones -f title='…' -f description='…'`,
   the description naming the iteration and milestone and pointing to
   the iteration's README. `/ship` puts the PR in it.

2. **Read the spec.** Read the design doc(s) for the milestone (the
   table in `doc/design/README.md` maps modules to docs), the accepted ADRs
   in `doc/decisions/`, and the existing code the work builds on,
   including earlier slices. List any open questions in those docs that
   block this slice, including any interface the tests will need that the
   doc leaves undecided (names of procedures, condition types, fields), and
   ask the user to decide them. Record each decision in the design doc
   before going further.

3. **Tests first.** Launch a subagent to write the tests from the design
   doc alone, without reading or writing the implementation, so the tests
   aren't shaped by the code. Give it:
   - the design doc path(s), the ADRs that apply, and the slice's scope
   - the test conventions in CLAUDE.md ("Tests"), including the exit-code
     idiom from `tests/smoke.scm`
   - for the reader: a test for every error case tagged with this slice
   - for a later slice: add to the existing `tests/<module>.scm` and
     don't change existing tests; if the spec seems to require changing
     one, report it instead

   Review what it wrote against the doc. Run `make check` and confirm that
   the new tests fail for the right reason (missing code), not because of
   mistakes in the tests, and that existing tests still pass.

4. **Pause for review.** Stop and ask the user to review the tests. Give
   a short list of the behaviours they pin down, mapped to the doc's
   steps and error cases, and point out any place where the doc was
   ambiguous and the tests had to choose. Wait for the user's go-ahead;
   make the changes they ask for first.

5. **Plan.** Enter plan mode and propose the implementation of this
   slice only: records, exported procedures, the order of work, and any
   design doc changes the work will need. Wait for approval.

6. **Implement** in small commits until `make check` passes. Follow
   "Scheme style" in CLAUDE.md.

7. **Finish.** Update the design doc: move what this slice built from
   Planned to Implemented, mark the slice implemented in "Slices", and
   set the `Status:` line (e.g. "partly implemented: slices 1-2 of 4";
   "implemented" after the last slice). If the work changes anything a
   user can see, update the user manual as "User manual" in CLAUDE.md
   says: read `doc/manual/STYLE.md`, add or change pages and example
   files, and run `make check` (and `make manual` if `mdbook` is
   installed). If nothing user-visible changed, say so. Then tell the
   user the slice is
   ready for `/ship`. Don't push or open a PR until they ask. After the
   last slice of a milestone (or a milestone without slices), also
   remind the user to run `/doc-audit`. After the last milestone of the
   iteration, say that the iteration moves to Verify: run its acceptance
   test (in its README) and `/doc-audit`, then `/release`.
