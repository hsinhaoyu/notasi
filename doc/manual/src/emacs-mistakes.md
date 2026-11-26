# When something is wrong

Here the part plays `dong2`, which the ugal doesn't have:

```scheme
{{#include ../../../examples/manual/mistakes/note-not-on-instrument.nts}}
```

As soon as the picture would be redrawn, Emacs shows the mistake:

- the line with the mistake is underlined, and with the cursor on it,
  notasi's message shows at the bottom of the window;
- the header line above the picture turns red and shows the same
  message, with the file and line:

```text
{{#include ../../../examples/manual/mistakes/note-not-on-instrument.txt}}
```

- the picture stays as it was, the last one drawn without a mistake, so
  you don't lose your place.

Fix the note, stop typing, and the underline and the red go away and
the picture is drawn again.

notasi stops at the first mistake it finds, so one line is marked at a
time. In a long piece, `M-x flymake-goto-next-error` takes you to it.
The messages are the same as when drawing from the command line: see
[error messages](errors.md).

## A mistake in a template

When the mistake is in a template the piece uses, not in the piece, the
`(use …)` line that loads it is marked, and the message says which
template file and which line the mistake is on.

## Other problems

When the score can't be drawn for another reason, for example because
Typst isn't installed, the header line turns red and says what is
wrong, and the picture stays. Nothing in the text is marked. See
[problems](emacs-problems.md).

Next: [several scores in one file](emacs-several-scores.md).
