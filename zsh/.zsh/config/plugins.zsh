zsh_source_plugin_if_exists() {
  local plugin_file="$1"

  if [[ -f "${plugin_file}" ]]; then
    source "${plugin_file}"
  fi
}

zsh_source_plugin_if_exists "${ZSH_PLUGIN_DIR}/fzf-tab/fzf-tab.plugin.zsh"
zsh_source_plugin_if_exists "${ZSH_PLUGIN_DIR}/powerlevel10k/powerlevel10k.zsh-theme"
zsh_source_plugin_if_exists "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"
zsh_source_plugin_if_exists "${ZSH_PLUGIN_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
