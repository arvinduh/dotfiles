<#
.SYNOPSIS
Creates Start Menu shortcuts for portable winget apps, which winget leaves out.

.DESCRIPTION
winget unpacks portable apps into a versioned folder under
%LOCALAPPDATA%\Microsoft\WinGet\Packages and adds no Start Menu entry. This
points each shortcut at the newest installed version, and refreshes a
same-named taskbar pin if there is one, so re-run it after `winget upgrade`.
Windows offers scripts no way to pin; pin once by hand from Start.
#>
$apps = @(
  @{ Name = 'OpenTabletDriver'; Package = 'OpenTabletDriver.OpenTabletDriver'; Exe = 'OpenTabletDriver.UX.Wpf.exe' }
)
$shell = New-Object -ComObject WScript.Shell
$programs = [Environment]::GetFolderPath('Programs')
$pinned = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"

foreach ($a in $apps) {
  $root = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Directory -Filter "$($a.Package)_*" |
    Select-Object -First 1
  $exe = if ($root) {
    Get-ChildItem $root.FullName -Recurse -Filter $a.Exe -ErrorAction SilentlyContinue |
      Sort-Object { $_.VersionInfo.FileVersionRaw } -Descending | Select-Object -First 1
  }
  if (-not $exe) { "skip     $($a.Name): not installed"; continue }
  foreach ($path in (Join-Path $programs "$($a.Name).lnk"), (Join-Path $pinned "$($a.Name).lnk")) {
    if ($path.StartsWith($pinned) -and -not (Test-Path $path)) { continue }  # only refresh existing pins
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = $exe.FullName
    $lnk.WorkingDirectory = $exe.DirectoryName
    $lnk.Save()
    "shortcut $path -> $($exe.FullName)"
  }
}
