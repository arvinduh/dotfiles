# Completion. Runs before 80-plugins.zsh because fzf-tab must hook a compinit
# that has already happened.

# Keep generated completion functions under XDG.
fpath=("$XDG_DATA_HOME/zsh/completions" $fpath)
[[ -d "$XDG_DATA_HOME/zsh/completions" ]] || mkdir -p "$XDG_DATA_HOME/zsh/completions"

autoload -Uz compinit

# Rebuild the compdump at most once a day; otherwise use the cache. This is the
# single biggest zsh startup win there is — a full compinit costs ~100ms+.
_zcompdump="$XDG_CACHE_HOME/zsh/zcompdump"
[[ -d "${_zcompdump:h}" ]] || mkdir -p "${_zcompdump:h}"
if [[ -n "$_zcompdump"(#qN.mh+24) ]]; then
  compinit -d "$_zcompdump"
  # Compile to bytecode so subsequent shells load it faster.
  { zcompile -R -- "$_zcompdump" } &!
else
  compinit -C -d "$_zcompdump"
fi
unset _zcompdump

zmodload -i zsh/complist

# ---- Matching ---------------------------------------------------------------
zstyle ':completion:*' completer _complete _match _approximate
# Case-insensitive, then partial-word (f.b -> foo.bar), then substring.
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'
zstyle ':completion:*' menu no          # fzf-tab replaces the built-in menu
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"

# ---- Presentation -----------------------------------------------------------
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:warnings' format 'no matches'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' special-dirs true   # offer ./ and ../

# Never offer the current argument again (e.g. `cp a a`).
zstyle ':completion:*' ignore-parents parent pwd
zstyle ':completion:*:(rm|cp|mv|kill|diff):*' ignore-line other

# ---- fzf-tab ----------------------------------------------------------------
# Replaces zsh's completion menu with an fzf picker, with live previews.
if [[ -r "$XDG_DATA_HOME/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]]; then
  source "$XDG_DATA_HOME/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh"

  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' switch-group '<' '>'
  zstyle ':fzf-tab:*' fzf-min-height 15

  # Preview directory contents when completing a path.
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons --color=always $realpath'
  zstyle ':fzf-tab:complete:z:*'  fzf-preview 'eza -1 --icons --color=always $realpath'
  # Preview file contents for the editors.
  zstyle ':fzf-tab:complete:(code|bat|cat|less):*' fzf-preview \
    '[[ -d $realpath ]] && eza -1 --icons --color=always $realpath || bat --color=always --style=numbers --line-range=:200 $realpath'
  # Preview the env var value when completing export/unset.
  zstyle ':fzf-tab:complete:(export|unset):*' fzf-preview 'echo ${(P)word}'
  # Preview systemd unit status.
  zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
fi
