# 0066 The README's Emacs section points to the manual; the configuration is tested there

Status: accepted (2026-11-27)

Context: 08 ("Documentation", decided when `feat/emacs-docs` started) gave the README's "Using notasi in Emacs" section what to install, the Emacs configuration for Emacs 29 and 30, and "open a `.nts` file", and ERT tests checked the configuration there. The manual's "Installing for Emacs" page gives the same steps and the same two blocks. With the README now a short page for musicians (ADR 0062), the same instructions in two places is more to keep in step, and the manual is where a reader follows them.

Decision:

- The README's "Using notasi in Emacs" section says in a sentence what `notasi-mode` does and links to the manual's chapter "Writing in Emacs", where the instructions are. It gives no configuration and no install steps.
- The ERT tests that checked the README's configuration (it reads as Lisp; `use-package :vc` and `package-vc-install` with the `:url`, `:lisp-dir` and `:branch` of 08) check the manual's "Installing for Emacs" page instead. An ERT test checks that the README's section links to the chapter, and `tests/readme.scm` that the section exists and links to the manual, as before.

Consequences: The instructions are in one place, the manual, and stay tested there. A reader of the README follows one link to install the package. This narrows 08's decision about the README's section; the rest of 08's documentation decisions stand.
