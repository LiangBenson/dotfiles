# Read by every zsh, including scripts and `ssh host command`, so this file
# only sets environment variables.

typeset -U path PATH                 # drop duplicate PATH entries
path=("${HOME}/.local/bin" $path)    # Claude Code, and the Linux tools from bootstrap.sh

export EDITOR=nvim
export VISUAL=nvim
