# Keys and settings

You never need a key: the picture follows your writing by itself. These
are there when you want them.

| Key | Does |
|---|---|
| `C-c C-c` | draw the score again now |
| `C-c C-p` | show or hide the preview window |
| `C-c C-s` | stay on one score, or follow the cursor again (see [several scores](emacs-several-scores.md)) |
| `C-c C-o` | write the score the preview shows to a PDF, PNG or SVG file |

`C-h m` in a `.nts` file lists them too.

## Settings

| Setting | At first | What it does |
|---|---|---|
| `notasi-preview-on-open` | on | open the preview when you open a file |
| `notasi-auto-preview` | on | draw again when you stop typing, and when you save; when off, only `C-c C-c` draws |
| `notasi-preview-delay` | 1 | how many seconds without typing count as stopping |
| `notasi-preview-side` | right if the Emacs frame is wide, else below | where the preview window goes: `right`, `below`, or wherever Emacs decides (`nil`) |
| `notasi-program` | unset | the `notasi` command to run, when the package can't find it (see [problems](emacs-problems.md)) |

Change them with `M-x customize-group RET notasi RET`, or in your
configuration, for example:

```elisp
(setq notasi-preview-delay 2
      notasi-preview-side 'below)
```

With `use-package`, put them in its `:custom` section instead:

```elisp
(use-package notasi-mode
  :vc (:url "https://github.com/hsinhaoyu/notasi"
       :lisp-dir "editors/emacs" :branch "dev")
  :custom
  (notasi-preview-delay 2))
```

The colours of notes, holds, rests, bars and pattern calls in the text
are in the same group, as faces, and can be changed there too.

Next: [problems](emacs-problems.md).
