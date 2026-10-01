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
  "$HOME/.local/bin"        # uv, uv tool installs, format-file, misc binaries
  "$HOME/.cargo/bin"        # rustup / cargo
  $path
)
export PATH

# ---- Core environment -------------------------------------------------------
export EDITOR="code --wait"
export VISUAL="code --wait"
export PAGER="less"
export LESS="-FRXi"         # one-screen quit, raw color, no clear, smart-case
export LESSHISTFILE="-"     # stop less writing ~/.lesshst

# ---- XDG-ify tools that would otherwise dirty $HOME -------------------------
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"
export DOCKER_CONFIG="$XDG_CONFIG_HOME/docker"
export NPM_CONFIG_INIT_MODULE="$XDG_CONFIG_HOME/npm/config/npm-init.js"
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
export IPYTHONDIR="$XDG_CONFIG_HOME/ipython"
export KERAS_HOME="$XDG_DATA_HOME/keras"
export PYTHON_HISTORY="$XDG_STATE_HOME/python_history" # Python 3.13+
