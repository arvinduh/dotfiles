<#
.SYNOPSIS
Overrides Windows defaults: ads, web search, background resource use, leftovers.

.DESCRIPTION
Applies every registry value and app removal in the tables below. -Check
prints what differs from the tables without changing anything and exits 1
when something does; audit.ps1 runs it, because feature updates are known to
switch some of these back on.

Applying needs an elevated Windows PowerShell 5.1 (`powershell`, not `pwsh`):
the HKLM policies need admin, and 5.1's native Appx cmdlets avoid the hang
pwsh 7 hits in its Appx compatibility session. ASCII-only for 5.1's parser.
Sign out afterwards so Start, search and Explorer reload.
#>
param([switch]$Check)
$ErrorActionPreference = 'Stop'

$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
# key, value name, DWORD, why
$values = @(
  , @($cdm, 'SilentInstalledAppsEnabled', 0, 'no silent installs of promoted apps')
  , @($cdm, 'PreInstalledAppsEnabled', 0, 'no promoted apps on new features')
  , @($cdm, 'OemPreInstalledAppsEnabled', 0, 'no OEM promoted apps')
  , @($cdm, 'SubscribedContent-338389Enabled', 0, 'no tips & suggestions notifications')
  , @($cdm, 'SoftLandingEnabled', 0, 'no "tips about Windows"')
  , @($cdm, 'SubscribedContent-310093Enabled', 0, 'no welcome experience after updates')
  , @($cdm, 'SystemPaneSuggestionsEnabled', 0, 'no Start suggestions')
  , @($cdm, 'SubscribedContent-338388Enabled', 0, 'no Start suggestions')
  , @($cdm, 'SubscribedContent-338393Enabled', 0, 'no suggested content in Settings')
  , @($cdm, 'SubscribedContent-353694Enabled', 0, 'no suggested content in Settings')
  , @($cdm, 'SubscribedContent-353696Enabled', 0, 'no suggested content in Settings')
  , @($cdm, 'RotatingLockScreenOverlayEnabled', 0, 'no lock screen fun facts')
  , @('HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', 'ScoobeSystemSettingEnabled', 0, 'no "finish setting up" nags')
  , @('HKCU:\Software\Policies\Microsoft\Windows\Explorer', 'DisableSearchBoxSuggestions', 1, 'no Bing/web results in Start')
  , @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Search', 'BingSearchEnabled', 0, 'no Bing/web results in Start')
  , @('HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings', 'IsDynamicSearchBoxEnabled', 0, 'no search highlights')
  , @('HKLM:\SOFTWARE\Policies\Microsoft\Edge', 'StartupBoostEnabled', 0, 'Edge does not preload at sign-in')
  , @('HKLM:\SOFTWARE\Policies\Microsoft\Edge', 'BackgroundModeEnabled', 0, 'Edge does not run after closing')
  , @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization', 'DODownloadMode', 1, 'update sharing on local network only')
  , @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection', 'AllowTelemetry', 1, 'required diagnostic data only')
  , @('HKCU:\Software\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis', 1, 'Recall snapshots off')
  , @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI', 'DisableAIDataAnalysis', 1, 'Recall snapshots off')
)
$apps = @('Microsoft.StartExperiencesApp')

function Get-Dword([string]$key, [string]$name) {
  $item = Get-ItemProperty -Path $key -Name $name -ErrorAction SilentlyContinue
  if ($item) { $item.$name } else { $null }
}

$drift = @(
  foreach ($v in $values) {
    $now = Get-Dword $v[0] $v[1]
    if ($now -ne $v[2]) { "{0} = {1} (now {2}): {3}" -f $v[1], $v[2], $(if ($null -eq $now) { 'unset' } else { $now }), $v[3] }
  }
  foreach ($a in $apps) { if (Get-AppxPackage $a) { "app $a still installed" } }
)

if ($Check -or -not $drift) {
  if ($drift) { $drift } else { 'defaults match defaults.ps1' }
  exit [int]($drift.Count -gt 0)
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Run elevated: the HKLM policies need admin.' }

foreach ($v in $values) {
  if (-not (Test-Path $v[0])) { New-Item -Path $v[0] -Force | Out-Null }
  Set-ItemProperty -Path $v[0] -Name $v[1] -Value $v[2] -Type DWord
}
foreach ($a in $apps) {
  Get-AppxPackage $a | Remove-AppxPackage
  Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $a |
    Remove-AppxProvisionedPackage -Online | Out-Null
}
$recall = Get-WindowsOptionalFeature -Online -FeatureName Recall -ErrorAction SilentlyContinue
if ($recall -and $recall.State -eq 'Enabled') {
  Disable-WindowsOptionalFeature -Online -FeatureName Recall -NoRestart | Out-Null
  'Recall feature disabled'
}
$drift
"`nDone. Sign out and back in so Start, search and Explorer reload."
