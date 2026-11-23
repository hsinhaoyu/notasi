# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

GNU Guile 3.0 project for notating and visualizing Balinese gamelan music. `(notasi piece)`, `(notasi reader)`, `(notasi expand)`, `(notasi json)`, `(notasi style)` and `(notasi layout)` are implemented (iteration 2's notation and scores are built; its acceptance test, `feat/targets`, is next: see the current iteration), `(notasi typst)` writes figure files and draws them with Typst (`render-piece`), and `scripts/notasi render` draws a piece from the command line; the rest of the Typst backend and the later milestones are built in the order given under "Build order" in `doc/design/README.md`.

## Commands

- Run all tests: `make check` (exits non-zero if any test file fails)
- Run one test file: `guile --fresh-auto-compile -L . tests/<name>.scm`
- Remove SRFI-64 logs: `make clean`
- Draw every score of each example to `build/preview/` (`NAME.png`, or `NAME.SCORE.png` for a file with scores) for a visual check: `make preview` (needs Typst)

Typst is pinned to **0.15.1** (05, "Version pinning"); CI installs exactly that version. `tests/template.scm` needs `typst` on the PATH.

Always run from the repo root with `-L .` so `(notasi ...)` modules resolve.

`--fresh-auto-compile` is deliberate: Guile caches compiled `.go` files in `~/.cache/guile/ccache` and checks freshness only by mtime. If a file is edited within the same second as the last compile, Guile loads the stale copy and tests give wrong results. `--no-auto-compile` does not fix this, because a cached `.go` that looks current is still loaded.

## Architecture

Modules live in `notasi/` under the `(notasi <name>)` namespace. The intended pipeline is:

`reader` (text notation, with `expand` turning each part's tokens into timed events) → `piece` (core records: instruments, notes, parts, colotomies, patterns) → `layout` (visual structure) → `typst` (Typst source output). There is no analysis module (ADR 0015).

The notation that `reader` parses is specified in `doc/design/01-notation.md`.

Repository layout (entries marked *planned* don't exist yet):

```
notasi/             Guile modules: piece, reader, expand, style, layout, json, typst, command
typst/              Typst template notasi.typ; the package's typst.toml (planned, 06)
scripts/            the notasi command: notasi render (typst, update, watch planned, 06);
                    preview.scm, used by make preview
examples/           real pieces (.nts), used as test fixtures
templates/          shared definitions (.nts) loaded with (use NAME)
tests/              SRFI-64 test files, one per module
tests/golden/       expected JSON figures, one per score of each example (make golden)
doc/prototypes/     hand-made mockup of the target output (score.typ, piece.json)
doc/manual/         user manual for musicians (mdBook; style in STYLE.md)
doc/design/         design documents (the current design)
doc/iterations/     one folder per iteration: README (goal, acceptance test,
                    status, milestones), design_ideas/ (thinking), targets/;
                    backlog.md
doc/references/     reference material useful beyond one iteration
doc/decisions/      decision log (ADRs)
```

## Design documents

`doc/design/` describes the current design; `doc/decisions/` holds numbered decision records (ADRs) explaining why. Read the relevant design doc before working on a module. Design ideas under `doc/iterations/*/design_ideas/` are thinking, never the design: never treat them as a spec or build from them. The one exception is the promotion step (`/promote-design`), which reads them when the user asks for it.

- Any change to behaviour, notation, the piece records or the JSON contract updates `doc/design/` in the same PR. Keep each doc's `Status:` line and its Implemented / Planned / Open questions labels accurate.
- Reversing or narrowing a documented decision requires a new ADR in `doc/decisions/` (format and rules in its README), and the old ADR's status becomes `superseded by NNNN`. `tests/decisions.scm` checks the format.
- Never edit an accepted ADR except its `Status:` line.
- `gh pr create --body` replaces `.github/pull_request_template.md`, so copy its docs checkboxes into every PR description and tick each only if those docs were updated or aren't needed.

## Iterations

Work is organised in iterations (ADRs 0023, 0024). An iteration is a goal plus an acceptance test, in `doc/iterations/NN-name/README.md`, worked through in five phases:

1. **Explore**: discussion, written as dated design ideas in the iteration's `design_ideas/`.
2. **Decide**: the design ideas are promoted into `doc/design/` and ADRs with `/promote-design`, one PR per design doc, in dependency order (01; 02 and 03; 04 and 05; 06 and the build order). Each ADR lands with the first design doc it changes.
3. **Build**: milestones and slices, with `/start-milestone`.
4. **Verify**: the acceptance test, and `/doc-audit`.
5. **Close**: `/release`, and a version tag.

An iteration's `Status:` is `deciding` (phases 1–2), `building` (3–4) or `done` (released). `tests/iterations.scm` checks it. While it is `deciding`, no milestone starts: promotion must be complete first, so no one builds from a half-updated design. Promotion is the only step that reads design ideas. `/promote-design` has `disable-model-invocation`, so the user runs it.

Versions: one minor version per iteration (iteration N is v0.N.0), with v0.N.x for fixes. Iteration 1 was released as v0.1.x.

Deferred work is in `doc/iterations/backlog.md`.

## User manual

`doc/manual/` is the user manual for musicians, built with mdBook (ADR 0014). Claude writes it, as part of the work rather than at the end:

- Any change a user can see (notation, error messages, commands, output) updates the manual in the same PR. Behaviour that isn't implemented yet is never documented there.
- Read `doc/manual/STYLE.md` before writing a page. It sets the reader, the tone and the outline.
- Examples are files in `doc/manual/src/examples/`, shown with `{{#include ...}}`. `tests/manual.scm` (under `make check`) checks that each one reads and is used by a page.
- Mistakes shown on a page are files in `doc/manual/src/mistakes/`: `NAME.nts` and the exact error message in `NAME.txt`. `tests/manual.scm` checks that each fails with that message, so a changed error message means updating its `.txt`.
- A page can show a drawn score as `![…](figures/NAME.svg)`, or another score of the example as `figures/NAME.SCORE.svg`: `make manual` draws it from `src/examples/NAME.nts` with `scripts/notasi render` (and `--score SCORE`) before building. `figures/` is generated, never committed; `tests/manual.scm` checks each figure has its example.
- `make manual` builds it (needs `mdbook`, Guile and Typst); CI builds it on every PR and deploys it to GitHub Pages when `main` changes.

## Git workflow

- `main` holds only what users need. It only receives release commits made by `/release`: `dev`'s files minus the dev-only paths listed in `.claude/skills/release/SKILL.md` (Claude Code files, design docs, ADRs, iterations, references, prototypes), one squash-merged commit per release, tagged there (ADR 0023).
- `dev` is the integration branch and holds everything. Feature branches are squash-merged into it.
- Never merge `dev` into `main` or `main` into `dev`: they don't share history.
- Never commit directly to `main` or `dev`. Work on a branch from an up-to-date `dev`, named `feat/…`, `fix/…`, `chore/…` or `doc/…`.
- Commit when the user asks; push and open a PR only when the user asks. Use `/ship` to open a PR.
- Every PR targets `dev` and needs green CI before merging.
- After a PR is merged, `/cleanup-branches` deletes its branch.
- Each milestone of an iteration has a GitHub milestone, `Iteration N · <milestone branch>` (e.g. `Iteration 2 · feat/music`): `/start-milestone` creates it, `/ship` puts every slice, fix and `/doc-audit` sync PR of that milestone in it, and `/release` closes it. Promotion, governance and housekeeping PRs get none.

## Working on a milestone

Milestones come from the current iteration: the one whose README's status is `building`, listed under "Milestones" there. A large milestone is split into slices, listed under "Slices" in its design doc; each slice is its own branch and PR. Start each milestone or slice with `/start-milestone <branch>`, which creates the branch, has a subagent write tests from the design doc before any code exists (so tests aren't shaped by the implementation), pauses for the user to review the tests, and plans the implementation for approval. It never builds beyond the slice's scope. The user runs `/doc-audit` at the end of each milestone to find drift between the docs and the code; it has `disable-model-invocation`, so Claude can't call it and should remind the user instead.

A PostToolUse hook (`.claude/hooks/guild-compile.sh`) compiles every edited `.scm` file with `guild`, catching unbalanced parentheses and unbound variables immediately.

## Scheme style

Write idiomatic Guile 3, not another language translated into Scheme:

- Data: immutable `define-record-type` (SRFI-9) records for domain objects; association lists or vectors only for small, simple data.
- Control flow: `match` from `(ice-9 match)` for destructuring and dispatch over cond/car/cdr chains; named `let`, `fold`, and SRFI-1 procedures over manual loops; tail recursion over mutation. Avoid `set!` unless state is truly local.
- Procedures: `define*` with `#:key` arguments for optional settings, `parameterize` for configuration passed through context (e.g. layout settings), and docstrings on exported procedures.
- Errors: Guile 3 exceptions (`raise-exception`, `make-exception` with `&error`/`&message`/`&irritants`; `guard` or `with-exception-handler` to catch them). Do not fail by returning `#f`.
- Modules: export explicitly with `#:export`, so a module's public surface is its export list.
- Macros: use one when a procedure can't do the job: a new binding form, control over evaluation (delay, short-circuit), a declarative mini-language (likely for instrument/notation definitions), or compile-time checks. Prefer `syntax-rules`; use `syntax-case` only for what it alone can do (e.g. building identifiers, checking syntax at expansion). Don't write a macro just to save a little typing or where a higher-order procedure works.

## Keeping README.md current

`tests/readme.scm` runs under `make check` and fails when README.md is out of sync with the code: a module file in `notasi/` that README doesn't mention, a `notasi/*.scm` path in README that doesn't exist, or a `make <target>` in README that the Makefile lacks. When you add, rename, or remove a module, Makefile target, or user-facing workflow, update README.md in the same change. If README needs a new kind of fact that could go stale (e.g. a CLI command), extend `tests/readme.scm` to check it.

## Tests

Tests use SRFI-64. Each `tests/*.scm` file is a standalone script that `make check` picks up automatically; CI runs the same command. A test file must exit non-zero on failure: save `(test-runner-current)` before `test-end`, then `(exit (zero? (+ fail-count xpass-count)))`. See `tests/smoke.scm`.

What to test:
- Unit tests, one file per module: reader token handling and every error case listed in `doc/design/03-reader.md`, piece derived functions, layout decisions (lanes, system splitting, colours), JSON serialiser escaping.
- Golden tests: for each score of each file in `examples/`, the generated JSON is compared with `tests/golden/` (`NAME.json` for a file with only the default score, `NAME.SCORE.json` otherwise). When an output change is intended, regenerate them with `make golden` and review the diff in the PR.
- Typst template test: `tests/template.scm` compiles every golden figure with `typst/notasi.typ` and fails on an error or a warning. Changes to the template are also checked by eye with `make preview`.
