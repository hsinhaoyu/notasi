# notasi

Tools for notating and visualizing Balinese gamelan music, written in GNU Guile 3.0.

## Layout

- `notasi/piece.scm`: records for a piece (instruments, notes, parts)
- `notasi/reader.scm`: parses textual notation into a piece
- `notasi/expand.scm`: turns a part's notes, rests and durations into timed events
- `notasi/layout.scm`: lays out scores
- `notasi/json.scm`: writes JSON (the figure files Typst reads)
- `notasi/style.scm`: how notes look: palettes and colour schemes
- `notasi/typst.scm`: the Guile side of the Typst backend: writes figure files and draws them with Typst
- `notasi/save.scm`: saves a piece, as notasi read it, as JSON or an s-expression
- `notasi/command.scm`: the `notasi` command (`scripts/notasi`)
- `tests/`: SRFI-64 test suites
- `examples/`: example pieces, in four folders: `gallery/`, showcase
  pieces such as Gold's Jaya Semara (`jaya-semara.nts`) and Tenzer's
  Baris (`baris.nts`), with their drawings in `gallery/images/`;
  `demos/`, examples of single features; `contrib/`, other people's
  pieces; and `manual/`, the user manual's examples and drawings
- `templates/`: shared scales, stroke sets and instruments, loaded with `(use NAME)`
- `doc/manual/`: the user manual (mdBook)
- `editors/emacs/`: `notasi-mode`, an Emacs package for writing `.nts` files, with the score drawn beside the text

Design documents, decisions and iterations' design ideas are on the `dev` branch:
[the design](https://github.com/hsinhaoyu/notasi/tree/dev/doc/design)
(the notation language is
[01-notation.md](https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md)),
[the decision log](https://github.com/hsinhaoyu/notasi/tree/dev/doc/decisions),
[iterations](https://github.com/hsinhaoyu/notasi/tree/dev/doc/iterations)
(goals, acceptance tests, design ideas and the backlog) and
[references](https://github.com/hsinhaoyu/notasi/tree/dev/doc/references).

## Drawing a score

    scripts/notasi render piece.nts            # writes piece.pdf
    scripts/notasi render piece.nts -o out.png # or .svg
    scripts/notasi render piece.nts --score excerpt  # writes piece_excerpt.pdf
    scripts/notasi render piece.nts --all      # every score, piece_SCORE.pdf
    scripts/notasi render piece.nts --list --save-piece -  # the piece as JSON, nothing drawn

Needs Guile 3.0 and Typst 0.15.1. See "Drawing a score" in the manual.

## Using notasi in Emacs

`notasi-mode` shows the score beside the text as you write, and marks
mistakes on their lines. You need Emacs 29.1 or later, Guile 3.0 and
Typst 0.15.1; the manual gives the commands to
[install them](https://hsinhaoyu.github.io/notasi/emacs-installing.html).

Then add this to your Emacs configuration. It installs the package from
GitHub, with notasi itself, the first time:

```elisp
;; Emacs 30 or later
(use-package notasi-mode
  :vc (:url "https://github.com/hsinhaoyu/notasi"
       :lisp-dir "editors/emacs" :branch "dev"))
```

or, in Emacs 29:

```elisp
(unless (package-installed-p 'notasi-mode)
  (package-vc-install
   '(notasi-mode :url "https://github.com/hsinhaoyu/notasi"
                 :lisp-dir "editors/emacs" :branch "dev")))
```

Open a `.nts` file, such as `examples/gallery/jaya-semara.nts`, and its score
is drawn beside it. The manual's chapter
[Writing in Emacs](https://hsinhaoyu.github.io/notasi/emacs-installing.html)
explains the rest.

## User manual

The manual for musicians is at <https://hsinhaoyu.github.io/notasi/>. Its
source is in `doc/manual/`; build it locally with `make manual`, or preview
it with `make manual-serve`. Both need only [mdBook](https://rust-lang.github.io/mdBook/):
the manual's figures are committed images.

## Running tests

    make check

`make check` includes golden tests: each piece in `examples/gallery/`
and `examples/demos/` is laid
out and compared with its saved figure in `tests/golden/`. When you
change the output on purpose, run `make golden` to rewrite the saved
figures, and review the diff.

Requires Guile 3.0, and Typst 0.15.1 (the tested version) for drawing
figures. Run code from the repo root with `guile -L .`.

`make check-emacs` checks the Emacs package in `editors/emacs/`: its
tests, byte-compiling, checkdoc and package-lint. It needs Emacs 29.1
or later, and isn't part of `make check`.

`make images` redraws the committed drawings: every score of each
piece in `examples/gallery/`, and the figures the manual shows. CI
draws them on Linux and fails when one is out of date; a PR that
changes how scores look commits the images CI uploads. To draw any
one piece, use `scripts/notasi render PIECE.nts --all`.
