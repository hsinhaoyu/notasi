# 06 — Scores in Typst documents

Status: planned, not implemented yet, and deferred: not part of
iteration 1, 2 or 3 (see the [backlog](../iterations/backlog.md)).
Written for the iteration 3 notation (01: parts with `:instrument`) and
contract version 3 (05, ADR 0043). Command:
`notasi typst`, `notasi watch` (`scripts/notasi`); Typst package:
`typst/` (published as `notasi`). Decision: ADR 0016 (proposed).

## Responsibility

Let someone writing a document, handout or textbook about gamelan in
Typst put scores into it, the way lilypond-book puts LilyPond scores
into LaTeX, while keeping the document a normal Typst file:

- notation is written in the document (a ` ```nts ` block) or kept in a
  `.nts` file and referred to by path;
- captions, figure numbers, cross-references, fonts and page layout are
  Typst's, not notasi's;
- `typst watch` and editor previews (tinymist) keep working;
- a notation error shows up in the document where the score would be.

Standalone figures (`notasi render`, 05) are still supported and share
the same Typst template.

## Why a side file

Typst cannot run other programs while it compiles, and its plugins must
be pure WebAssembly in a form a Guile program (via Hoot, which needs
WasmGC) cannot currently take. So Guile has to run next to Typst, not
inside it.

lilypond-book does this by rewriting the source into a second file that
is then compiled. notasi does not rewrite anything. It reads the
document's scores by asking Typst to query it (`typst eval --in`), lays them out, and writes their
figures to a side file (the **manifest**) that the document loads with
`json()`. The user's file is the file that gets compiled. ADR 0016
records this choice.

## What the user writes

**Planned.**

```typst
#import "@preview/notasi:0.1.0" as notasi
#show: notasi.setup(
  json("book.notasi.json"),          // the manifest, written by notasi
  use: ("gong-kebyar",),             // templates for every snippet
)

The reyong interlocks like this:

#notasi.figure(caption: [Kotekan: polos and sangsih])[
  ```nts
  (part :instrument reyong :name polos    i3:1/4 _ i3 o3 | _ i3 o3 _)
  (part :instrument reyong :name sangsih  e3:1/4 u3 e3 _ | u3 e3 _ u3)
  (score kotekan  (group "Reyong" polos sangsih))
  ```
] <fig:kotekan>

As @fig:kotekan shows, …

#notasi.file("examples/jaya-semara.nts", score: "kotekan")
```

- `setup` takes the loaded manifest as its first argument. A Typst
  package can only read files inside the package, so the document has
  to load the manifest itself and pass it in.
- Every ` ```nts ` block in the document is drawn as a score: the show
  rule `setup` installs replaces the code block with the figure.
- `notasi.file(path, score: NAME)` draws a score of a `.nts` file; without
  `score`, its first score (or the default score). The path is relative
  to the folder of the main `.typ` file.
- A snippet draws its first score, or the default score when it has
  none (01, "Files without a score").
- The figure uses the document's font and text size: its `font_size` is
  `null` (05).
- `notasi.figure` is `figure` with `kind: image`. A plain `figure` around
  a code block would be numbered as a listing, because Typst works out a
  figure's kind from the raw block inside it before the show rule runs
  (checked with Typst 0.15.1).
- Labels and `@` references are ordinary Typst.

### Snippets and the `piece` form

A snippet that has no `piece` form is completed by notasi before
reading. It adds one line in front of it:

```scheme
(piece "") (use gong-kebyar)
```

built from the `setup` options: `use` is the only one. A snippet that
needs a colotomy or a pickup writes its own `piece` form. The title is empty because the caption
does that job. A snippet that starts with its own `piece` form is read
as a complete file and `setup` does not apply to it. `.nts` files given
to `notasi.file` are always complete files.

This needs no change to the reader: an empty string is a valid title,
and the extra line goes first, where `piece` and `use` must be. Line
numbers in error messages are shifted back by one.

## The manifest

**Planned.** `NAME.notasi.json` beside `NAME.typ`:

```json
{
  "version": 3,
  "setup": { "use": ["gong-kebyar"] },
  "snippets": {
    "(part :instrument reyong :name polos i3:1/4 ...)\n...": { "figure": { ...05 contract... } },
    "(part :instrument ugal a1 o9 ...)":                     { "error": "book.typ, nts block 2, line 1: part `ugal', pulse 2: note `o9' is not on instrument `ugal'" }
  },
  "files": {
    "examples/jaya-semara.nts": { "scores": { "kotekan": { "figure": { ... } } } }
  }
}
```

