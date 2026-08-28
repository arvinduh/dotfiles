# Emacs keymap (default even when EDITOR=nvim — modal editing in a one-line
# prompt is friction, and ^R/^A/^E muscle memory is universal over SSH).
bindkey -e

# ---- Word motions -----------------------------------------------------------
# Treat /, ., -, _ as word separators so ^W deletes one path segment, not the
# whole path. This is the single most useful zsh tweak most people never make.
WORDCHARS='*?[]~&;!#$%^(){}<>'

bindkey '^[[1;5C' forward-word          # ctrl-right
bindkey '^[[1;5D' backward-word         # ctrl-left
bindkey '^[[3;5~' kill-word             # ctrl-delete
bindkey '^H'      backward-kill-word    # ctrl-backspace
bindkey '^[[3~'   delete-char

# ---- Line motions -----------------------------------------------------------
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^U'   backward-kill-line       # kill to start, not the whole line

# ---- History ----------------------------------------------------------------
# Up/Down search history using what you have already typed as a prefix.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^P'   up-line-or-beginning-search
bindkey '^N'   down-line-or-beginning-search

# ---- Edit the current command line in $EDITOR -------------------------------
# ^X^E — indispensable once a one-liner grows past a couple of pipes.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ---- Menu navigation (inside completion menus) ------------------------------
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect '^[[Z' reverse-menu-complete   # shift-tab

# ---- Sudo prefix ------------------------------------------------------------
# ESC-ESC toggles `sudo ` on the front of the current line.
_sudo-toggle() {
  [[ -z $BUFFER ]] && zle up-history
  if [[ $BUFFER == sudo\ * ]]; then
    BUFFER="${BUFFER#sudo }"; CURSOR=$((CURSOR - 5))
  else
    BUFFER="sudo $BUFFER";    CURSOR=$((CURSOR + 5))
  fi
}
zle -N _sudo-toggle
bindkey '^[^[' _sudo-toggle
