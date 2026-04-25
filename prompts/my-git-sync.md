Stage everything, commit with a short summary of the staged changes, then push the current branch.

Steps:

1. Run from the git repository root.
2. `git add -A` — stage new, modified, and deleted paths.
3. Check `git diff --cached --quiet`. If exit 0 (nothing staged), skip the commit step but still run `git push` so any earlier unpushed commits reach the remote.
4. Otherwise, derive a short single-line commit message (3–15 words, under ~90 characters) from `git diff --cached --name-status` and/or `--stat`. Name the areas or themes (folders, features, add/remove), not a bare path dump unless there are very few files. No prefix, no timestamp.
5. `git commit -m "<message>"`. If a filename could break shell quoting, use `git commit -F` with a temp file instead.
6. `git push`. If push fails because no upstream is set, retry once with `git push -u origin HEAD` when `origin` exists; otherwise report the error and stop.
7. Report: what was staged, whether a commit was created (full message), and the push result.

Safe defaults: never `--force` push unless the user explicitly asks. If `git commit` fails for a reason other than "nothing to commit", do not push — show the error.
