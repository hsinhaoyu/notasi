# Problems

## Nothing is drawn

Look at the preview's header line: when the score can't be drawn, it
turns red and says why, in one sentence. The first time, the same
sentence also shows at the bottom of the Emacs window.

- **"Typst 0.15.1 is needed to draw figures, but `typst' isn't on the
  PATH"**: install Typst 0.15.1 as in [installing](emacs-installing.md), and
  check that `~/.local/bin` is on the `PATH` Emacs sees. If you start
  Emacs from the Dock on a Mac, it may not see the `PATH` your shell
  has; the package
  [exec-path-from-shell](https://github.com/purcell/exec-path-from-shell)
  fixes that.
- **A message about Guile**: install Guile 3.0, as in
  [installing](emacs-installing.md).
- Fix the cause, and the score is drawn the next time you stop typing,
  or at once with `C-c C-c`.

## "Can't find notasi"

The package runs the first of these it finds:

1. the command named in the setting `notasi-program`, if you set it;
2. a `notasi` command on your `PATH`;
3. `scripts/notasi` in the copy of notasi the package was installed
   from (the usual case);
4. `scripts/notasi` in a folder above the file you are editing.

If you installed the package some other way, set `notasi-program` to
your copy's `scripts/notasi`:

```elisp
(setq notasi-program "~/src/notasi/scripts/notasi")
```

## "This notasi is older than notasi-mode"

The notasi found is older than the package, so some things may not
work. The score is still drawn. Update both with
`M-x package-vc-upgrade`, or point `notasi-program` at a newer notasi.

## It is slow

A drawing takes about half a second for a piece the size of Jaya
Semara, and it never stops Emacs while you type. If the picture is
redrawn too often for you, make `notasi-preview-delay` longer, or turn
`notasi-auto-preview` off and press `C-c C-c` when you want a new
picture.

## The preview is in the way

`C-c C-p` hides the preview window, and shows it again. To open files
without it, turn `notasi-preview-on-open` off; `C-c C-p` or `C-c C-c`
then shows it when you want it. See [keys and settings](emacs-keys-and-settings.md).
