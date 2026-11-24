---
name: release
description: Release dev to main at the end of an iteration (or as a fix) - build one commit with dev's files minus the dev-only paths, open a PR into main, and tag it after the merge.
disable-model-invocation: true
---

# Release dev to main

`main` holds only what users need (ADR 0023). A release is never a merge:
it is one commit on a `release/vX.Y.Z` branch from `main`, holding `dev`'s
files minus the dev-only paths below, squash-merged into `main` and
tagged there. `dev` and `main` don't share history; never merge one into
the other.

## Dev-only paths

These exist only on `dev`. This list is the one place they are named
(CLAUDE.md points here):

```
.claude
CLAUDE.md
doc/design
doc/decisions
doc/iterations
doc/references
doc/prototypes
tests/decisions.scm
tests/iterations.scm
```

`tests/decisions.scm` and `tests/iterations.scm` are on the list
because they check `doc/decisions/` and `doc/iterations/`.
If a new test reads a dev-only path, add it here.

`editors/` (the Emacs package) is not dev-only: it ships to `main`
with notasi and the same version tag (ADR 0050).

## Steps

1. **What's new.** `git fetch --prune origin --tags`. Compare the last
   release with `origin/dev`: `git diff --stat <last tag on main>
   origin/dev` (before the first release, `main` is "Project skeleton").
   If nothing outside the dev-only paths changed, say so and stop.

2. **CI.** Check `origin/dev`'s CI (`gh run list --branch dev --limit 1`).
   If it isn't green, stop and say so.

3. **Which release.** Ask the user, unless they said:
   - which iteration it completes, or whether it's a fix release;
   - the tag, suggesting `v0.N.0` for iteration N (from its folder,
     `doc/iterations/NN-*`), or the next `.PATCH` after the latest tag
     on `main` for a fix.

   For an iteration, check that its README's status is `building` and
   that the Verify phase is done: its acceptance test passes and
   `/doc-audit` has been run since its last milestone. Suggest either if
   it hasn't.

4. **Build the release commit** in a separate worktree, so the user's
   working tree isn't touched:

   ```
   W=$TMPDIR/notasi-release-<tag>
   git worktree add -b release/<tag> "$W" origin/main
   cd "$W"
   git rm -rq .                         # start from an empty index
   git checkout origin/dev -- .         # dev's files
   git rm -rq --ignore-unmatch <every dev-only path>
   git ls-files -- <every dev-only path>   # must print nothing
   make check                           # must pass without them
   git commit -m "Release <tag>: <iteration name, or the fixes>"
   ```

   If `make check` fails, stop and show the failures: usually a test
   reads a dev-only path. Don't commit.

5. **Open the PR** from the worktree:

   ```
   git push -u origin release/<tag>
   gh pr create --base main --head release/<tag> --title "Release <tag>: <name>"
   ```

   The body lists the PRs into `dev` since the last release (from
   `git log --oneline <last release's dev commit>..origin/dev`, or every
   PR before the first release), says which dev-only paths were left
   out, and has the template's Test plan with `make check` ticked.

6. **Tell the user** to merge it with **"Squash and merge"**, so `main`
   gets one commit per release. Don't merge it yourself. Then remove the
   worktree: `git worktree remove "$W"`.

7. **After the merge**, when the user asks:
   - tag `main`'s new commit (`gh pr view <n> --json mergeCommit`) with
     an annotated tag, `git tag -a <tag> -m "<iteration name, or the
     fixes>" <commit>`, and `git push origin <tag>`;
   - delete the `release/<tag>` branch locally (GitHub deletes its copy
     on merge);
   - for an iteration release, close the iteration's GitHub milestones
     (`Iteration N · …`) whose PRs are all merged:
     `gh api -X PATCH repos/{owner}/{repo}/milestones/<number> -f state=closed`;
   - for an iteration release, remind the user to set the iteration's
     `Status:` to `done` on `dev` (a `doc/…` PR), and to move the
     build order in `doc/design/README.md` on.

`dev` survives every release: nothing is merged from it, and it is
protected. Never delete `dev`.
