# History. Atuin owns interactive search (^R), but zsh's own history is still
# the source of truth on disk and what ^P / !! / !$ read from — so it is tuned
# properly rather than left at defaults.

HISTFILE="$XDG_STATE_HOME/zsh/history"
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

HISTSIZE=200000 # entries kept in memory
SAVEHIST=200000 # entries written to disk
HISTDUP=erase

setopt EXTENDED_HISTORY   # record timestamp + duration per entry
setopt INC_APPEND_HISTORY # write as you go, not just at exit
setopt SHARE_HISTORY      # live-share across concurrent shells
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE # a leading space keeps a command out of history
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY # expand !! and let you inspect before running
