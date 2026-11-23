# 0045 Standalone figures use a sans-serif font found on the machine

Status: accepted (2026-11-23)

Context: The standalone entry file sets Libertinus Serif, built into Typst, so a figure looks the same on every machine (05). Typst has no built-in proportional sans serif, and a serif face looks heavy in a grid of small labels and names. Shipping a font file would add fonts to the repository and the package.

Decision: Standalone figures (`notasi render`, `make preview`, the manual's figures) use a sans-serif font from those installed, the first found of a list (Helvetica, Arial, DejaVu Sans, Liberation Sans; the exact list is settled by eye), and Libertinus Serif when none is, so a figure is always drawn. `(notasi typst)` finds the family once with `typst fonts` and writes only that family into the entry file, so Typst never warns about a family it can't find. Scores in documents keep the document's font. There is no font option yet.

Consequences: Figures look a little different from machine to machine, which reverses 05's reason for Libertinus Serif. Golden files compare JSON, so they don't depend on the font; the entry file's text does, and its tests change. Label widths are estimated from character counts and are checked with each font in the list.
