#!/usr/bin/env bash
#
# Saves the file (or folder) Claude last wrote in the current Ghostty tab into
# ~/Downloads, then shows a notification. The tab can be ssh'd into a host
# running tmux + Claude, or be a local tmux tab. The host needs
# ~/.tmux/send-latest.sh (bootstrap.sh links it), which picks the file.
#
# Run by the Quick Actions in ~/Library/Services (cmd+shift+O for the file,
# cmd+shift+D for the folder, in Ghostty only).
#
#   download-latest.sh file|dir [--pid PID]
#
# --pid: use this process instead of asking Ghostty for the current tab's.

set -u

# Quick Actions start with only the system folders on PATH (tmux is in Homebrew's).
PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

mode="${1:-file}"
pid=""
[[ "${2:-}" == --pid ]] && pid="${3:-}"
downloads="${DOWNLOAD_DIR:-${HOME}/Downloads}"

# Shows a notification and keeps a line of it in ~/Library/Logs/download-latest.log.
notify() {
  printf '%s  %s: %s\n' "$(date '+%F %T')" "$1" "$2" >>"${HOME}/Library/Logs/download-latest.log"
  osascript - "$1" "$2" >/dev/null 2>&1 <<'EOF'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
EOF
}

fail() {
  printf 'download-latest: %s\n' "$*" >&2
  notify "Download failed" "$*"
  exit 1
}

# Asks before a big folder; "Download" or "Cancel".
confirm_big() {
  osascript - "$1" 2>/dev/null <<'EOF'
on run argv
  display dialog (item 1 of argv) & " is over 100 MB. Download it anyway?" buttons {"Cancel", "Download"} default button "Download" with title "Download from Claude"
  return button returned of result
end run
EOF
}

command_name() {
  ps -o comm= -p "$1" 2>/dev/null | sed 's#.*/##'
}

# The ssh process: the given process or one below it (Ghostty's ssh wrapper
# runs ssh as a child).
find_ssh() {
  local p c
  for p in "$1" $(pgrep -P "$1"); do
    [[ "$(command_name "${p}")" == ssh ]] && { echo "${p}"; return 0; }
    for c in $(pgrep -P "${p}"); do
      [[ "$(command_name "${c}")" == ssh ]] && { echo "${c}"; return 0; }
    done
  done
  return 1
}

# From the ssh process's arguments, keep what picks the host and how to log
# in (-p, -l, -i, -J, -F, most -o), and drop forwardings, tty flags and the
# remote command. Sets ssh_opts and ssh_dest.
parse_ssh() {
  local args=() i=1 arg rest flag value
  read -r -a args <<<"$(ps -o args= -ww -p "$1")"
  ssh_opts=()
  ssh_dest=""
  while ((i < ${#args[@]})); do
    arg="${args[i]}"
    case "${arg}" in
      --) ssh_dest="${args[i + 1]:-}"; break ;;
      -?*)
        rest="${arg#-}"
        while [[ -n "${rest}" ]]; do
          flag="${rest:0:1}"
          rest="${rest:1}"
          case "${flag}" in
            [BbcDEeFIiJLlmOoPpQRSWw])
              if [[ -n "${rest}" ]]; then value="${rest}"; else i=$((i + 1)); value="${args[i]:-}"; fi
              rest=""
              case "${flag}" in
                [BbcFIiJlmPpS]) ssh_opts+=("-${flag}" "${value}") ;;
                o)
                  case "$(printf '%s' "${value%%[= ]*}" | tr '[:upper:]' '[:lower:]')" in
                    localforward | remoteforward | dynamicforward | requesttty | remotecommand | sessiontype | \
                      forkafterauthentication | stdinnull | exitonforwardfailure | permitlocalcommand | localcommand) ;;
                    *) ssh_opts+=(-o "${value}") ;;
                  esac
                  ;;
              esac
              ;;
            4 | 6 | C) ssh_opts+=("-${flag}") ;;
          esac
        done
        ;;
      *) ssh_dest="${arg}"; break ;;
    esac
    i=$((i + 1))
  done
  [[ -n "${ssh_dest}" ]]
}

# ── Which tab, and where it's connected ───────────────────────────────────

if [[ -z "${pid}" ]]; then
  pid="$(osascript -e 'tell application "Ghostty" to get pid of focused terminal of selected tab of front window' 2>/dev/null)" ||
    fail "Couldn't ask Ghostty for the current tab."
fi

ssh_pid=""
match=""
if ssh_pid="$(find_ssh "${pid}")"; then
  :
