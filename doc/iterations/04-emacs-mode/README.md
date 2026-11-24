# Iteration 4: writing music in Emacs

Status: building

## Goal

Give Emacs users a friendly place to write music with notasi: a
polished Emacs package, `notasi-mode`, shipped as part of notasi. The
user opens a `.nts` file and sees the drawn score beside it. As they
write, the picture follows by itself. They never run a command or see
the process behind it.

We assume the user has Emacs and knows how to use it. Everything else
(installing the package, finding notasi, drawing, showing errors)
should be as easy as we can make it.

## Acceptance test

On a machine with Emacs 29 or later, Guile and Typst, a user who
follows only the README and the manual:

1. installs the package with the few lines of Emacs configuration the
   README gives;
2. opens `examples/jaya-semara.nts`, and the `full` score appears beside
   it with no command typed;
3. changes a note and stops typing, and the picture changes within a
   few seconds without saving;
4. types a note the instrument doesn't have: the picture stays, the
   mistake is shown on its line with notasi's message, and fixing it
   brings the picture back;
5. moves the cursor into `(score kotekan …)`, and the picture switches
   to that score.

`make check` and `make check-emacs` pass, in CI too.

## Design ideas

Thinking, not the design (ADRs 0023, 0024). All from the discussion of
2026-11-24, in [`design_ideas/`](design_ideas/):

What the user sees:

- [The score appears and follows the text](design_ideas/2026-11-24-live-preview.md):
  a preview window, redrawn when the user pauses, no saving needed.
- [The score the cursor is in](design_ideas/2026-11-24-score-at-point.md):
  the preview follows the cursor between `(score …)` forms.
- [Mistakes shown in the text](design_ideas/2026-11-24-errors.md):
  through Flymake, with the last good picture kept.
- [Help while writing](design_ideas/2026-11-24-editing-help.md):
  highlighting and indentation; completion, Eldoc and Imenu later.

How it works:

- [How a drawing is made](design_ideas/2026-11-24-drawing.md): the
  mode only calls `notasi render`; unsaved text, temporary files,
  speed.
- [Finding notasi](design_ideas/2026-11-24-finding-notasi.md): the
  setting, the PATH, the package's own clone, the repo.

Shipping it:

- [The package](design_ideas/2026-11-24-package.md): where it lives,
  how it is installed, how its version follows notasi's.
- [Testing the mode](design_ideas/2026-11-24-testing.md): ERT, a fake
  `notasi`, `make check-emacs`, CI.
- [Documentation](design_ideas/2026-11-24-documentation.md): the
  README and a manual chapter for Emacs users.

## Promotion

In dependency order (ADR 0023). No change to 01–04 or 06:

1. `05-typst-backend.md`: `notasi render`'s options, exit codes and
   error format become a stated contract, and `notasi --version`.
2. `07-environment.md`: installing Guile and Typst for Emacs users.
3. `08-emacs.md`, a new design document: the package, the preview,
   the score at point, mistakes, finding notasi, testing.
4. The build order in `doc/design/README.md`.

Promoted so far: `05-typst-backend.md` (ADR 0048), `07-environment.md` (ADR 0049), `08-emacs.md` (ADR 0050) and the build order. Promotion is complete.

## Milestones

Each milestone, or each slice of one, is its own branch and PR into
`dev`, started with `/start-milestone <branch>` (see
[08-emacs.md](../../design/08-emacs.md)).

1. **`feat/emacs-package`**: the package (`editors/emacs/`, headers,
   autoloads, the `notasi` customisation group), the major mode with
   highlighting and indentation, `make check-emacs` and its CI job,
   `.gitignore`, and `editors/` shipped to `main` by `/release`.
2. **`feat/emacs-preview`**, in three slices:
   1. `feat/emacs-preview-draw`: finding notasi, `notasi --version`
      and its check, drawing, the preview window and header line,
      `C-c C-c`, `C-c C-p`, `C-c C-o`, cleaning up.
   2. `feat/emacs-preview-live`: redrawing on a pause and on saving,
      the settings, the score shown, `C-c C-s`.
   3. `feat/emacs-preview-errors`: mistakes through Flymake, the red
      header and the last good picture, mistakes in templates, other
      problems.
3. **`feat/emacs-docs`**, the acceptance test: the README's section,
   the manual's chapter "Writing in Emacs", and the acceptance test
   run on a fresh Emacs.
