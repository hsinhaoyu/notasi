# Design idea: who owns each section of the README

Status: agreed in discussion (2026-11-27). Not the design until
promoted.

## The problem

The README has two kinds of text. Some says what notasi is and why it
exists; that is the user's to write, and a rewrite by Claude would
change the project's voice. The rest states facts that change with
the code: what notasi can do, how to install it, the commands, the
manual's address. Today nothing says which is which, so Claude either
leaves the facts to go stale or edits text the user meant to keep.

## Settled (2026-11-27)

- **The README is for users**: musicians who want to write and draw
  gamelan scores with notasi, not developers. This narrows ADR 0014
  ("the README (for developers)"), so it needs a new ADR when it is
  promoted. Developer material moves out (below).
- **Lightweight.** It is one file; the process stays small. Two
  owners, one marker, no states.
- **Markers.** Each section has an HTML comment on the line after its
  heading, invisible on GitHub; the part before the first `## `
  heading has it after the `# ` title:

      ## Drawing a score
      <!-- owner: claude -->

  - `owner: user`: the user writes it. Claude never edits it; it only
    suggests changes, as PR review comments (see the upkeep idea).
  - `owner: claude`: Claude keeps it in step with the code.
- **Briefs.** The user can put `<!-- todo: ... -->` under any heading,
  saying what to write. Claude writes it and removes the brief. In a
  user's section the text is then the user's, to edit or keep.
- **Sections**, in order:

  | Section | Owner |
  |---|---|
  | Title, one-line description, gallery picture and caption, and one sentence on how settled notasi is ("young; the notation may still change") | user |
  | Why notasi: what it does for a gamelan musician, three to five sentences | user |
  | What it can do: a short list in musician terms, each item linking to its manual chapter | claude |
  | Installing: Guile, Typst, getting notasi; details in the manual | claude |
  | Drawing a score: commands that work on a gallery piece right after installing | claude |
  | Using notasi in Emacs | claude |
  | User manual: where it is | claude |
  | Licence: the code is MIT, the manual and examples CC BY 4.0 (see the licences idea) | user |

- **Developer sections move out.** "Layout" and "Running tests" go
  to a new `CONTRIBUTING.md` at the top of the repository, Claude's (no
  markers), which GitHub links from the repository page.
  `tests/readme.scm`'s checks on modules, `make` targets and the
  `editors/emacs/` layout entry move with them, to check
  `CONTRIBUTING.md`.
- **Short.** About 150 lines at most. What doesn't fit goes into the
  manual, and the README links to it. A guideline Claude follows, not
  a test.

## Notes for promotion

The rules belong in `07-environment.md`, which already describes the
README test and the README's versions, with a new ADR ("The README is
for users, and its sections have owners", narrowing 0014), and one
rule in CLAUDE.md under "Design documents".
