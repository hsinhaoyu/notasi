# Several scores in one file

A file can print its music in several ways, with a `score` form for
each (see [scores](scores.md)). This one has two:

```scheme
{{#include ../../../examples/manual/scores-excerpt.nts}}
```

## The score the cursor is in

When you open the file, the preview shows the first score, `whole`:

![The first score, whole](figures/scores-excerpt_whole.png)

Move the cursor into `(score second …)`, and the picture switches to
that score:

![The second score](figures/scores-excerpt_second.png)

Move the cursor out again, into the parts, and the picture stays on the
score you were last in, so you can change the music and watch that
score. The header line shows which score it is: `Title — second`.

Switching back to a score you have already seen shows its picture at
once, and draws it again only if you have changed the text since.

## Staying on one score

`C-c C-s` asks which score to show, with the file's scores to choose
from. The preview then stays on that score wherever the cursor goes,
and the header line says `(chosen)` after its name. Choose
"follow the cursor" in the same list to go back.

Next: [keys and settings](emacs-keys-and-settings.md).
