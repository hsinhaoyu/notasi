# Design idea: finding notasi

Status: agreed in discussion (2026-11-24); see "Settled". Not the
design until promoted.

## The problem

Installed as a package, the mode lives in `~/.emacs.d/elpa/…`, and the
user's pieces are in their own folders. The mode has to find the
`notasi` command without the user setting anything, if at all
possible.

## The idea

The mode tries, in order:

1. `notasi-program`, if the user set it;
2. `notasi` on the PATH (`executable-find`);
3. `scripts/notasi` in the same clone as the package itself, found
   from the package's own file. Installed from GitHub with
   `package-vc`, the whole repo is cloned, so this works with no
   setup;
4. `scripts/notasi` in a folder above the `.nts` file, for people
   working in the notasi repo.

If none is found, the preview says so in one sentence and points to
the manual's installation page. It also says when Guile or Typst is
missing (notasi's own error tells it which).

## Open

- How Emacs users install notasi itself (and Guile, and Typst at the
  pinned version) is an open question in 07-environment. Option 3
  covers notasi; Guile and Typst still need installing. The manual
  should give the commands for macOS (Homebrew) and Debian/Ubuntu at
  least.
- Should the package check that the notasi it found is the version it
  was released with? That needs `notasi --version`, which doesn't
  exist. Suggested: add it; it is small, and lets the mode say
  "this notasi is older than the package" instead of failing oddly.

## Settled (2026-11-24)

- **`notasi --version`** is added in this iteration: it prints notasi's
  version, and the mode uses it to say when the notasi it found is
  older than the package.
- **Installing Guile and Typst** (at the pinned version) is in the
  manual's chapter, with the commands for macOS (Homebrew) and
  Debian/Ubuntu ([documentation](2026-11-24-documentation.md)).
