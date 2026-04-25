# redirwin dotfiles

Personal config that follows me from machine to machine. Currently scoped to user-level slash commands and shared agent skills for AI coding tools; can grow to cover shell, git, and editor config later.

## What's here

```
dotfiles/
  install.ps1     Windows installer - copies prompts and skills into each agent's user folder
  prompts/        Canonical source for personal slash commands (my-*.md)
  skills/         Canonical source for user-scoped agent skills (one folder each, with SKILL.md)
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

## How the skills work

Each `skills/<skill-name>/SKILL.md` becomes a user-scoped agent skill that the agent loads when the description matches the user's request. Skills are how an agent learns *behavioral procedures* (e.g. "how to do a git sync"), as opposed to slash commands which are *one-shot prompt templates*.

| Agent          | Target folder                       |
| -------------- | ----------------------------------- |
| Claude Code    | `~/.claude/skills/<skill-name>/`    |
| OpenAI Codex   | `~/.codex/skills/<skill-name>/`     |

Cursor and Copilot do not support user-scoped skills, so this layer covers Claude Code and Codex only.

## Current prompts

| Command          | What it does                                                                 |
| ---------------- | ---------------------------------------------------------------------------- |
| `/my-onboard`    | Alias for `/my-new-convo`.                                                   |
| `/my-new-convo`  | Read root readme, AGENTS/CLAUDE.md, manifest, and folder structure; summarize the project in <=200 words and stand by for updates. |
| `/my-nccp`       | "No code changes, please" - read-only analysis only; no file writes.         |
| `/my-commit-msg` | Review work since the last commit and propose one short commit message; do not run git. |
| `/my-git-sync`   | `git add -A`, commit with a short summary derived from the staged diff (only if anything is staged), then `git push`. Never force-pushes. |

## Current skills

| Skill                     | What it does                                                                              |
| ------------------------- | ----------------------------------------------------------------------------------------- |
| `shortcut-interpretation` | Expands inline prompt shortcuts (`/onboard`, `/nccp`, `/commit msg`, `/git sync`, `/sync agents`) anywhere in a message. |
| `git-sync`                | Defines the full git add+commit+push procedure used by `/my-git-sync` and `/git sync`.    |
| `skill-authoring`         | Conventions for writing skills in repos using the repo-agents-sync scaffolding (`.agents/skills/`, `repo-` command prefix, etc.). |

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

**Editing a prompt or skill:**

1. Edit the file in `~/dotfiles/prompts/` or `~/dotfiles/skills/<name>/`.
2. Re-run `powershell -File $HOME\dotfiles\install.ps1`.
3. Restart the affected agent(s) so they re-scan the picker / skill index.

**Adding a new prompt:**

1. Create `~/dotfiles/prompts/my-<name>.md` with the prompt body. Keep it self-contained.
2. Re-run the installer.
3. Commit the new file.

**Adding a new skill:**

1. Create `~/dotfiles/skills/<skill-name>/SKILL.md` with YAML frontmatter (`name`, `description`) and body.
2. Re-run the installer.
3. Commit the new folder.

**Removing a prompt or skill:**

1. Delete the file or folder from `~/dotfiles/prompts/` or `~/dotfiles/skills/`.
2. Re-run the installer. The script reports any orphans now sitting in target folders.
3. Manually delete those orphans (the installer never deletes from targets, by design).
4. Commit the removal.

## Conventions

- Slash commands are named `my-<name>.md` so they cannot collide with native commands (`/init`, `/review`) or with repo-scoped commands (`/repo-*`).
- Prompt bodies are plain markdown; no YAML frontmatter is required for any of the three agents to recognize the file as a command.
- Skill folders use lowercase-hyphen names matching the YAML `name`. Each contains exactly one `SKILL.md`; supporting files (`reference.md`, `scripts/`) are optional.
- Prompts and skills must be self-contained: do not reference files that may not exist in an arbitrary repo. The whole point of user-scoping is that they work everywhere.

## Pairs with repo-scoped tooling

This repo handles the **user-scoped** layer only. Repos that need their own committed agent config (skills, commands, rules tied to that codebase) use a separate kit at [redirwin/repo-agents-sync](https://github.com/redirwin/repo-agents-sync), which mirrors a canonical `<repo>/.agents/` tree into `<repo>/.cursor/`, `<repo>/.claude/`, and `<repo>/.github/`.

The two systems run **independently** and write to non-overlapping paths:

- This repo's `install.ps1` writes to `~/.claude/`, `~/.codex/`, and the VS Code user folder.
- `repo-agents-sync`'s `sync-agents.ps1` writes to a repo's `.cursor/`, `.claude/`, and `.github/`.

Either can be used alone. When both are present, the agents merge both layers automatically. Naming conventions (`my-*` here vs. `repo-*` in the kit) keep slash commands from colliding.

## Cursor coverage gap

Cursor has no user-scoped commands or skills folder, so the `/my-*` prompts and the user-scoped skills above (`shortcut-interpretation`, `git-sync`) do **not** automatically reach Cursor. They work in Claude Code and Codex on every machine where this dotfiles repo is installed; they do nothing in Cursor unless the current repo provides them.

This is a deliberate tradeoff (no implicit per-repo injection of personal config). When you actually need a `/my-*` prompt or user-scoped skill to work in Cursor for a specific repo, use the **tactical fallback**:

1. Copy the file or folder you need from `~/dotfiles/` into the repo's canonical agent source:
   - Prompts → copy `~/dotfiles/prompts/my-<name>.md` to `<repo>/.agents/commands/` (rename if the repo's prefix scheme differs - e.g. `repo-<name>.md`).
   - Skills → copy `~/dotfiles/skills/<skill-name>/` to `<repo>/.agents/skills/<skill-name>/`.
2. Run that repo's sync script (`scripts/sync-agents.ps1` on Windows or `.sh` on macOS/Linux). This mirrors the new file or folder into `.cursor/`, `.claude/`, and `.github/`.
3. Commit the addition to the repo if other people work there and need the same behavior; otherwise gitignore the copy as a personal-only addition.

**Heuristic:** only do this for repos where you'll routinely use Cursor *and* need the specific behavior. For one-off use, just type the explicit instruction instead of typing the shortcut.

## What's not in scope (yet)

- macOS/Linux installer (`install.sh`).
- Shell profile, git config, editor settings.
- Automatic Cursor coverage from dotfiles - see "Cursor coverage gap" above for the manual fallback.
