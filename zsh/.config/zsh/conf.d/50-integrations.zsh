# Third-party tool hookups. Every block is guarded so a missing tool degrades
# to "that feature is absent" rather than an error on every prompt.

# ---- fzf --------------------------------------------------------------------
if (( $+commands[fzf] )); then
  # No --color: fzf inherits the terminal palette, so re-theming the terminal
  # re-themes fzf with nothing to edit here.
  export FZF_DEFAULT_OPTS="
    --height=60% --layout=reverse --border=rounded --info=inline
    --preview-window=right:55%:border-left
    --bind=ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down
    --bind=ctrl-y:accept"

  # Use fd for traversal: respects .gitignore and is dramatically faster.
  if (( $+commands[fd] || $+commands[fdfind] )); then
    _fdcmd=${commands[fd]:-${commands[fdfind]}}
    export FZF_DEFAULT_COMMAND="$_fdcmd --type=file --hidden --follow --exclude=.git"
    export FZF_CTRL_T_COMMAND="$_fdcmd --hidden --follow --exclude=.git"
    export FZF_ALT_C_COMMAND="$_fdcmd --type=directory --hidden --follow --exclude=.git"
    unset _fdcmd
  fi
  # Preview commands run via sh, where the interactive `bat` alias does not
  # exist — so resolve the real binary name here, the same way fd is handled.
  if (( $+commands[bat] || $+commands[batcat] )); then
    _batcmd=${commands[bat]:-${commands[batcat]}}
    export FZF_CTRL_T_OPTS="--preview '$_batcmd --color=always --style=numbers --line-range=:300 {} 2>/dev/null || eza -1 --icons --color=always {}'"
    unset _batcmd
  fi
  export FZF_ALT_C_OPTS="--preview 'eza --tree --level=2 --icons --color=always {}'"

  # fzf >= 0.48 ships its own shell integration; prefer it over vendored files.
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -r /usr/share/doc/fzf/examples/completion.zsh   ]] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# ---- zoxide (smarter cd) ----------------------------------------------------
# `cd` is replaced wholesale: zoxide falls back to plain cd semantics for real
# paths, so nothing is lost, and `cd foo` jumps to a frecent match otherwise.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
fi

# ---- atuin (shell history) --------------------------------------------------
# Local-only: sync is disabled in atuin/config.toml. Owns ^R. Up-arrow is
# deliberately left to zsh's prefix search from 30-keybinds.zsh.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# ---- uv ---------------------------------------------------------------------
if (( $+commands[uv] )); then
  eval "$(uv generate-shell-completion zsh)" 2>/dev/null
  eval "$(uvx --generate-shell-completion zsh)" 2>/dev/null
fi

# ---- gh ---------------------------------------------------------------------
if (( $+commands[gh] )); then
  _ghcomp="$XDG_DATA_HOME/zsh/completions/_gh"
  [[ -r "$_ghcomp" ]] || gh completion -s zsh > "$_ghcomp" 2>/dev/null
  unset _ghcomp
fi
