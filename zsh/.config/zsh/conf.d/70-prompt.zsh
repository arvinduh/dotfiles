# powerlevel10k. Cloned by the README bootstrap into $XDG_DATA_HOME/zsh/plugins.
#
# Loads before 80-plugins.zsh so zsh-syntax-highlighting can wrap the widgets
# the prompt defines. Appearance is NOT configured here — that lives in
# ~/.config/zsh/.p10k.zsh, which `p10k configure` writes.

for _p in \
  "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/powerlevel10k/powerlevel10k.zsh-theme" \
  /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
do
  if [[ -r "$_p" ]]; then
    source "$_p"
    break
  fi
done
unset _p
