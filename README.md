# redirwin dotfiles

Personal config that follows me from machine to machine. Currently scoped to user-level slash commands for AI coding agents; can grow to cover shell, git, and editor config later.

## What's here

```
dotfiles/
  install.ps1     Windows installer - copies prompts into each agent's user folder
  prompts/        Canonical source for personal slash commands (my-*.md)
  README.md
```

## How the slash commands work

Each `prompts/my-*.md` file becomes a `/my-<name>` slash command in three AI coding agents:

| Agent          | Target folder                                  | Filename                  |
| -------------- | ---------------------------------------------- | ------------------------- |
| Claude Code    | `~/.claude/commands/`                          | `my-<name>.md`            |
| OpenAI Codex   | `~/.codex/prompts/`                            | `my-<name>.md`            |
| GitHub Copilot | `%APPDATA%\Code\User\prompts\` (VS Code user)  | `my-<name>.prompt.md`     |

The installer **copies** files into these target folders (no symlinks, no admin/Developer Mode required). Edits made directly in a target folder do **not** flow back - always edit in `prompts/` and re-run the installer.

## Current commands

| Command          | What it does                                                                 |
| ---------------- | ---------------------------------------------------------------------------- |
| `/my-onboard`    | Alias for `/my-new-convo`.                                                   |
| `/my-new-convo`  | Read root readme, AGENTS/CLAUDE.md, manifest, and folder structure; summarize the project in <=200 words and stand by for updates. |
| `/my-nccp`       | "No code changes, please" - read-only analysis only; no file writes.         |
| `/my-commit-msg` | Review work since the last commit and propose one short commit message; do not run git. |
| `/my-git-sync`   | `git add -A`, commit with a short summary derived from the staged diff (only if anything is staged), then `git push`. Never force-pushes. |

## First-time setup on a new machine

```powershell
git clone https://github.com/redirwin/dotfiles.git $HOME\dotfiles
powershell -File $HOME\dotfiles\install.ps1
```

If script execution is blocked, allow it for the current user once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## Day-to-day workflow

**Editing a command:**

1. Edit the file in `~/dotfiles/prompts/`.
2. Re-run `powershell -File $HOME\dotfiles\install.ps1`.
3. Restart the affected agent(s) so they re-scan the picker.

**Adding a new command:**

1. Create `~/dotfiles/prompts/my-<name>.md` with the prompt body. Keep it self-contained - do not reference files that may not exist in arbitrary repos.
2. Re-run the installer.
3. Commit the new file.

**Removing a command:**

1. Delete the file from `~/dotfiles/prompts/`.
2. Re-run the installer. The script will report the now-orphaned copies in each target folder.
3. Manually delete those orphans (the installer never deletes files in target folders by design).
4. Commit the removal.

## Conventions

- All slash command files are named `my-<name>.md` so they cannot collide with native commands (`/init`, `/review`).
- Prompt bodies are plain markdown. No YAML frontmatter is required for any of the three agents to recognize the file as a command.
- Prompts must be self-contained: do not reference external skills or files that may not exist in an arbitrary repo. The whole point of user-scoping is that they work everywhere.

## What's not in scope (yet)

- macOS/Linux installer (`install.sh`).
- Shell profile, git config, editor settings.
