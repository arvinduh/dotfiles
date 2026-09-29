# WSL-specific glue. No-op on native Linux.

if [[ -n "$WSL_DISTRO_NAME" ]] || grep -qi microsoft /proc/version 2>/dev/null; then

  # /etc/wsl.conf sets appendWindowsPath=false (see scripts/wsl-path-fix.sh),
  # which removes ~40 slow /mnt/c PATH entries and stops Windows node/python
  # from shadowing the Linux ones. Add back only what is genuinely useful.
  _win32="/mnt/c/Windows/System32"
  [[ -d "$_win32" ]] && path+=("$_win32")
  unset _win32

  # Clipboard. `pbcopy`/`pbpaste` names so the same muscle memory works here.
  if (($ + commands[clip.exe])); then
    alias pbcopy='clip.exe'
    alias pbpaste='powershell.exe -NoProfile -Command Get-Clipboard | tr -d "\r"'
  fi

  # Open a path or URL with the Windows default handler.
  if (($ + commands[wslview])); then
    alias open='wslview'
  elif (($ + commands[explorer.exe])); then
    open() { explorer.exe "$(wslpath -w "${1:-.}")"; }
  fi

  # Jump to the Windows home directory.
  if (($ + commands[powershell.exe])); then
    export WINHOME="$(wslpath "$(powershell.exe -NoProfile -Command '$env:USERPROFILE' 2>/dev/null | tr -d '\r')" 2>/dev/null)"
    [[ -d "$WINHOME" ]] && alias cdwin='cd "$WINHOME"' || unset WINHOME
  fi

  # Warn when working inside /mnt/c — the 9p bridge makes git and builds
  # 10-50x slower there. Keep repos on the Linux filesystem.
  _wsl_slowfs_warn() {
    if [[ "$PWD" == /mnt/[a-z]/* ]]; then
      print -P "%F{yellow}wsl:%f on a Windows mount — expect slow I/O. Prefer ~/ for repos."
    fi
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _wsl_slowfs_warn
fi
