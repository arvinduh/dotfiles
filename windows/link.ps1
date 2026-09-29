<#
.SYNOPSIS
    The Windows equivalent of `make link`. Symlinks only.

.DESCRIPTION
    Linux gets its symlinks from one `stow` command, driven by the directory
    layout. Windows has no stow, and its target paths do not mirror the repo
    the way $HOME does, so the map has to be written out. That map — and
    nothing else — is what this script is.

    It does NOT install packages. See the bootstrap block in README.md.

.PARAMETER DryRun
    Print what would happen and change nothing.

.EXAMPLE
    .\windows\link.ps1 -DryRun
    .\windows\link.ps1
#>
[CmdletBinding()]
param([switch]$DryRun)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Docs = [Environment]::GetFolderPath('MyDocuments')

# Windows target  <-  path inside this repo.
#
# Everything under format\ exists because prettier, clang-format and taplo
# find config only by walking UP from the file being formatted, and that walk
# stops at the drive root. A project on C:\code never reaches %USERPROFILE%.
# nvim's format.lua passes these paths explicitly as a fallback, so what is
# linked here is what it points at.
$Map = @(
    # nvim must be a DIRECTORY link: lazy-lock.json is written back into the
    # repo through it, exactly as stow's folding does on Linux.
    @{ Target = "$env:LOCALAPPDATA\nvim"                  ; Source = 'nvim\.config\nvim' }

    @{ Target = "$env:USERPROFILE\.editorconfig"          ; Source = 'format\.editorconfig' }
    @{ Target = "$env:USERPROFILE\.clang-format"          ; Source = 'format\.clang-format' }
    @{ Target = "$env:USERPROFILE\.rustfmt.toml"          ; Source = 'format\.rustfmt.toml' }
    @{ Target = "$env:USERPROFILE\.prettierrc"            ; Source = 'format\.prettierrc' }
    @{ Target = "$env:USERPROFILE\.taplo.toml"            ; Source = 'format\.taplo.toml' }
    @{ Target = "$env:USERPROFILE\.markdownlint-cli2.jsonc"; Source = 'format\.markdownlint-cli2.jsonc' }
    @{ Target = "$env:USERPROFILE\.clippy.toml"           ; Source = 'format\.clippy.toml' }

    # Antigravity agent directives, skills, and lifecycle hooks
    @{ Target = "$env:USERPROFILE\.gemini\config\AGENTS.md" ; Source = 'agents\.gemini\config\AGENTS.md' }
    @{ Target = "$env:USERPROFILE\.gemini\config\skills"   ; Source = 'agents\.gemini\config\skills' }
    @{ Target = "$env:USERPROFILE\.gemini\config\hooks.json"; Source = 'agents\.gemini\config\hooks.json' }

    # Git hooks
    @{ Target = "$env:USERPROFILE\.config\git\hooks\pre-commit"; Source = 'git\.config\git\hooks\pre-commit' }

    # ruff, stylua and bat have real user-level config slots and are immune to
    # the parent-search problem above.
    @{ Target = "$env:APPDATA\ruff\ruff.toml"             ; Source = 'format\.config\ruff\ruff.toml' }
    @{ Target = "$env:APPDATA\stylua\stylua.toml"         ; Source = 'format\.config\stylua\stylua.toml' }
    @{ Target = "$env:APPDATA\bat\config"                 ; Source = 'bat\.config\bat\config' }

    @{ Target = "$env:USERPROFILE\.config\starship.toml"  ; Source = 'windows\starship.toml' }

    # PowerShell 7, not Windows PowerShell. The 5.1 profile lives under
    # Documents\WindowsPowerShell and is deliberately left alone.
    @{ Target = "$Docs\PowerShell\Microsoft.PowerShell_profile.ps1" ; Source = 'windows\profile.ps1' }
)

# --- preflight ---------------------------------------------------------------
# Read the registry and you learn about Developer Mode; run elevated and the
# registry says nothing useful. Probing is the only answer that covers both.
function Test-SymlinkPermission {
    $probe = Join-Path ([IO.Path]::GetTempPath()) ("dotfiles-symlink-probe-" + [guid]::NewGuid())
    try {
        New-Item -ItemType SymbolicLink -Path $probe -Target $PSCommandPath -EA Stop | Out-Null
        Remove-Item $probe -Force -EA SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-SymlinkPermission)) {
    $msg = @(
        ''
        'Cannot create symlinks on this account.'
        ''
        'Fix it either way:'
        '  1. Settings > System > For developers > Developer Mode = On   (once, preferred)'
        '  2. Re-run this script from an elevated PowerShell             (every time)'
        ''
    )
    # -DryRun changes nothing, so it is still worth running to check the map.
    if ($DryRun) {
        $msg | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
        Write-Host 'Continuing anyway: -DryRun writes nothing.' -ForegroundColor Yellow
    } else {
        $msg | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        exit 1
    }
}

# --- link --------------------------------------------------------------------
function Get-LinkTarget {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -EA SilentlyContinue
    if (-not $item -or $item.LinkType -ne 'SymbolicLink') { return $null }
    # 5.1 hands back a string[]; 6+ hands back a string.
    $t = $item.Target
    if ($t -is [array]) { $t = $t[0] }
    return $t
}

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$results = @()
$failed  = 0

foreach ($entry in $Map) {
    $target = $entry.Target
    $source = Join-Path $Repo $entry.Source
    $status = ''
    $note   = ''

    if (-not (Test-Path -LiteralPath $source)) {
        $status = 'MISSING'
        $note   = "no $($entry.Source) in repo"
        $failed++
        $results += [pscustomobject]@{ Status = $status; Link = $target; Note = $note }
        continue
    }

    $existing = Get-LinkTarget -Path $target
    if ($existing -and $existing.TrimEnd('\') -ieq $source.TrimEnd('\')) {
        $results += [pscustomobject]@{ Status = 'ok'; Link = $target; Note = 'already linked' }
        continue
    }

    $action = if ($existing) { 'relink' } elseif (Test-Path -LiteralPath $target) { 'backup' } else { 'create' }

    if ($DryRun) {
        $results += [pscustomobject]@{ Status = "would $action"; Link = $target; Note = "-> $($entry.Source)" }
        continue
    }

    try {
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }

        if ($action -eq 'backup') {
            # A real file, not a link of ours. Never overwrite it.
            $backup = "$target.bak-$stamp"
            Move-Item -LiteralPath $target -Destination $backup -Force
            $note = "saved $(Split-Path -Leaf $backup)"
        } elseif ($action -eq 'relink') {
            Remove-Item -LiteralPath $target -Force -Recurse
            $note = 'replaced stale link'
        }

        New-Item -ItemType SymbolicLink -Path $target -Target $source -Force -EA Stop | Out-Null
        $results += [pscustomobject]@{ Status = 'linked'; Link = $target; Note = $note }
    } catch {
        $failed++
        $results += [pscustomobject]@{ Status = 'FAILED'; Link = $target; Note = $_.Exception.Message }
    }
}

Write-Host ''
if ($DryRun) { Write-Host "DRY RUN - nothing changed. Repo: $Repo" -ForegroundColor Yellow }
else         { Write-Host "Repo: $Repo" }
$results | Format-Table -AutoSize Status, Link, Note

if ($failed) {
    Write-Host "$failed link(s) did not resolve." -ForegroundColor Red
    exit 1
}
