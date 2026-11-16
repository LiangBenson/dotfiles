#!/usr/bin/env bash

set -euo pipefail

direction="${1:-}"
pane_id="${2:-}"

if [[ -z "${direction}" || -z "${pane_id}" ]]; then
  exit 1
fi

pane_command="$(tmux display-message -p -t "${pane_id}" '#{pane_current_command}')"
fzf_active="$(tmux display-message -p -t "${pane_id}" '#{@fzf-active}')"

case "${direction}" in
  left)
    key="C-h"
    select_flag="-L"
    ;;
  right)
    key="C-l"
    select_flag="-R"
    ;;
  up)
    key="C-k"
    select_flag="-U"
    ;;
  down)
    key="C-j"
    select_flag="-D"
    ;;
  *)
    exit 1
    ;;
esac

# A single (or zoomed) pane has nowhere to move to: let the program have the
# key, so C-j / C-l / C-k / C-h work in Claude Code and the shell.
only_pane="$(tmux display-message -p -t "${pane_id}" '#{||:#{==:#{window_panes},1},#{window_zoomed_flag}}')"

if [[ "${fzf_active}" == "1" || "${only_pane}" == "1" ]]; then
  tmux send-keys -t "${pane_id}" "${key}"
  exit 0
fi

if [[ "${pane_command}" =~ (^|/)(tig|lazygit|g?(view|n?vim?)(diff)?)$ ]]; then
  tmux send-keys -t "${pane_id}" "${key}"
  exit 0
fi

tmux select-pane -t "${pane_id}" "${select_flag}"
