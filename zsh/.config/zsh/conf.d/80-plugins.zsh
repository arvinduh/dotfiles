# Plugins. LAST on purpose.
#
# zsh-syntax-highlighting wraps every ZLE widget that exists when it loads, so
# it must come after fzf, atuin, zoxide and fzf-tab have defined theirs.
# Loading it earlier silently breaks highlighting on those widgets.

# ---- zsh-autosuggestions (the "autofill" ghost text) ------------------------
for _p in \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  "$XDG_DATA_HOME/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
do
  if [[ -r "$_p" ]]; then
    source "$_p"
    # Suggest from history first, then completion — completion is the slow one.
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'         # ANSI bright black; follows the terminal
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20             # don't suggest on huge lines
    bindkey '^ '  autosuggest-accept               # ctrl-space: accept all
    bindkey '^[f' forward-word                     # alt-f: accept one word
    break
  fi
done

# ---- zsh-syntax-highlighting (must be dead last) ----------------------------
for _p in \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  "$XDG_DATA_HOME/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
do
  if [[ -r "$_p" ]]; then
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
    source "$_p"
    break
  fi
done
unset _p
