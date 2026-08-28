# dotfiles

A zsh + Neovim environment for WSL2, built to be rebuilt from scratch by
reading one page.

There is no install script. Symlinking is a single `stow` command, and
bootstrapping a fresh machine happens about once a year — a script that runs
that rarely is a script whose bugs you meet at the worst possible moment. The
block below is the installer.

## Bootstrap

```bash
git clone https://github.com/arvinduh/dotfiles ~/.dotfiles
cd ~/.dotfiles
make packages
make link
```

```bash
mkdir -p ~/.local/share/zsh/plugins
git clone --depth=1 https://github.com/Aloxaf/fzf-tab ~/.local/share/zsh/plugins/fzf-tab
git clone --depth=1 https://github.com/romkatv/powerlevel10k ~/.local/share/zsh/plugins/powerlevel10k
```

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
~/.cargo/bin/rustup component add rust-analyzer rustfmt clippy
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install ruff
uv tool install basedpyright
curl -sL https://github.com/boyter/scc/releases/latest/download/scc_Linux_x86_64.tar.gz \
  | tar -xz -C ~/.local/bin scc
```

```bash
git config --file ~/.config/git/local user.name  "Your Name"
git config --file ~/.config/git/local user.email "you@example.com"
chsh -s "$(command -v zsh)"
exec zsh
```

On first launch `p10k configure` runs its wizard and writes
`~/.config/zsh/.p10k.zsh` — that file is committed, so every machine gets the
same prompt. Neovim installs its own plugins and language servers the first
time you open a file.

## Daily

```bash
make link       # re-link after adding or moving a config
make packages   # install anything new in packages.txt
make doctor     # dangling links, missing commands, startup time
make audit      # line counts by language
```

Moving between versions is `git pull && make link`. `--restow` unlinks and
relinks, so renames and moves reconcile on their own; `make doctor` reports
any symlink left pointing at a file that no longer exists.

## What installs what

Every tool has exactly one owner. Nothing is installed by two things.

| Owner | Installs |
| --- | --- |
| **apt** (`packages.txt`) | zsh, neovim, tmux, git, the clang toolchain, node + npm, and the CLI tools |
| **stow** (`make link`) | every symlink into `$HOME` |
| **git clone** | the two zsh plugins apt does not carry: fzf-tab, powerlevel10k |
| **rustup** | rust, cargo, rust-analyzer, rustfmt, clippy |
| **uv** | python interpreters, per-project dependencies, and the two python tools: `ruff` and `basedpyright` |
| **lazy.nvim** | Neovim plugins, pinned by `lazy-lock.json` |
| **Mason** | language servers with no distro packaging — lua_ls, vtsls, jsonls, yamlls, taplo, marksman — plus prettier, stylua, markdownlint-cli2 |

Four servers deliberately do **not** come from Mason, each supplied by whatever
already owns that language: `clangd` (apt) because Mason's build disagrees with
your system headers, `rust-analyzer` (rustup) because it must match the
toolchain, and `ruff` + `basedpyright` (uv) because Mason would build them in a
stdlib venv needing `python3-venv`, while uv brings its own Python. That also
puts `ruff` on `$PATH`, so it works in the shell and not only in the editor.

Node is here for the editor, not for writing JavaScript: Mason installs several
servers as npm packages, and prettier is npm too. Without it, format-on-save
silently does nothing.

## Design rules

1. **Use the distribution first.** Ubuntu 26.04 ships current ripgrep, fd, bat,
   eza, zoxide, fzf, delta, atuin, lazygit and Neovim. Third-party installers
   are used only for what apt genuinely lacks: rustup, uv, and two zsh plugins.
2. **One file in `$HOME`.** `.zshenv` sets `ZDOTDIR` and the XDG variables;
   everything else lives under `~/.config`.
3. **No plugin manager for zsh.** Two `git clone`s and two `source` lines.
4. **Every tool owns exactly one thing.** Overlapping tools are why these
   setups rot. One formatter per language, one installer per tool.
5. **The directory layout is the manifest.** A stow package is a directory
   mirroring its target path. Adding one requires editing nothing.

## Languages

Rust, C/C++, Python, TypeScript, and Markdown — with Lua, TOML, JSON, YAML and
shell along for the ride because the config itself is written in them. One
formatter each, configured globally in `format/` and overridden automatically
by any project that ships its own config.

## Layout

```
Makefile        link, unlink, packages, doctor
packages.txt    the apt list
zsh/ nvim/ tmux/ git/ bat/ atuin/ format/ scc/
                stow packages — each mirrors its target directory structure
docs/           the decisions and the keybinds worth memorising
```

## WSL

Disabling Windows `PATH` injection takes interactive zsh startup from **~1.6 s
to ~0.10 s**. It is the largest single win here: every `/mnt/c` entry on `PATH`
is a 9p round-trip on *every* command lookup, and Windows `node`/`npm` shadow
the Linux ones — so `npm install` silently runs the Windows binary against your
Linux files.

```bash
sudo tee -a /etc/wsl.conf >/dev/null <<'WSLCONF'

[interop]
enabled = true
appendWindowsPath = false
WSLCONF
```

Then `wsl --shutdown` from PowerShell. Interop still works — `60-wsl.zsh` adds
`/mnt/c/Windows/System32` back explicitly, so `clip.exe` and `explorer.exe`
keep working.

The terminal font is rendered by Windows, not WSL, so install it on the
Windows side or the prompt's glyphs will be broken boxes:

```powershell
winget install DEVCOM.JetBrainsMonoNerdFont
```

## Docs

- [docs/setup.md](docs/setup.md) — the decisions and why they were made
- [docs/cheatsheet.md](docs/cheatsheet.md) — keybinds worth memorising
