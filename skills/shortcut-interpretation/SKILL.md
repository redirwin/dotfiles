---
name: shortcut-interpretation
description: >-
  Expands inline prompt shortcuts (/onboard, /new convo, /nccp, /commit msg,
  /git sync, /sync agents). Use whenever those tokens appear in the user's
  message (start, end, or inline), or for shortcut stacking and conflicts.
---

# Shortcut interpretation

Inline prompt shortcuts. The tokens below can be typed anywhere in a prompt and expand into the full instruction in the [Shortcuts](#shortcuts) table.

This skill defines **inline text shortcuts only**. Some shortcuts also have `/` picker counterparts (`/my-onboard`, `/my-nccp`, etc., installed from a personal dotfiles repo; or `/repo-*` entries in repos with that scaffolding), but the inline tokens here work in any agent that loads this skill, regardless of whether picker counterparts are installed.

**Extending this file:** add a row under [Shortcuts](#shortcuts), and add one line under [Processing rules](#processing-rules) if a new rule is needed.

## Processing rules

1. Shortcuts may appear **before**, **after**, or **inline** with the rest of the prompt. Detect the tokens anywhere in the message.
2. If **multiple** shortcuts appear, **apply all** of them. Combine their expanded meanings for that turn.
3. If a shortcut **conflicts** with another instruction in the prompt, the **shortcut wins**, unless the user **explicitly overrides** the shortcut in the **same** message (for example: "ignore /nccp" or "/nccp does not apply").
4. Shortcuts are **slash-led** as listed in the table. Match them **case-insensitively** with the leading `/` required (no bare-word legacy aliases).
5. **Prefix overlap:** If you later add two shortcuts where one is a strict prefix of the other, match the **longer** token for that span of the message, not the shorter prefix alone.

Token matching: include spaces where shown (for example `/commit msg` is two words after the slash).

## Shortcuts

When a shortcut is present, treat it as the following full instruction (in addition to any other prompt text and any other expanded shortcuts).

| Shortcut | Expanded instruction |
| -------- | ---------------------- |
| `/onboard` | Familiarize yourself with the full project and codebase in the current workspace; then summarize the project in 200 words or less and be ready to help with updates. If the repo is documentation-only or tiny, say so plainly. |
| `/new convo` | Same as `/onboard`. |
| `/nccp` | No code changes, please; provide analysis, guidance, suggestions, or commands only and do not modify files. Do not state in your reply that you are following this shortcut or name the shortcut. |
| `/commit msg` | Review work since the last commit using read-only git inspection and conversation context, then produce one short, descriptive commit message appropriate for the changes. Do not create a commit or modify git state; only display the suggested message for the user to use. If diff context is unavailable, say what is missing and suggest a message from described changes only. |
| `/git sync` | Follow the `git-sync` skill; use that skill as the source of truth for procedure, safety rules, commit message format, upstream handling, and reporting. |
| `/sync agents` | If the current repo has a `scripts/sync-agents.ps1` (Windows) or `scripts/sync-agents.sh` (macOS/Linux), run it from repo root to mirror `.agents/` into `.cursor/`, `.claude/`, and `.github/`. If no such script exists, report that the current repo does not use the `.agents/` mirror pattern. Never edit files under `.cursor/`, `.claude/`, or `.github/` directly; they are regenerated from `.agents/`. |
