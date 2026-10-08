# PowerShell 7 profile. Linked to Documents\PowerShell\Microsoft.PowerShell_profile.ps1.
#
# The Windows PowerShell 5.1 profile lives under Documents\WindowsPowerShell
# and is a DIFFERENT file. Installing PS7 made it inert on its own; it is left
# alone rather than migrated.
#
# This is PowerShell, not a zsh port. The zsh side gets its behaviour from
# plugins; here it comes from PSReadLine, one module, and starship. Nothing
# below defines a `prompt` function — starship owns it, and a second one would
# silently win or lose depending on load order.
#
# Cost: ~1.3s, of which ~0.8s is PowerShell compiling starship's 207-line init
# script. See docs/setup.md before adding anything here.

# --- prompt ------------------------------------------------------------------
Invoke-Expression (&starship init powershell)

# Collapse the finished prompt to a bare `>` once a command runs, so scrollback
# is output rather than a column of repeated paths. p10k does this on WSL.
Enable-TransientPrompt

# --- line editing -------------------------------------------------------------
# HistoryAndPlugin, not History: it also takes suggestions from modules that
# register a predictor. ListView shows them as a dropdown rather than a single
# ghosted line — closer to zsh-autosuggestions plus fzf-tab than InlineView is.
#
# The try/catch is not defensive padding. Setting PredictionSource THROWS a
# terminating error when the console does not support virtual terminal
# processing or stdout is redirected — `pwsh -c ...` from a script, a build
# step, an editor's task runner. Without the guard the profile dies right here
# and everything below it, zoxide included, silently never loads.
if ($Host.Name -eq 'ConsoleHost') {
    try {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    } catch {
        # Not a console that can render predictions. Editing still works.
    }
}
Set-PSReadLineOption -EditMode Windows

# --- modules ------------------------------------------------------------------
# Terminal-Icons is deliberately NOT imported. Measured on this machine it cost
# ~1.0s on its own — more than starship, and more than everything else here
# combined — to put glyphs on `Get-ChildItem` output. Dropping it took the
# profile from ~2.0s to ~1.3s. `eza` already does that natively and faster, and
# eza is what owns directory listing on the Linux side, so importing it here
# would also have meant two owners for one job.

# ^t files, ^r history — the same two chords zsh binds through fzf.
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# --- cd -----------------------------------------------------------------------
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# --- drift --------------------------------------------------------------------
# The weekly audit task (windows/audit.ps1) leaves this file only when the
# machine drifted from the dotfiles. One Test-Path costs nothing at startup.
if (Test-Path "$HOME\.local\state\audit.txt") {
  Write-Host 'drift since last audit: Get-Content ~\.local\state\audit.txt' -ForegroundColor Yellow
}

# No auto-venv. The old 5.1 profile shadowed Set-Location/Push-Location/
# Pop-Location to activate one; that was for pip. `uv run` resolves the project
# venv with no activation at all, and `uv run --with <pkg>` covers ad-hoc use.
# If it is ever wanted back, the supported hook is
# $ExecutionContext.SessionState.InvokeCommand.LocationChangedAction — do not
# go back to shadowing cmdlets.
