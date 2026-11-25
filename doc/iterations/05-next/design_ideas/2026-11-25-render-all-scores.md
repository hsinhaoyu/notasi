# Design idea: drawing every score of a file

Status: agreed in discussion (2026-11-25), with one open question.
Not the design until promoted.

## The problem

A `.nts` file can hold several scores (`examples/jaya-semara.nts` has
`full` and `kotekan`), but `notasi render` draws one per run: the first
score without `--score`, or the one `--score NAME` names (05, "The
`notasi` command"). Drawing them all takes one command per score, and
the writer has to know their names. `make preview` draws every score of
every example, but only for the repository's examples, into
`build/preview/`.

## Agreed (2026-11-25)

- `notasi` gets a way to draw every score of one `.nts` file in one
  command. Part of iteration 5.
- Each score's file is named as ADR 0040 says: `NAME_SCORE.EXT`.
- **It is `--all` on `render`**:
  ```sh
  notasi render examples/jaya-semara.nts --all
  ```
  Drawing stays one subcommand, and no score name is reserved.
  `--all` and `--score` together are a usage error (status 2).
- **A resolution option for PNG** (its name is open question 1).
- **`make preview` is removed** ([the collection of
  examples](2026-11-25-examples-collection.md)); this idea doesn't
  replace it.
- **A new `--format pdf/png/svg`** chooses the format, default `pdf`.
  It is needed with `--all`, where there is no single output file
  whose extension could choose, and it works on `render` without
  `--all` too.

- **Where the files go.** Without `-o`, each score's file goes beside
  the piece (`examples/jaya-semara_full.pdf`,
  `examples/jaya-semara_kotekan.pdf`). With `--all`, `-o DIR` names a
  folder instead (an existing folder, or a path ending in `/`), the
  names inside it as ADR 0040 says. `-o` naming a file with `--all`
  is a usage error, except for one PDF (below).
- **`--format` and `-o`.** With `-o FILE` and no `--format`, FILE's
  extension chooses the format, as now. With `--format` and an `-o FILE`
  without an extension, `--format` adds it. `--format` and an extension
  that disagree (`-o out.png --format svg`) are a usage error (status
  2).
- **One PDF for every score**: `--all --one-file` writes one file,
  **each score on its own page**, in score order, each page sized to
  its score. It goes to `NAME.pdf` beside the piece, or to `-o
  FILE.pdf`. `--one-file` without `--all`, or with a format other than
  PDF, is a usage error (status 2).
- **When one score fails** (Typst fails on it), the others are still
  drawn; each failure is reported as now (`notasi: ...`), and the
  command exits with status 1 if any failed. A notation mistake still
  stops everything, since the piece is read once before drawing.

- **Every score is named.** With `--all`, each score's file is
  `NAME_SCORE.EXT`, the first score included
  (`jaya-semara_full.pdf`, `jaya-semara_kotekan.pdf`). A file with no
  `score` form has only the default score, which has no name, and is
  drawn as `NAME.EXT`.
- **In the one PDF, each score is on its own page**: no page holds two
  scores, and no score is split across pages by `--all` (a score's own
  systems are laid out as now).
- **What it prints.** One path per line, in score order (one line for
  the one PDF). This widens the contract with editors (ADR 0048), which
  says one line; editors draw one score and see no change.
- **`--list`** prints the file's score names, one per line, in the
  order they are written, to standard output, and draws nothing:
  ```sh
  notasi render examples/jaya-semara.nts --list
  ```
  It exits with status 0, or 1 for a notation mistake (the piece is
  read). A file with no `score` form lists nothing: its default score
  has no name, so the output is empty, with status 0. `--list` with `--all`, `--score`, `-o`, `--format` or
  `--one-file` is a usage error (status 2). `--list` with
  `--save-piece` lists and saves the piece, without drawing ([saving
  the piece](2026-11-24-saving-the-piece.md)).

## Open

1. **The resolution option.** PNG needs a resolution, and today it is
   fixed. A new option on `render` sets it. Options for its name:
   `--ppi N` (Typst's own word, pixels per inch), `--dpi N` (the more
   familiar word), `--resolution N`. Leaning: `--ppi`, default Typst's
   144; an error (status 2) with `--format pdf` or `svg`, or an `-o`
   that isn't `.png`. It works with and without `--all`.

## Notes for promotion

- 05: "The `notasi` command": `--all`, `--format`, `--list`,
  `--one-file` and the resolution option, default names,
  `-o` with several files, exit status when some scores fail, what is
  printed; "The command line as a contract": the new options and the
  widened success output.
- A new ADR: `--all`, `--format`, `--list`, `--one-file` and the resolution
  option on `render`;
  narrows ADR 0048's "one line on success" to one line per file.
- `(notasi command)` and `tests/command.scm`.
- Manual: the page on drawing (`drawing.md`).
- 08: the Emacs mode needn't change; it draws one score, with `-o`. A command to
  draw every score from Emacs is possible later.
- `notasi --help` and `notasi render --help`.
