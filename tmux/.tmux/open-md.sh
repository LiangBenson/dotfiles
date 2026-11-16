#!/usr/bin/env bash
#
# prefix + g: open the markdown file Claude (or anything else) just wrote in
# glow, in a new pane on the right. Picks the first match of:
#   1. the last .md path shown in this pane, if it changed in the last 30 minutes
#   2. the newest .md under this pane's folder changed in the last 30 minutes
#   3. the last .md path shown in this pane that exists

set -u

pane_id="${1:-}"
[[ -n "${pane_id}" ]] || exit 1
recent_minutes=30
dir="$(tmux display-message -p -t "${pane_id}" '#{pane_current_path}')"

# .md paths in the pane's recent output, last one first.
on_screen() {
  tmux capture-pane -p -J -S -2000 -t "${pane_id}" |
    grep -oE '[[:alnum:]_./~+-]+\.md([^[:alnum:]_]|$)' |
    sed -E 's/\.md.$/.md/' |
    awk '{ lines[NR] = $0 } END { for (i = NR; i > 0; i--) print lines[i] }'
}

# Absolute path of an existing file; relative paths are taken from the pane's folder.
resolve() {
  local path="$1"
  case "${path}" in
    "~/"*) path="${HOME}/${path#"~/"}" ;;
    /*) ;;
    *) path="${dir}/${path}" ;;
  esac
  [[ -f "${path}" ]] && printf '%s\n' "${path}"
}

is_recent() {
  [[ -n "$(find "$1" -mmin "-${recent_minutes}" 2>/dev/null)" ]]
}

pick() {
  local path file newest=""

  while IFS= read -r path; do
    file="$(resolve "${path}")" && is_recent "${file}" && { echo "${file}"; return; }
  done < <(on_screen)

  if command -v fd >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
      [[ -z "${newest}" || "${file}" -nt "${newest}" ]] && newest="${file}"
    done < <(fd --type f --extension md --max-depth 5 --changed-within "${recent_minutes}m" -0 . "${dir}")
    [[ -n "${newest}" ]] && { echo "${newest}"; return; }
  fi

  while IFS= read -r path; do
    file="$(resolve "${path}")" && { echo "${file}"; return; }
  done < <(on_screen)
}

file="$(pick)"
if [[ -z "${file}" ]]; then
  tmux display-message "No markdown file on screen or changed in the last ${recent_minutes} minutes"
  exit 0
fi

# glow's pager mode, wrapped to the new pane's width (half of this one). Its
# TUI mode ignores --width and cuts long lines off at the pane edge.
width=$(($(tmux display-message -p -t "${pane_id}" '#{pane_width}') / 2 - 6))
((width < 40)) && width=40

# --clear-screen starts short files at the top of the pane instead of the
# bottom; --tilde leaves the lines past the end blank. Mouse-wheel scrolling
# needs less 551 or newer.
pager="less -R --clear-screen --tilde"
(($(less -V 2>/dev/null | awk 'NR == 1 { print $2 + 0 }') >= 551)) && pager="${pager} --mouse"

tmux split-window -h -t "${pane_id}" -c "$(dirname "${file}")" \
  env PAGER="${pager}" glow --pager --width "${width}" "${file}"
