<#
.SYNOPSIS
Makes HKCU\Environment match windows/env.psd1 exactly.

.DESCRIPTION
Declared variables are written as REG_EXPAND_SZ, Path as the declared entries
joined in order, and anything undeclared is removed. -Check prints the same
differences without writing and exits 1 when there are any; audit.ps1 runs it.

Runs on Windows PowerShell 5.1 too, so a fresh machine can apply it before
anything else is installed. Kept ASCII-only because 5.1 reads BOM-less files
as ANSI.
#>
param([switch]$Check)
$ErrorActionPreference = 'Stop'

$spec = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'env.psd1')
$want = @{ Path = ($spec.Path -join ';') }
foreach ($name in $spec.Vars.Keys) { $want[$name] = $spec.Vars[$name] }

$key = Get-Item 'HKCU:\Environment'
$have = @{}
foreach ($name in $key.Property) {
  $have[$name] = $key.GetValue($name, $null, 'DoNotExpandEnvironmentNames')
}

$drift = @(
  # Path is diffed by entry; a whole-string diff of 10 entries is unreadable.
  $havePath = @($have['Path'] -split ';' | Where-Object { $_ })
  foreach ($e in $havePath) { if ($spec.Path -notcontains $e) { "path -  $e" } }
  foreach ($e in $spec.Path) { if ($havePath -notcontains $e) { "path +  $e" } }
  if ($have['Path'] -and $have['Path'] -cne $want['Path'] -and
      -not (Compare-Object $havePath $spec.Path)) { 'path    reordered' }

  foreach ($name in ($want.Keys | Where-Object { $_ -ne 'Path' } | Sort-Object)) {
    if (-not $have.ContainsKey($name)) { "set     $name = $($want[$name])" }
    elseif ($have[$name] -cne $want[$name]) {
      "update  $name = $($want[$name])  (was $($have[$name]))"
    }
    elseif ($key.GetValueKind($name) -ne 'ExpandString') { "retype  $name -> REG_EXPAND_SZ" }
  }
  foreach ($name in ($have.Keys | Sort-Object)) {
    if (-not $want.ContainsKey($name)) { "remove  $name  (was $($have[$name]))" }
  }
)

if ($Check -or -not $drift) {
  if ($drift) { $drift } else { 'environment matches env.psd1' }
  exit [int]($drift.Count -gt 0)
}

foreach ($name in $want.Keys) {
  Set-ItemProperty 'HKCU:\Environment' -Name $name -Value $want[$name] -Type ExpandString
}
foreach ($name in $have.Keys) {
  if (-not $want.ContainsKey($name)) { Remove-ItemProperty 'HKCU:\Environment' -Name $name }
}
$drift

# Broadcast WM_SETTINGCHANGE so Explorer hands new processes the new values.
Add-Type -Namespace Win32 -Name Broadcast -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, UIntPtr wParam,
  string lParam, uint flags, uint timeoutMs, out UIntPtr result);
'@
$result = [UIntPtr]::Zero
[void][Win32.Broadcast]::SendMessageTimeout(
  [IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
