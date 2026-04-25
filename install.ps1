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

# ---------- summary ----------

Write-Host ""
Write-Host "Done. $promptCount prompt(s), $skillCount skill(s) synced." -ForegroundColor Green

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
