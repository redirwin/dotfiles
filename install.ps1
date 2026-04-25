#Requires -Version 5.1
<#
Personal dotfiles installer (Windows).

Copies ~/dotfiles/prompts/*.md into the three user-scoped tool folders so
generic /my-* commands appear in each agent's slash picker:

  - Claude Code : $HOME\.claude\commands\<name>.md
  - Codex CLI   : $HOME\.codex\prompts\<name>.md
  - Copilot     : $env:APPDATA\Code\User\prompts\<name>.prompt.md

Re-run this script after editing anything in ~/dotfiles/prompts/.

Usage:
  pwsh ~/dotfiles/install.ps1
#>

$ErrorActionPreference = 'Stop'

$Root          = $PSScriptRoot
$PromptsSource = Join-Path $Root 'prompts'

if (-not (Test-Path $PromptsSource)) {
    Write-Error "Source folder not found: $PromptsSource"
    exit 1
}

$Targets = @(
    [pscustomobject]@{ Name = 'Claude Code'; Path = Join-Path $HOME '.claude\commands';        Suffix = '.md' }
    [pscustomobject]@{ Name = 'Codex CLI';   Path = Join-Path $HOME '.codex\prompts';          Suffix = '.md' }
    [pscustomobject]@{ Name = 'Copilot';     Path = Join-Path $env:APPDATA 'Code\User\prompts'; Suffix = '.prompt.md' }
)

$promptFiles = Get-ChildItem -Path $PromptsSource -Filter '*.md' -File
if ($promptFiles.Count -eq 0) {
    Write-Warning "No .md files found in $PromptsSource - nothing to sync."
    exit 0
}

$sourceBaseNames = $promptFiles | ForEach-Object { $_.BaseName }
$orphansByTarget = @{}

foreach ($target in $Targets) {
    Write-Host "-> $($target.Name): $($target.Path)" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $target.Path | Out-Null

    foreach ($file in $promptFiles) {
        $destName = $file.BaseName + $target.Suffix
        $destPath = Join-Path $target.Path $destName
        Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
        Write-Host "    $($file.Name)  ->  $destName"
    }

    # Scan target for files matching the suffix but not present in source.
    $existing = Get-ChildItem -Path $target.Path -Filter ('*' + $target.Suffix) -File -ErrorAction SilentlyContinue
    $orphans = foreach ($f in $existing) {
        # Strip the target suffix to recover a comparable basename.
        $stem = $f.Name.Substring(0, $f.Name.Length - $target.Suffix.Length)
        if ($sourceBaseNames -notcontains $stem) { $f.Name }
    }
    if ($orphans) { $orphansByTarget[$target.Name] = $orphans }
}

Write-Host ""
Write-Host "Done. $($promptFiles.Count) prompt(s) synced to $($Targets.Count) target(s)." -ForegroundColor Green

if ($orphansByTarget.Count -gt 0) {
    Write-Host ""
    Write-Host "Files in target folders NOT overwritten by this run (no matching source in ~/dotfiles/prompts/):" -ForegroundColor DarkYellow
    foreach ($name in $orphansByTarget.Keys) {
        Write-Host "  $name :" -ForegroundColor DarkYellow
        foreach ($orphan in $orphansByTarget[$name]) {
            Write-Host "    $orphan" -ForegroundColor DarkYellow
        }
    }
    Write-Host "These may be stale (renamed/deleted prompts) or unrelated files. Remove manually if needed." -ForegroundColor DarkYellow
}
