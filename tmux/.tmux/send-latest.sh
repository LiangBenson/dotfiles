#!/usr/bin/env bash
#
# Finds the file (or folder) Claude last wrote in a tmux pane and writes it to
# stdout as a .tar.gz. ~/.config/ghostty/download-latest.sh on the Mac runs this
# over ssh and saves the result in ~/Downloads.
#
#   send-latest.sh file|dir [port:N | pid:N] [--force]
#
# Which pane: the active pane of the tmux client whose ssh connection comes
# from the Mac's port N, or the client with process id N (a local tab). If
# neither matches, the most recently used client.
#
# file: the last Write(...) or Update(...) target shown in the pane, else the
#       last path on screen that exists and changed in the last 30 minutes.
# dir:  the last folder path on screen that changed in the last 30 minutes
#       (not the pane's own folder or one above it), else the folder of the
#       file above. Skips .git and node_modules. Over 100 MB it asks first:
#       it prints "big" and sends nothing unless --force is given.
#
# Output: one line "send-latest<TAB>ok<TAB>NAME" followed by the archive, or
# "send-latest<TAB>big<TAB>NAME", or "send-latest<TAB>error<TAB>MESSAGE".

set -u

# -u: ssh sessions often have no UTF-8 locale, and tmux then prints tabs in
# its list output as "_".
tmux() { command tmux -u "$@"; }

mode="${1:-}"
match="${2:-}"
force="${3:-}"
recent_minutes=30
max_bytes=$((100 * 1024 * 1024))

reply() {
  local IFS=$'\t'
  printf 'send-latest\t%s\n' "$*"
}

fail() {
  reply error "$*"
  exit 0
}

# Port on the Mac that a process's ssh connection comes from (from its
# SSH_CONNECTION: "client-ip client-port server-ip server-port").
ssh_port_of() {
  local env
  if [[ -r "/proc/$1/environ" ]]; then
    env="$(tr '\0' '\n' <"/proc/$1/environ" | grep '^SSH_CONNECTION=')"
  else
    env="$(ps -E -ww -o command= -p "$1" 2>/dev/null | grep -oE 'SSH_CONNECTION=[^ ]+ [0-9]+')"
  fi
  [[ -n "${env}" ]] || return 0
  env="${env#SSH_CONNECTION=* }"
  printf '%s' "${env%% *}"
}

# Prints "pane-id<TAB>pane-folder" of the matching client (see the top).
find_pane() {
  local filter="$1" activity pid pane dir
  while IFS=$'\t' read -r activity pid pane dir; do
    case "${filter}" in
      pid:*) [[ "${pid}" == "${filter#pid:}" ]] || continue ;;
      port:*) [[ "$(ssh_port_of "${pid}")" == "${filter#port:}" ]] || continue ;;
    esac
    printf '%s\t%s\n' "${pane}" "${dir}"
    return 0
  done < <(tmux list-clients -F '#{client_activity}	#{client_pid}	#{pane_id}	#{pane_current_path}' 2>/dev/null | sort -rn)
  return 1
}

found="$(find_pane "${match}" || find_pane any)"
[[ -n "${found}" ]] || fail "No tmux session is open on $(hostname -s)."
pane="${found%%$'\t'*}"
dir="${found#*$'\t'}"

screen() {
  tmux capture-pane -p -J -S -2000 -t "${pane}"
}

last_first() {
  awk '{ lines[NR] = $0 } END { for (i = NR; i > 0; i--) print lines[i] }'
}

# Targets of Claude Code's Write(path) and Update(path) lines, last first.
written() {
  screen |
    grep -oE '(Write|Update|Edit|MultiEdit|NotebookEdit)\([^)]+\)' |
    sed -E 's/^[A-Za-z]+\((.*)\)$/\1/' |
    last_first
}

