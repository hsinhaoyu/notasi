# 0052 Examples live in four folders under examples/; the gallery's and the manual's drawings are committed

Status: accepted (2026-11-26)

Context: `examples/` held a handful of pieces used as test fixtures, drawn by `make preview` into `build/preview/` for a check by eye. The manual's examples lived apart, in `doc/manual/src/examples/`, and `make manual` drew their figures as SVG on every build, never committed, so building or deploying the manual needed Guile and Typst. The README, shipped on `main`, could show no drawing. Some examples are pieces worth showing; others only show a feature; other people's pieces need a place that doesn't hold the tests to their standard.

Decision: Every `.nts` example is under `examples/`, in four folders:

- `gallery/`: showcase pieces, which the README and the manual may show. Tested (golden JSON), and their drawings, every score of every file, are committed in `gallery/images/`.
- `demos/`: examples that show a feature but aren't gallery pieces, not necessarily whole pieces. Tested (golden JSON); drawings not committed.
- `contrib/`: other people's examples. Not tested, not even read; credited by the piece information keys, by convention.
- `manual/`: the manual's examples, with its templates (`manual/templates/`) and its mistakes (`manual/mistakes/`). Tested by `tests/manual.scm`; the drawings its pages show are committed in `manual/images/`.

Committed drawings are PNG, named as ADR 0040 says. One target, `make images`, redraws them all with `notasi render --all` at one fixed resolution. The committed images are drawn on Linux with the pinned Typst, as CI draws them: CI redraws them and fails if any changes, and then uploads the images it drew, which the PR commits. Images drawn on another system are for looking only. `make manual` copies the manual's images into `doc/manual/src/figures/` and draws nothing. Example names are unique across `examples/`, and golden files keep their names (`tests/golden/NAME.json`, `NAME_SCORE.json`). `make preview` and `scripts/preview.scm` are removed.

Consequences: The README can show the gallery, by relative path, since `examples/` is released to `main`. The manual builds and deploys with mdBook alone. A change to how scores look shows in a PR as changed images, and a PR that changes the look must commit them. The manual's figures become PNG instead of SVG. The repository grows with every image, so their resolution is kept as low as reads well. Drawing on Linux only means the check doesn't depend on Typst drawing the same bytes on every system; a developer on macOS takes the images from CI rather than drawing them, one more step in a PR that changes the look. This reverses 05's rule that the manual's figures are generated and never committed; ADR 0014's decision still holds.
