# dotfiles

Personal dotfiles for **WSL2 / Linux** (zsh + Neovim) and **native Windows**
(PowerShell 7 + Neovim).

Both environments share this repository, the Neovim configuration, and global
code formatting rules, syncing across machines via git. Symlinks are managed by
GNU Stow on Linux and `link.ps1` on Windows.

---

## Bootstrap (WSL / Linux)

```bash
git clone https://github.com/arvinduh/dotfiles ~/.dotfiles
cd ~/.dotfiles
make packages
make link
```

```bash
# zsh plugins
mkdir -p ~/.local/share/zsh/plugins
git clone --depth=1 https://github.com/Aloxaf/fzf-tab ~/.local/share/zsh/plugins/fzf-tab
git clone --depth=1 https://github.com/romkatv/powerlevel10k ~/.local/share/zsh/plugins/powerlevel10k

# toolchains & CLI utilities
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
~/.cargo/bin/rustup component add rust-analyzer rustfmt clippy
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install ruff basedpyright
curl -sL https://github.com/boyter/scc/releases/latest/download/scc_Linux_x86_64.tar.gz | tar -xz -C ~/.local/bin scc

# identity & default shell
git config --file ~/.config/git/local user.name  "Your Name"
git config --file ~/.config/git/local user.email "you@example.com"
chsh -s "$(command -v zsh)"
exec zsh
```

> **WSL Tip**: Disable Windows `PATH` injection in `/etc/wsl.conf` to drop shell
> startup from ~1.6s to ~0.10s. See [docs/setup.md#wsl](docs/setup.md#wsl).
>
> On first start, open `nvim` and allow Lazy, Mason, and treesitter to finish
> installing.

---

## Bootstrap (native Windows)

1. Turn on **Developer Mode** once (_Settings → System → For developers_) to
   allow unprivileged symlinks.
2. If running Windows PowerShell 5.1, install PowerShell 7:
   ```powershell
   winget install --id Microsoft.PowerShell --exact
   ```
3. Open a **PowerShell 7 (`pwsh`)** console:
   ```powershell
   git clone https://github.com/arvinduh/dotfiles $env:USERPROFILE\.dotfiles
   cd $env:USERPROFILE\.dotfiles

   # Install packages
   Get-Content windows\packages.txt |
     ForEach-Object { ($_ -replace '#.*','').Trim() } | Where-Object { $_ } |
     ForEach-Object { winget install --id $_ --exact --silent --accept-package-agreements --accept-source-agreements }

   # Modules and language tools
   Install-Module PSFzf -Scope CurrentUser -Force
   uv tool install ruff basedpyright
   uv tool update-shell
   rustup component add rust-analyzer rustfmt clippy

   # Symlink configs
   .\windows\link.ps1
   ```
4. Reopen the terminal so `PATH` refreshes, then run `nvim` once until Mason and
   treesitter parsers complete.

---

## Daily

| Action                        | Linux / WSL     | Windows (`pwsh`)             |
| :---------------------------- | :-------------- | :--------------------------- |
| **Apply / refresh symlinks**  | `make link`     | `.\windows\link.ps1`         |
| **Run config test suite**     | `make check`    | `.\windows\check.ps1`        |
| **Check links / diagnostics** | `make doctor`   | `.\windows\link.ps1 -DryRun` |
| **Install new packages**      | `make packages` | Re-run package loop          |
| **Code line count**           | `make audit`    | `scc`                        |

---

## Layout

```text
agents/      Antigravity directives (AGENTS.md), skills, and lifecycle hooks
atuin/       Shell history sync config
bat/         bat syntax-highlighting pager config
docs/        Design rationale (setup.md) and keybindings (cheatsheet.md)
format/      Universal formatters (clang-format, prettier, ruff, rustfmt, taplo)
git/         Git config, delta diff pager, global pre-commit formatting hook
nvim/        Shared Neovim config (Lazy, Treesitter, LSP, Conform)
scc/         Source code counter config
tests/       Cross-platform headless Neovim test suite (run.lua)
tmux/        Terminal multiplexer config
wget/        wget cache redirect
windows/     Native Windows configs (profile.ps1, starship.toml, link.ps1, check.ps1)
zsh/         zsh environment (modular conf.d, p10k prompt)
```

---

## Documentation

- [docs/setup.md](docs/setup.md) — Architecture decisions, tool ownership,
  formatting fallback logic, and WSL tuning.
- [docs/cheatsheet.md](docs/cheatsheet.md) — Memorized keybindings and daily
  shortcuts.
