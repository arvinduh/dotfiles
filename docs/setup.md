# Setup

Why this is put together the way it is. To install, see the bootstrap block in
the [README](../README.md); [cheatsheet.md](cheatsheet.md) has the keybinds.

## Tool ownership

The single rule that keeps this from rotting: **every tool owns exactly one
thing, and no two tools own the same thing.** Overlap is what produces the "why
is `python` pointing at the wrong interpreter" class of problem.

| Language | Version      | Packages                        | Format         | Lint                | LSP                      |
| -------- | ------------ | ------------------------------- | -------------- | ------------------- | ------------------------ |
| Python   | `uv`         | `uv`                            | `ruff format`  | `ruff`              | `basedpyright`           |
| C++      | system (apt) | `vcpkg` or CMake `FetchContent` | `clang-format` | `clang-tidy`        | `clangd` (apt)           |
| Rust     | `rustup`     | `cargo`                         | `rustfmt`      | `clippy`            | `rust-analyzer` (rustup) |
| TS/JS    | node (apt)   | `npm`                           | `prettier`     | `vtsls`             | `vtsls`                  |
| JSON     | —            | —                               | `prettier`     | —                   | `jsonls` + SchemaStore   |
| Markdown | —            | —                               | `prettier`     | `markdownlint-cli2` | `marksman`               |
| TOML     | —            | —                               | `taplo`        | `taplo`             | `taplo`                  |
| YAML     | —            | —                               | `prettier`     | —                   | `yamlls`                 |
| Shell    | —            | —                               | `shfmt`        | `shellcheck`        | —                        |
| Lua      | —            | —                               | `stylua`       | —                   | `lua_ls`                 |

### There is no version manager

There used to be (mise). It was removed, because after dropping Go and Bun it
was managing exactly one runtime while adding a shim layer, a config file and an
`eval` on every shell start.

Each language already has a blessed answer, and using it directly is fewer
moving parts than a manager wrapping it:

- **Python — `uv`.** It installs interpreters, pins them per-project via
  `.python-version`, and resolves dependencies. A second shim would just fight
  it over `which python`.
- **Rust — `rustup`.** `rust-toolchain.toml` is what the ecosystem and every CI
  already understand. mise's rust backend only wrapped rustup anyway.
- **C++ — apt.** You want the compiler matching your libc and headers.
- **Node — apt.** Pinned per-project only if a project needs it, which is rare
  here. Node is installed for the _editor_: Mason fetches several language
  servers as npm packages, and prettier is npm too. Without it, format-on-save
  silently does nothing.

If a project ever demands a specific Node, add `mise` back for that project
alone rather than globally.

### Four LSPs come from the system, not Mason

- **`clangd`** — Mason's prebuilt binary links against a different glibc and
  then disagrees with your system headers. For C++ that is fatal. Install from
  apt. Also set `CMAKE_EXPORT_COMPILE_COMMANDS=ON` so it finds
  `compile_commands.json`.
- **`rust-analyzer`** — must match the rustup toolchain or it drifts on edition
  and nightly features. `rustup component add rust-analyzer`.
- **`basedpyright` and `ruff`** — `uv tool install`. Mason installs Python
  packages into a stdlib venv, which needs the `python3-venv` apt package; uv
  ships its own Python and needs nothing extra. Since uv already owns Python
  here, letting Mason own two Python tools would mean two installers for one
  language. Installing via uv also puts `ruff` on `$PATH`, so `ruff check` works
  in a terminal, not just inside Neovim.

Everything else comes from Mason, which installs into
`~/.local/share/nvim/mason` and is **editor-scoped**: Mason tools are for
Neovim, project tools come from uv/npm/cargo. conform.nvim prefers a
project-local binary when one exists, so a repo pinning `ruff==0.5` gets that
version rather than your global.

## Formatting: one style everywhere

Target: **2-space indent, 80 columns, Google-derived, auto-format on save.**

Almost every modern formatter resolves config by walking **up** parent
directories and stopping at the first one it finds. So configs in `$HOME` become
the fallback for everything under it, while **any repo with its own config
automatically wins**. Your style applies to your code; cloning someone else's
repo silently does the right thing with nothing to toggle.

