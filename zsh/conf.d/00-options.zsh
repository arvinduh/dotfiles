# Shell behaviour. `man zshoptions` for the full list.

# ---- Directory navigation ---------------------------------------------------
setopt AUTO_CD    # bare `foo` cds into ./foo
setopt AUTO_PUSHD # every cd pushes onto the dir stack
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# ---- Globbing ---------------------------------------------------------------
setopt EXTENDED_GLOB     # ^ # ~ operators; needed by lots of zsh idiom
setopt GLOB_DOTS         # * matches dotfiles too
setopt NO_NOMATCH        # pass through unmatched globs instead of erroring
setopt NUMERIC_GLOB_SORT # file10 sorts after file9

# ---- Correction / quality of life ------------------------------------------
setopt INTERACTIVE_COMMENTS # allow # comments when typing interactively
setopt NO_BEEP
setopt NO_FLOW_CONTROL # frees ^S and ^Q for keybinds
unsetopt CORRECT       # zsh's guesses are worse than fzf-tab; off.

# ---- Job control ------------------------------------------------------------
setopt LONG_LIST_JOBS
setopt AUTO_RESUME # `foo` resumes a suspended job named foo
setopt NOTIFY      # report background job status immediately
setopt NO_HUP      # don't kill background jobs when the shell exits
