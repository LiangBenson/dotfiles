autoload -Uz compinit

if [[ -d "${ZSH_PLUGIN_DIR}/zsh-completions/src" ]]; then
  fpath=("${ZSH_PLUGIN_DIR}/zsh-completions/src" $fpath)
fi

compinit
