---
name: git-sync
description: >-
  Stages all changes in the current git repo, commits with a short
  description of what changed, then pushes to the configured remote. Use
  when the user asks to sync, push everything, or runs /git sync or
  /my-git-sync.
---

# Git sync

End-to-end workflow for the current git repository (workspace root): stage everything, commit with a **short change summary**, then push.

## Preconditions

- User intends **writes** to git and **network** for push. Request **git_write** and **network** (or **full_network**) for the shell step.
- Run from the **git repository root**, not a subfolder, unless the user explicitly asked to operate in another git repo.

## Steps

1. **`git add -A`**
   Stages new, modified, and deleted paths across the repo.

2. **Commit only if there is something staged**
   After staging, if the index is empty, **skip** `git commit` (do not fail the turn; report that the working tree had nothing to commit).

   Check with `git diff --cached --quiet` (exit 0 means no staged changes) or equivalent.

3. **Commit message format**
   A **short description of the staged changes** - about **3 to 15 words**, aim **under ~90 characters**. No `sync` prefix, no timestamp, no separator.

   Derive the description from **`git diff --cached`** (for example `--name-status` and/or `--stat`): name the areas or themes (folders, features, add/remove), not a bare dump of every path unless there are very few files. If both renames and edits matter, say so in plain language.

   Full message example: `git-sync skill: drop sync prefix and timestamp; update shortcut docs`

4. **`git commit`** (only when step 2 showed staged changes)
   `git commit -m "..."` with the full single-line message from step 3. If a filename could break shell quoting, use `git commit -F` with a temp file containing the message instead of `-m`.

5. **`git push`**
   Push the **current branch** to its **upstream** (plain `git push`). Run **even when** no new commit was made, so **unpushed commits** from earlier work still reach the remote. If push fails because **no upstream** is set, retry once with `git push -u origin HEAD` when `origin` exists, or report the error and stop.

6. **Report**
   Summarize: what was staged, whether a commit was created (full message including the **change summary**), and push result (including `Everything up-to-date` when applicable).

## Safe defaults

- Do **not** `--force` push unless the user explicitly asks for a force push.
- If `git commit` fails for a reason other than "nothing to commit", do **not** push; show the error.

## Reference one-liner (optional)

Shell-only fallback when no agent is composing a phrase: use **`git diff --cached --shortstat`** (trimmed) as the commit message. From repo root:

```bash
git add -A
if git diff --cached --quiet; then
  git push
else
  msg=$(git diff --cached --shortstat | sed 's/^ *//')
  git commit -m "$msg" && git push
fi
```
