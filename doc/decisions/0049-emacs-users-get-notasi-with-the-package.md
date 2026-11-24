# 0049 Emacs users get notasi with its Emacs package, and install Guile and Typst by hand

Status: accepted (2026-11-24)

Context: Iteration 4 adds an Emacs package, `notasi-mode`, for writing music with the score drawn beside it. Its users need notasi itself, Guile 3.0 and Typst at the pinned version (05). How users install notasi is an open question (07, question 2), and no installer exists. The package is installed from GitHub with `package-vc` (built into Emacs 29) or `use-package :vc` (Emacs 30), which clones the whole repository, `scripts/notasi` included.

Decision: For Emacs users, notasi comes with the package: the mode runs `scripts/notasi` from the clone the package was installed from, when the user hasn't set a program and none is on the PATH. Guile and Typst are installed by hand, with the commands the manual gives for macOS and for Debian and Ubuntu: Guile from the system's package manager, Typst at the pinned version from Typst's own releases, as CI installs it. Emacs 29.1 is the oldest Emacs supported. CI checks the package in its own job, on Emacs 29.1 and the newest Emacs release.

Consequences: An Emacs user installs two tools and adds a few lines to their Emacs configuration; nothing else needs installing or setting. This answers 07's question 2 for Emacs users only: other users still run `scripts/notasi` from a copy of the repository, and a general installer stays open. Typst is pinned for users as it is for CI, so the template is drawn by the version it was tested with; the manual's Typst commands change when the pin does.
