# ~/.zshenv — the ONLY dotfile this setup puts in $HOME.
# Sourced by every zsh (interactive, non-interactive, scripts). Keep it cheap.

# ---- XDG base directories ---------------------------------------------------
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Everything zsh writes now lives under XDG instead of littering $HOME.
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

export DOTFILES="${DOTFILES:-$HOME/.dotfiles}"

# ---- PATH -------------------------------------------------------------------
# typeset -U dedupes; $path and $PATH stay mirrored automatically.
typeset -U path PATH
path=(
  "$HOME/.local/bin"        # uv, uv tool installs, scc, misc user binaries
  "$HOME/.cargo/bin"        # rustup / cargo
  $path
)
export PATH

# ---- Core environment -------------------------------------------------------
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"
export LESS="-FRXi"         # one-screen quit, raw color, no clear, smart-case
export LESSHISTFILE="-"     # stop less writing ~/.lesshst

# ---- XDG-ify tools that would otherwise dirty $HOME -------------------------
export WGETRC="$XDG_CONFIG_HOME/wgetrc"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export NPM_CONFIG_INIT_MODULE="$XDG_CONFIG_HOME/npm/config/npm-init.js"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export PYTHONSTARTUP="$XDG_CONFIG_HOME/python/pythonrc"
export SCC_CONFIG_PATH="$XDG_CONFIG_HOME/scc/config"
. "$HOME/.cargo/env"
