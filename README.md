# dotfiles

Personal config for **WSL2 / Linux** (zsh) and **native Windows** (PowerShell
7), plus the agent setup shared by Claude Code and Antigravity. Editor: VS Code.
Languages: Python, C/C++, Rust, and TOML / JSON / YAML / Markdown.

`link.py` symlinks everything into place on Linux, Windows, and Claude Code
cloud sessions from one table. It only links: it never installs anything, and
moves any real file in the way to `<file>.bak-<timestamp>` first.

## Layout

```text
link.py      the link table and the script that applies it
agents/      AGENTS.md and skills: the one copy, at ~/.agents
claude/      Claude Code: CLAUDE.md (imports AGENTS.md), hooks
gemini/      Antigravity hooks; its AGENTS.md and skills link to agents/
vscode/      settings.json (VS Code and Antigravity) and extensions.txt
format/      one global config per formatter, and format-file
git/         git config and global ignore
zsh/         zsh (conf.d/ modules, p10k prompt)
atuin/ bat/  shell history sync; `cat` with syntax highlighting
mise/        every portable dev toolchain and CLI, declared once
windows/     PowerShell profile, starship, winget list, env + drift audit
```

## Bootstrap: WSL / Linux

```bash
git clone https://github.com/arvinduh/dotfiles ~/.dotfiles && cd ~/.dotfiles
sed -e 's/#.*//' -e '/^\s*$/d' packages.txt | xargs sudo apt-get install -y
python3 link.py

# zsh plugins
mkdir -p ~/.local/share/zsh/plugins && cd ~/.local/share/zsh/plugins
git clone --depth=1 https://github.com/Aloxaf/fzf-tab
git clone --depth=1 https://github.com/romkatv/powerlevel10k

# toolchains and formatters
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
~/.cargo/bin/rustup component add rust-analyzer rustfmt clippy
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install ruff basedpyright
npm install -g prettier markdownlint-cli2 @taplo/cli

# shell
chsh -s "$(command -v zsh)" && exec zsh
```

On WSL, `appendWindowsPath = false` under `[interop]` in `/etc/wsl.conf` cuts
shell startup from ~1.6s to ~0.1s.

## Bootstrap: Windows

Turn on **Developer Mode** once (_Settings → System → For developers_) so
symlinks don't need an elevated shell. Then, in PowerShell 7 (`pwsh`):

```powershell
git clone https://github.com/arvinduh/dotfiles $env:USERPROFILE\.dotfiles
cd $env:USERPROFILE\.dotfiles
# Env vars first, so every tool below installs under ~/.local and ~/.cache.
powershell -ExecutionPolicy Bypass -File windows\env.ps1
Get-Content windows\packages.txt | % { ($_ -replace '#.*','').Trim() } | ? { $_ } |
  % { winget install --id $_ --exact --silent --accept-package-agreements --accept-source-agreements }
```

Open a new terminal so the environment applies, then:

```powershell
mise install                  # toolchains, linters, CLIs from mise/config.toml
uv python install 3.14 --default --preview-features python-install-default
foreach ($t in 'ruff', 'basedpyright', 'yamllint', 'git-filter-repo') { uv tool install $t }
rustup default stable-x86_64-pc-windows-gnullvm
rustup component add rust-analyzer rustfmt clippy
Install-Module PSFzf -Scope CurrentUser -Force
python link.py
uv run windows\icons\icons.py apply   # Fluent Color folder icons (icons.toml)
pwsh windows\shortcuts.ps1            # Start Menu entries for portable winget apps
# elevated, in Windows PowerShell 5.1: ads, web search, background use off
powershell -ExecutionPolicy Bypass -File windows\defaults.ps1
pwsh windows\env.ps1          # drop any PATH entries the installers added
```

Ownership: winget holds OS-coupled software and GUI apps (`packages.txt`),
mise every portable toolchain and CLI, uv Python, rustup Rust. Nothing else
installs dev tools.

## Staying clean: Windows

`windows/env.psd1` is the whole user environment, PATH included, and
`windows/env.ps1` makes the registry match it exactly (`-Check` to preview).
`windows/audit.ps1` reports, without changing anything, where the machine has
drifted: environment, Windows default overrides (`windows/defaults.ps1`: ads,
web search, Edge preloading, telemetry level, Recall), winget packages vs
`packages.txt` in both directions, and dead Machine PATH entries.
A weekly task runs it; the profile prints one line when it found something.

```powershell
$audit = New-ScheduledTaskAction -Execute conhost.exe -Argument ((
  '--headless "{0}\Microsoft\WindowsApps\pwsh.exe" -NoProfile -File ' +
  '"{1}\.dotfiles\windows\audit.ps1" -Report "{1}\.local\state\audit.txt"'
) -f $env:LOCALAPPDATA, $env:USERPROFILE)
Register-ScheduledTask dotfiles-audit -Action $audit -Settings (
  New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries
) -Trigger (New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 12pm)
```

To fix drift: install or uninstall to match `packages.txt` (or edit it), re-run
`pwsh windows\env.ps1`, and re-run `windows\defaults.ps1` elevated.

