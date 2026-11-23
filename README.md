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
- `notasi/command.scm`: the `notasi` command (`scripts/notasi`)
- `tests/`: SRFI-64 test suites
- `examples/`: example pieces
- `templates/`: shared scales, stroke sets and instruments, loaded with `(use NAME)`
- `doc/manual/`: the user manual (mdBook)

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
    scripts/notasi render piece.nts --score excerpt  # writes piece.excerpt.pdf

Needs Guile 3.0 and Typst 0.15.1. See "Drawing a score" in the manual.

## User manual

The manual for musicians is at <https://hsinhaoyu.github.io/notasi/>. Its
source is in `doc/manual/`; build it locally with `make manual`, or preview
it with `make manual-serve`. Both need [mdBook](https://rust-lang.github.io/mdBook/),
and Guile and Typst to draw the manual's figures.

## Running tests

    make check

`make check` includes golden tests: each piece in `examples/` is laid
out and compared with its saved figure in `tests/golden/`. When you
change the output on purpose, run `make golden` to rewrite the saved
figures, and review the diff.

Requires Guile 3.0, and Typst 0.15.1 (the tested version) for drawing
figures. Run code from the repo root with `guile -L .`.

`make preview` draws every score of each piece in `examples/` with
Typst, to `build/preview/NAME.png` (or `NAME.SCORE.png` for a piece with
scores), so you can check how it looks.
