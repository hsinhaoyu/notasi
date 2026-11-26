# 07 — Environment, installation and testing

Status: mostly open questions. Iteration 4 (ADR 0049): CI for the
Emacs package and what Emacs users install are implemented.
This answers question 2 for Emacs users only. The examples in four
folders, their committed drawings and the CI check that keeps them
current (ADR 0052) since iteration 5's `feat/examples`. Each question, once decided, gets an
ADR and this document is updated to describe the choice.

## Responsibility

How the tools notasi needs get onto a machine, for the people who work
on notasi and for the people who use it, and how we check that a fresh
machine really works. This covers tools, not code: the pipeline is in
01–06.

## What is needed

ADR 0007 (standard library first) means notasi has no Guile library
dependencies, so there is nothing to resolve, only programs to install
at the right versions:

| Tool | Needed by | Why |
|---|---|---|
| Guile 3.0 | everyone | runs notasi and its tests |
| Typst | everyone who draws, and contributors | draws the figures (05, 06); pinned to 0.15.1 |
| mdBook | contributors | builds the user manual (ADR 0014) |
| Emacs 29.1 or later | Emacs users of `notasi-mode`, and contributors to it | runs the package (08); since iteration 4 |

Typst is pre-1.0 and has breaking changes in most releases, usually
small (05, "Version pinning"). Whatever is decided below has to pin
its version.

## Current state

**Implemented.**

- Contributors install the tools by hand. The README says Guile 3.0 is
  required, with no version or install method.
- CI (`.github/workflows/ci.yml`) runs `make check` on every PR to
  `dev` and `main`, on a fresh `ubuntu-latest` machine, with Guile from
  apt. The Guile version is whatever Ubuntu ships, and it changes when
  `ubuntu-latest` moves to a newer Ubuntu.
