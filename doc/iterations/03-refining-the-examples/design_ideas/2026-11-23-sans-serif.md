# Design idea: standalone figures use a sans-serif font

Status: agreed in discussion (2026-11-23). Not the design until
promoted.

## Now

The template (`typst/notasi.typ`) sets no font, so a score in a Typst
document uses the document's font (05-typst-backend, rule 7). Only the
standalone entry file written by `(notasi typst)` sets one:

```typst
#set text(font: "Libertinus Serif", size: 8pt)
```

05-typst-backend chose Libertinus Serif because it is built into Typst,
so a figure looks the same on every machine. Typst's built-in text
fonts are Libertinus Serif and New Computer Modern (plus New Computer
Modern Math and DejaVu Sans Mono); none is a proportional sans serif.

## Agreed (2026-11-23)

- Standalone figures (`notasi render`, `make preview`, the manual's
  figures) use a sans-serif font.
- It comes from the fonts installed on the machine, not a font shipped
  with notasi. Typst takes a list and uses the first it finds, e.g.

  ```typst
  #set text(font: ("Helvetica", "Arial", "DejaVu Sans",
                   "Liberation Sans", "Libertinus Serif"), size: 8pt)
  ```

  macOS has Helvetica, Windows Arial, most Linux systems (and CI's
  Ubuntu) DejaVu Sans or Liberation Sans. Libertinus Serif last, so a
  figure is always drawn even on a machine with none of them.
- Scores in documents are unchanged: they use the document's font.

Considered and not taken: shipping an open-licence sans font (Libertinus
Sans, Source Sans 3, Noto Sans) with `--font-path`. Same look
everywhere, but font files in the repository and the package.

## Consequences

- Figures look a little different from machine to machine. This
  reverses 05's reason for Libertinus Serif ("looks the same on every
  machine"), so it needs an ADR.
- Golden tests compare JSON, not pictures, so they don't depend on the
  font. `tests/typst.scm` checks the entry file's text and changes.
- `lane_width` and `label_width` are estimated from character counts
  (0.52em per character). Sans fonts are often wider than Libertinus;
  check that labels still fit with each font in the list.
- Typst warns about each family in the list it can't find
  (`unknown font family`). `notasi render` should not show these
  warnings to a musician, or should pass only the fonts present.

## Open

- An option to choose the font (`:font "Gill Sans"` on a score, or a
  `notasi render --font`)? Leaning: later, if asked for.
- The exact list and order.

## Notes for promotion

- 05-typst-backend, "The entry file and running Typst": the font line
  and its reason. New ADR.
- `notasi/typst.scm` (`write-entry-file`) and `tests/typst.scm`.
- Manual: the drawing page, if it mentions the font; every figure
  changes.

## Settled (2026-11-23)

The open questions above, answered before promotion:

- No font option for now (later, if asked for).
- The exact list and order of fonts is chosen by eye while building.
