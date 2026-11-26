# 0061 `notasi render --all` draws every score of a file; `--format`, `--ppi`, `--one-file` and `--list`

Status: accepted (2026-11-26)

Context: A `.nts` file can hold several scores, but `notasi render` draws one per run, so drawing them all takes one command per score, and the writer has to know their names. `make preview` drew every score, but only of the repository's examples, and it is removed (ADR 0052), while `make images` needs every score of a file drawn as PNG at a fixed resolution. A PNG's resolution is fixed today (144 ppi), and the format comes only from the output file's extension.

Decision: `render` gets five options. Drawing stays one subcommand, and no score name is reserved.
- `--all` draws every score of the file, each to its own `NAME_SCORE.EXT` (ADR 0040), the first score included. A file with no `score` form has only its default score, drawn as `NAME.EXT`. Without `-o` the files go beside the piece. With `-o DIR` (an existing folder, or a path ending in `/`) they go in DIR. `--all` with `--score`, or with `-o` naming a file (except for `--one-file`), is a usage error.
- `--format pdf/png/svg` chooses the format, default `pdf`, with or without `--all`. With `-o FILE` and no `--format`, FILE's extension chooses, as now. `--format` adds the extension to an `-o FILE` that has none. A `--format` that disagrees with FILE's extension is a usage error.
- `--ppi N` sets a PNG's resolution, default 144 (Typst's). It is a usage error for a PDF or an SVG.
- `--one-file`, with `--all`, writes one PDF with each score on its own page, in score order, each page sized to its score, to `NAME.pdf` or `-o FILE.pdf`. Without `--all`, or for another format, it is a usage error.
- `--list` prints the file's score names, one per line, in the order written, and draws nothing. A file with no `score` form prints nothing. It reads the piece, so a notation mistake is reported (status 1). With `--all`, `--score`, `-o`, `--format`, `--ppi` or `--one-file` it is a usage error. With `--save-piece` it lists and saves, as ADR 0058 says.

With `--all`, the piece is read once. A notation mistake stops everything. A score that Typst fails on is reported (`notasi: ...`), the others are still drawn, and the exit status is 1 if any failed. On success `render` prints one line per file written, in score order: one line for one score or for `--one-file`.

Consequences: Every score of a file can be drawn in one command, and `make images` uses it. The command line's contract with editors (ADR 0048) widens: "one line on success" becomes one line per file written. Editors draw one score with `-o` and see no change, so ADR 0048 stands and the Emacs package needn't change; a command to draw every score from Emacs can come later. `(notasi command)`, `(notasi typst)`, `tests/command.scm`, `notasi --help` and the manual's page on drawing change.