- Snippets are keyed by their exact text (what `raw.text` is in Typst),
  so the template finds a figure with a dictionary lookup and an edited
  snippet is simply not found until notasi runs again. No hashing is
  needed on the Typst side.
- A snippet's value is either a `figure` (its first score, in the JSON
  contract of 05) or an `error` (the reader's message, with the location rewritten to
  name the document and the block number).
- A file's value holds one entry per score the document draws from it,
  keyed by score name, each a `figure` or an `error` (e.g. a score the
  file doesn't have); or an `error` for the whole file.
- Entries for snippets, files and scores no longer in the document are
  dropped.
- `setup` records the options the snippets were completed with. A
  snippet's text doesn't change when `setup` does, so the package
  compares this with its own options and, if they differ, treats every
  snippet as not rendered yet rather than drawing figures made for
  other options.
- The manifest has its own `version`, 3, to go with contract version 3.
  A change to the figure contract increments both.

## What the template draws

**Planned.**

| Manifest says | Drawn |
|---|---|
| a figure | the score, using the document's font and text size |
| an error | the snippet's source with the error message in red, in a box |
| nothing (not run yet, edited since, or `setup` changed since) | the snippet's source in a grey box marked "not rendered yet" |

The document always compiles, so previews never stop at a score.

A known limit: an edited `.nts` file named by `notasi.file` keeps its
path, and the package can't read the file to compare, so until notasi
runs again the old figure is drawn without a warning. `notasi typst`
and `notasi watch` always update first, so this only shows in a
preview with neither running.

## Commands

**Planned.** One command, `scripts/notasi`, with subcommands (ADR
0018):

- `notasi render PIECE.nts [-o OUT]`: a standalone figure (05, "The
  `notasi` command"). **Implemented**; the subcommands below are
  planned.
- `notasi typst DOC.typ [typst options]`: update the manifest, then run
  `typst compile` with the remaining options.
- `notasi update DOC.typ`: update the manifest only.
- `notasi watch DOC.typ`: update the manifest whenever the document,
  a file it includes or a `.nts` file it names changes. Meant to run
  beside `typst watch` or an editor preview.

Updating the manifest:

1. If the manifest doesn't exist, write an empty one, so that the
   document compiles.
2. `typst eval 'query(raw.where(lang: "nts")).map(it => it.text)' --in DOC.typ`
   lists every snippet, in document order, including from `#include`d
   files. The same with `query(<notasi-file>)` and
   `query(<notasi-setup>)` lists the `notasi.file` paths with their
   scores, and the `setup` options, which the package records as labelled `metadata`.
   notasi never parses Typst itself. (`typst query` does the same but
   is deprecated as of Typst 0.15; checked with 0.15.1.)
3. Read and lay out each snippet and file; collect errors instead of
   stopping at the first.
4. Write the manifest only if it changed, so a watching Typst doesn't
   recompile for nothing.

Snippet text does not depend on the manifest, so one query is enough;
there is no second pass.

Without Guile (e.g. on typst.app), a user can run `notasi update`
locally and upload the manifest with the document.

## Slices

**Planned.** Each its own branch and PR, started with `/start-milestone`.

1. `feat/documents-update`: `notasi update` and `notasi typst`: the
   query, completing snippets from `setup`, collecting errors with
   rewritten locations, writing the manifest only when it changes.
   Tested with query output saved as fixtures, so `make check`
   doesn't need Typst.
2. `feat/documents-package`: the Typst side: `setup`, the show rule,
   `notasi.figure`, `notasi.file`, the three cases in "What the
   template draws", `typst.toml` for the package. Developed against
   hand-written manifests, as the template was against hand-written
   JSON (ADR 0006).
3. `feat/documents-watch`: `notasi watch`.

## Open questions

1. **System width.** Layout decides system breaks (ADR 0005), but only
   Typst knows how wide the text is. For now: `:system-length` or
   `:breaks` in the snippet's score. Later, the package could record
   the available width with `layout()` and `metadata`, and notasi could
   choose the breaks from it.
2. **Paths for `notasi.file`.** Relative to the main file is simple but
   surprising inside an `#include`d chapter in another folder. Typst's
   query output doesn't say which file a `metadata` came from.
3. **Package name and publishing.** `@preview/notasi` on Typst Universe,
   or `@local/notasi` until the template is stable?
4. **Hoot.** If Typst's plugin runtime ever supports WasmGC, notasi
   could run inside Typst and the side file would go away. Worth a spike
   then, not now.
