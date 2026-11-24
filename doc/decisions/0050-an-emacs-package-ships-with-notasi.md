# 0050 An Emacs package, notasi-mode, ships with notasi and only runs the notasi command

Status: accepted (2026-11-24)

Context: Iteration 4's goal is a friendly place for Emacs users to write music: the score drawn beside the text, following it as they write. Editor support could live in its own repository or inside notasi, and could draw by loading notasi's Guile modules or by running the command. `main` holds only what users need (ADR 0023), and the release skill lists dev-only paths.

Decision: The package, `notasi-mode`, lives in the notasi repository under `editors/emacs/`. It is released to `main` with the rest of notasi and the same version tag (`editors/` is not a dev-only path), and its `Version:` is notasi's. It draws only by running `notasi render` and reads only what the command line's contract gives (ADR 0048); it loads nothing from `notasi/`, and notasi never needs it. It is a proper Emacs package (Emacs 29.1 or later, autoloads, a customisation group) checked by `make check-emacs`, separately from `make check`.

Consequences: Package and notasi change together in one PR and are always released as a pair, so the package's version says which notasi it expects. The package's tests run without Guile or Typst, against a fake notasi that follows the contract. notasi's modules stay free to change. Contributors without Emacs are not affected: `make check` doesn't need it. Other editors could follow the same pattern under `editors/`.
