# Design idea: saving the piece from the command line

Status: agreed in discussion (2026-11-24, open questions settled
2026-11-25). Not the design until promoted.

## The idea

The command line gets an option to save the **internal
representation** of a piece (the `piece` record of 02, after reading)
to a file, as an **s-expression** or as **JSON**. It exists only on
the command line: nothing in a `.nts` file asks for it.

Why:

- **Seeing what notasi understood.** A writer, or a developer, can
  check what the reader made of a piece: every part's events with
  their exact times, the generated gong and kempli parts, the pattern
  spans, the scores' settings. Today this is only visible through a
  drawing, or from a Guile REPL.
- **Using the music elsewhere.** ADR 0015 says notasi doesn't analyse
  pieces, and that anyone who wants analysis can build it outside the
  package on the piece records. Saving the piece lets them do that
  without loading notasi's modules, from any language that reads JSON.
- **Tests and debugging.** A saved piece is a readable record of the
  reader's output, as the figure JSON is of layout's.

## Agreed (2026-11-24)

- A command-line option, not a `.nts` option.
- Two formats: s-expression and JSON.
- What is saved is the piece (02), not the figure. The figure JSON
  (05, ADR 0006) is layout's output for one score, and already the
  contract with Typst.

## Open

1. *(Settled 2026-11-25: an option on `render`.)* The form of the
   command:
   ```sh
   notasi render PIECE.nts --save-piece OUT.json
   notasi render PIECE.nts --save-piece OUT.scm
   ```
   OUT's extension chooses the format. It draws as `render` always
   does, and also saves the piece. This adds to `render`'s options,
   which are a contract for editors (ADR 0048; editors don't use it),
   and doesn't follow ADR 0018's "adding a feature means adding a
   subcommand": the ADR for this idea says why (saving goes with
   drawing). Still open: the default name, and saving without drawing
   (question 8).
2. *(Settled 2026-11-25: fractions as strings.)* Exact times in JSON.
   A time or duration that is a whole number is a JSON number
   (`"start": 2`); one that isn't is a string in lowest terms, as
   written in a `.nts` (`"start": "5/4"`, `"dur": "1/4"`). The
   s-expression keeps rationals as Guile numbers (`5/4`).
3. *(Settled 2026-11-25: all of it, with source locations.)* What is
   in it. All of the piece, field for field as in 02: title, length,
   pickup, the colotomy, scales, stroke sets, instruments and their
   keys, patterns, parts (written and generated, with `origin`), each
   part's events and pattern spans, and the scores with their groups
   and options. Each definition (part, pattern, score, colotomy,
   instrument, scale, stroke set) carries its source, file and line
   (`"source": {"file": "...", "line": 88}`); single notes don't.
4. *(Settled 2026-11-25: versioned, not yet promised.)* Is it a
   contract? The saved piece has a `version` field from the start, and
   golden files for the examples, so every change shows in review. The
   manual says the format may change between versions until it
   settles; no change needs an ADR of its own until then.
5. *(Settled 2026-11-25: tagged lists, output only.)* The
   s-expression's shape. Records are tagged lists, readable with
   `read`, times as exact rationals:
   `(piece (title "...") (length 16) (pickup 1) (part (name polos) ...) ...)`.
   It must not look like notation. notasi writes it and never reads it
   back; the `.nts` is the only input.
6. *(Settled 2026-11-25: always the whole piece.)* One score's view.
   `--score` (and `--all`) choose only what is drawn; the saved file is
   the same whatever is drawn. Its scores section records each score's
   parts and range, so a tool can work out one score's view itself.
7. *(Settled 2026-11-25: folded in, with `--save-piece -`.)* The
   backlog's `notasi describe FILE`. It becomes
   ```sh
   notasi render PIECE.nts --list --save-piece -
   ```
   which reads the piece, writes it as JSON to standard output, and
   draws nothing (no Typst). `-` means standard output, always JSON.
   With `-`, nothing else is printed to standard output (not the score
   names of `--list`, which the JSON holds, nor the paths of drawn
   files), so the output is one JSON document. `--list` alone is also
   the backlog's "faster check": it reports a notation mistake without
   drawing. The backlog's `describe` item and "a faster check" point
   here.
8. **Details of `--save-piece`.**
   - *(Settled 2026-11-25.)* It always takes a file name, or `-` for
     standard output (JSON; question 7); a file's extension (`.json`
     or `.scm`) chooses the format; any other extension is a usage
     error (status 2). There is no default name.
   - *(Settled 2026-11-25.)* Saving without drawing: `--save-piece`
     with `--list` lists the score names and saves the piece, and draws
     nothing, so it needs Guile but not Typst. Otherwise `render` draws
     as always.
   - With `--all`, the piece is saved once.

## Later changes (2026-11-25)

- The saved piece includes what this iteration's other ideas add to
  the piece: patterns' `:annotation`s and pattern uses' replacements,
  `(text ...)` events in parts ([annotation
  row](2026-11-25-annotation-row.md)), and the scores' new options
  (`:part-marker`, the `:annotation-*` options, `:rows compact`,
  `:note-label`, `:row-labels`, the octave options).
- `notasi render PIECE.nts --list` ([drawing every
  score](2026-11-25-render-all-scores.md)) now lists a file's score
  names, part of what open question 7's `notasi describe` was for.
- Terms follow the [glossary](2026-11-25-glossary.md) (pitch name, not
  degree).

## Notes for promotion

- 05: `--save-piece FILE` (and `-`) on `notasi render`; with `--list`,
  no drawing; what goes to standard output with `-`; usage errors;
  "The command line as a contract": the new option; `--help`.
- 02: how each record is written in each format, and the version.
- A new ADR: the piece can be saved, in two formats, with `render
  --save-piece`, an option rather than a subcommand (narrowing ADR
  0018's "adding a feature means adding a subcommand"); versioned but
  not yet promised (open question 4).
- `(notasi command)`, a new module or functions for writing the piece
  (beside `(notasi json)`, which writes the figure), tests in
  `tests/command.scm`, golden files for the examples.
- Manual: a short page or section on saving a piece.
- Backlog: the `notasi describe` item and "a faster check" point here
  (open question 7).

## Related

- [Internal representation](../../02-gold-and-tenzer/design_ideas/2026-11-21-internal-representation.md)
  (iteration 2), where the piece records were worked out.
- [Help while writing](../../04-emacs-mode/design_ideas/2026-11-24-editing-help.md)
  (iteration 4), where `notasi describe` was proposed.
