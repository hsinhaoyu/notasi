# 07 — Environment, installation and testing

Status: mostly open questions. Planned (iteration 4, ADR 0049): what
Emacs users install, and CI for the Emacs package; this answers
question 2 for Emacs users only. Each question, once decided, gets an
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
| Emacs 29.1 or later | Emacs users of `notasi-mode`, and contributors to it | runs the package (08); planned, iteration 4 |

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

**Planned** (iteration 4, ADR 0049).

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
  `make check-emacs` on Emacs 29.1 and on the newest Emacs release. It
  installs `package-lint` from MELPA. `make check` does not need Emacs.
- Before the iteration is accepted, the acceptance test is run by hand
  on a fresh Emacs, following only the README and the manual (the
  "README test" of question 3, done once, by hand).

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

Depends on: question 1 (whether CI and laptop share one environment
definition) and on when Typst enters the build (milestone 4), after
which the Typst-related rows matter.
