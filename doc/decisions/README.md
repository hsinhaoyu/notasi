# Decision log

This folder records design decisions as short, numbered ADRs (Architecture
Decision Records). `doc/design/` describes the design as it is now; these
records explain why it is that way.

## When to write one

- You reverse or narrow a decision documented in `doc/design/`.
- You make a choice someone might later question or "fix".

Routine changes that follow the existing design don't need one.

## Rules

- Number ADRs in order: the next one is the highest number plus one.
- An accepted ADR is never edited, except its `Status:` line.
- To change a decision, write a new ADR that says what it supersedes, and
  set the old one's status to `superseded by NNNN`. Update `doc/design/`
  in the same PR.
- Add every new ADR to the index below.

`tests/decisions.scm` checks the numbering, status lines and index.

## Template

```markdown
# NNNN Short title

Status: proposed | accepted (YYYY-MM-DD) | superseded by NNNN | deprecated

Context: What problem or situation prompted this.

Decision: What was decided.

Consequences: What follows from it, good and bad.

Supersedes: NNNN (only if it replaces an earlier decision)
```

## Index

- [0001 Notation is s-expressions](0001-notation-is-s-expressions.md)
- [0002 Time is a grid of equal steps](0002-time-is-a-grid-of-equal-steps.md)
- [0003 Notes are symbolic](0003-notes-are-symbolic.md)
- [0004 The model is the centre](0004-the-model-is-the-centre.md)
- [0005 Guile decides, Typst draws](0005-guile-decides-typst-draws.md)
- [0006 The JSON file is the contract with Typst](0006-json-is-the-contract-with-typst.md)
- [0007 Guile 3.0, standard library first](0007-guile-3-standard-library-first.md)
- [0008 The piece is the centre](0008-the-piece-is-the-centre.md)
- [0009 Count in pulses, not beats](0009-count-in-pulses-not-beats.md)
- [0010 The package is called notasi](0010-the-package-is-called-notasi.md)
- [0011 One pitched instrument per group](0011-one-pitched-instrument-per-group.md)
- [0012 part-steps checks event bounds, not part length](0012-part-steps-checks-event-bounds.md)
- [0013 The repository is called notasi](0013-the-repository-is-called-notasi.md)
- [0014 The user manual is an mdBook, written with the code](0014-the-user-manual-is-an-mdbook.md)
- [0015 notasi does not analyse pieces](0015-no-analysis.md)
- [0016 Typst documents load scores from a side file](0016-documents-load-scores-from-a-side-file.md)
- [0017 Notes are coloured by pitch](0017-notes-are-coloured-by-pitch.md)
- [0018 One notasi command with subcommands](0018-one-notasi-command.md)
- [0019 Notes are square blocks; note names are optional](0019-square-notes-optional-names.md)
- [0020 A plain white grid; notes fill their cells](0020-plain-grid-notes-fill-cells.md)
- [0021 pastel1 is the default palette](0021-pastel1-is-the-default-palette.md)
- [0022 Notation files end in .nts](0022-notation-files-end-in-nts.md)
- [0023 Work is organised in iterations](0023-work-is-organised-in-iterations.md)
- [0024 An iteration's notes are called design ideas](0024-iteration-notes-are-design-ideas.md)
- [0025 Time is measured in pulses, with durations](0025-time-is-measured-in-pulses.md)
- [0026 Options are written :key value](0026-options-are-key-value.md)
- [0027 A part names its instrument first](0027-a-part-names-its-instrument-first.md)
- [0028 _ holds, - damps, and · is dropped](0028-hold-sustains-rest-damps.md)
- [0029 Patterns belong to one instrument](0029-patterns-belong-to-one-instrument.md)
- [0030 Colotomies generate the gong and kempli parts](0030-colotomies-generate-gong-and-kempli-parts.md)
- [0031 Printing belongs to scores](0031-printing-belongs-to-scores.md)
- [0032 The palette is chosen in the score](0032-the-palette-is-chosen-in-the-score.md)
- [0033 Groups carry their effective settings](0033-groups-carry-their-effective-settings.md)
- [0034 Pitched and stroke instruments are grouped apart](0034-pitched-and-stroke-instruments-are-grouped-apart.md)
- [0035 Expansion is its own module](0035-expansion-is-its-own-module.md)
- [0036 The JSON contract is version 2](0036-json-contract-version-2.md)
- [0037 Cycle lines are heavier than pulse lines](0037-cycle-lines-are-heavier.md)
- [0038 A part names its instrument with :instrument, in a colotomy too](0038-parts-name-their-instrument-with-an-option.md)
- [0039 The cycle and pulse rows are labelled by default](0039-number-rows-are-labelled.md)
- [0040 Files drawn from a score are named NAME_SCORE](0040-score-files-are-named-with-an-underscore.md)
- [0041 The lines behind the notes are chosen by the score; notes have grey borders](0041-lines-behind-the-notes-and-grey-borders.md)
- [0042 Strokes are drawn one column wide](0042-strokes-are-drawn-one-column-wide.md)
- [0043 The JSON contract is version 3](0043-json-contract-version-3.md)
- [0044 Header numbers are centred over their pulse, and the grid is framed](0044-header-centred-grid-framed.md)
- [0045 Standalone figures use a sans-serif font found on the machine](0045-figures-use-a-sans-serif-font.md)
