# 08 — The Emacs package

Status: partly implemented (iteration 4): milestone 1,
`feat/emacs-package` (the package, writing, `make check-emacs`), and
slice 1 of the preview, `feat/emacs-preview-draw` (the preview, how a
drawing is made, finding notasi); redrawing as the user writes, the
score shown, mistakes and the documentation are planned. ADRs 0048 (the command line it depends on),
0049 (installing) and 0050 (the package).

## Responsibility

`notasi-mode` gives Emacs users a place to write music: they open a
`.nts` file and see its score drawn beside it, and the picture follows
the text as they write. They never run a command or see the process
behind it.

The package draws only by running the `notasi` command, as the
contract in 05 ("The command line as a contract") describes. It loads
nothing from `notasi/`, and notasi never needs it.

## The package

**Implemented** (`feat/emacs-package`, ADR 0050). Installing from
GitHub is not tried yet: the acceptance test of `feat/emacs-docs` tries
it on a fresh Emacs.

- **Where it lives:** `editors/emacs/notasi-mode.el`, in the notasi
  repository; more files beside it (`notasi-mode-*.el`) only if it
  grows.
- **Name:** `notasi-mode`, the package and the major mode.
- **An Emacs package:** the standard headers, with
  `Package-Requires: ((emacs "29.1"))` and `Version:` notasi's version
  (`0.4.0`; on `dev` too, since package versions can't carry `-dev`);
  `lexical-binding`; autoload cookies on the mode and on its
  `auto-mode-alist` entry for `.nts`, so installing it is enough and
  nothing needs `require`; every setting in a `notasi` customisation
  group; docstrings on every command and setting, so `C-h m` in a
  `.nts` buffer describes the mode, its keys and its settings.
- **Shipped with notasi:** `editors/` is released to `main` with the
  rest of notasi and the same version tag; it is not a dev-only path.
- **Installing** (07, "Emacs users"; ADR 0049), easiest first:
  1. from GitHub with `package-vc-install` (Emacs 29) or
     `use-package :vc` (Emacs 30), with `:lisp-dir "editors/emacs"`;
     until notasi is released to `main`, from `dev`;
  2. from a clone of the repository, adding `editors/emacs` to
     `load-path`.
- **Quality:** byte-compiles with no warnings, and passes `checkdoc`
  and `package-lint`.

## Writing

**Implemented** (`feat/emacs-package`).

- `notasi-mode` is derived from `lisp-data-mode`: moving by forms,
  `show-paren-mode`, commenting (`;`) and Lisp indentation come with
  it.
- **Indentation:** `piece`, `scale`, `strokes`, `instrument`,
  `colotomy`, `part`, `pattern`, `score`, `group` and `rep` indent their
  body by 2, like `defun`, so

      (score full :fill none
        (group "Ugal" ugal))

      (pattern pokok-ugal :instrument ugal
        _ i2 _ a1 _ e2 _ o2)

  A line of options in such a form (a line starting with `:key`) is
  indented by 4, so the options stand apart from the body (except in
  `piece`, whose options are all it has):

      (pattern panyacah-fill :instrument panyacah :short "fill"
          :long "Panyacah: 6 1 5 6 2 3 1 2"
        a3 i3 u3 a3 o3 e3 i3 o3)

  Everything else (`use`, `(@ …)`, chords) follows Lisp's usual rule. Indentation uses spaces, never tabs. This applies in
  `notasi-mode` buffers only; Emacs Lisp elsewhere is unaffected.
- **Highlighting:**
  - the form names (`piece`, `use`, `scale`, `strokes`, `instrument`,
    `colotomy`, `pattern`, `part`, `score`, `group`, `rep`, `@`) in
    `font-lock-keyword-face`, `:keywords` in `font-lock-builtin-face`,
    strings and comments as in Lisp;
  - in the music, the tokens after the options of `part`, `pattern`
    and `colotomy` (inside `rep`, chords and colotomy parts too),
    faces of the mode's own:

    | Face | Tokens |
    |---|---|
    | `notasi-note` | notes, by name or number, with or without a duration (`a1`, `5`, `o3:1/4`, `GL:1`) |
    | `notasi-hold` | holds, `_` and `_:D` |
    | `notasi-rest` | rests, `-` and `-:D` |
    | `notasi-bar` | `|` and `||` |
    | `notasi-pattern` | pattern calls, `@NAME`, and the name in `(@ NAME …)` |

  - names outside the music (an option's value such as
    `:instrument ugal`, a pattern's or score's name, the notes listed
    in an `instrument` form) are not in these faces.
  - Every face is in the `notasi` customisation group, so users can
    change it.

## The preview

**Implemented** (`feat/emacs-preview-draw`): opening a file (point 1,
always, without the setting), the picture fitting its window, the
header line, closing the buffer, the preview buffer, `C-c C-c`,
`C-c C-p`, `C-c C-o`, and the settings `notasi-program` and
`notasi-preview-side`. **Planned** (`feat/emacs-preview-live`):
redrawing as the user writes and on saving (point 2), `C-c C-s`, and
the other three settings. Until then the first score is drawn.

1. **Opening a `.nts` file** turns on `notasi-mode`, opens a preview
   window beside the text (to the right when the frame is wide enough,
   below otherwise), and draws the score in it.
2. **Writing.** A second after the user stops typing, the picture is
   redrawn, without saving. Saving also redraws.
3. **The picture fits** the width of its window, and refits when the
   window changes size.
4. **The header line** shows the piece's title and the score's name
   (`Jaya Semara: pangecet — full`), and "drawing…" while a drawing is
   being made. Nothing else shows that a process runs.
5. **Closing the `.nts` buffer** closes its preview and removes its
   temporary files.

The preview is a read-only buffer, `*notasi: NAME*`, showing only the
picture under its header line.

Commands, which nothing needs:

| Key | Does |
|---|---|
| `C-c C-c` | redraw now |
| `C-c C-p` | show or hide the preview |
| `C-c C-s` | choose a score from a list, and stay on it; or "follow the cursor" |
| `C-c C-o` | write the current score to a PDF, PNG or SVG file the user names |

Settings (`M-x customize-group RET notasi`):

| Setting | Default | Meaning |
|---|---|---|
| `notasi-preview-on-open` | on | open the preview with the file |
| `notasi-auto-preview` | on | redraw when the user pauses and on saving |
| `notasi-preview-delay` | 1 second | how long a pause is |
| `notasi-preview-side` | right if wide enough, else below | where the preview window goes: right, below, or where Emacs decides |
| `notasi-program` | unset | the `notasi` command to run (see "Finding notasi") |

## The score shown

**Planned.** A file can have several `(score NAME …)` forms. The
preview shows, in this order:

1. the score chosen with `C-c C-s`, if one is;
2. otherwise the score whose form the cursor is in;
3. otherwise the score shown last; at first, the first score in the
   file, which `notasi render` draws without `--score`.

So moving the cursor into `(score kotekan …)` switches the picture, and
moving out into the patterns and parts keeps it. Choosing "follow the
cursor" in `C-c C-s`'s list undoes a choice.

The mode finds the score forms, and the piece's title, by reading the
buffer's top-level forms in Emacs Lisp. It keeps the last picture of
each score, so switching back to one is instant; it is redrawn if the
text has changed since.

## How a drawing is made

**Implemented** (`feat/emacs-preview-draw`). Hidden from the user:

- **Unsaved text.** The mode writes the buffer's text to a hidden file
  beside the `.nts` file, `.notasi-preview-NAME.nts`, so local
  `(use …)` files are found as for the real file, and runs, in the
  file's folder,

      notasi render .notasi-preview-NAME.nts [--score SCORE] -o DIR/SCORE.svg

  then deletes the hidden file. In messages, its name is replaced by
  the real file's. The repository's `.gitignore` has
  `.notasi-preview-*`.
- **Output** goes to a temporary folder made for the buffer, never
  beside the user's file, and is removed with the buffer.
- **SVG**, sharp at any size; PNG when this Emacs can't show SVG.
- **In the background** (`make-process`), so Emacs never waits. A
  drawing still running when a new one is needed is stopped.
- **Fresh pictures:** the image is reloaded from its file each time,
  never from Emacs's image cache.

A drawing takes about 0.6 s (`jaya-semara.nts`'s `full` score), so the
one-second pause is enough, and notasi needs no process kept running.

## Mistakes

**Planned.** `notasi render` exits with status 1 and prints
`FILE:LINE: message` for a mistake in the notation, or a line starting
`notasi: ` for any other problem (05).

- **A mistake in the notation** is shown through Flymake: the mode is
  a Flymake backend, so the line is marked, the message shows with the
  cursor on it, and `flymake-goto-next-error` and the mode line's count
  work. notasi stops at the first mistake, so one is marked. Messages
  give a line and no column, so the whole line is marked.
- **A mistake in a template** (FILE is not the piece) is marked on the
  `(use …)` form whose name is the template's file name (`(use
  gong-kebyar)` for `gong-kebyar.nts`), or on the first `(use …)` form
  if none is, with notasi's message.
- **The picture stays:** the preview keeps the last good drawing, and
  its header line turns red and shows the message. Fixing the mistake
  clears the mark and the red header, and the picture is redrawn.
- **Any other problem** (Typst missing or failing, notasi or Guile not
  found) is not a mistake in the notation: the preview says what is
  missing in one plain sentence, pointing to the manual, once, not on
  every redraw.

## Finding notasi

**Implemented** (`feat/emacs-preview-draw`). The mode runs the first
`notasi` it finds:

1. `notasi-program`, if the user set it;
2. `notasi` on the PATH;
3. `scripts/notasi` in the clone the package was installed from (ADR
   0049), found from the package's own file;
4. `scripts/notasi` in a folder above the `.nts` file, for people
   working in the notasi repository.

If none is found, the preview says so in one sentence and points to
the manual's installation section. The mode runs `notasi --version`
(05) once for each notasi it finds; when that notasi is older than the
package (comparing the numbers, ignoring `-dev`), the preview says so
in one sentence, and still draws.

## Testing

**Implemented**: the ERT tests of the package and writing, and
`make check-emacs` with its CI job (`feat/emacs-package`); the fake
notasi and the real test (`feat/emacs-preview-draw`).

- **ERT tests** in `editors/emacs/notasi-mode-tests.el`, run with
  `emacs -Q --batch`, so no one's configuration matters.
- **A fake notasi**, `editors/emacs/fake-notasi`: a short script that
  writes a small SVG to the `-o` file, or, when its input contains
  `MISTAKE`, prints `FILE:3: a mistake` to standard error and exits
  with 1, as the contract in 05 says. The tests use it, so they need
  neither Guile nor Typst. It changes when the contract does.
- **One real test** draws `examples/jaya-semara.nts` with
  `scripts/notasi`, skipped when Guile or Typst is missing.
- **`make check-emacs`** runs the tests, byte-compiles with warnings as
  errors, and runs `checkdoc` and `package-lint`. It is separate from
  `make check`, which doesn't need Emacs. CI runs it in a job of its
  own (07).
  - It runs `$(EMACS)`, by default `emacs`, or, when that isn't on the
    PATH, `/Applications/Emacs.app/Contents/MacOS/Emacs` if it exists.
  - `package-lint` is installed from MELPA into
    `build/emacs-packages/` the first time, and reused after; CI does
    the same. Nothing is added to the user's Emacs configuration.
- The tests cover the logic: finding scores, finding notasi, reading
  messages, cleaning up. What batch mode can't show (the windows and
  the picture) is checked by hand, from a short checklist in each
  milestone's PR.

## Documentation

**Planned.** The reader knows Emacs; the documentation takes them from
nothing to a drawn score.

- **README:** a short "Using notasi in Emacs" section: what to install,
  the Emacs configuration, and "open a `.nts` file", linking to the
  manual.
- **The manual:** a chapter "Writing in Emacs", for musicians, in the
  manual's style: installing (Guile and Typst, with the commands of 07;
  then the package); a first score in Emacs; when something is wrong;
  several scores in one file; the settings and keys; problems ("nothing
  is drawn", "notasi can't be found", "it is slow"). Few screenshots,
  of the preview only. The manual's first page points to the chapter
  in one sentence.

## Not in this design

Completion, Eldoc and Imenu, a preview that scrolls with the cursor,
highlighting a pattern's notes in the picture, and MELPA are later
(see the backlog).

## Slices

Milestone 2 (`feat/emacs-preview`) is built in three slices, each its
own branch and PR into `dev`, started with `/start-milestone <branch>`:

1. **Implemented.** `feat/emacs-preview-draw`: finding notasi (with `notasi --version`
   and its check), how a drawing is made, the preview window and its
   header line, `C-c C-c`, `C-c C-p`, `C-c C-o`, and cleaning up.
   Decided for this slice:
   - **Opening a file** opens the preview and draws, always; slice 2
     adds `notasi-preview-on-open` to turn it off.
   - **Settings:** `notasi-program` and `notasi-preview-side` come in
     this slice; the other three with slice 2.
   - **The score drawn** is the first in the file (no `--score`). The
     header line is `TITLE — NAME`, or `TITLE` alone when the file has
     no `score` forms.
   - **A failed drawing** keeps the last picture and shows notasi's
     message, uncoloured, in the header line; slice 3 adds Flymake, the
     red header and showing other problems once.
   - **Names:** the commands `notasi-preview-redraw` (`C-c C-c`),
     `notasi-preview-toggle` (`C-c C-p`) and `notasi-write-score`
     (`C-c C-o`); `(notasi-find-program)`, the program or nil; the
     preview buffer `*notasi: FILE*` (`*notasi: jaya-semara.nts*`);
     the hidden file `.notasi-preview-FILE` (`.notasi-preview-jaya-semara.nts`);
     the picture `DIR/NAME.svg`, or `DIR/piece.svg` without a score
     name. `notasi-preview-redraw` returns the drawing's process.
   - **`notasi --version`** prints `notasi 0.4.0-dev` on `dev`, from
     `notasi-version` in `(notasi command)`. The mode runs it once per
     program found; when its numbers (ignoring `-dev`) are older than
     the package's, the preview's header line says "This notasi (0.3.0)
     is older than notasi-mode (0.4.0)" after the title, until the next
     drawing, and the score is still drawn.
   - **The picture fits** the preview's width, and refits when the
     window changes size.
2. `feat/emacs-preview-live`: redrawing on a pause and on saving, the
   settings, the score shown, and `C-c C-s`.
   Decided for this slice:
   - **A pause** is a second (`notasi-preview-delay`) with no change to
     the text: each change restarts a timer, and the drawing happens
     when it runs out. Moving the cursor or scrolling never redraws.
   - **`--score NAME`** is passed for any score but the first in the
     file; the first is drawn without it.
   - **`notasi-choose-score`** (`C-c C-s`) takes a score's name, or nil
     for "follow the cursor"; interactively it offers the file's
     scores and "follow the cursor" with completion. A chosen score
     that disappears (renamed or deleted) goes back to following the
     cursor.
   - **A chosen score** is marked in the header line:
     `Jaya Semara: pangecet — kotekan (chosen)`.
   - **Switching back** to a score shows its kept picture at once, and
     redraws it in the background if the text has changed since it was
     drawn.
   - **The settings:** `notasi-preview-on-open` and
     `notasi-auto-preview` are on or off; `notasi-preview-delay` is a
     number of seconds, 1 by default. With `notasi-auto-preview` off,
     neither a pause nor saving redraws; `C-c C-c` still does.
3. `feat/emacs-preview-errors`: mistakes through Flymake, the red
   header and the last good picture, mistakes in templates, and the
   other problems.
