# EnigmarsOS default zsh configuration
export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LANG=en_US.UTF-8

# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS SHARE_HISTORY EXTENDED_HISTORY

# Completion (cached dump; full rescan at most once a day)
autoload -Uz compinit
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -f "${_zcompdump}" && -n "$(find "${_zcompdump}" -mtime -1 2>/dev/null)" ]]; then
  compinit -C -d "${_zcompdump}"
else
  compinit -d "${_zcompdump}"
fi
unset _zcompdump
zstyle ':completion:*' menu select

# Plugins when available (highlighting last: it wraps ZLE widgets)
[[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
# Only the main highlighter: brackets/cursor/line passes cost per-keystroke
# latency without adding readability. Must be set before sourcing.
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)
[[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Tools
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
command -v fzf >/dev/null && eval "$(fzf --zsh 2>/dev/null || true)"

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias cat='bat --paging=never 2>/dev/null || cat'
alias vim='nvim'
alias vi='nvim'
alias top='btop'
alias fetch='fastfetch'

# Fastfetch on interactive shells (skip for scripts)
if [[ $- == *i* ]] && command -v fastfetch >/dev/null; then
  fastfetch
fi
