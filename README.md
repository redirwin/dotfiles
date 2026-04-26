# My dotfiles

Personal config that follows me from machine to machine. Currently scoped to user-level slash commands, shared agent skills, and MCP servers for AI coding tools; can grow to cover shell, git, and editor config later.

## What's here

```
dotfiles/
  install.ps1     Windows installer - syncs prompts, skills, and MCP servers into each agent's user-level config
  install.sh      macOS installer - syncs prompts, skills, and MCP servers into each agent's user-level config
  prompts/        Canonical source for personal slash commands (my-*.md)
  skills/         Canonical source for user-scoped agent skills (one folder each, with SKILL.md)
  mcp.json        Canonical source for user-scoped MCP servers (mcpServers map)
  README.md
```

## How the slash commands work

Each `prompts/my-*.md` file becomes a `/my-<name>` slash command in three AI coding agents:

| Agent          | Target folder                                 | Filename              |
| -------------- | --------------------------------------------- | --------------------- |
| Claude Code    | `~/.claude/commands/`                         | `my-<name>.md`        |
| OpenAI Codex   | `~/.codex/prompts/`                           | `my-<name>.md`        |
| GitHub Copilot | `%APPDATA%\Code\User\prompts\` (VS Code user) | `my-<name>.prompt.md` |

The installer **copies** files into these target folders (no symlinks, no admin/Developer Mode required). Edits made directly in a target folder do **not** flow back - always edit in `prompts/` and re-run the installer.

## How the skills work

Each `skills/<skill-name>/SKILL.md` becomes a user-scoped agent skill that the agent loads when the description matches the user's request. Skills are how an agent learns _behavioral procedures_ (e.g. "how to do a git sync"), as opposed to slash commands which are _one-shot prompt templates_.

| Agent          | Target folder                       |
| -------------- | ----------------------------------- |
| Claude Code    | `~/.claude/skills/<skill-name>/`    |
| OpenAI Codex   | `~/.codex/skills/<skill-name>/`     |
| GitHub Copilot | `~/.copilot/skills/<skill-name>/`    |

Cursor does not support this repo's user-scoped skills or commands directly, so Cursor coverage uses the repo-scoped fallback described below.

## How the MCP servers work

`mcp.json` is the canonical user-level set of MCP servers — anything in this file becomes available to every agent on every machine where the installer runs. Use it for MCPs that should follow you everywhere; for project-specific MCPs, use a per-repo `.mcp.json` (or a `.agents/mcp.json` if the repo uses repo-agents-sync).

The installer mirrors `mcp.json` into each tool's expected user-level config:

| Agent          | Target                                              | Strategy |
| -------------- | --------------------------------------------------- | -------- |
| Cursor         | `~/.cursor/mcp.json`                                | Full overwrite (file is treated as dotfiles-managed) |
| VS Code Copilot| `%APPDATA%\Code\User\mcp.json` (Win), `~/Library/Application Support/Code/User/mcp.json` (mac) | Full overwrite, top-level key renamed `mcpServers` → `servers` |
| Claude Code    | `~/.claude.json` mcpServers section                 | Managed via `claude mcp` CLI so unrelated settings are preserved |
| Codex CLI      | `~/.codex/config.toml` `[mcp_servers.<name>]` blocks | Managed in-place; other TOML tables are preserved |

Cursor and Copilot's `mcp.json` files are treated as **dotfiles-managed** — if you've manually added MCPs there outside dotfiles, the installer will overwrite them. Move those entries into `~/dotfiles/mcp.json` instead.

**Removed entries are pruned from every agent.** Cursor and Copilot drop them via the full overwrite; Claude Code and Codex are explicitly cleaned: the installer reads the user-scope MCP list from `~/.claude.json` and `~/.codex/config.toml`, compares against `mcp.json`, and removes any orphan entries it finds. Each removal is printed (`removing orphan: <name>`) so a surprise prune is visible in the install output. **This means anything you add to user-scope Claude Code or Codex MCPs outside dotfiles will be wiped on the next install** — manage user-level MCPs from `mcp.json`, not by hand.

The Codex install requires Python 3 (used for safe TOML section editing). The Bash installer additionally needs `jq`.

## Current prompts

Prompts are picker-friendly entry points. When a workflow also has a skill, the skill is the source of truth for detailed procedure and safety rules.

| Command          | What it does                                                                                                                              |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `/my-onboard`    | Entry point for the `/onboard` behavior in `shortcut-interpretation`.                                                                      |
| `/my-new-convo`  | Entry point for the `/onboard` behavior in `shortcut-interpretation`.                                                                      |
| `/my-nccp`       | Entry point for the `/nccp` behavior in `shortcut-interpretation`.                                                                         |
| `/my-commit-msg` | Entry point for the `/commit msg` behavior in `shortcut-interpretation`.                                                                   |
| `/my-git-sync`   | Entry point for the `git-sync` skill: stage all changes, commit only when needed, then push the current branch.                         |

## Current skills

| Skill                     | What it does                                                                                                                      |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `shortcut-interpretation` | Expands inline prompt shortcuts (`/onboard`, `/nccp`, `/commit msg`, `/git sync`, `/sync agents`) anywhere in a message.          |
| `git-sync`                | Defines the full git add+commit+push procedure used by `/my-git-sync` and `/git sync`.                                            |
| `skill-authoring`         | Conventions for writing skills in repos using the repo-agents-sync scaffolding (`.agents/skills/`, `repo-` command prefix, etc.). |

## First-time setup on a new Windows machine

```powershell
git clone https://github.com/redirwin/dotfiles.git $HOME\dotfiles
powershell -File $HOME\dotfiles\install.ps1
```

If script execution is blocked, allow it for the current user once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## First-time setup on a new Mac

```bash
git clone https://github.com/redirwin/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh
```

## Day-to-day workflow

**Editing a prompt, skill, or MCP server:**

1. Edit the file in `~/dotfiles/prompts/`, `~/dotfiles/skills/<name>/`, or `~/dotfiles/mcp.json`.
2. Re-run `powershell -File $HOME\dotfiles\install.ps1` on Windows or `bash ~/dotfiles/install.sh` on macOS.
3. Restart the affected agent(s) so they re-scan the picker / skill index / MCP servers.

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

**Removing an MCP server:**

1. Delete the entry from `~/dotfiles/mcp.json` (or empty the `mcpServers` object entirely).
2. Re-run the installer. Cursor, Copilot, Claude Code, and Codex all auto-prune the removed entries; each removal prints as `removing orphan: <name>`.
3. Commit the removal.

## Conventions

- Slash commands are named `my-<name>.md` so they cannot collide with native commands (`/init`, `/review`) or with repo-scoped commands (`/repo-*`).
- Prompt bodies are plain markdown; no YAML frontmatter is required for any of the three agents to recognize the file as a command. Keep them short when they are picker aliases for a skill-owned behavior.
- Skill folders use lowercase-hyphen names matching the YAML `name`. Each contains exactly one `SKILL.md`; supporting files (`reference.md`, `scripts/`) are optional.
- Prompts and skills must not reference repo-local files that may not exist in an arbitrary repo. They may reference user-scoped skills installed by this repo.

## Pairs with repo-scoped tooling

This repo handles the **user-scoped** layer only. Repos that need their own committed agent config (skills, commands, rules, MCP servers tied to that codebase) use a separate kit at [redirwin/repo-agents-sync](https://github.com/redirwin/repo-agents-sync), which mirrors a canonical `<repo>/.agents/` tree into `<repo>/.cursor/`, `<repo>/.claude/`, `<repo>/.github/`, `<repo>/.vscode/`, and `<repo>/.mcp.json`.

The two systems run **independently** and write to non-overlapping paths:

- This repo's installers write to user-scoped paths: `~/.claude/`, `~/.codex/`, `~/.copilot/skills/`, the VS Code user prompts folder, and (for MCP servers) `~/.cursor/mcp.json`, the VS Code user `mcp.json`, `~/.claude.json`'s `mcpServers` section, and `~/.codex/config.toml`'s `[mcp_servers.*]` blocks.
- `repo-agents-sync`'s `sync-agents.ps1` writes to repo-scoped paths: `<repo>/.cursor/`, `<repo>/.claude/`, `<repo>/.github/`, `<repo>/.vscode/mcp.json`, and `<repo>/.mcp.json`.

Either can be used alone. When both are present, the agents merge both layers automatically. Naming conventions (`my-*` here vs. `repo-*` in the kit) keep slash commands from colliding.

## Cursor coverage gap

Cursor has no user-scoped commands or skills folder, so the `/my-*` prompts and the user-scoped skills above (`shortcut-interpretation`, `git-sync`) do **not** automatically reach Cursor. They work in Claude Code, Codex, and Copilot on every machine where this dotfiles repo is installed; they do nothing in Cursor unless the current repo provides them.

**MCP servers are an exception** — Cursor *does* support a user-scoped `~/.cursor/mcp.json`, so MCPs from `~/dotfiles/mcp.json` reach Cursor like every other agent. The gap below applies to prompts and skills only.

This is a deliberate tradeoff (no implicit per-repo injection of personal config). When you actually need a `/my-*` prompt or user-scoped skill to work in Cursor for a specific repo, use the **tactical fallback**:

1. Copy the file or folder you need from `~/dotfiles/` into the repo's canonical agent source:
   - Prompts → copy `~/dotfiles/prompts/my-<name>.md` to `<repo>/.agents/commands/` (rename if the repo's prefix scheme differs - e.g. `repo-<name>.md`).
   - Skills → copy `~/dotfiles/skills/<skill-name>/` to `<repo>/.agents/skills/<skill-name>/`.
2. Run that repo's sync script (`scripts/sync-agents.ps1` on Windows or `.sh` on macOS/Linux). This mirrors the new file or folder into `.cursor/`, `.claude/`, and `.github/`.
3. Commit the addition to the repo if other people work there and need the same behavior; otherwise gitignore the copy as a personal-only addition.

**Heuristic:** only do this for repos where you'll routinely use Cursor _and_ need the specific behavior. For one-off use, just type the explicit instruction instead of typing the shortcut.

## What's not in scope (yet)

- Linux installer.
- Shell profile, git config, editor settings.
- Automatic Cursor coverage from dotfiles - see "Cursor coverage gap" above for the manual fallback.
