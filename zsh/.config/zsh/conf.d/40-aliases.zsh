# Aliases and small functions.
#
# Convention: modern tools shadow the classic name ONLY where the flags are
# compatible enough that muscle memory still works. Where they are not (find,
# grep), the new tool keeps its own name so scripts and SSH sessions are never
# surprised.

# ---- Listing: eza -----------------------------------------------------------
if (( $+commands[eza] )); then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -l  --group-directories-first --icons=auto --git --time-style=long-iso'
  alias la='eza -la --group-directories-first --icons=auto --git --time-style=long-iso'
  alias lt='eza --tree --level=2 --group-directories-first --icons=auto'
  alias ltt='eza --tree --level=4 --group-directories-first --icons=auto'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lh'
  alias la='ls -lah'
fi

# ---- Viewing: bat -----------------------------------------------------------
if (( $+commands[batcat] )); then alias bat='batcat'; fi # Debian binary name
if (( $+commands[bat] || $+commands[batcat] )); then
  alias cat='bat --paging=never'
  alias catp='bat' # paged
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

# ---- Search -----------------------------------------------------------------
# fd/rg intentionally keep their own names. `grep` stays GNU grep.
if (( $+commands[fdfind] )); then alias fd='fdfind'; fi
alias grep='grep --color=auto'

# ---- Safety nets ------------------------------------------------------------
# -I prompts once for 3+ files rather than per-file; keeps rm usable but
# catches the catastrophic case.
alias rm='rm -I --preserve-root'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'
alias df='df -h'
alias free='free -h'

# ---- Git --------------------------------------------------------------------
alias g='git'
alias gs='git status --short --branch'
alias ga='git add'
alias gc='git commit'
alias gca='git commit --amend'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gsw='git switch'
alias gb='git branch'
(( $+commands[lazygit] )) && alias lg='lazygit'

# ---- Editor -----------------------------------------------------------------
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# ---- Navigation -------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# ---- Dotfiles ---------------------------------------------------------------
alias dotf='cd "$DOTFILES"'
alias zrc='nvim "$ZDOTDIR/.zshrc"'
alias vrc='nvim "$XDG_CONFIG_HOME/nvim/init.lua"'
alias reload='exec zsh'

# ---- Modern replacements (only if installed) --------------------------------
(( $+commands[btop] )) && alias top='btop'
(( $+commands[duf] )) && alias df='duf'
(( $+commands[procs] )) && alias ps='procs'
(( $+commands[tldr] )) && alias help='tldr'

# ---- Functions --------------------------------------------------------------

# mkcd — make a directory and enter it.
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# extract — one command for every archive format.
extract() {
  [[ -f "$1" ]] || {
    print -u2 "extract: '$1' is not a file"
    return 1
  }
  case "$1" in
    *.tar.bz2 | *.tbz2) tar xjf "$1" ;;
    *.tar.gz | *.tgz) tar xzf "$1" ;;
    *.tar.xz) tar xJf "$1" ;;
    *.tar.zst) tar --zstd -xf "$1" ;;
    *.tar) tar xf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.gz) gunzip "$1" ;;
    *.zip) unzip "$1" ;;
    *.7z) 7z x "$1" ;;
    *.rar) unrar x "$1" ;;
    *)
      print -u2 "extract: unknown archive type '$1'"
      return 1
      ;;
  esac
}

# take — clone a repo and cd into it.
take() { git clone "$1" && cd -- "$(basename "${1%%.git}")"; }
