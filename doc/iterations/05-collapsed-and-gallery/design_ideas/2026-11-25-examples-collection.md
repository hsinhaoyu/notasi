# Design idea: the collection of examples

Status: idea (2026-11-25). Open questions below. Not the design until
promoted.

## The idea

The repository comes with a collection of `.nts` files of four kinds,
all under `examples/`, each with its own rule for testing and for
whether its drawings are committed:

```
examples/
  gallery/                showcase pieces, chosen to look good
    jaya-semara.nts
    baris.nts
    images/               their drawings, committed
  demos/                  show a feature, not pretty enough for the gallery
  contrib/                from other users
  manual/                 the user manual's examples (from doc/manual/src/examples/)
    templates/            templates the manual's examples use
    images/               their drawings, committed
```

| Folder | What it is | Tested | Drawings committed |
|---|---|---|---|
| `gallery/` | Showcase pieces; the README and the manual may show them | yes (golden JSON) and images up to date | yes, `gallery/images/` |
| `demos/` | Examples that show a feature, not visually appealing enough for the gallery; not necessarily full pieces | yes (golden JSON) | no |
| `contrib/` | Examples from other users | no | no |
| `manual/` | The manual's examples, shown with `{{#include}}` | yes (`tests/manual.scm`) and images up to date | yes, `manual/images/` |

Today `examples/` holds four pieces used as test fixtures
(`tests/golden.scm`, and `make preview`, which draws them), and the manual's examples live in
`doc/manual/src/examples/` with figures drawn by `make manual` and never
committed.

## Agreed (2026-11-25)

- Everything is under `examples/`.
- `examples/gallery/` with its drawings in `examples/gallery/images/`,
  committed. `jaya-semara` and `baris` move there.
- `examples/demos/` for examples that demonstrate features but aren't
  gallery material. They are tested; their drawings aren't committed.
  They need not be full pieces.
- `examples/contrib/` for other users' examples. Not tested. No README
  in the folder.
- The manual's examples move to `examples/manual/`, with their drawings
  committed in `examples/manual/images/`.

## Why committed drawings

- The README, shipped on `main`, can show gallery pictures by relative
  path. `examples/` is not a dev-only path (`.claude/skills/release`),
  so the images are released with it.
- The manual builds with mdBook alone: no Guile or Typst needed to
  build or deploy it, locally or in CI.
- A change to how scores look shows up as changed images in the PR.

- **Drawings are PNG**, named as ADR 0040: `NAME.png`, or
  `NAME_SCORE.png` for a file with scores. Their resolution is to be
  chosen (open question 1).
- **Keeping them current**: one make target (`make images`) redraws
  every committed image, using `notasi render --all` ([drawing every
  score](2026-11-25-render-all-scores.md)); CI redraws them and fails if
  any image changes, so a PR that changes the look commits the new
  images.
- **The manual's images are copied** into `doc/manual/src/figures/` by
  `make manual` before mdBook builds (mdBook publishes only files under
  `src/`). The `.nts` sources are shown with `{{#include}}` straight
  from `examples/manual/`, which reads any path.
- **The manual's mistakes move** to `examples/manual/mistakes/`, so
  every `.nts` is under `examples/`; the other folders' tests skip it.
- **`gilak` and `tenzer1` go to `demos/`.**
- **No reading check for `contrib/`.**
- **Contributions are credited** by the keys of [information about a
  piece](2026-11-24-piece-information.md) (`:contributor`, `:source`,
  `:transcriber`), by convention, not as a rule.

- **No `make preview`.** It is removed, with `scripts/preview.scm`:
  `make images` draws `gallery/` and `manual/`, and `notasi render
  --all` draws any one file, `demos/` included.
- **A resolution option for PNG.** `notasi render` gets an option
  that sets a PNG's resolution (see [drawing every
  score](2026-11-25-render-all-scores.md)); `make images` passes one
  fixed value, set in one place.
- **Not now**: how a reviewer sees what changed in a PNG, and whether
  Typst draws identical bytes on every machine for the CI check. To be
  looked at when the check is built.

- **Example names are unique across `examples/`.** A test fails if two
  folders hold a file of the same name. Golden files keep their names
  (`tests/golden/NAME.json`, `NAME_SCORE.json`), with no folder.

- **Only the manual's images a page shows are committed.** `make
  images` reads the manual's pages for image links
  (`![...](figures/NAME_SCORE.png)`) and draws just those into
  `examples/manual/images/`. The gallery's images are every score of
  every gallery file.

- **The manual's templates move with its examples.** `(use "templates/my-gamelan.nts")`
  is resolved relative to the file that contains it (01, "use"), so
  `examples/manual/templates/` keeps `use-my-gamelan.nts` working
  unchanged.

## Open

1. **The resolution of committed images.** Sharp enough for the README
   and the manual, small enough for the repository. To be chosen by
   eye.

## Notes for promotion

- A new ADR: the four folders and their rules; committed drawings for
  `gallery/` and `manual/`. It reverses the manual's rule that figures
  are generated and never committed (CLAUDE.md, "User manual"; ADR
  0014's consequences).
- 07 (environment): the layout of `examples/`, the make target for the
  images, the CI check.
- Moving files: `jaya-semara` and `baris` into `gallery/`, `gilak` and
  `tenzer1` into `demos/`; `doc/manual/src/examples/` (and
  `templates/`) to `examples/manual/`; `doc/manual/src/mistakes/` to
  `examples/manual/mistakes/`.
- Tests: `tests/golden.scm` reads `gallery/` and `demos/` (golden file
  names keep `NAME` or `NAME_SCORE`), and checks that names are unique
  across `examples/`; `tests/manual.scm` reads `examples/manual/`; a test or
  CI step for current images.
- Makefile: `make golden` and `make manual` read the new folders;
  `make images` is added; `make preview` and `scripts/preview.scm` are
  removed (README, CLAUDE.md and `tests/readme.scm` with them).
- Manual: every `{{#include}}` path and image link; `STYLE.md`.
- README: a gallery picture or two; the layout of `examples/`.
- CLAUDE.md: the repository layout, "User manual", "Tests".
- `tests/readme.scm`, if README names the folders.
