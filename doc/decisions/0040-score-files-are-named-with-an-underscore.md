# 0040 Files drawn from a score are named NAME_SCORE

Status: accepted (2026-11-23)

Context: A file drawn from one score of a piece is named `NAME.SCORE.EXT` (`gilak.full.png`, `tests/golden/baris.kendang-composite.json`). A `.` should only start the extension; tools read `gilak.full.png` as a file `gilak` with a two-part extension. A `-` can't separate the two, because names use `-` themselves.

Decision: A file drawn from a score is named `NAME_SCORE.EXT`: `gilak_full.png`, `figures/gilak_full.svg`, `tests/golden/baris_kendang-composite.json`. A file drawn without choosing a score, from a piece with only the default score, stays `NAME.EXT`. The rule is the same for `notasi render`'s default output, `make preview`, golden files and the manual's figures. Score names may not contain `_` (the reader checks), so `NAME_SCORE` can always be split; for piece file names it is a convention.

Consequences: Every golden file and figure of a piece with scores is renamed, in the same change as the code. Users see the new default name from `notasi render --score`.
