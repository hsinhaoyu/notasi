# 0062 The README is for users, and its sections have owners

Status: accepted (2026-11-27)

Context: ADR 0014 calls the README the document "for developers", but it is the first page a musician sees, on GitHub and on `main`, and it now shows the gallery. Its text is of two kinds: some says what notasi is and why it exists, in the user's voice, which a rewrite by Claude would change; the rest states facts that change with the code (what notasi can do, how to install it, the commands, the manual's address). Nothing said which was which, so facts went stale or Claude edited text the user meant to keep. Only a test runs on every push; a skill runs only when someone runs it.

Decision: The README is for users: musicians who write and draw gamelan scores with notasi. It has these sections, in order, each with an owner:

- user: the title, the one-line description, the gallery picture and its caption, and one sentence on how settled notasi is; "Why notasi"; "Licence";
- Claude: "What it can do" (linking each item to its manual chapter), "Installing", "Drawing a score", "Using notasi in Emacs", "User manual".

Each section says its owner in an HTML comment on the line after its heading (`<!-- owner: user -->` or `<!-- owner: claude -->`; for the part before the first `## ` heading, after the `# ` title). Claude keeps `owner: claude` sections in step with the code, and never edits an `owner: user` section: it suggests changes as review comments on the PR. A `<!-- todo: ... -->` brief under any heading asks Claude to write that text and remove the brief; in a user's section the text is then the user's. The README is about 150 lines at most, a guideline: what doesn't fit goes into the manual.

"Layout" and "Running tests" move to a new `CONTRIBUTING.md` at the top of the repository, Claude's, with no markers, released to `main` like the README, and `tests/readme.scm`'s checks on modules, `make` targets and the layout move with them. `tests/readme.scm` checks that every README section has one owner marker, that every relative link and image path exists, and that the "Drawing a score" commands, run on a copy of `examples/gallery/jaya-semara.nts` in a temporary folder, write the files they should.

A skill, `/readme-sync`, which only the user can run, updates the `owner: claude` sections and writes the briefs, on its own branch and PR, and posts its suggestions for the user's sections as review comments on that PR. It is run as an iteration closes, before `/release`, and whenever the user wants. `/doc-audit` reports README drift, with "README" as the doc side.

Consequences: The README describes notasi to musicians, and the user's voice in it is kept. Its facts are checked by tests where a test can check them, and by `/readme-sync` and `/doc-audit` where only reading can; neither the length nor whether Claude kept out of a user's section is tested, since the user sees both in the PR. The "Drawing a score" test needs Typst, as `tests/template.scm` does. Developers read `CONTRIBUTING.md`, which GitHub links from the repository page. This narrows only ADR 0014's description of the README; its decision about the manual stands.
