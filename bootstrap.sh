#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_HOME="${HOME}/.zsh"
ZSH_PLUGIN_DIR="${ZSH_HOME}/plugins"
TMUX_HOME="${HOME}/.tmux"
TMUX_PLUGIN_DIR="${TMUX_HOME}/plugins"

ZSH_PLUGIN_NAMES=(
  "fzf-tab"
  "powerlevel10k"
  "zsh-autosuggestions"
  "zsh-completions"
  "zsh-syntax-highlighting"
)

ZSH_PLUGIN_URLS=(
  "https://github.com/Aloxaf/fzf-tab"
  "https://github.com/romkatv/powerlevel10k"
  "https://github.com/zsh-users/zsh-autosuggestions"
  "https://github.com/zsh-users/zsh-completions"
  "https://github.com/zsh-users/zsh-syntax-highlighting"
)

TMUX_PLUGIN_NAMES=(
  "tmux-resurrect"
  "tmux-continuum"
)

TMUX_PLUGIN_URLS=(
  "https://github.com/tmux-plugins/tmux-resurrect"
  "https://github.com/tmux-plugins/tmux-continuum"
)

log() {
  printf '==> %s\n' "$1"
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    *) echo "unsupported" ;;
  esac
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  command -v brew >/dev/null 2>&1 || fail "Homebrew installation completed, but brew was not found in PATH."
}

install_with_homebrew() {
  local package="$1"
  install_homebrew
  log "Installing ${package} with Homebrew"
  brew install "${package}"
}

ensure_macos_font() {
  local font_name="$1"
  local font_cask="$2"

  if [[ "$(detect_os)" != "macos" ]]; then
    return
  fi

  if system_profiler SPFontsDataType 2>/dev/null | grep -Fqi "${font_name}"; then
    log "${font_name} is already installed"
    return
  fi

  install_homebrew
  log "Installing ${font_name} with Homebrew"
  brew tap homebrew/cask-fonts >/dev/null 2>&1 || true
  brew install --cask "${font_cask}"
}

install_with_apt() {
  local package="$1"
  if command -v apt-get >/dev/null 2>&1; then
    log "Installing ${package} with apt-get"
    sudo apt-get update
    sudo apt-get install -y "${package}"
  else
    fail "apt-get is required to install ${package} on Linux in v1. Install ${package} manually, then re-run bootstrap.sh."
  fi
}

ensure_package() {
  local command_name="$1"
  local package_name="$2"
  local os_name="$3"

  if command -v "${command_name}" >/dev/null 2>&1; then
    log "${command_name} is already installed"
    return
  fi

  case "${os_name}" in
    macos) install_with_homebrew "${package_name}" ;;
    linux) install_with_apt "${package_name}" ;;
    *) fail "Unsupported operating system: $(uname -s)" ;;
  esac
}

ensure_directories() {
  log "Ensuring Zsh and tmux directories exist"
  mkdir -p "${ZSH_HOME}" "${ZSH_PLUGIN_DIR}" "${TMUX_HOME}" "${TMUX_PLUGIN_DIR}"
}

clone_zsh_plugins() {
  local name
  local url
  local target
  local i

  log "Ensuring Zsh plugins are present"

  for i in "${!ZSH_PLUGIN_NAMES[@]}"; do
    name="${ZSH_PLUGIN_NAMES[$i]}"
    url="${ZSH_PLUGIN_URLS[$i]}"
    target="${ZSH_PLUGIN_DIR}/${name}"
 
    if [[ -d "${target}" ]]; then
      log "Skipping ${name}; ${target} already exists"
      continue
    fi

    log "Cloning ${name}"
    git clone "${url}" "${target}"
  done
}

clone_tmux_plugins() {
  local name
  local url
  local target
  local i

  log "Ensuring tmux plugins are present"

  for i in "${!TMUX_PLUGIN_NAMES[@]}"; do
    name="${TMUX_PLUGIN_NAMES[$i]}"
    url="${TMUX_PLUGIN_URLS[$i]}"
    target="${TMUX_PLUGIN_DIR}/${name}"

    if [[ -d "${target}" ]]; then
      log "Skipping ${name}; ${target} already exists"
      continue
    fi

    log "Cloning ${name}"
    git clone "${url}" "${target}"
  done
}

clone_plugins() {
  clone_zsh_plugins
  clone_tmux_plugins
}

discover_stow_packages() {
  local entry
  for entry in "${REPO_ROOT}"/*; do
    [[ -d "${entry}" ]] || continue
    printf '%s\n' "$(basename "${entry}")"
  done
}

stow_packages() {
  log "Stowing top-level packages"

  local package
  local packages=()

  while IFS= read -r package; do
    [[ -n "${package}" ]] || continue
    packages+=("${package}")
  done < <(discover_stow_packages)

  if [[ "${#packages[@]}" -eq 0 ]]; then
    log "No stow packages found"
    return
  fi

  (
    cd "${REPO_ROOT}"
    stow "${packages[@]}"
  )
}

main() {
  local os_name
  os_name="$(detect_os)"

  log "Bootstrapping dotfiles from ${REPO_ROOT}"
  ensure_package "git" "git" "${os_name}"
  ensure_package "stow" "stow" "${os_name}"
  ensure_package "fzf" "fzf" "${os_name}"
  ensure_package "nvim" "neovim" "${os_name}"
  ensure_package "tmux" "tmux" "${os_name}"
  ensure_macos_font "FiraCode Nerd Font" "font-fira-code-nerd-font"
  ensure_directories
  clone_plugins
  stow_packages
  log "Bootstrap complete"
}

main "$@"
