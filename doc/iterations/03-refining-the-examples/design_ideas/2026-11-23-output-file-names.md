# Design idea: score file names use `_`, not `.`

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## The problem

A file drawn from one score of a piece is named `NAME.SCORE`:
`gilak.full.png`, `baris.kendang-composite.json`. A `.` should only
start the extension. `gilak.full.png` reads as a file `gilak` with a
two-part extension, and some tools treat it that way.

The rule appears in four places:

- `notasi render`'s default output, `default-output` in
  `notasi/command.scm`: `songs/gilak.nts` → `songs/gilak.full.pdf`.
- `make preview`, `scripts/preview.scm`: `build/preview/NAME.SCORE.png`.
- Golden tests: `tests/golden/NAME.SCORE.json` (`tests/golden.scm`,
  `tests/targets.scm`).
- The manual's figures: `figures/NAME.SCORE.svg` (`tests/manual.scm`,
  `make manual`).

## Options considered

| Option | Example | Why not |
|---|---|---|
| `-` | `jaya-semara-kotekan.png` | Names use `-` too, so it can't say where the piece ends and the score begins. |
| `--` | `jaya-semara--kotekan.png` | Unambiguous but awkward. |
| A folder per piece | `gilak/full.png` | `notasi render` would make folders beside the user's `.nts` files. |
| `_` | `jaya-semara_kotekan.png` | Taken. |

## Agreed (2026-11-23)

- A file drawn from a score is named `NAME_SCORE.EXT`:
  `gilak_full.png`, `gilak_second-cycle.png`,
  `baris_kendang-composite.json`, `figures/gilak_full.svg`.
- A file with no scores (or drawn without `--score` where that's
  allowed) stays `NAME.EXT`.
- The same rule everywhere: `notasi render`, `make preview`, golden
  files, manual figures.

## Open

- Should piece file names and score names be forbidden from containing
  `_`, so `NAME_SCORE` can always be split? Names are Scheme symbols
  and by convention use `-`. Suggested: yes for score names (the reader
  can check them); for file names, a convention only.

## Notes for promotion

- 04-layout ("golden"), 05-typst-backend (figures, preview), the manual
  page on drawing, README, CLAUDE.md, the Makefile comments.
- Rename every file in `tests/golden/` and the manual's figures, in the
  same change.
- The user sees the new default name from `notasi render`, so the
  manual changes with it.

## Settled (2026-11-23)

The open questions above, answered before promotion:

- Score names may not contain `_` (the reader checks); for piece file
  names it is a convention only.