# Words on screen that look like paths ("out/data.csv", "site/"), last first.
mentioned() {
  screen |
    grep -oE '[[:alnum:]_.~/+@%=-]*[/.][[:alnum:]_.~/+@%=-]*' |
    sed -E 's/[.:,;]+$//' |
    grep -vxE '[./]*' |
    last_first
}

# Absolute path of something that exists; relative paths start at the pane's folder.
resolve() {
  local path="$1"
  case "${path}" in
    "~") path="${HOME}" ;;
    "~/"*) path="${HOME}/${path#"~/"}" ;;
    /*) ;;
    *) path="${dir}/${path}" ;;
  esac
  [[ -e "${path}" ]] && printf '%s\n' "${path}"
}

is_recent() {
  [[ -n "$(find "$1" -maxdepth 0 -mmin "-${recent_minutes}" 2>/dev/null)" ]]
}

# Created (not just changed) in the last 30 minutes. False where the file
# system doesn't record creation times.
is_new() {
  local born
  born="$(stat -c %W "$1" 2>/dev/null || stat -f %B "$1" 2>/dev/null)"
  [[ "${born}" =~ ^[0-9]+$ ]] && ((born > 0 && $(date +%s) - born < recent_minutes * 60))
}

# "site/assets" -> "site" when Claude created both: steps up while the parent
# is also new, staying inside the pane's folder.
top_new_folder() {
  local folder="$1" here="$2" parent
  while parent="$(dirname "${folder}")" && [[ "${parent}" == "${here}"/* ]] && is_new "${parent}"; do
    folder="${parent}"
  done
  echo "${folder}"
}

last_written_file() {
  local path file
  while IFS= read -r path; do
    file="$(resolve "${path}")" && [[ -f "${file}" ]] && { echo "${file}"; return 0; }
  done < <(written)
  return 1
}

pick_file() {
  local path file
  last_written_file && return 0
  while IFS= read -r path; do
    file="$(resolve "${path}")" && [[ -f "${file}" ]] && is_recent "${file}" && { echo "${file}"; return 0; }
  done < <(mentioned)
  return 1
}

pick_dir() {
  local path folder here home file
  here="$(cd "${dir}" && pwd -P)"
  home="$(cd "${HOME}" && pwd -P)"
  while IFS= read -r path; do
    [[ "${path}" == */* ]] || continue
    folder="$(resolve "${path}")" && [[ -d "${folder}" ]] || continue
    folder="$(cd "${folder}" && pwd -P)"
    # Skip the pane's own folder, the folders above it, and the home folder.
    case "${here}/" in "${folder%/}/"*) continue ;; esac
    [[ "${folder}" == "${home}" ]] && continue
    is_recent "${folder}" && { top_new_folder "${folder}" "${here}"; return 0; }
  done < <(mentioned)
  file="$(last_written_file)" || return 1
  folder="$(cd "$(dirname "${file}")" && pwd -P)"
  top_new_folder "${folder}" "${here}"
}

case "${mode}" in
  file) item="$(pick_file)" || fail "No file Claude wrote is on screen ($(hostname -s):${dir})." ;;
  dir) item="$(pick_dir)" || fail "No folder Claude made is on screen ($(hostname -s):${dir})." ;;
  *) fail "Usage: send-latest.sh file|dir [port:N | pid:N] [--force]" ;;
esac

parent="$(dirname "${item}")"
name="$(basename "${item}")"
skip=()
[[ -d "${item}" ]] && skip=(--exclude=.git --exclude=node_modules)

if [[ -d "${item}" && "${force}" != --force ]]; then
  size="$(tar -cf - ${skip[@]+"${skip[@]}"} -C "${parent}" "${name}" 2>/dev/null |
    head -c $((max_bytes + 1)) | wc -c | tr -d ' ')"
  ((size > max_bytes)) && { reply big "${name}"; exit 0; }
fi

reply ok "${name}"
exec tar -czf - ${skip[@]+"${skip[@]}"} -C "${parent}" "${name}"
