# 0067 The README has no "Why notasi" or "What it can do" sections

Status: accepted (2026-11-27)

Context: ADR 0062 listed the README's sections, among them the user's "Why notasi" and Claude's "What it can do", a list of features linking to the manual. Writing the README showed it reads better short: the picture and the one-line description say what notasi is, and the manual, which the README links, is where a musician finds what it can do. A features list in the README is one more thing to keep in step with the manual.

Decision: The README has no "Why notasi" and no "What it can do" section. Its sections are: the part before the first heading and "What is notasi for?" (the user's), "Installing", "Drawing a score", "Using notasi in Emacs" and "User manual" (Claude's), and "Licence" (the user's). Everything else in ADR 0062 stands: the owners and their markers, the briefs, the tests, `/readme-sync` and `/doc-audit`. The headings aren't tested (07), so the user may change the sections again.

Consequences: The README is shorter, and the manual is the one place that lists what notasi can do. Whoever wants either section back writes a new ADR.

Supersedes: 0062 (only its list of sections)
