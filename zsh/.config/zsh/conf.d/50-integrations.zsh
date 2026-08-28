# Third-party tool hookups. Every block is guarded so a missing tool degrades
# to "that feature is absent" rather than an error on every prompt.

# ---- fzf --------------------------------------------------------------------
if (( $+commands[fzf] )); then
  # Catppuccin Mocha, matching nvim / tmux / the prompt.
  export FZF_DEFAULT_OPTS="
    --height=60% --layout=reverse --border=rounded --info=inline
    --preview-window=right:55%:border-left
    --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
    --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
    --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8
    --color=border:#585b70
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
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:300 {} 2>/dev/null || eza -1 --icons --color=always {}'"
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
