# Your first score in Emacs

Save this piece as `pokok.nts`, in a folder of your own, and open it in
Emacs:

```scheme
{{#include examples/drawing.nts}}
```

Emacs knows a `.nts` file: the forms are coloured, and the notes, rests
and holds of each part each have a colour of their own. A moment later,
a window opens beside the text with the score drawn in it:

![The score shown beside the text](figures/drawing.svg)

Above the picture, the window's header line shows the piece's title,
and the score's name when the file has `score` forms. While a drawing
is being made, it says "drawing…".

## The picture follows your writing

Change a note, say the first `a1` to `e2`, and stop typing. About a
second later the picture is drawn again, with your change. You don't
need to save; saving draws it again too.

The window is as wide as Emacs makes it, and the picture fits its
width. Make the window wider for a larger picture.

## Writing the score to a file

`C-c C-o` asks for a file name and writes the score there: a PDF, PNG
or SVG file, chosen by the name's ending (`pokok.pdf`, `pokok.png`).
When the file has several scores, it writes the one the preview shows.

## The examples

The examples that come with notasi, such as Gold's Jaya Semara, are in
the folder the package was installed in: `~/.emacs.d/elpa/notasi-mode/examples/`
(open `jaya-semara.nts` there). They are a good place to see a long
piece drawn.

Next: [when something is wrong](emacs-mistakes.md).
