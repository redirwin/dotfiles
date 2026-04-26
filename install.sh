#!/usr/bin/env bash
set -euo pipefail

# Personal dotfiles installer (macOS).
#
# Syncs ~/dotfiles/prompts/ and ~/dotfiles/skills/ into each agent's
# user-scoped folders so generic /my-* commands and shared skills are
# available in every repo, on every supported agent.
#
# Prompts (file-based, one .md per command):
#   - Claude Code : $HOME/.claude/commands/<name>.md
#   - Codex CLI   : $HOME/.codex/prompts/<name>.md
#   - Copilot     : $HOME/Library/Application Support/Code/User/prompts/<name>.prompt.md
#
# Skills (folder-based, each skill is a folder containing SKILL.md):
#   - Claude Code : $HOME/.claude/skills/<skill-name>/
#   - Codex CLI   : $HOME/.codex/skills/<skill-name>/
#   - Copilot     : $HOME/.copilot/skills/<skill-name>/
#
# Re-run this script after editing anything in ~/dotfiles/prompts/ or
# ~/dotfiles/skills/. The script copies (does not symlink) and never
# deletes unrelated files from target folders; orphans are only reported.
#
# Usage:
#   bash ~/dotfiles/install.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_SOURCE="$ROOT/prompts"
SKILLS_SOURCE="$ROOT/skills"

prompt_orphans=""
skill_orphans=""
prompt_count=0
skill_count=0

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

contains_name() {
  local needle="$1"
  shift

  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done

  return 1
}

