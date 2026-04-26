#Requires -Version 5.1
<#
Personal dotfiles installer (Windows).

Syncs ~/dotfiles/prompts/ and ~/dotfiles/skills/ into each agent's
user-scoped folders so generic /my-* commands and shared skills are
available in every repo, on every supported agent.

Prompts (file-based, one .md per command):
  - Claude Code : $HOME\.claude\commands\<name>.md
  - Codex CLI   : $HOME\.codex\prompts\<name>.md
  - Copilot     : $env:APPDATA\Code\User\prompts\<name>.prompt.md

Skills (folder-based, each skill is a folder containing SKILL.md):
  - Claude Code : $HOME\.claude\skills\<skill-name>\
  - Codex CLI   : $HOME\.codex\skills\<skill-name>\
  - Copilot     : $HOME\.copilot\skills\<skill-name>\

Re-run this script after editing anything in ~/dotfiles/prompts/ or
~/dotfiles/skills/. The script copies (does not symlink) and never
deletes anything from target folders; orphans are only reported.

Usage:
  pwsh ~/dotfiles/install.ps1
#>

$ErrorActionPreference = 'Stop'

$Root          = $PSScriptRoot
$PromptsSource = Join-Path $Root 'prompts'
$SkillsSource  = Join-Path $Root 'skills'

# ---------- prompts ----------

$PromptTargets = @(
    [pscustomobject]@{ Name = 'Claude Code'; Path = Join-Path $HOME '.claude\commands';        Suffix = '.md' }
    [pscustomobject]@{ Name = 'Codex CLI';   Path = Join-Path $HOME '.codex\prompts';          Suffix = '.md' }
    [pscustomobject]@{ Name = 'Copilot';     Path = Join-Path $env:APPDATA 'Code\User\prompts'; Suffix = '.prompt.md' }
)

$promptOrphans = @{}
$promptCount   = 0

if (Test-Path $PromptsSource) {
    $promptFiles = Get-ChildItem -Path $PromptsSource -Filter '*.md' -File
    $promptCount = $promptFiles.Count

    if ($promptCount -eq 0) {
        Write-Warning "No .md files found in $PromptsSource - skipping prompts."
    } else {
        $sourceBaseNames = $promptFiles | ForEach-Object { $_.BaseName }

        Write-Host ""
        Write-Host "=== Prompts ===" -ForegroundColor White

        foreach ($target in $PromptTargets) {
            Write-Host "-> $($target.Name): $($target.Path)" -ForegroundColor Cyan
            New-Item -ItemType Directory -Force -Path $target.Path | Out-Null

            foreach ($file in $promptFiles) {
                $destName = $file.BaseName + $target.Suffix
                $destPath = Join-Path $target.Path $destName
                Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
                Write-Host "    $($file.Name)  ->  $destName"
            }

            $existing = Get-ChildItem -Path $target.Path -Filter ('*' + $target.Suffix) -File -ErrorAction SilentlyContinue
            $orphans = foreach ($f in $existing) {
                $stem = $f.Name.Substring(0, $f.Name.Length - $target.Suffix.Length)
                if ($sourceBaseNames -notcontains $stem) { $f.Name }
            }
            if ($orphans) { $promptOrphans[$target.Name] = $orphans }
        }
    }
} else {
    Write-Warning "Prompts folder not found: $PromptsSource - skipping."
}

# ---------- skills ----------

$SkillTargets = @(
    [pscustomobject]@{ Name = 'Claude Code'; Path = Join-Path $HOME '.claude\skills' }
    [pscustomobject]@{ Name = 'Codex CLI';   Path = Join-Path $HOME '.codex\skills'  }
    [pscustomobject]@{ Name = 'Copilot';     Path = Join-Path $HOME '.copilot\skills' }
)

$skillOrphans = @{}
$skillCount   = 0

