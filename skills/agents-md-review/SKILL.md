---
name: agents-md-review
description: >-
  Audits and tidies a repo's agent briefing file (AGENTS.md, CLAUDE.md, or
  equivalent): removes rot, verifies claims against the actual repo, moves
  out-of-place content, and tightens tone. Use when the user asks to review,
  clean up, audit, refresh, or "tidy" AGENTS.md / CLAUDE.md, or when the
  briefing has drifted from the codebase.
---

# AGENTS.md review

Audits the repo's agent briefing for **drift**, **rot**, and **misplaced content**, then proposes edits. The goal is a briefing that is short, accurate, agent-directed, and free of anything an agent could derive from the code itself.

Applies to whichever briefing the repo uses: `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*.md`, `.github/copilot-instructions.md`, or a `CLAUDE.md` that just `@AGENTS.md`-includes another file. If multiple exist, audit the canonical one and treat the others as mirrors.

## Steps

**This skill is review-then-edit, not edit-in-place. Do not modify the briefing during steps 1–3. The first write happens only after step 4 returns explicit approval.**

1. **Read the briefing in full** before proposing anything. Note the section headings — those are the audit targets.

2. **Verify every concrete claim** against the current repo (read-only). For each:
   - **File paths and folders** mentioned (`db/schema.ts`, `(app)/`, `_Docs/Foo.md`, etc.) — confirm they exist with Glob/Read.
   - **Commands** (`npm run db:up`, scripts referenced) — confirm in `package.json` / scripts dir.
   - **Tools, MCP servers, library versions** — confirm against `.mcp.json`, `package.json`, lockfile.
   - **Route lists / file trees** — confirm they match the filesystem.
   Flag every mismatch. Do not silently "fix" by guessing.

3. **Produce a written audit** organized by section, with one entry per proposed change. Each entry must state: **what** (the exact text or block), **action** (delete / move to `<path>` / rewrite as `<new text>`), and **why** (which rot-checklist row, or which verification failed). Do not edit any file yet.

4. **Stop and ask for approval before any edit.** Present the audit to the user and ask which proposals to apply. Acceptable inputs: "all", a list of items, or item-by-item. If the user has not given explicit approval for a specific change, do not apply it. When in doubt about scope, ask — do not interpret "looks good" as carte blanche to edit.

5. **Apply only the approved edits.** Keep diffs surgical — do not reflow unrelated paragraphs, do not rename headings the user did not approve, do not "while I'm here" tidy adjacent prose.

6. **Report**: what was verified, what was changed (with the approval that authorized each change), what was flagged but deferred.

## Rot checklist — what does NOT belong in the briefing

| Smell | Why it's wrong | Where it should go |
| ----- | -------------- | ------------------ |
| **Build status / progress checklists** (`[x] auth wired`, `[ ] export feature`) | Goes stale within days; not actionable for an agent. | A dedicated `_Docs/Build_Status.md` or similar, linked from the briefing. |
| **File-tree diagrams** of the project layout | Duplicates what the agent will see when it reads the repo; rots on every restructure. | Replace with prose only if a structure is **non-obvious** (e.g. route groups with auth meaning); otherwise delete. |
| **Domain knowledge dumps** (long explanations of the business problem) | Bloats the briefing; agents can't act on most of it. | A planning workspace or `_Docs/` with a one-line pointer in the briefing. |
| **Tutorial-style "how the framework works"** | Belongs in framework docs, not project briefing. | Delete; link to docs / Context7 instead. |
| **Aspirational "we will..." / "TODO: decide..."** without an action surface | Reads as prose, not instruction; agents cannot act on it. | Either turn into a concrete "do not assume X" directive, or move to an open-questions doc. |
| **Restating CLAUDE.md / repo conventions verbatim** in multiple files | Drifts out of sync. | One canonical file; others `@`-include or link. |
| **Specific bug histories or PR references** | Rots; not actionable for a fresh task. | Commit messages and PR descriptions already hold this. |
| **Commentary about the agent itself** ("you are a careful assistant...") | Tone-setting belongs in a system prompt, not project briefing. | Delete. |

## What DOES belong

- **Architectural commitments** stated as directives ("server components by default", "every table carries `firm_id`", "no hardcoded SACS").
- **Concrete "do not guess" lists** — open questions where wrong assumptions would cost real work.
- **Tool / MCP wiring** the agent needs to discover (with version pins where unversioned IDs return mixed results).
- **Behaviors the agent must or must not perform** ("do not start the dev server", "use `npx shadcn@latest add`, not hand-written components").
- **Pointers** into `_Docs/`, planning workspaces, or external systems — short, named, with the reason to consult them.

## Tone rules to enforce on edits

- **Agent-directed, imperative.** "Use Context7 before writing Drizzle code" — not "the team uses Context7."
- **Terse.** Tables and bullet lists beat paragraphs. Cut adjectives.
- **Claim-bearing sentences must be verifiable.** If a sentence asserts a path, command, version, or tool exists, the agent must be able to confirm it now.
- **No emojis** unless the existing file uses them.

## When the briefing has a sibling (CLAUDE.md + AGENTS.md)

If `CLAUDE.md` is just `See @AGENTS.md` (or similar one-line include), edit `AGENTS.md` only and leave the include intact. If both files have real content, flag the duplication and recommend collapsing to one canonical file with includes from the others.

## Anti-patterns

- **Editing before approval.** The skill is review-first. Even an "obviously correct" fix waits for step 4.
- Editing without verifying — do not "tidy" a path that turns out to be wrong; investigate first.
- Treating a friendly response ("nice", "looks good") as approval to edit. Approval must reference specific proposals.
- Bulk reflows that produce huge diffs without changing meaning. Keep diffs reviewable.
- Adding new sections the user did not ask for. The job is **review and tighten**, not redesign.
- Deleting "open questions" sections because they look like rot — they are often the most load-bearing part of the briefing. Tighten them; do not remove unless the user confirms each item is resolved.
