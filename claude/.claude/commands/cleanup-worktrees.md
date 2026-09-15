---
description: Find git worktrees under the current directory whose branch has already been merged via PR, and remove them
argument-hint: [path (defaults to current directory)]
allowed-tools: Bash, AskUserQuestion
---

# Clean up merged git worktrees

Scope: `$ARGUMENTS` if given, otherwise the current working directory. Only
touch worktrees found under that root — never wander outside it.

## 1. Discover worktrees

Search under the scope root for git worktrees. Worktrees show up two ways in
this environment:

- Sibling folders named `<repo>-worktrees/<branch-dir>` next to a main repo
  checkout (e.g. `onyx-intake-api/` + `onyx-intake-api-worktrees/foo`).
- Ad-hoc directories elsewhere that are still registered worktrees of some
  repo (e.g. a `some-task/onyx-intake-api` folder).

Reliable method: find every directory under the scope root containing a
`.git` (file or dir) — that's every repo checkout AND every worktree. Group
them by the main repo they belong to, then for each main repo run:

```
git -C <main-repo-path> worktree list
```

This gives the authoritative list of worktrees for that repo, including ones
that live outside the obvious `-worktrees/` folder. Skip the main worktree
itself (the first line, on `main`/`master` or whatever the primary checkout
branch is) — only evaluate the additional entries.

## 2. For each worktree, check merge status

For the branch checked out in that worktree:

```
gh pr list --head "<branch>" --state all --json number,title,state,headRefName,mergedAt
```

Run this from inside that worktree (or the main repo) so `gh` resolves the
right remote. Classify:

- **MERGED** → candidate for cleanup.
- **OPEN** or no PR found → leave it alone, note why.
- **CLOSED but not merged** → leave it alone, flag it as ambiguous (don't
  assume abandoned work is safe to delete).

## 3. Safety checks before removing a MERGED worktree

For each candidate, check:

```
git -C <worktree-path> status --short --branch
git -C <worktree-path> log @{u}.. --oneline
```

- Unpushed commits (`log @{u}..` non-empty) → **do not remove**, flag it.
- Uncommitted changes (modified or untracked files) → don't silently discard.
  Collect what's uncommitted across all candidates and summarize it for the
  user in one batch (file paths, rough nature — scratch notes vs. real
  code). Then use AskUserQuestion once to ask how to proceed for the whole
  batch (delete everything / save the uncommitted bits somewhere first /
  only remove the fully-clean ones). Do not ask one question per worktree.

## 4. Remove

For every worktree cleared for removal:

```
git -C <main-repo-path> worktree remove --force <worktree-path>
```

`git worktree remove` can fail with "Directory not empty" when gitignored
build output (e.g. `dist/`, `node_modules/`, `.venv/`) is left behind — it
still deregisters the worktree even when this happens. After it runs, check
whether the directory still exists and `rm -rf` it if so.

Then delete the now-merged local branch, if one exists in the main repo:

```
git -C <main-repo-path> branch -D <branch>
```

Don't touch the remote branch — leave that to GitHub's own merge cleanup.

## 5. Report

End with a short table/list: what was removed, what was left behind and why
(open PR, unpushed commits, ambiguous state). Don't pad it with process
narration.