if (Test-Path $SkillsSource) {
    $skillFolders = Get-ChildItem -Path $SkillsSource -Directory |
                    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
    $skillCount = $skillFolders.Count

    if ($skillCount -eq 0) {
        Write-Warning "No skill folders (containing SKILL.md) found in $SkillsSource - skipping skills."
    } else {
        $sourceSkillNames = $skillFolders | ForEach-Object { $_.Name }

        Write-Host ""
        Write-Host "=== Skills ===" -ForegroundColor White

        foreach ($target in $SkillTargets) {
            Write-Host "-> $($target.Name): $($target.Path)" -ForegroundColor Cyan
            New-Item -ItemType Directory -Force -Path $target.Path | Out-Null

            foreach ($skill in $skillFolders) {
                $destFolder = Join-Path $target.Path $skill.Name
                # Wipe target subfolder before copy so renames/deletions inside the skill propagate.
                if (Test-Path $destFolder) { Remove-Item -Recurse -Force $destFolder }
                Copy-Item -LiteralPath $skill.FullName -Destination $destFolder -Recurse -Force
                Write-Host "    $($skill.Name)/"
            }

            $existing = Get-ChildItem -Path $target.Path -Directory -ErrorAction SilentlyContinue
            $orphans = foreach ($d in $existing) {
                if ($sourceSkillNames -notcontains $d.Name) { $d.Name }
            }
            if ($orphans) { $skillOrphans[$target.Name] = $orphans }
        }
    }
} else {
    Write-Warning "Skills folder not found: $SkillsSource - skipping."
}

# ---------- mcp ----------
#
# User-level MCP servers, mirrored from ~/dotfiles/mcp.json into each agent.
# Canonical shape uses `mcpServers` (matches Claude/Cursor); VS Code key is
# renamed to `servers` on emit; Codex gets [mcp_servers.<name>] TOML blocks
# managed in-place inside ~/.codex/config.toml.
#
# Cursor and Copilot user-level mcp.json files are treated as
# dotfiles-managed (full overwrite). Claude Code and Codex are merged
# carefully because their config files hold unrelated settings.

$McpSource = Join-Path $Root 'mcp.json'
$mcpCount  = 0

