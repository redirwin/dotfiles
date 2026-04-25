---
name: skill-authoring
description: >-
  Defines how to add or edit Agent Skills in repos using the repo-agents-sync
  scaffolding (`.agents/skills/`): YAML frontmatter, folder naming,
  descriptions, links from the skill index, and style constraints. Use when
  creating a new skill, editing SKILL.md frontmatter, or aligning skills with
  the repo's root README.
---

# Skill authoring

Applies to any repo using the `repo-agents-sync` scaffolding (`.agents/skills/` + the `sync-agents` script). If the current repo doesn't have that structure, this skill doesn't apply.

Skills live in `.agents/skills/<skill-name>/` with a required `SKILL.md`. Optional: `reference.md`, `scripts/`, etc. The `sync-agents` script mirrors them into `.cursor/skills/`, `.claude/skills/`, and `.github/skills/`.

## Required shape

| Rule | Detail |
| ---- | ------ |
| Folder name | Lowercase letters, numbers, hyphens only; **must match** YAML `name` exactly. |
| `SKILL.md` frontmatter | `name` and `description` (non-empty). `description` in **third person**, includes **what** the skill does and **when** to use it; add **trigger keywords** users or tasks will mention. |
| Length | Keep `SKILL.md` focused; move long tables or API detail to `reference.md`. |

## Style

- Skill text is internal; em dashes are fine. Follow the repo's root **Conventions** for any external-facing text a skill tells the agent to produce.
- Prefer checklists and tables over long prose.

## After adding or renaming a skill

1. Add or update a row in `.agents/skills/README.md`.
2. If the skill should be discoverable from the repo's root `AGENTS.md` without opening the index, ensure **Skills** there still points at the README (preferred) or mention the skill explicitly.
3. Run `scripts/sync-agents.ps1` (or `.sh`) to regenerate the tool-specific mirrors. Use `-Clean` if you renamed or deleted anything.

## Repo-scoped slash commands (`repo-*`)

Repo-scoped picker entries (those that ship with the repo and operate on its scaffolding) live in **`.agents/commands/`** as `repo-<name>.md` and are mirrored into each tool's commands folder by `sync-agents`. The `repo-` prefix is **required** by the kit's sync script: it disambiguates kit-provided commands from native commands (`/init`, `/review`) and from user-scoped commands (e.g. `/my-*` from a personal dotfiles repo). The sync script will refuse to run if any command file under `.agents/commands/` lacks the prefix.

## Anti-patterns

- Editing files under `.cursor/`, `.claude/`, or `.github/` directly - those are regenerated mirrors. Edit only under `.agents/`.
- Mismatch between folder name and YAML `name`.
- Vague `description` with no trigger terms (hurts auto-discovery).
- Adding a command file to `.agents/commands/` without the `repo-` prefix.
