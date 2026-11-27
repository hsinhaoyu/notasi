# 0068 No `/readme-sync` skill, and no README step in `/doc-audit`

Status: accepted (2026-11-28)

Context: ADR 0062 gave the README two ways to stay current besides its tests: a `/readme-sync` skill, run by the user as an iteration closes, that updates Claude's sections on its own branch and PR and posts suggestions for the user's sections as review comments; and a README step in `/doc-audit` that reports README drift. Designing the skill showed it to be more process than the README needs: GitHub allows line comments only on lines in a PR's diff, which the user's sections never are, and a run with nothing to change has no PR to comment on. The README is short, `tests/readme.scm` checks the facts most likely to break (markers, links, the "Drawing a score" commands), and CLAUDE.md already has Claude update its sections in the change that makes them stale.

Decision: There is no `/readme-sync` skill and no README step in `/doc-audit`. Claude keeps the `owner: claude` sections in step with the code in the same change that affects them, as CLAUDE.md says, and writes a `todo:` brief when asked. The user edits their own sections when they want. Everything else in ADR 0062, as narrowed by ADR 0067, stands: the README is for users, its sections have owners and markers, Claude never edits a user's section, and the tests.

Consequences: No skill to run when an iteration closes, and iteration 6 ends with three milestones. Drift in a README fact the tests don't check is found only when someone reads it, or when Claude touches the code it describes. Whoever wants the skill or the audit step back writes a new ADR.

Supersedes: 0062 (only `/readme-sync` and the README step in `/doc-audit`)