### Layer 1 — `~/.editorconfig`

The universal baseline. Read natively by **Neovim 0.9+**, `shfmt` and
Prettier 3.

### Layer 2 — per-tool globals

The tools that matter most do not read `.editorconfig`, so each gets a config
carrying the same rules. **They do not all find those configs the same way**,
and the difference decides whether your style applies outside `$HOME`. Tested,
not assumed:

| Tool              | Global config                    | How it is found                        | Applies outside `$HOME`?        |
| ----------------- | -------------------------------- | -------------------------------------- | ------------------------------- |
| ruff              | `~/.config/ruff/ruff.toml`       | real user-level config slot            | **yes**                         |
| rustfmt           | `~/.rustfmt.toml`                | parent search, then `$HOME`            | **yes**                         |
| stylua            | `~/.config/stylua/stylua.toml` ¹ | parent search, then `$XDG_CONFIG_HOME` | yes on Linux, **no on Windows** |
| prettier          | `~/.prettierrc`                  | parent search only                     | no                              |
| clang-format      | `~/.clang-format`                | parent search only                     | no                              |
| shfmt             | `~/.editorconfig`                | parent search only                     | no                              |
| taplo             | `~/.taplo.toml`                  | parent search only                     | no                              |
| markdownlint-cli2 | `~/.markdownlint-cli2.jsonc`     | **cwd only — no search at all** ²      | only via `--config`             |

¹ Requires `--search-parent-directories`, which conform.nvim passes. ² See
below. This one silently broke every rule in the file.

Every "no" in that last column is repaired by `global_fallback` in
[format.lua](../nvim/.config/nvim/lua/plugins/format.lua) — see below.

Ruff has a genuine user-level config slot rather than a parent-search accident,
and it maps to `%APPDATA%\ruff\ruff.toml` on Windows.

**stylua is the trap.** Its last-resort lookup is `$XDG_CONFIG_HOME` and _only_
that — it does not fall back to the platform config dir the way most Rust tools
do. Linux sets that variable in `.zshenv`, so `~/.config/stylua` is found;
Windows leaves it unset, and stylua silently reverts to its own default of
**tabs**. Verified 2026-08-27: a config at `%APPDATA%\stylua\stylua.toml` was
ignored until `XDG_CONFIG_HOME` was pointed at `%APPDATA%`. Rather than set a
broad environment variable for one tool, `platform.stylua_config()` names the
path and conform passes `--config-path`.

### The parent-search boundary

Parent search walks **up** from the file and stops at the filesystem root. On
Linux that is invisible, because your code lives under `~/` and the search
passes through `$HOME` on the way. It matters in two places:

- **Anything outside `$HOME`.** A repo at `/srv/thing` or `/tmp` would get
  prettier, clang-format, shfmt and taplo **defaults**, not yours. Verified: the
  same file formatted differently in `~/cfgtest` and `/tmp`.
- **Windows.** A project at `C:\code\thing` walks up to `C:\` and never reaches
  `%USERPROFILE%`.

`global_fallback` in `format.lua` closes both. For each affected tool it looks
for that tool's own project config, walking up from the file; if one exists the
project wins and the tool is left to find it. If none exists, the global path is
passed explicitly with `--config` / `--style=file:` / `--config-path`. So the
rule "any repo with its own config wins, everything else gets your style" holds
at any path on either OS, and you do **not** have to keep Windows projects under
`C:\Users\<you>\`.

Verified 2026-08-27 from `C:\fmttest`, outside `%USERPROFILE%`: `.cpp`, `.lua`,
`.py`, `.md`, `.toml`, `.ts`, `.json` and `.sh` all came back in this repo's
style, and a subdirectory carrying its own `stylua.toml` and `.taplo.toml`
overrode it.

Two things this does not cover: `rustfmt` and `ruff` never needed it (real
user-level config slots), and `shfmt` gets its flags passed outright in
`format.lua` so it behaves the same everywhere by construction.

### taplo needs its flag after the subcommand

`prepend_args` cannot be used for taplo. conform's default invocation is
`taplo format --stdin-filepath $FILENAME -`, and prepending produces
`taplo --config X format ...`, which taplo rejects:

```text
error: unexpected argument '--config' found
  tip: 'format --config' exists
