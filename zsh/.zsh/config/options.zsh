# Standard line-editing keys (Ctrl-A, Ctrl-E, Alt-B, Alt-F). Without this, zsh
# switches to vi keys because EDITOR (nvim) contains "vi".
bindkey -e

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt INTERACTIVE_COMMENTS
setopt SHARE_HISTORY

HISTFILE="${HOME}/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
