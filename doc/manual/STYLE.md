# Manual style guide

How to write `doc/manual/`. Read this before writing or changing a page.

## The reader

Anyone who wants clear scores of gamelan music and doesn't work on
notasi's code: a player, a student, a teacher or a researcher (ADR
0070). They may never have programmed and have never heard of Scheme. They know
words like *pokok*, *kotekan*, *polos* and *sangsih*; they don't know
words like *s-expression*, *record* or *parse*.

## Tone

Friendly, plain and short. Talk to the reader as "you". Say what to do,
show it, then show what comes out.

- Not: "The reader parses the part form and resolves each token against
  the instrument's note vector."
- But: "Each word after the instrument's name is one step: a note to
  play, or a rest."

## Rules

- **Describe only what works now.** The manual documents behaviour that is
  implemented, never planned features. When a feature lands, its page lands
  in the same PR.
- **One idea per page**, and a page should fit on a screen or two.
- **Start from something to try, end with what it produces.** Every page
  that teaches notation has at least one complete example.
- **Examples are real files.** Put each example in
  `examples/manual/NAME.nts` (at the top of the repository) and show it
  with `{{#include ../../../examples/manual/NAME.nts}}`; never paste notation
  into a page by hand. `tests/manual.scm` checks that every example reads
  without errors and that every example is used by a page.
- **Errors in musician terms.** When showing a mistake, show the error
  message notasi gives and how to fix it. A mistake is a real file too:
  `examples/manual/mistakes/NAME.nts`, with the exact message notasi
  gives for it in `examples/manual/mistakes/NAME.txt`. Show both with
  `{{#include ...}}`.
  `tests/manual.scm` checks that each mistake fails with that message, so
  when a message changes, update its `.txt` file.
- **Templates in examples.** A template an example or mistake uses goes
  in a `templates/` folder beside it (`examples/manual/templates/`,
  `examples/manual/mistakes/templates/`), and is shown with
  `{{#include ...}}` too. `tests/manual.scm` doesn't read these as pieces.
- **Drawn scores are PNG.** Show an example's first score as
  `![…](figures/NAME.png)`, or its score SCORE as
  `figures/NAME_SCORE.png`. `make images` draws them into
  `examples/manual/images/`, where they are committed (CI draws the
  committed ones; see CLAUDE.md), and `make manual` copies them.
- **No internals.** Don't mention Guile, modules, records or the JSON
  file, except on pages about installing or running notasi.
- **Link to the full rules** in the notation reference
  (`https://github.com/hsinhaoyu/notasi/blob/dev/doc/design/01-notation.md`)
  rather than repeating every detail.
- British spelling (colour, centre), matching the rest of the repository.
- Manual typography follows Hugo Book: system font stack, no web fonts; see `theme/custom.css`.

## Outline

Where pages go as features arrive. Add a page to `src/SUMMARY.md` only
when it is written.

1. Introduction
2. Getting started: installing, your first piece
3. Scales, strokes and instruments
4. Writing music: steps and pulses, notes and octaves, rests and holds,
   chords, several parts on one instrument
5. Templates: using `(use gong-kebyar)`, writing your own
6. Drawing a score (once rendering exists)
7. When something goes wrong: common error messages
