# Cheatsheet

## Shell

| Key             | Does                                                    |
| --------------- | ------------------------------------------------------- |
| `Ctrl-R`        | history search (atuin)                                  |
| `Ctrl-T`        | fuzzy-find a file, insert its path                      |
| `Alt-C`         | fuzzy-find a directory and cd into it                   |
| `Tab`           | completion, as an fzf picker with previews              |
| `Ctrl-Space`    | accept the whole autosuggestion                         |
| `Alt-F`         | accept **one word** of the autosuggestion               |
| `Ctrl-X Ctrl-E` | edit the current command line in nvim                   |
| `Esc Esc`       | toggle `sudo` on the current line                       |
| `Ctrl-W`        | delete one path segment (not the whole path)            |
| `↑` / `↓`       | history search using what you already typed as a prefix |

`cd` is zoxide: `cd foo` jumps to the most frecent match, and real paths still
work exactly as before.

## dotfiles

Run from `~/.dotfiles`.

| Command                 | Does                                               |
| ----------------------- | -------------------------------------------------- |
| `make link`             | re-link every config into `$HOME` (idempotent)     |
| `make packages`         | install anything new in `packages.txt`             |
| `make doctor`           | dangling links, missing commands, zsh startup time |
| `git pull && make link` | move this machine to the newest config             |

## tmux

Prefix is `Ctrl-A`.

| Key         | Does                                          |
| ----------- | --------------------------------------------- |
| `\|` / `-`  | split right / below, in the current directory |
| `h j k l`   | move between panes                            |
| `H J K L`   | resize (repeatable)                           |
| `Alt-arrow` | move between panes, **no prefix**             |
| `c`         | new window                                    |
| `Tab`       | last window                                   |
| `s`         | session picker                                |
| `Enter`     | copy mode — then `v` select, `y` yank         |
| `r`         | reload config                                 |

## Neovim

Leader is `Space`.

### Find

| Key               | Does                           |
| ----------------- | ------------------------------ |
| `<leader><space>` | find files                     |
| `<leader>fg`      | live grep                      |
| `<leader>fw`      | grep the word under the cursor |
| `<leader>fb`      | buffers                        |
| `<leader>fr`      | recent files                   |
| `<leader>f/`      | search in the current buffer   |
| `<leader>fR`      | resume the last picker         |

### LSP

| Key                 | Does                                                |
| ------------------- | --------------------------------------------------- |
| `gd` `gr` `gI` `gy` | definitions, references, implementations, type defs |
| `K`                 | hover                                               |
| `<leader>cr`        | rename                                              |
| `<leader>ca`        | code action                                         |
| `<leader>cf`        | format buffer                                       |
| `<leader>ch`        | toggle inlay hints                                  |
| `[d` `]d`           | previous / next diagnostic                          |

### Git

| Key          | Does                                |
| ------------ | ----------------------------------- |
| `[h` `]h`    | previous / next hunk                |
| `<leader>gs` | stage hunk (or selection in visual) |
| `<leader>gr` | reset hunk                          |
| `<leader>gp` | preview hunk inline                 |
| `<leader>gb` | toggle line blame                   |

### Editing

| Key                       | Does                                              |
| ------------------------- | ------------------------------------------------- |
| `-`                       | open the parent directory in oil                  |
| `s`                       | flash jump — two characters to anywhere on screen |
| `gcc` / `gc`              | comment line / selection                          |
| `saiw)`                   | surround inner word with parens                   |
| `sd"`                     | delete surrounding quotes                         |
| `<leader>y` / `<leader>p` | system clipboard yank / paste                     |
| `<C-space>`               | expand treesitter selection                       |
| `J` / `K` in visual       | move the selection up / down                      |

### Escape hatches

| Command          | Does                                    |
| ---------------- | --------------------------------------- |
| `:FormatToggle`  | format-on-save off for this buffer      |
| `:FormatToggle!` | format-on-save off globally             |
| `<leader>?`      | which-key: every keymap for this buffer |
| `:Lazy`          | plugin manager UI                       |
| `:Mason`         | LSP/tool installer UI                   |
| `:checkhealth`   | diagnose a broken setup                 |

In oil (`-`): edit the buffer like text — `cw` renames, `dd` deletes, a new line
creates a file — then `:w` commits it to disk.