if (Test-Path $McpSource) {
    Write-Host ""
    Write-Host "=== MCP servers ===" -ForegroundColor White

    $mcpText = [System.IO.File]::ReadAllText($McpSource)
    $mcp     = $mcpText | ConvertFrom-Json
    $entries = @()
    if ($mcp.PSObject.Properties.Name -contains 'mcpServers') {
        $entries = $mcp.mcpServers.PSObject.Properties
    }
    $mcpCount = @($entries).Count
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false

    # Cursor (user-level, MCP-only file -> overwrite)
    $cursorPath = Join-Path $HOME '.cursor\mcp.json'
    New-Item -ItemType Directory -Force -Path (Split-Path $cursorPath) | Out-Null
    [System.IO.File]::WriteAllText($cursorPath, $mcpText, $utf8NoBom)
    Write-Host "-> Cursor: $cursorPath" -ForegroundColor Cyan
    Write-Host "    wrote $mcpCount entry/entries"

    # VS Code Copilot (user-level) -- rename top-level key
    $vscodePath = Join-Path $env:APPDATA 'Code\User\mcp.json'
    New-Item -ItemType Directory -Force -Path (Split-Path $vscodePath) | Out-Null
    $vscodeText = [regex]::Replace($mcpText, '"mcpServers"\s*:', '"servers":')
    [System.IO.File]::WriteAllText($vscodePath, $vscodeText, $utf8NoBom)
    Write-Host "-> Copilot (VS Code): $vscodePath" -ForegroundColor Cyan
    Write-Host "    wrote $mcpCount entry/entries (key renamed to 'servers')"

    # Claude Code -- use the CLI so we don't touch unrelated settings.
    # Supports both HTTP (`url`) and stdio (`command` + `args`) MCP entries.
    Write-Host "-> Claude Code: via 'claude mcp' CLI (user scope)" -ForegroundColor Cyan
    $claudeCli = Get-Command claude -ErrorAction SilentlyContinue
    $canonicalNames = @($entries | ForEach-Object { $_.Name })
    if (-not $claudeCli) {
        Write-Warning "    'claude' CLI not on PATH; skipping Claude Code MCP install."
    } else {
        foreach ($entry in $entries) {
            $name = $entry.Name
            $cfg  = $entry.Value
            # Idempotent: remove (ignore "not found" on first run) then add.
            # Route through cmd so stderr is discarded by the OS — PS 5.1 wraps
            # native stderr as a terminating error under ErrorActionPreference=Stop.
            & cmd /c "claude mcp remove $name --scope user >nul 2>&1"

            $isHttp = $cfg.PSObject.Properties.Name -contains 'url'
            $isStdio = $cfg.PSObject.Properties.Name -contains 'command'
            if ($isHttp) {
                $url  = $cfg.url
                $type = if ($cfg.PSObject.Properties.Name -contains 'type') { $cfg.type } else { 'http' }
                & claude mcp add --scope user --transport $type $name $url | Out-Null
                $detail = "$url ($type)"
            } elseif ($isStdio) {
                # claude mcp add --scope user <name> -- <command> [args...]
                $command = $cfg.command
                $argList = if ($cfg.PSObject.Properties.Name -contains 'args' -and $cfg.args) {
                    @($cfg.args)
                } else { @() }
                $cliArgs = @('mcp', 'add', '--scope', 'user', $name, '--', $command) + $argList
                & claude @cliArgs | Out-Null
                $detail = "$command $($argList -join ' ') (stdio)"
            } else {
                Write-Warning "    entry '$name' has neither 'url' nor 'command'; skipped."
                continue
            }
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    $name  ->  $detail"
            } else {
                Write-Warning "    failed to add '$name' to Claude Code"
            }
        }
        # Orphan cleanup: read user-scope MCPs straight from ~/.claude.json
        # (claude mcp list shows all scopes/sources; .claude.json mcpServers is
        # the user-scope source of truth) and remove any not in canonical.
        $claudeJsonPath = Join-Path $HOME '.claude.json'
        if (Test-Path $claudeJsonPath) {
            try {
                $claudeJson = Get-Content $claudeJsonPath -Raw | ConvertFrom-Json
                if ($claudeJson.PSObject.Properties.Name -contains 'mcpServers' -and $claudeJson.mcpServers) {
                    $installed = @($claudeJson.mcpServers.PSObject.Properties.Name)
                    $orphans = $installed | Where-Object { $canonicalNames -notcontains $_ }
                    foreach ($orphan in $orphans) {
                        Write-Host "    removing orphan: $orphan" -ForegroundColor DarkYellow
                        & cmd /c "claude mcp remove $orphan --scope user >nul 2>&1"
                    }
                }
            } catch {
                Write-Warning "    could not parse $claudeJsonPath for orphan check; skipped."
            }
        }
    }

    # Codex -- manage [mcp_servers.<name>] blocks in ~/.codex/config.toml
    $codexCfg = Join-Path $HOME '.codex\config.toml'
    New-Item -ItemType Directory -Force -Path (Split-Path $codexCfg) | Out-Null
    if (-not (Test-Path $codexCfg)) {
        [System.IO.File]::WriteAllText($codexCfg, '', $utf8NoBom)
    }
    $codexText = [System.IO.File]::ReadAllText($codexCfg)
    # Orphan cleanup (Codex): scan existing [mcp_servers.<name>] blocks; strip any
    # name not in canonical. Done before re-writing canonical entries so the next
    # loop just adds them back fresh.
    $existingCodex = [regex]::Matches($codexText, '(?ms)^\s*\[mcp_servers\.([^\]]+)\]') |
                     ForEach-Object { $_.Groups[1].Value }
    foreach ($existingName in $existingCodex) {
        if ($canonicalNames -notcontains $existingName) {
            Write-Host "    removing orphan: $existingName" -ForegroundColor DarkYellow
            # Match the section header through to the next line starting with '['
            # (a real TOML section header) or end of string. Avoids false-stopping
            # at '[' characters inside values like `args = ["foo"]`.
            $orphanPattern = "(?ms)^\s*\[mcp_servers\.$([regex]::Escape($existingName))\].*?(?=^\s*\[|\z)"
            $codexText = [regex]::Replace($codexText, $orphanPattern, '')
        }
    }
    foreach ($entry in $entries) {
        $name = $entry.Name
        $cfg  = $entry.Value
        # Build TOML block. HTTP entries use `url = "..."`; stdio entries use
        # `command = "..."` and (optionally) `args = [...]`.
        if ($cfg.PSObject.Properties.Name -contains 'url') {
            $block = "[mcp_servers.$name]`r`nurl = `"$($cfg.url)`"`r`n"
        } elseif ($cfg.PSObject.Properties.Name -contains 'command') {
            $block = "[mcp_servers.$name]`r`ncommand = `"$($cfg.command)`"`r`n"
            if ($cfg.PSObject.Properties.Name -contains 'args' -and $cfg.args) {
                $argParts = @($cfg.args) | ForEach-Object { '"' + ($_ -replace '"','\"') + '"' }
                $block += "args = [" + ($argParts -join ', ') + "]`r`n"
            }
        } else {
            Write-Warning "    entry '$name' has neither 'url' nor 'command'; skipped (Codex)."
            continue
        }
        # Strip any existing block for this name (header line + following lines until next [section] or EOF).
        # Lookahead matches a line starting with '[' so we don't false-stop at '[' inside values like `args = ["foo"]`.
        $pattern = "(?ms)^\s*\[mcp_servers\.$([regex]::Escape($name))\].*?(?=^\s*\[|\z)"
        $codexText = [regex]::Replace($codexText, $pattern, '')
        # Append fresh block, ensuring trailing newline separation.
        if ($codexText.Length -gt 0 -and $codexText[-1] -ne "`n") { $codexText += "`r`n" }
        $codexText += "`r`n" + $block
    }
    # Collapse runs of >2 blank lines for tidiness.
    $codexText = [regex]::Replace($codexText, '(\r?\n){3,}', "`r`n`r`n").TrimStart()
    [System.IO.File]::WriteAllText($codexCfg, $codexText, $utf8NoBom)
    Write-Host "-> Codex: $codexCfg" -ForegroundColor Cyan
    Write-Host "    wrote/updated $mcpCount [mcp_servers.*] block(s)"
}

