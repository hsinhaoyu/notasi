# 0048 The notasi command line is a contract for editors

Status: accepted (2026-11-24)

Context: Iteration 4 adds an Emacs package, `notasi-mode`, that draws a score as the user writes. It doesn't load notasi's modules; it runs `notasi render` and reads what comes back: the picture, the exit status and the messages, with the line a mistake is on. Until now these were described in 05 but free to change: only notasi's own tests and the manual depended on them. The package also needs to know which notasi it found, to say when it is older than the package, and the command has no way to tell.

Decision: `notasi render`'s options, its exit statuses (0 drawn, 1 a problem with the piece or the drawing, 2 the command used wrongly), what it prints on success, and the form of its messages (a mistake in the notation is `FILE:LINE: message`; any other problem starts `notasi: `) are a stated contract, written in 05. A new `notasi --version` prints notasi's version. A change to any of them changes the editor package in the same PR.

Consequences: The package depends only on the command line, which can be tested on its own (`tests/command.scm`) and imitated by a fake notasi in the package's tests. Changing a message's form, an option or an exit status is no longer a change inside notasi alone. The reader's messages keep their wording free; only their form is fixed. notasi gets a version string, kept in one place and set when a version is tagged.
