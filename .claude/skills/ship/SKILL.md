---
name: ship
description: Open a pull request from the current branch into dev - run the tests, check that the design docs were updated, push, and create the PR with the template's sections. Use when the user asks to open, create or make a PR.
---

# Open a PR into dev

## Steps

1. **Check the branch.** Never ship from `main` or `dev`; if on one of
   them, stop and say so. Commit nothing new without the user asking: if
   the working tree has uncommitted changes, ask whether to commit them.

2. **Bring it up to date.** `git fetch --prune origin`. If `origin/dev`
   has commits the branch lacks, rebase onto it. If the branch was built
   on another branch whose PR has since been squash-merged, rebase only
   this branch's own commits:
   `git rebase --onto origin/dev <last commit of the merged PR>`.

3. **Test.** Run `make check`. If it fails, stop and show the failures.

4. **Check the docs.** Compare `git diff origin/dev...HEAD` with
   `doc/design/`:
   - Behaviour, notation, piece records or the JSON contract changed but
     no design doc changed: stop and say which doc needs updating.
   - A documented decision was reversed or narrowed without a new ADR in
     `doc/decisions/`: stop and say so.
   - A design doc's `Status:` line or Implemented / Planned labels no
     longer match the code: stop and say which.
   - Something a user can see changed (notation, error messages,
     commands, output) but `doc/manual/` didn't: stop and say which page
     needs writing or updating. If `mdbook` is installed, run
     `make manual` and stop if it fails.

5. **Push and open the PR.**
   - `git push -u origin <branch>`. If the branch was rebased after an
     earlier push, use `--force-with-lease`.
   - `gh pr create --base dev`, with `--milestone '<title>'` when the
     branch belongs to a milestone of the current iteration: a slice or
     the milestone itself (as its README's "Milestones" lists them), or
     a fix or `/doc-audit` sync for it. The title is
     `Iteration N · <milestone branch>` (`/start-milestone` creates it).
     Promotions, governance and housekeeping PRs get no milestone; if
     it isn't clear, ask. `--body` replaces
     `.github/pull_request_template.md`, so write the body with the
     template's sections: Summary, Test plan (with `make check` ticked),
     and Docs, with each docs checkbox (design docs, user manual) ticked
     only if step 4 passed for it.
   - If an earlier PR from the same branch was closed, open a new one and
     mention the old number.

6. **Report** the PR URL. Say if it depends on another open PR being
   merged first.