- CI also installs Typst at the pinned version (`TYPST_VERSION`,
  0.15.1, from Typst's GitHub releases), so the template and the
  `notasi` command are tested on every PR.
- The manual workflow (`.github/workflows/manual.yml`) pins mdBook
  (`MDBOOK_VERSION`), installs Guile and Typst 0.15.1 to draw the
  manual's figures, builds the manual (`make manual`) on every PR, and
  publishes it to GitHub Pages when `main` changes (ADR 0014). Nothing
  else publishes to Pages.
- The developer's machine runs macOS; CI runs only Linux.
- Nothing installs notasi for users yet: they run `scripts/notasi`
  from a copy of the repository, with Guile and Typst installed by
  hand.

## Emacs users

**Implemented** (iteration 4, ADR 0049; the manual's chapter "Writing in
Emacs", `feat/emacs-docs`).

- **notasi** comes with the Emacs package (08): installed from GitHub
  with `package-vc` or `use-package :vc`, the whole repository is
  cloned, and the mode runs its `scripts/notasi`. Nothing else
  installs notasi.
- **Guile and Typst** are installed by hand. The manual's chapter for
  Emacs users gives the commands for macOS and for Debian and Ubuntu:
  Guile 3.0 from the system's package manager (Homebrew, apt), and
  Typst at the pinned version (0.15.1) from Typst's GitHub releases,
  as CI installs it. When the pin changes, those commands change with
  it.
- **Emacs 29.1** is the oldest supported.
- **CI** checks the package in a job of its own, running
  `make check-emacs` on Emacs 29.1 and on the newest Emacs release
  (31.1). It installs `package-lint` from MELPA. `make check` does not
  need Emacs. **Implemented** (`feat/emacs-package`).
- Before the iteration is accepted, the acceptance test is run by hand
  on a fresh Emacs, following only the README and the manual (the
  "README test" of question 3, done once, by hand).

## Examples and their drawings

**Implemented** (iteration 5's `feat/examples`, ADR 0052), tests in
`tests/examples.scm`, `tests/golden.scm` and `tests/manual.scm`.

Every `.nts` example in the repository is under `examples/`:

```
examples/
  gallery/          showcase pieces
    images/         their drawings, committed
  demos/            examples that show a feature
  contrib/          other people's examples
  manual/           the user manual's examples
    templates/      templates they use
    mistakes/       the manual's mistakes (NAME.nts, NAME.txt)
    images/         the drawings its pages show, committed
```

| Folder | What it holds | Tested | Drawings committed |
|---|---|---|---|
| `gallery/` | Showcase pieces; the README and the manual may show them | golden JSON; images up to date | every score of every file, in `gallery/images/` |
| `demos/` | Examples that show a feature; not necessarily whole pieces | golden JSON | no |
| `contrib/` | Other people's examples; no README in the folder (an empty `.gitkeep` keeps it in git) | no, not even read | no |
| `manual/` | The manual's examples, shown with `{{#include}}` from here | `tests/manual.scm`; images up to date | those a page shows, in `manual/images/` |

- **The pieces:** `gallery/` holds `jaya-semara`, `baris` and
  `gambangan-excerpt`; `demos/` holds `gilak` and `tenzer1`.
- **Names** are unique across `examples/`: a test fails if two folders
  hold a file of the same name. Golden files keep their names, with no
  folder: `tests/golden/NAME.json`, or `NAME_SCORE.json` for a file
  with scores (ADR 0040). They cover `gallery/` and `demos/`.
- **The manual's mistakes** are under `manual/mistakes/`, so every
  `.nts` is under `examples/`; the other folders' tests skip it.
- **The manual's templates** move with its examples, so
  `(use "templates/my-gamelan.nts")`, resolved relative to the file
  that contains it (01), works unchanged.
- **`templates/`**, the shared definitions loaded with `(use NAME)`,
  stays where it is.
- **Contributions** are credited with the piece information keys
  `:contributor`, `:source` and `:transcriber` (01), by convention.

### Drawings

- **PNG**, named as ADR 0040 says: `NAME.png`, or `NAME_SCORE.png` for
  a file with scores.
- **`make images`** redraws every committed drawing with `notasi
  render` (05), passing one fixed `--ppi` value set in one place in the
  Makefile. It draws every score of every gallery file into
  `gallery/images/` with `--all`, and, for the manual, only the images
  its pages link to, one by one, as each link names them
  (`![…](figures/NAME.png)` for the example's first score, or
  `figures/NAME_SCORE.png` with `--score SCORE`), into
  `manual/images/`. It empties each `images/` folder first, so an image
  no longer needed is deleted. The resolution,
  chosen by eye, is 144 ppi (`IMAGES_PPI`): sharp on high-resolution
  screens, and about 60 KB for one of Jaya Semara's scores.
- **The committed images are Linux's.** They are drawn on Linux with
  the pinned Typst (0.15.1), as CI draws them, so the check doesn't
  depend on Typst drawing the same bytes on every system. CI runs
  `make images` and fails if any image changes; when it fails, it
  uploads the images it drew as a workflow artifact, and the PR commits
  those. `make images` on another system (macOS) is for looking: its
  images may differ in their bytes and are not committed.
- **`make check` checks the set of images**, on any system: one in
  `gallery/images/` for each score of each gallery file, one in
  `manual/images/` for each image a manual page links to, and nothing
  else in either folder. A manual page links PNGs only. Only CI
  compares the images' bytes.
- **The manual** builds with mdBook alone: `make manual` copies the
  images its pages show from `examples/manual/images/` into
  `doc/manual/src/figures/` (which stays generated, not committed) and
  draws nothing. Its CI workflow then needs only mdBook.
- **`make preview`** and `scripts/preview.scm` are removed. To draw any
  one file, `demos/` included, use `notasi render --all`.

## Open questions

### 1. A reproducible environment for developers

How does a contributor (or the same person on a new laptop) get the
right tools at the right versions after a fresh clone, as `uv` does for
a Python project?

| Option | For | Against |
|---|---|---|
| **Nix flake** (`nix develop`, `flake.lock`) | Works on macOS and Linux; packages Guile, Typst and mdBook; a lock file pins exact versions; CI can use the same definition | Nix is hard to learn; one more tool to install |
| **Guix** (`guix shell`, `channels.scm`) | The natural choice for a Guile project; a channels file pins everything | Linux only, so on macOS only inside a VM or container |
| **Version manager + system packages** (e.g. mise for Typst and mdBook, Homebrew or apt for Guile) | Easy, familiar | Guile's version still depends on the package manager; less exact |
| **Documented versions + a check** (README lists versions; a check reports missing or wrong tools) | Smallest change | Not reproducible; only explains failures |

Depends on: nothing. Affects question 3.

### 2. A user-friendly installer

How does a musician who is not a programmer install notasi?

| Option | For | Against |
|---|---|---|
| **Homebrew tap** | Familiar on macOS; Homebrew has Guile and Typst | macOS (and Linux Homebrew) only; a tap to maintain |
| **Guix package** | Natural for Guile; exact dependencies | Few musicians use Guix; Linux only |
| **Container image** | Same everywhere; nothing to install but Docker | Docker is heavy and unfamiliar to most musicians; awkward for files on their machine |
| **autotools install** (`./configure && make install`, scaffolded with guile-hall) | The traditional way to install Guile modules | Users must install Guile and Typst themselves first |
| **Typst Universe** (for the Typst package in 06) | Typst downloads it from the import line | Covers only the Typst side; the `notasi` command still needs installing |

Partly answered for Emacs users (ADR 0049, "Emacs users" above);
open for everyone else.

Depends on: how much of 06 goes ahead. Standalone figures need Guile and
Typst; documents also need the Typst package. Can wait until there is
something worth installing.

### 3. Testing in a fresh environment

How do we know notasi works on a machine other than the developer's
laptop?

| Option | Catches |
|---|---|
| **CI as today** (fresh Ubuntu per PR) | Missing files, forgotten steps, Linux problems |
| **Pinned tool versions in CI** (Guile, Typst, as mdBook already is) | Laptop and CI drifting apart; surprise upgrades |
| **CI uses the developer environment of question 1** (e.g. the Nix flake) | Laptop and CI disagreeing at all: "passes CI" means "works on a fresh clone" |
| **macOS runner in the CI matrix** | macOS-only problems |
| **Scheduled run** (e.g. weekly) | Breakage from outside (new Ubuntu, new Typst) in weeks with no PRs |
| **README test**: a bare container, clone, follow only the README | Instructions that are wrong or incomplete; best before each release to `main` |
| **Several Typst versions** (pinned, latest, nightly allowed to fail) | Typst releases that break the template, before users hit them |
| **Visual regression tests** (render PNGs, compare with stored images) | Small layout changes a Typst release makes that still compile |

These are not exclusive; the question is which to adopt and when.
Locally, the same checks can run in a throwaway container, a dev
container or Codespaces, or with `act` (which runs GitHub workflows
locally, not exactly as GitHub does).

Partly answered for drawings (ADR 0052): CI redraws the committed
images and fails if any changes, a visual regression test for the
gallery and the manual. The images are drawn on Linux only, so the
check doesn't depend on Typst drawing the same bytes on every system.

Depends on: question 1 (whether CI and laptop share one environment
definition) and on when Typst enters the build (milestone 4), after
which the Typst-related rows matter.
