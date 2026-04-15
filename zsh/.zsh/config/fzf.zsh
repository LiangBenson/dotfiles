if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

tmux_set_fzf_active() {
  [[ -n "${TMUX_PANE:-}" ]] || return 0
  tmux set -pt "${TMUX_PANE}" @fzf-active "$1" >/dev/null 2>&1
}

tmux_wrap_fzf_widget() {
  local widget_name="$1"
  local original_widget="_original_${widget_name//-/_}"
  local wrapper_function="wrapped_${widget_name//-/_}"

  zle -l "${widget_name}" >/dev/null 2>&1 || return 0
  zle -A "${widget_name}" "${original_widget}"

  eval "
${wrapper_function}() {
  tmux_set_fzf_active 1
  zle ${original_widget}
  local widget_status=\$?
  tmux_set_fzf_active 0
  return \$widget_status
}
"

  zle -N "${widget_name}" "${wrapper_function}"
}

tmux_wrap_fzf_widget fzf-file-widget
tmux_wrap_fzf_widget fzf-cd-widget
tmux_wrap_fzf_widget fzf-history-widget