elif [[ "$(command_name "${pid}")" == tmux ]]; then
  # A local tmux tab. If its current pane runs ssh, use that connection.
  pane_pid="$(tmux list-clients -F '#{client_pid} #{pane_pid}' 2>/dev/null | awk -v p="${pid}" '$1 == p { print $2 }')"
  if [[ -n "${pane_pid}" ]] && ssh_pid="$(find_ssh "${pane_pid}")"; then
    :
  else
    ssh_pid=""
    match="pid:${pid}"
  fi
else
  fail "This tab isn't running ssh or tmux."
fi

if [[ -n "${ssh_pid}" ]]; then
  parse_ssh "${ssh_pid}" || fail "Couldn't read the ssh command of this tab."
  # The Mac-side port of the tab's connection tells the host which tmux
  # client is this tab. (None with ProxyJump or a shared connection; the host
  # then uses its most recently used client.)
  port="$(lsof -a -nP -p "${ssh_pid}" -iTCP -sTCP:ESTABLISHED -Fn 2>/dev/null |
    sed -nE 's/^n.*:([0-9]+)->.*/\1/p' | head -n 1)"
  match="${port:+port:${port}}"
fi

# ── Fetch ─────────────────────────────────────────────────────────────────

mkdir -p "${downloads}"
tmp="$(mktemp -d "${downloads}/.download-latest.XXXXXX")" || fail "Can't write to ${downloads}."
trap 'rm -rf "${tmp}"' EXIT

# fetch [--force]: runs send-latest.sh into ${tmp}/stream.
fetch() {
  if [[ -n "${ssh_pid}" ]]; then
    ssh -T -o BatchMode=yes -o ConnectTimeout=10 -o ClearAllForwardings=yes -o RequestTTY=no \
      -o RemoteCommand=none -o LogLevel=ERROR ${ssh_opts[@]+"${ssh_opts[@]}"} "${ssh_dest}" \
      "exec \"\$HOME/.tmux/send-latest.sh\" ${mode} ${match:-any} ${1:-}" >"${tmp}/stream" 2>"${tmp}/err"
  else
    "${HOME}/.tmux/send-latest.sh" "${mode}" "${match}" "${1:-}" >"${tmp}/stream" 2>"${tmp}/err"
  fi
}

# Reads the status line (skipping anything a login script printed first),
# then unpacks the archive that follows it into ${tmp}/out.
unpack() {
  local line="" kind
  exec 3<"${tmp}/stream"
  while IFS= read -r line <&3; do
    [[ "${line}" == send-latest$'\t'* ]] && break
    line=""
  done
  if [[ -z "${line}" ]]; then
    if grep -q 'send-latest.sh' "${tmp}/err"; then
      fail "${ssh_dest:-This Mac} has no ~/.tmux/send-latest.sh. Run bootstrap.sh there."
    fi
    fail "$(head -n 3 "${tmp}/err" | tr '\n' ' ')"
  fi
  IFS=$'\t' read -r _ kind name <<<"${line}"
  case "${kind}" in
    ok)
      mkdir "${tmp}/out"
      tar -xzf - -C "${tmp}/out" <&3 || fail "Couldn't unpack ${name}."
      ;;
    big) ;;
    *) fail "${name}" ;;
  esac
  exec 3<&-
  status="${kind}"
}

fetch
unpack
if [[ "${status}" == big ]]; then
  [[ "$(confirm_big "${name}")" == Download ]] || exit 0
  fetch --force
  unpack
fi

# ── Save ──────────────────────────────────────────────────────────────────

src="${tmp}/out/${name}"
[[ -e "${src}" ]] || fail "The download didn't contain ${name}."

# Never overwrite: report.html, then "report (1).html", "report (2).html", ...
dest="${downloads}/${name}"
if [[ -e "${dest}" ]]; then
  base="${dest}" ext=""
  if [[ -f "${src}" && "${name}" == ?*.* ]]; then
    base="${dest%.*}" ext=".${name##*.}"
  fi
  n=1
  while [[ -e "${base} (${n})${ext}" ]]; do n=$((n + 1)); done
  dest="${base} (${n})${ext}"
fi
mv "${src}" "${dest}" || fail "Couldn't move ${name} into ${downloads}."

if [[ -d "${dest}" ]]; then
  notify "Saved to Downloads" "${dest##*/}/ ($(find "${dest}" -type f | wc -l | tr -d ' ') files)"
else
  notify "Saved to Downloads" "${dest##*/}"
fi
printf '%s\n' "${dest}"
