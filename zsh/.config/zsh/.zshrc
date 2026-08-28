# ~/.config/zsh/.zshrc — interactive shells only.
#
# A loader and nothing else. Real configuration lives in conf.d/*.zsh and is
# sourced in numeric order. Ordering is load-bearing:
#   20 must run before 80  (fzf-tab needs compinit)
#   70 must run before 80  (the prompt defines widgets 80 has to wrap)
#   80 must run last       (zsh-syntax-highlighting must wrap every widget
#                           defined by everything before it)

# powerlevel10k instant prompt. MUST stay at the very top, above anything that
# prints output or reads input, or the prompt cannot be drawn before the rest
# of this file has finished running. That early draw is the whole feature.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

for _f in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$_f"
done
unset _f

# Prompt appearance, written by `p10k configure`. Committed, so every machine
# gets the same prompt.
[[ -r "$ZDOTDIR/.p10k.zsh" ]] && source "$ZDOTDIR/.p10k.zsh"

# Machine-specific overrides. Gitignored — never committed, never shared.
[[ -r "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
