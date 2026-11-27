# Design idea: what the tests check in the README

Status: agreed in discussion (2026-11-27). Not the design until
promoted.

## The problem

A skill only runs when someone runs it; a test runs on every push.
What can be checked mechanically should be, and no more.

## Settled (2026-11-27)

Add to `tests/readme.scm`:

- **Markers.** Every section has one `owner:` marker, `user` or
  `claude`.
- **Links.** Every relative link and image path points to a file
  that exists. (Links to the manual's site aren't checked: no network
  in the tests.)
- **The commands run.** "Drawing a score" uses
  `examples/gallery/jaya-semara.nts`, so a musician can copy the
  commands straight after installing. The test copies that file into
  a temporary folder, runs each command from the section's code block
  there, and checks that the file it should write appears. Nothing is
  written into `examples/`. It needs Typst, as `tests/template.scm`
  already does.

Not checked by a test: the length (a guideline), and that Claude
didn't edit a user's section (the user sees that in the PR).
