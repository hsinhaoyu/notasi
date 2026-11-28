# 0069 The rule for contributing examples is in the README

Status: accepted (2026-11-28)

Context: ADR 0063 put the rule for `examples/contrib/`, with its sentence "By adding a file to `examples/contrib/`, you license it under CC BY 4.0 …", in `CONTRIBUTING.md` and `examples/LICENSE`. `CONTRIBUTING.md` is for developers (ADR 0062), but the people who contribute pieces are users, who read the README. ADR 0067 listed the README's sections, without one for contributions.

Decision: The rule for contributing examples is a README section, "Contributing examples", owned by Claude (`<!-- owner: claude -->`), just before "Licence". It holds what `CONTRIBUTING.md`'s section held: where pieces go, the contribution sentence word for word, that opening the pull request is the agreement, and how to credit yourself in the file. `CONTRIBUTING.md` keeps a one-line section pointing to it. `tests/licences.scm` checks the sentence in `README.md` and `examples/LICENSE`. Everything else in ADRs 0063 and 0067 stands.

Consequences: A contributor finds the rule on the page they read first. The README is a few lines longer. `CONTRIBUTING.md` no longer states the rule itself, so a developer follows its link.

Supersedes: 0063 (only where the contribution rule is stated), 0067 (only its list of sections)
