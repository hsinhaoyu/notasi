# Design idea: the score the cursor is in

Status: proposed in discussion (2026-11-24). Not the design until
promoted.

## The idea

A file can have several `(score NAME …)` forms
(`examples/jaya-semara.nts` has `full` and `kotekan`). The preview
shows:

1. the score the user chose with `C-c C-s`, if they chose one;
2. otherwise the score whose form the cursor is inside;
3. otherwise the score shown last, or, at first, the first score in
   the file (what `notasi render` draws without `--score`).

So moving the cursor into `(score kotekan …)` switches the picture,
and moving out again into the patterns and parts keeps it. Writing the
music therefore shows the score the user last looked at.

The mode finds the score forms by reading the buffer's top-level
forms in Emacs Lisp; it doesn't need notasi for this.

## Open

- Switching when the cursor moves redraws right away (or shows a
  drawing kept from before). Should the mode keep the last picture of
  every score, so switching back is instant? Suggested: yes, one SVG
  per score in the temporary folder.
- `C-c C-s` "stays on" a score: how does the user go back to following
  the cursor? Suggested: choose "follow the cursor" in the same list.