## VS Code

`vscode/settings.json` is linked into both VS Code and Antigravity, so the two
editors share one settings file and edits made in the Settings UI land in this
repo. Turn off Settings Sync for Settings and Extensions so it doesn't fight the
link. Antigravity can't use Microsoft's Settings Sync anyway.

Extensions live in `vscode/extensions.txt`:

```bash
code $(sed 's/^/--install-extension /' vscode/extensions.txt)  # install (bash/zsh)
code --list-extensions > vscode/extensions.txt                # save current set
```

```powershell
code (Get-Content vscode\extensions.txt | % { '--install-extension', $_ })
```

One `code` call installs the whole list; looping launches VS Code's CLI once per
extension, which is slow and prints nothing between installs.

On WSL, VS Code's user settings live on the Windows side, so run `link.py` from
Windows for the editor.

## Formatting

VS Code formats on save. Agents get the same result through a post-edit hook:
Claude Code (`claude/settings.json`) and Antigravity (`gemini/hooks.json`) both
run `format-file` on every file an agent writes or edits. `format-file` picks
the formatter by extension (rustfmt, ruff, clang-format, taplo, prettier, then
markdownlint for Markdown), and every tool reads the global config linked from
`format/`. A missing formatter leaves the file untouched.

## Claude Code cloud sessions

This repository is public so cloud sessions can clone it without credentials.
Each cloud environment's Setup script is:

```bash
git clone -q --depth 1 https://github.com/arvinduh/dotfiles ~/.dotfiles
python3 ~/.dotfiles/link.py --platform cloud
```

`--platform cloud` links only the entries marked `cloud` in `link.py`: the agent
directives and skills, Claude's settings, and the `format-file` and `stop-gate`
hooks. Cloud is Linux, so an entry's `linux` target wins over `home`.

A SessionStart hook in `claude/settings.json` pulls and relinks at the start of
every cloud session; outside the cloud it does nothing.

## Keeping ~ clean

Most clutter is a tool writing its own dot-folder into `~`. In order of
preference:

1. **Uninstall what you don't use.** Through winget, apt, uv or npm, so the
   uninstall is clean.
2. **Redirect it.** Many tools honor an environment variable that moves their
   folder under `~/.config`, `~/.local/share` or `~/.cache`. Linux gets these
   from `zsh/.zshenv`; [xdg-ninja](https://github.com/b3nj5m1n/xdg-ninja) lists
   the variable for hundreds of tools. Windows GUI apps never read a shell
   profile, so set the Windows ones once as user variables:

   ```powershell
   $vars = @{
     IPYTHONDIR   = "$env:APPDATA\ipython"
     MPLCONFIGDIR = "$env:APPDATA\matplotlib"
     KERAS_HOME   = "$env:LOCALAPPDATA\keras"
     LESSHISTFILE = "-"
   }
   $vars.GetEnumerator() | % { [Environment]::SetEnvironmentVariable($_.Key, $_.Value, 'User') }
   ```

3. **Accept it.** Some tools hard-code `~` (`.cargo`, `.rustup`, `.claude`,
   `.gemini`, `.vscode-server`). Those are fine.

Keep scratch files in a temp directory and code in one folder (`~/prj`), never
loose in `~`.

## PATH

PATH is a list of directories searched in order; the first match wins. Clutter
there means dead entries, duplicates, and the wrong version of a tool winning.

**Linux / WSL.** `zsh/.zshenv` is the one place PATH is set, and
`typeset -U path` drops duplicates. Add a directory there, never in a tool's
installer prompt (answer "no" to "modify PATH?", or pass `--no-modify-path`). On
WSL, set this in `/etc/wsl.conf` so the ~40 Windows directories stay out;
`zsh/conf.d/60-wsl.zsh` adds back the few that matter (System32, VS Code):

```ini
[interop]
appendWindowsPath = false
```

Inspect with `print -l $path`; spot dead entries with
`for d in $path; [[ -d $d ]] || echo "missing: $d"`.

**Windows.** PATH is the system list (needs admin) followed by your user list.
Installers append to the user list and rarely clean up. Inspect it with
`$env:Path -split ';'`. To drop dead and duplicate entries from your user list:

```powershell
$keep = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' |
  ? { $_ -and (Test-Path $_) } | Select-Object -Unique
[Environment]::SetEnvironmentVariable('Path', ($keep -join ';'), 'User')
```

Edit the system list by hand (Start → "Edit the system environment variables").
Let winget, `uv tool update-shell` and rustup own their PATH entries rather than
adding them yourself, and never change PATH in `profile.ps1`: it would only
apply inside PowerShell, not to VS Code or other apps.

## Daily

| Action               | Linux / WSL                   | Windows (`pwsh`)           |
| :------------------- | :---------------------------- | :------------------------- |
| Update to newest     | `git pull && python3 link.py` | `git pull; uv run link.py` |
| Preview link changes | `python3 link.py --dry-run`   | `uv run link.py --dry-run` |
