# Design idea: keeping the README up to date

Status: agreed in discussion (2026-11-27). Not the design until
promoted.

## The problem

The README is shipped on `main`, so it should describe what is
released, not what is half-built. Its facts drift when a milestone
changes a command or adds a feature, and nothing updates them unless
someone remembers to.

## Settled (2026-11-27)

- **One skill, `/readme-sync`** (`disable-model-invocation`, so only
  the user runs it). On its own branch, through `/ship`, Claude:
  - updates the `owner: claude` sections that no longer match the
    code, the manual and the iterations that are done, and fixes their
    spelling and grammar;
  - writes any section with a `todo:` brief, and removes the brief;
  - posts suggestions for the `owner: user` sections (a stale fact, a
    spelling mistake, a new feature worth naming) as **review comments
    on the PR**, each on its line. The user makes the edits they
    accept and resolves the rest. Never comments in the file.
- **When.** Once as an iteration closes: after its last milestone is
  merged, before `/release`, so the README on `main` matches the
  release. Any other time the user wants.
- **Fact-check.** `/doc-audit` gains one step: compare the README
  with the code and the manual, and report drift in its table with
  "README" as the doc side. It reports only, as now.
- **The user's own edits** need no process: edit, commit, ship.
