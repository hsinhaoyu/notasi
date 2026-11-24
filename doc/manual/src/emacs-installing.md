# Installing for Emacs

If you write in Emacs, notasi can draw your score in a window beside the
text, and redraw it as you write. This chapter shows how. It assumes you
know Emacs already.

You need three things: Emacs 29.1 or later, Guile 3.0 (which runs
notasi), and Typst 0.15.1 (which draws the scores). notasi itself comes
with the Emacs package.

## Guile

On a Mac, with [Homebrew](https://brew.sh):

```text
brew install guile
```

On Debian or Ubuntu:

```text
sudo apt install guile-3.0
```

## Typst

notasi is tested with Typst 0.15.1 exactly, so install that version
rather than the newest. Download it from Typst's releases on GitHub and
put it in `~/.local/bin`. On a Mac with Apple silicon (M1 or later):

```text
curl -fsSL -o typst.tar.xz https://github.com/typst/typst/releases/download/v0.15.1/typst-aarch64-apple-darwin.tar.xz
tar -xf typst.tar.xz
mkdir -p ~/.local/bin
mv typst-aarch64-apple-darwin/typst ~/.local/bin/
```

On an Intel Mac, write `typst-x86_64-apple-darwin` instead of
`typst-aarch64-apple-darwin`, both times; on Linux,
`typst-x86_64-unknown-linux-musl`.

`~/.local/bin` must be on your `PATH`, for your shell and for Emacs.
Check with:

```text
typst --version
```

It should say `typst 0.15.1`.

## The package

Add this to your Emacs configuration (usually `~/.emacs.d/init.el`). In
Emacs 30 or later:

```elisp
(use-package notasi-mode
  :vc (:url "https://github.com/hsinhaoyu/notasi"
       :lisp-dir "editors/emacs" :branch "dev"))
```

In Emacs 29:

```elisp
(unless (package-installed-p 'notasi-mode)
  (package-vc-install
   '(notasi-mode :url "https://github.com/hsinhaoyu/notasi"
                 :lisp-dir "editors/emacs" :branch "dev")))
```

The first time Emacs starts with it, it downloads notasi from GitHub,
with its examples, and installs the package. Nothing else is needed:
the package finds notasi in what it downloaded.

To update later, run `M-x package-vc-upgrade RET notasi-mode RET`.

Next: [your first score in Emacs](emacs-first-score.md).