```

`--config` belongs to the `format` subcommand, not to `taplo` itself, so the
whole argument list is replaced rather than prepended. Before this was fixed the
formatter simply exited non-zero and conform left the buffer untouched — TOML
looked like it had no formatter at all.

The mirror-image mistake exists for stylua: conform **already** passes
`--search-parent-directories`, and stylua errors out if it is given twice, so
the fallback must prepend nothing when a project config is present.

### markdownlint-cli2 does not search at all

Unlike every other tool here, markdownlint-cli2 reads its config from the
**current working directory**, not by walking up from the file. So
`~/.markdownlint-cli2.jsonc` was invisible whenever Neovim was started anywhere
else, and every rule disabled in it — `MD013` line-length in particular — came
back. nvim-lint therefore passes `--config` explicitly. A project shipping its
own config still wins, because the per-directory config merges over it.

That file also must not contain a `globs` key. markdownlint-cli2 **appends**
globs to whatever path it is given, so `"globs": ["**/*.md"]` turns "lint this
file" into "lint every markdown file under the cwd" — running it from `$HOME`
started linting `~/.rustup` and `~/projects`.

### Two conflicts that cannot be solved

These are limitations, not bugs. They are documented here so you do not spend an
evening re-discovering them.

1. **Google's Python style is 4 spaces, not 2.** Google's C++, TypeScript and
   Java guides all say 2; the Python one says 4, matching PEP 8. So "Google
   style, 2 spaces everywhere" is self-contradictory exactly at Python. The
   default here is 2 as configured, with a commented line in `ruff.toml` to flip
   it.
2. **rustfmt comment wrapping is nightly-only.** `max_width` and `tab_spaces`
   are stable and work. `wrap_comments` and `format_strings` are unstable;
   stable rustfmt warns and ignores them. Either accept no comment reflow, or
   uncomment them and run `cargo +nightly fmt`. Neovim's `formatoptions=c` still
   wraps comments as you type either way.

### Prettier formats, markdownlint lints

They are not the same job. **Prettier is a formatter** — it parses to an AST and
reprints it, so it normalises list markers, emphasis, table alignment and
wrapping. It can never _report_ a problem: it will not tell you that you skipped
from `##` to `####`, reused a heading, or left a bare URL.
**`markdownlint-cli2`** does that.

They overlap on layout rules, which would produce a fight neither can win, so
`~/.markdownlint-cli2.jsonc` disables the subset Prettier owns (MD013, MD004,
MD007, MD049, MD050 and friends) with a comment on each explaining why.

`proseWrap: "always"` in `~/.prettierrc` is what wraps Markdown prose at 80.

### Escape hatch

`:FormatToggle` disables format-on-save for the buffer, `:FormatToggle!` for the
session. You will need it the first time you open a repo whose style you must
not touch.

## C++ dependencies

Left per-project deliberately. `vcpkg` in manifest mode (a `vcpkg.json` in the
repo) is the usual answer, and CMake `FetchContent` is fine for small things.
Neither is installed globally, because a global C++ package manager tends to
disagree with whatever the project already assumed.

```bash
git clone https://github.com/microsoft/vcpkg ~/.local/share/vcpkg
~/.local/share/vcpkg/bootstrap-vcpkg.sh
# then, per project:
cmake -B build -DCMAKE_TOOLCHAIN_FILE=~/.local/share/vcpkg/scripts/buildsystems/vcpkg.cmake
```

## WSL

Disabling Windows `PATH` injection takes interactive zsh startup from **~1.6 s
to ~0.10 s**. It is the largest single win here: every `/mnt/c` entry on `PATH`
is a 9p round-trip on _every_ command lookup, and Windows `node`/`npm` shadow
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
`/mnt/c/Windows/System32` back explicitly, so `clip.exe` and `explorer.exe` keep
working.

The terminal font is rendered by Windows, not WSL, so install it on the Windows
side or the prompt's glyphs will be broken boxes:

```powershell
winget install DEVCOM.JetBrainsMonoNerdFont
```

## Windows