copy_prompts_to_target() {
  local target_name="$1"
  local target_path="$2"
  local suffix="$3"
  shift 3

  local source_base_names=("$@")
  local file dest_name dest_path existing stem target_orphans

  printf -- '-> %s: %s\n' "$target_name" "$target_path"
  mkdir -p "$target_path"

  for file in "${prompt_files[@]}"; do
    dest_name="$(basename "${file%.md}")$suffix"
    dest_path="$target_path/$dest_name"
    cp -f "$file" "$dest_path"
    printf '    %s  ->  %s\n' "$(basename "$file")" "$dest_name"
  done

  target_orphans=""
  shopt -s nullglob
  for existing in "$target_path"/*"$suffix"; do
    [[ -f "$existing" ]] || continue
    stem="$(basename "$existing")"
    stem="${stem:0:${#stem}-${#suffix}}"
    if ! contains_name "$stem" "${source_base_names[@]}"; then
      target_orphans+=$'    '"$(basename "$existing")"$'\n'
    fi
  done
  shopt -u nullglob

  if [[ -n "$target_orphans" ]]; then
    prompt_orphans+=$'  '"$target_name :"$'\n'"$target_orphans"
  fi
}

copy_skills_to_target() {
  local target_name="$1"
  local target_path="$2"
  shift 2

  local source_skill_names=("$@")
  local skill skill_name dest_folder existing target_orphans

  printf -- '-> %s: %s\n' "$target_name" "$target_path"
  mkdir -p "$target_path"

  for skill in "${skill_folders[@]}"; do
    skill_name="$(basename "$skill")"
    dest_folder="$target_path/$skill_name"

    # Wipe the matching target subfolder before copy so renames/deletions
    # inside the skill propagate, while unrelated target skills stay untouched.
    if [[ -d "$dest_folder" ]]; then
      rm -rf "$dest_folder"
    fi

    cp -R "$skill" "$dest_folder"
    printf '    %s/\n' "$skill_name"
  done

  target_orphans=""
  shopt -s nullglob
  for existing in "$target_path"/*; do
    [[ -d "$existing" ]] || continue
    skill_name="$(basename "$existing")"
    if ! contains_name "$skill_name" "${source_skill_names[@]}"; then
      target_orphans+=$'    '"$skill_name/"$'\n'
    fi
  done
  shopt -u nullglob

  if [[ -n "$target_orphans" ]]; then
    skill_orphans+=$'  '"$target_name :"$'\n'"$target_orphans"
  fi
}

# ---------- prompts ----------

if [[ -d "$PROMPTS_SOURCE" ]]; then
  shopt -s nullglob
  prompt_files=("$PROMPTS_SOURCE"/*.md)
  shopt -u nullglob
  prompt_count="${#prompt_files[@]}"

  if [[ "$prompt_count" -eq 0 ]]; then
    warn "No .md files found in $PROMPTS_SOURCE - skipping prompts."
  else
    prompt_source_base_names=()
    for file in "${prompt_files[@]}"; do
      prompt_source_base_names+=("$(basename "${file%.md}")")
    done

    printf '\n=== Prompts ===\n'
    copy_prompts_to_target "Claude Code" "$HOME/.claude/commands" ".md" "${prompt_source_base_names[@]}"
    copy_prompts_to_target "Codex CLI" "$HOME/.codex/prompts" ".md" "${prompt_source_base_names[@]}"
    copy_prompts_to_target "Copilot" "$HOME/Library/Application Support/Code/User/prompts" ".prompt.md" "${prompt_source_base_names[@]}"
  fi
else
  warn "Prompts folder not found: $PROMPTS_SOURCE - skipping."
fi

# ---------- skills ----------

if [[ -d "$SKILLS_SOURCE" ]]; then
  skill_folders=()
  shopt -s nullglob
  for skill in "$SKILLS_SOURCE"/*; do
    if [[ -d "$skill" && -f "$skill/SKILL.md" ]]; then
      skill_folders+=("$skill")
    fi
  done
  shopt -u nullglob
  skill_count="${#skill_folders[@]}"

  if [[ "$skill_count" -eq 0 ]]; then
    warn "No skill folders (containing SKILL.md) found in $SKILLS_SOURCE - skipping skills."
  else
    skill_source_names=()
    for skill in "${skill_folders[@]}"; do
      skill_source_names+=("$(basename "$skill")")
    done

    printf '\n=== Skills ===\n'
    copy_skills_to_target "Claude Code" "$HOME/.claude/skills" "${skill_source_names[@]}"
    copy_skills_to_target "Codex CLI" "$HOME/.codex/skills" "${skill_source_names[@]}"
    copy_skills_to_target "Copilot" "$HOME/.copilot/skills" "${skill_source_names[@]}"
  fi
else
  warn "Skills folder not found: $SKILLS_SOURCE - skipping."
fi

# ---------- mcp ----------
#
# User-level MCP servers, mirrored from ~/dotfiles/mcp.json into each agent.
# Cursor and Copilot user-level mcp.json files are dotfiles-managed (full
# overwrite). Claude Code is updated via `claude mcp` so other settings in
# ~/.claude.json aren't touched. Codex is managed by replacing
# [mcp_servers.<name>] blocks inside ~/.codex/config.toml.
#
# Requires `jq` for JSON handling.

MCP_SOURCE="$ROOT/mcp.json"
mcp_count=0

if [[ -f "$MCP_SOURCE" ]]; then
  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found; skipping MCP sync. Install jq (brew install jq) to enable."
  else
    printf '\n=== MCP servers ===\n'
    mcp_count="$(jq '.mcpServers | length' "$MCP_SOURCE")"

    # Cursor (user-level)
    cursor_path="$HOME/.cursor/mcp.json"
    mkdir -p "$(dirname "$cursor_path")"
    cp "$MCP_SOURCE" "$cursor_path"
    printf -- '-> Cursor: %s\n    wrote %s entry/entries\n' "$cursor_path" "$mcp_count"

    # VS Code Copilot (user-level) -- rename top-level mcpServers -> servers
    vscode_path="$HOME/Library/Application Support/Code/User/mcp.json"
    mkdir -p "$(dirname "$vscode_path")"
    jq '{servers: .mcpServers}' "$MCP_SOURCE" > "$vscode_path"
    printf -- '-> Copilot (VS Code): %s\n    wrote %s entry/entries (key renamed to servers)\n' "$vscode_path" "$mcp_count"

    # Canonical name set, used by orphan-cleanup steps below
    canonical_names="$(jq -r '.mcpServers | keys[]' "$MCP_SOURCE")"

    # Claude Code (user-level) -- via the CLI
    printf -- '-> Claude Code: via "claude mcp" CLI (user scope)\n'
    if ! command -v claude >/dev/null 2>&1; then
      warn "    'claude' CLI not on PATH; skipping Claude Code MCP install."
    else
      while IFS=$'\t' read -r name url type; do
        [[ -z "$type" || "$type" == "null" ]] && type="http"
        claude mcp remove "$name" --scope user >/dev/null 2>&1 || true
        if claude mcp add --scope user --transport "$type" "$name" "$url" >/dev/null; then
          printf '    %s  ->  %s (%s)\n' "$name" "$url" "$type"
        else
          warn "    failed to add '$name' to Claude Code"
        fi
      done < <(jq -r '.mcpServers | to_entries[] | [.key, .value.url, (.value.type // "http")] | @tsv' "$MCP_SOURCE")
      # Orphan cleanup: read user-scope MCPs straight from ~/.claude.json
      # and remove any not in canonical.
      claude_json="$HOME/.claude.json"
      if [[ -f "$claude_json" ]]; then
        installed_claude="$(jq -r '.mcpServers // {} | keys[]' "$claude_json" 2>/dev/null || true)"
        while IFS= read -r installed_name; do
          [[ -z "$installed_name" ]] && continue
          if ! grep -Fxq "$installed_name" <<<"$canonical_names"; then
            printf '    removing orphan: %s\n' "$installed_name"
            claude mcp remove "$installed_name" --scope user >/dev/null 2>&1 || true
          fi
        done <<<"$installed_claude"
      fi
    fi

    # Codex -- manage [mcp_servers.<name>] blocks in ~/.codex/config.toml
    codex_cfg="$HOME/.codex/config.toml"
    mkdir -p "$(dirname "$codex_cfg")"
    [[ -f "$codex_cfg" ]] || : > "$codex_cfg"
    # Orphan cleanup (Codex): scan existing blocks; strip any name not in canonical.
    python3 - "$codex_cfg" <<PY
import re, sys, pathlib
path = sys.argv[1]
canonical = set("""$canonical_names""".split())
text = pathlib.Path(path).read_text(encoding="utf-8")
existing = re.findall(r"(?m)^[ \t]*\[mcp_servers\.([^\]]+)\]", text)
removed = []
for name in existing:
    if name not in canonical:
        removed.append(name)
        text = re.sub(r"(?ms)^[ \t]*\[mcp_servers\." + re.escape(name) + r"\][^\[]*", "", text)
text = re.sub(r"\n{3,}", "\n\n", text).lstrip()
pathlib.Path(path).write_text(text, encoding="utf-8")
for name in removed:
    print(f"    removing orphan: {name}")
PY
    while IFS=$'\t' read -r name url; do
      python3 - "$codex_cfg" "$name" "$url" <<'PY'
import re, sys, pathlib
path, name, url = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(path).read_text(encoding="utf-8")
pattern = re.compile(r"(?ms)^[ \t]*\[mcp_servers\." + re.escape(name) + r"\][^\[]*")
text = pattern.sub("", text)
text = text.rstrip() + ("\n\n" if text.strip() else "")
text += f"[mcp_servers.{name}]\nurl = \"{url}\"\n"
text = re.sub(r"\n{3,}", "\n\n", text).lstrip()
pathlib.Path(path).write_text(text, encoding="utf-8")
PY
    done < <(jq -r '.mcpServers | to_entries[] | [.key, .value.url] | @tsv' "$MCP_SOURCE")
    printf -- '-> Codex: %s\n    wrote/updated %s [mcp_servers.*] block(s)\n' "$codex_cfg" "$mcp_count"
  fi
fi

# ---------- summary ----------

printf '\nDone. %s prompt(s), %s skill(s), %s MCP server(s) synced.\n' "$prompt_count" "$skill_count" "$mcp_count"

if [[ -n "$prompt_orphans" ]]; then
  printf '\nPrompt files in target folders NOT overwritten by this run (no matching source in ~/dotfiles/prompts/):\n'
  printf '%s' "$prompt_orphans"
fi

if [[ -n "$skill_orphans" ]]; then
  printf '\nSkill folders in target locations NOT overwritten by this run (no matching source in ~/dotfiles/skills/):\n'
  printf '%s' "$skill_orphans"
fi

if [[ -n "$prompt_orphans" || -n "$skill_orphans" ]]; then
  printf '\nThese may be stale (renamed/deleted) or unrelated. Remove manually if needed.\n'
fi
