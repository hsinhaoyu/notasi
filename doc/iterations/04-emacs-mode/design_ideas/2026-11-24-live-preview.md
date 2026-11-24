# Design idea: the score appears and follows the text

Status: proposed in discussion (2026-11-24). Not the design until
promoted.

## The idea

Writing a `.nts` file in Emacs should feel like the picture is part of
the file. The user never asks for a drawing; it is just there.

1. **Opening a `.nts` file** turns on `notasi-mode`. A preview window
   opens beside the text (to the right if the frame is wide enough,
   below otherwise) and the score appears in it.
2. **Writing.** About a second after the user stops typing, the
   picture is redrawn. Saving is not needed. Saving also redraws.
3. **The preview fits** the width of its window, and refits when the
   window changes size.
4. **The header line** of the preview shows the piece's title and the
   score's name, e.g. `Jaya Semara: pangecet — full`. While a drawing
   is being made, a small "drawing…" appears there; nothing else shows
   that a process runs.
5. **Closing the `.nts` buffer** closes its preview and removes its
   temporary files.

Commands exist for people who want them, but nothing needs them:

| Key | Does |
|---|---|
| `C-c C-c` | redraw now |
| `C-c C-p` | show or hide the preview |
| `C-c C-s` | choose a score from a list, and stay on it |
| `C-c C-o` | write the current score to a PDF, PNG or SVG file the user names |

Settings, in `M-x customize-group RET notasi`:

- `notasi-preview-on-open` (default on): open the preview with the file;
- `notasi-auto-preview` (default on): redraw when the user pauses;
- `notasi-preview-delay` (default 1 second);
- where the preview window goes (right, below, or Emacs decides).

## Open

- Is one second right? It depends on how long a drawing takes (see
  [How a drawing is made](2026-11-24-drawing.md)).
- Should the preview scroll to follow the cursor in a long piece? That
  needs to know which part of the picture a line of text is drawn at.
  Suggested: later.
- `C-c C-o`: worth having in this iteration, or is `notasi render` in
  a terminal enough for writing files? Suggested: have it; it is small
  and keeps users in Emacs.

## Later

Not for this iteration; for the backlog at promotion:

- Highlighting, in the picture, the notes of the pattern under the
  cursor.
- A faster check that finds mistakes without drawing (skipping Typst).
- A Guile process kept running between drawings (see `notasi serve`
  in [How a drawing is made](2026-11-24-drawing.md)).
