# Design idea: documentation

Status: proposed in discussion (2026-11-24). Not the design until
promoted.

## The idea

The reader knows Emacs. The documentation doesn't explain Emacs; it
gets them from nothing to a drawn score as quickly as possible.

- **README:** a short "Using notasi in Emacs" section: what to install
  (Guile, Typst), the `use-package` lines, and "open a `.nts` file".
  Nothing more; it links to the manual.
- **The manual:** a chapter "Writing in Emacs", for musicians, in the
  manual's style (`doc/manual/STYLE.md`):
  1. Installing: Guile and Typst (macOS and Debian/Ubuntu commands),
     then the package, with each of the ways in "The package".
  2. Your first score in Emacs: open an example, watch it draw, change
     a note.
  3. When something is wrong: how mistakes are shown, with a
     screenshot.
  4. Several scores in one file.
  5. Writing faster: completion, Eldoc, Imenu.
  6. Settings, and the keys.
  7. Problems: "nothing is drawn", "notasi can't be found", "it is
     slow".
- **In Emacs:** `C-h m` in a `.nts` buffer describes the mode, its
  keys and its settings; every command and setting has a docstring.

## Open

- Screenshots in the manual go stale. Suggested: few, and of the
  preview only.
- The manual is for musicians and so far doesn't assume any editor.
  Should the first pages mention Emacs, or only the new chapter?
  Suggested: one sentence on the first page pointing to the chapter.
