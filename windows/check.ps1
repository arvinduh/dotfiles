#Requires -Version 5.1
<#
.SYNOPSIS
  Run the config test suite. The Windows equivalent of `make check`.

.DESCRIPTION
  A one-line wrapper around the same tests/run.lua that Linux runs, so there is
  a single suite rather than two implementations that drift apart.

  Exits non-zero when a test fails, so it is usable in a pipeline.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
  Write-Host "nvim is not on PATH — see docs/windows.md" -ForegroundColor Red
  exit 1
}

Push-Location $repo
try {
  nvim --headless -c 'luafile tests/run.lua'
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
