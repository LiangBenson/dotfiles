# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_HOME="${HOME}/.zsh"
ZSH_CONFIG_DIR="${ZSH_HOME}/config"
ZSH_PLUGIN_DIR="${ZSH_HOME}/plugins"

zsh_source_if_exists() {
  local file_path="$1"

  if [[ -f "${file_path}" ]]; then
    source "${file_path}"
  fi
}

zsh_source_if_exists "${ZSH_CONFIG_DIR}/options.zsh"
zsh_source_if_exists "${ZSH_CONFIG_DIR}/aliases.zsh"
zsh_source_if_exists "${ZSH_CONFIG_DIR}/completions.zsh"
zsh_source_if_exists "${ZSH_CONFIG_DIR}/plugins.zsh"
zsh_source_if_exists "${ZSH_CONFIG_DIR}/fzf.zsh"
zsh_source_if_exists "${ZSH_CONFIG_DIR}/prompt.zsh"

# Settings for this machine only (not tracked in git).
zsh_source_if_exists "${ZSH_CONFIG_DIR}/local.zsh"

# Last: it wraps every key binding widget defined before it.
zsh_source_if_exists "${ZSH_PLUGIN_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