# ---------- summary ----------

Write-Host ""
Write-Host "Done. $promptCount prompt(s), $skillCount skill(s), $mcpCount MCP server(s) synced." -ForegroundColor Green

if ($promptOrphans.Count -gt 0) {
    Write-Host ""
    Write-Host "Prompt files in target folders NOT overwritten by this run (no matching source in ~/dotfiles/prompts/):" -ForegroundColor DarkYellow
    foreach ($name in $promptOrphans.Keys) {
        Write-Host "  $name :" -ForegroundColor DarkYellow
        foreach ($orphan in $promptOrphans[$name]) {
            Write-Host "    $orphan" -ForegroundColor DarkYellow
        }
    }
}

if ($skillOrphans.Count -gt 0) {
    Write-Host ""
    Write-Host "Skill folders in target locations NOT overwritten by this run (no matching source in ~/dotfiles/skills/):" -ForegroundColor DarkYellow
    foreach ($name in $skillOrphans.Keys) {
        Write-Host "  $name :" -ForegroundColor DarkYellow
        foreach ($orphan in $skillOrphans[$name]) {
            Write-Host "    $orphan/" -ForegroundColor DarkYellow
        }
    }
}

if ($promptOrphans.Count -gt 0 -or $skillOrphans.Count -gt 0) {
    Write-Host ""
    Write-Host "These may be stale (renamed/deleted) or unrelated. Remove manually if needed." -ForegroundColor DarkYellow
}
