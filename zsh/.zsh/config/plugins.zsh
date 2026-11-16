# fzf-tab must come after compinit and before plugins that wrap widgets.
# zsh-syntax-highlighting is loaded at the end of ~/.zshrc.
zsh_source_if_exists "${ZSH_PLUGIN_DIR}/fzf-tab/fzf-tab.plugin.zsh"
zsh_source_if_exists "${ZSH_PLUGIN_DIR}/powerlevel10k/powerlevel10k.zsh-theme"
zsh_source_if_exists "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"
