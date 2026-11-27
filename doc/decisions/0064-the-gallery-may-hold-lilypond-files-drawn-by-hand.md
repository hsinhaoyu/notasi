# 0064 The gallery may hold LilyPond files, whose images are drawn by hand

Status: accepted (2026-11-27)

Context: The README is to show a passage drawn by notasi next to the same passage on a staff, so that a musician who reads Western notation can compare them. The staff picture is drawn with LilyPond, not notasi. ADR 0052 says every image in `gallery/images/` is a notasi drawing: `make images` empties the folder and redraws every score, CI redraws them on Linux and fails if any changes, and `make check` allows nothing else in the folder. CI has no LilyPond, and the LilyPond in Ubuntu's packages (2.24) differs from the one the user draws with (2.26), so its drawing wouldn't match.

Decision:

- `examples/gallery/` may hold LilyPond files, `NAME.ly`. Each has one image, `gallery/images/NAME.png`, cropped to the music.
- A Makefile target, `make lilypond`, draws them (`lilypond -dcrop -dno-print-pages --png`, at 200 dpi, so a staff picture is about as wide as a notasi drawing at 144 ppi). It needs LilyPond.
- The image is committed as drawn on the user's machine. CI doesn't run `make lilypond` and doesn't compare these images; `make images` leaves them alone.
- `make check` checks the set: one PNG in `gallery/images/` per score of each `.nts` file and one per `.ly` file, nothing else.
- The first is `gambangan-readme-piano.ly`, the passage of `gambangan-readme.nts` (score `kotekan`).

Consequences: The README can show a staff picture beside a notasi drawing, both by relative path, both released to `main` with `examples/`. Nothing checks that a LilyPond image matches its file: whoever changes a `.ly` file runs `make lilypond` and commits the image. Building the repository's tests still needs no LilyPond. This narrows ADR 0052, which still holds for every notasi drawing. The passage is McPhee's transcription, so `examples/LICENSE` (ADR 0063) names it with its source.