Native Windows runs the same Neovim config and the same `format/` globals. It
does **not** share a shell, a prompt, or a multiplexer, and it is not supposed
to look like the WSL side.

| Decision                             | Why                                                                                                                                                                                                                                                                                                                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Two checkouts, one repo, git as sync | Pointing Windows at the WSL checkout through `\\wsl$` means 9p — the same protocol whose `PATH` cost is documented under [WSL](#wsl). Neovim reading its config and 20+ plugins over it on every launch would reintroduce exactly that                                                                                                                        |
| PowerShell 7, not 5.1                | `$ErrorView` defaults to `ConciseView` (5.1 spends six lines saying a file does not exist), and PSReadLine is new enough for `PredictiveIntelliSense`. The 7.x profile is a different file from the 5.1 one, so installing it retires the old profile with nothing to migrate                                                                                 |
| starship, not oh-my-posh             | oh-my-posh's value is its theme library and Windows segments, which is what a minimal prompt does not need. Neither matches p10k, which runs in-process with a `gitstatusd` daemon; both spawn a process per render                                                                                                                                           |
| The prompt is not shared             | p10k is zsh-only. `windows/starship.toml` is deliberately a single line with no OS icon and no right prompt, so the two machines are not mistakable                                                                                                                                                                                                           |
| PowerShell stays PowerShell          | PSReadLine and PSFzf, not a zsh port                                                                                                                                                                                                                                                                                                                          |
| No tmux                              | No usable native port. Windows Terminal has panes (`Alt+Shift+D`)                                                                                                                                                                                                                                                                                             |
| No auto-venv                         | The old 5.1 profile shadowed `Set-Location`/`Push-Location`/`Pop-Location` to activate one. That was for pip; `uv run` resolves the project venv with no activation, and `uv run --with <pkg>` covers ad-hoc use. If it is ever wanted back, the supported hook is `$ExecutionContext.SessionState.InvokeCommand.LocationChangedAction`, not cmdlet shadowing |

`windows/link.ps1` is the Windows `make link`: symlinks only, idempotent, with a
`-DryRun` switch. It is a written-out map rather than a layout convention
because Windows targets are scattered across `%APPDATA%`, `%LOCALAPPDATA%`,
`%USERPROFILE%` and `Documents` instead of all living under `$HOME`. `windows/`
is excluded from stow in the `Makefile` for the same reason.

Windows does not grant symlink permission by default. Turn on **Developer
Mode**, or run the script elevated every time; `link.ps1` probes for the
capability up front and names both fixes rather than failing halfway through the
map.

### Both machines must run the same Neovim

`lazy-lock.json` pins every plugin to an exact commit — but a pinned plugin only
behaves identically if the **host Neovim** matches too, and winget will happily
install a newer one than apt ships.

This is not theoretical. Windows on 0.12.5 against WSL's 0.11.6 produced:

```text
Error in BufWinEnter Autocommands for "*":
  .../runtime/lua/vim/treesitter.lua:197: attempt to call method 'range' (a nil value)
```

`nvim-treesitter` is pinned to its `master` branch, which targets 0.11 and
below; 0.12 changed treesitter internals its query predicates call into. The
failure only surfaces once something parses a markdown injection — markview, in
that case — so it reads as a markview bug and is not one.

Install the matching version explicitly rather than letting winget pick:

```powershell
winget install --id Neovim.Neovim --version 0.11.6 --exact --uninstall-previous
```

`make check` and `windows\check.ps1` assert the version, so a mismatch fails
with a plain message instead of a traceback three files deep. Moving both
machines to 0.12 later means moving `nvim-treesitter` to its `main` branch at
the same time, and updating the version in `tests/run.lua` and
`windows/packages.txt` with it.

### Startup cost

Measured 2026-08-27, average of five cold `pwsh` launches: **~0.45s** bare,
**~1.75s** with this profile, so the profile itself costs **~1.3s**. The WSL
side starts zsh in ~0.10s. They are not comparable and will not become so.

Most of it — ~0.8s — is `starship init`. The line is cheap to _run_; it is
expensive to _compile_. starship emits a bootstrap that re-runs starship to
print a 207-line script, and PowerShell parses that script on every launch. Two
fixes were measured and rejected: calling `--print-full-init` directly to skip
the second process saved ~7ms (the spawn was never the cost), and caching the
generated script to a file saved ~140ms while adding a staleness failure mode
the rest of this repo exists to avoid.

`Terminal-Icons` was dropped rather than kept. On its own it measured **~1.0s**
— more than everything else in the profile combined — to put glyphs on
`Get-ChildItem` output, which `eza` already does natively and faster. Removing
it took the profile from ~2.0s to ~1.3s. Keeping both would also have meant two
owners for one job.

The prompt then costs ~250ms per render inside a git repo and ~50ms outside one,
most of it process startup rather than anything starship does. p10k avoids this
by running in-process with a `gitstatusd` daemon; no PowerShell prompt does.

### LLVM on Windows is not a C compiler

`LLVM.LLVM` is installed for `clangd` and `clang-format`, and it is tempting to
assume it also covers the C compiler treesitter needs to build its parsers. It
does not. The standalone Windows LLVM distribution ships **no C runtime
headers**, so compiling a parser dies immediately:

```text
tree_sitter/parser.h:10:10: fatal error: 'stdlib.h' file not found
```

It needs a Windows SDK or a MinGW toolchain beside it before it is a compiler at
all. `MartinStorsjo.LLVM-MinGW.UCRT` supplies the headers, and its `gcc` builds
parsers unmodified.

This matters more than it looks, because `nvim-treesitter` selects the first
compiler on its list that **exists**, not the first that works. Leaving `clang`
first meant it was chosen every time and every parser failed — with the failure
invisible under `--headless`, presenting as "the downloads keep restarting".
`platform.ts_compilers()` therefore puts `clang` **last** on Windows.

Note this is about compiling treesitter parsers, not about writing C++. Native
Windows C/C++ work still wants the MSVC C++ workload and a Windows SDK; the WSL
side is where that toolchain already exists.

### Line endings

Git for Windows ships `core.autocrlf=true`, which wants CRLF in the working
tree. Neovim writes `lazy-lock.json` with LF, so every launch left that file
showing as modified with an **empty** content diff — and `lazy-lock.json` is
precisely the file both machines must agree on. `.gitattributes` pins
`* text=auto eol=lf`, which settles it; nothing here needs CRLF, and PowerShell
reads LF scripts fine.

## How updates flow

Plugin source is **never** in this repo. lazy.nvim clones plugins into
`~/.local/share/nvim/lazy/`, outside `~/.dotfiles`. The only thing that changes
here is `lazy-lock.json`, which pins every plugin to an exact commit.

That separation is why `:Lazy update` cannot clobber your config: your
customisations are `opts` tables in `lua/plugins/*.lua` that lazy merges over
plugin defaults. You never edit plugin source.

| Command         | Effect                                             |
| --------------- | -------------------------------------------------- |
| `:Lazy update`  | pull upstream, **rewrite** `lazy-lock.json`        |
| `:Lazy restore` | check out **exactly** the SHAs in `lazy-lock.json` |
| `:Lazy sync`    | install missing + clean removed + update           |

So: run `:Lazy update` on one machine, commit the lockfile, then on any other
machine `git pull && make link` and `:Lazy restore`. `restore` rather than
`update` on the second machine is what makes both boxes identical instead of
independently drifting. On Windows that is `git pull`, `.\windows\link.ps1`,
`:Lazy restore`.

A fresh checkout is the one case that needs care: bootstrapping clones lazy.nvim
from its `stable` branch, which is usually **ahead** of the pinned SHA, so a
first `:Lazy install` rewrites lazy.nvim's own line in the lockfile. Revert the
file and run `:Lazy restore` — do not commit that bump from the machine you are
setting up.

Mason binaries are platform-specific and live in `nvim-data/mason`, outside this
repo, so each machine fetches its own and they cannot conflict. Treesitter
parsers are compiled locally too; Windows has no `cc` by default, which is why
`platform.ts_compilers()` puts `clang` first and `packages.txt` installs LLVM.

If you ever need to patch a plugin's source, point its spec at
`dir = "~/code/some-plugin"` for local development, or `url =` at your own fork.
The normal workflow does not change.
