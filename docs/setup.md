# Setup

Why this is put together the way it is. To install, see the bootstrap block in
the [README](../README.md); [cheatsheet.md](cheatsheet.md) has the keybinds.

## Tool ownership

The single rule that keeps this from rotting: **every tool owns exactly one
thing, and no two tools own the same thing.** Overlap is what produces the
"why is `python` pointing at the wrong interpreter" class of problem.

| Language | Version | Packages | Format | Lint | LSP |
| --- | --- | --- | --- | --- | --- |
| Python | `uv` | `uv` | `ruff format` | `ruff` | `basedpyright` |
| C++ | system (apt) | `vcpkg` or CMake `FetchContent` | `clang-format` | `clang-tidy` | `clangd` (apt) |
| Rust | `rustup` | `cargo` | `rustfmt` | `clippy` | `rust-analyzer` (rustup) |
| TS/JS | node (apt) | `npm` | `prettier` | `vtsls` | `vtsls` |
| JSON | — | — | `prettier` | — | `jsonls` + SchemaStore |
| Markdown | — | — | `prettier` | `markdownlint-cli2` | `marksman` |
| TOML | — | — | `taplo` | `taplo` | `taplo` |
| YAML | — | — | `prettier` | — | `yamlls` |
| Shell | — | — | `shfmt` | `shellcheck` | — |
| Lua | — | — | `stylua` | — | `lua_ls` |

### There is no version manager

There used to be (mise). It was removed, because after dropping Go and Bun it
was managing exactly one runtime while adding a shim layer, a config file and
an `eval` on every shell start.

Each language already has a blessed answer, and using it directly is fewer
moving parts than a manager wrapping it:

- **Python — `uv`.** It installs interpreters, pins them per-project via
  `.python-version`, and resolves dependencies. A second shim would just fight
  it over `which python`.
- **Rust — `rustup`.** `rust-toolchain.toml` is what the ecosystem and every CI
  already understand. mise's rust backend only wrapped rustup anyway.
- **C++ — apt.** You want the compiler matching your libc and headers.
- **Node — apt.** Pinned per-project only if a project needs it, which is rare
  here. Node is installed for the *editor*: Mason fetches several language
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
  packages into a stdlib venv, which needs the `python3-venv` apt package;
  uv ships its own Python and needs nothing extra. Since uv already owns
  Python here, letting Mason own two Python tools would mean two installers
  for one language. Installing via uv also puts `ruff` on `$PATH`, so
  `ruff check` works in a terminal, not just inside Neovim.

Everything else comes from Mason, which installs into
`~/.local/share/nvim/mason` and is **editor-scoped**: Mason tools are for
Neovim, project tools come from uv/npm/cargo. conform.nvim prefers a
project-local binary when one exists, so a repo pinning `ruff==0.5` gets that
version rather than your global.

## Formatting: one style everywhere

Target: **2-space indent, 80 columns, Google-derived, auto-format on save.**

Almost every modern formatter resolves config by walking **up** parent
directories and stopping at the first one it finds. So configs in `$HOME`
become the fallback for everything under it, while **any repo with its own
config automatically wins**. Your style applies to your code; cloning someone
else's repo silently does the right thing with nothing to toggle.

### Layer 1 — `~/.editorconfig`

The universal baseline. Read natively by **Neovim 0.9+**, `shfmt` and
Prettier 3.

### Layer 2 — per-tool globals

The tools that matter most do not read `.editorconfig`, so each gets a config
carrying the same rules:

| Tool | Global config | Reads `.editorconfig`? |
| --- | --- | --- |
| ruff | `~/.config/ruff/ruff.toml` ¹ | no |
| clang-format | `~/.clang-format` | no |
| rustfmt | `~/.rustfmt.toml` | no |
| stylua | `~/.config/stylua/stylua.toml` ² | no |
| taplo | `~/.taplo.toml` | no |
| markdownlint-cli2 | `~/.markdownlint-cli2.jsonc` | no |
| prettier | `~/.prettierrc` | yes |
| shfmt | — | yes |

¹ Ruff has a genuine user-level config slot rather than a parent-search
accident, and it maps to `%APPDATA%\ruff\ruff.toml` on Windows.
² Requires `--search-parent-directories`, which conform.nvim passes.

### Two conflicts that cannot be solved

These are limitations, not bugs. They are documented here so you do not spend
an evening re-discovering them.

1. **Google's Python style is 4 spaces, not 2.** Google's C++, TypeScript and
   Java guides all say 2; the Python one says 4, matching PEP 8. So "Google
   style, 2 spaces everywhere" is self-contradictory exactly at Python. The
   default here is 2 as configured, with a commented line in `ruff.toml` to
   flip it.
2. **rustfmt comment wrapping is nightly-only.** `max_width` and `tab_spaces`
   are stable and work. `wrap_comments` and `format_strings` are unstable;
   stable rustfmt warns and ignores them. Either accept no comment reflow, or
   uncomment them and run `cargo +nightly fmt`. Neovim's `formatoptions=c`
   still wraps comments as you type either way.

### Prettier formats, markdownlint lints

They are not the same job. **Prettier is a formatter** — it parses to an AST
and reprints it, so it normalises list markers, emphasis, table alignment and
wrapping. It can never *report* a problem: it will not tell you that you
skipped from `##` to `####`, reused a heading, or left a bare URL.
**`markdownlint-cli2`** does that.

They overlap on layout rules, which would produce a fight neither can win, so
`~/.markdownlint-cli2.jsonc` disables the subset Prettier owns (MD013, MD004,
MD007, MD049, MD050 and friends) with a comment on each explaining why.

`proseWrap: "always"` in `~/.prettierrc` is what wraps Markdown prose at 80.

### Escape hatch

`:FormatToggle` disables format-on-save for the buffer, `:FormatToggle!` for
the session. You will need it the first time you open a repo whose style you
must not touch.

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

## How updates flow

Plugin source is **never** in this repo. lazy.nvim clones plugins into
`~/.local/share/nvim/lazy/`, outside `~/.dotfiles`. The only thing that changes
here is `lazy-lock.json`, which pins every plugin to an exact commit.

That separation is why `:Lazy update` cannot clobber your config: your
customisations are `opts` tables in `lua/plugins/*.lua` that lazy merges over
plugin defaults. You never edit plugin source.

| Command | Effect |
| --- | --- |
| `:Lazy update` | pull upstream, **rewrite** `lazy-lock.json` |
| `:Lazy restore` | check out **exactly** the SHAs in `lazy-lock.json` |
| `:Lazy sync` | install missing + clean removed + update |

So: run `:Lazy update` on one machine, commit the lockfile, then on any other
machine `git pull && make link` and `:Lazy restore`. `restore` rather than
`update` on the second machine is what makes both boxes identical instead of
independently drifting.

If you ever need to patch a plugin's source, point its spec at
`dir = "~/code/some-plugin"` for local development, or `url =` at your own
fork. The normal workflow does not change.
