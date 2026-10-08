<#
.SYNOPSIS
Reports drift from the declared Windows setup; exits 1 when anything drifted.

.DESCRIPTION
Checks the machine against this repo, report-only (it never changes anything):
  env     HKCU\Environment vs env.psd1 (via env.ps1 -Check)
  home    entries in ~ vs home.txt
  winget  installed packages vs packages.txt, both ways
  path    Machine PATH entries that point nowhere

With -Report, findings are written to that file, and the file is deleted when
clean; the PowerShell profile mentions it at startup. The weekly scheduled task
in README.md runs it that way. ASCII-only so Windows PowerShell 5.1 parses it.
#>
param([string]$Report)

function Read-List([string]$file) {
  Get-Content $file | ForEach-Object { ($_ -replace '#.*', '').Trim() } | Where-Object { $_ }
}

$findings = @(
  & (Join-Path $PSScriptRoot 'env.ps1') -Check | Where-Object { $_ -ne 'environment matches env.psd1' } |
    ForEach-Object { "env     $_" }

  $allowed = @(Read-List (Join-Path $PSScriptRoot 'home.txt'))
  $skip = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
  Get-ChildItem -Force $HOME | Where-Object { -not ($_.Attributes -band $skip) -and $allowed -notcontains $_.Name } |
    ForEach-Object { "home    unexpected ~\$($_.Name)" }

  # `winget export` emits JSON; `winget list` truncates ids to fit the console.
  $declared = @(Read-List (Join-Path $PSScriptRoot 'packages.txt'))
  $export = Join-Path $env:TEMP "winget-audit-$PID.json"
  winget export -o $export --accept-source-agreements --disable-interactivity | Out-Null
  $installed = @((Get-Content $export -Raw | ConvertFrom-Json).Sources.Packages.PackageIdentifier)
  Remove-Item $export
  $installed | Where-Object { $declared -notcontains $_ } | ForEach-Object { "winget  installed, not in packages.txt: $_" }
  $declared | Where-Object { $installed -notcontains $_ } | ForEach-Object { "winget  in packages.txt, not installed: $_" }

  $sysEnv = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
  (Get-Item $sysEnv).GetValue('Path', $null, 'DoNotExpandEnvironmentNames') -split ';' |
    Where-Object { $_ -and -not (Test-Path ([Environment]::ExpandEnvironmentVariables($_))) } |
    ForEach-Object { "path    machine PATH entry points nowhere: $_" }
)

if ($Report) {
  if ($findings) { $findings | Set-Content $Report } else { Remove-Item $Report -ErrorAction SilentlyContinue }
}
if ($findings) { $findings } else { 'no drift' }
exit [int]($findings.Count -gt 0)
