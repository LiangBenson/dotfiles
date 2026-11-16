#!/usr/bin/env bash
#
# Sets up macOS or Linux from this repo in one command. Safe to re-run: it
# skips whatever is already installed and backs up files it would replace.
#
#   git clone https://github.com/liangbenson/dotfiles ~/dotfiles && ~/dotfiles/bootstrap.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
LOCAL_BIN="${HOME}/.local/bin"
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Repo folders linked into ~ with stow (ghostty is added on macOS only).
STOW_PACKAGES=(nvim tmux zsh)

# macOS: everything comes from Homebrew.
BREW_FORMULAS=(stow tmux neovim fzf ripgrep fd tree-sitter-cli glow lazygit)
BREW_CASKS=(ghostty font-fira-code-nerd-font)

# Linux: only these come from the system package manager (with sudo, and only
# the missing ones). The other tools go in ~/.local/bin; see install_linux_tools.
LINUX_PACKAGES=(zsh git tmux stow curl unzip gcc make)

ZSH_PLUGINS=(
  https://github.com/Aloxaf/fzf-tab
  https://github.com/romkatv/powerlevel10k
  https://github.com/zsh-users/zsh-autosuggestions
  https://github.com/zsh-users/zsh-completions
  https://github.com/zsh-users/zsh-syntax-highlighting
)

# ~/.tmux.conf loads these directly, so there's no tmux plugin manager step.
TMUX_PLUGINS=(
  https://github.com/tmux-plugins/tmux-resurrect
  https://github.com/tmux-plugins/tmux-continuum
)

log() { printf '==> %s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── macOS ─────────────────────────────────────────────────────────────────

setup_macos() {
  if ! have brew; then
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # A fresh install isn't on PATH yet (new shells get it from ~/.zprofile).
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  have brew || fail "Homebrew is installed, but brew isn't on PATH."

  local pkg missing=()
  for pkg in "${BREW_FORMULAS[@]}"; do
    brew list --formula "${pkg}" >/dev/null 2>&1 || missing+=("${pkg}")
  done
  if ((${#missing[@]})); then
    log "Installing ${missing[*]}"
    brew install "${missing[@]}"
  fi

  for pkg in "${BREW_CASKS[@]}"; do
    brew list --cask "${pkg}" >/dev/null 2>&1 && continue
    log "Installing ${pkg}"
    # Fails if the app or font was installed some other way, which is fine.
    brew install --cask "${pkg}" || warn "Couldn't install ${pkg}; skipping it."
  done
}

# ── Linux ─────────────────────────────────────────────────────────────────

SUDO_OK=""

# Asks for the sudo password once; remembers the answer.
can_sudo() {
  if [[ -z "${SUDO_OK}" ]]; then
    if [[ "${EUID}" -eq 0 ]] || { have sudo && sudo -v; }; then
      SUDO_OK=yes
    else
      SUDO_OK=no
    fi
  fi
  [[ "${SUDO_OK}" == yes ]]
}

as_root() {
  if [[ "${EUID}" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

install_system_package() {
  if have apt-get; then as_root apt-get install -y "$1"
  elif have dnf; then as_root dnf install -y "$1"
  elif have yum; then as_root yum install -y "$1"
  elif have pacman; then as_root pacman -S --needed --noconfirm "$1"
  elif have zypper; then as_root zypper install -y "$1"
  elif have apk; then as_root apk add "$1"
  else return 1
  fi
}

setup_linux() {
  local pkg missing=()
  for pkg in "${LINUX_PACKAGES[@]}"; do
    have "${pkg}" || missing+=("${pkg}")
  done

  if ((${#missing[@]})); then
    if can_sudo; then
      log "Installing ${missing[*]}"
      if have apt-get; then
        as_root apt-get update -qq || warn "apt-get update failed; trying anyway."
      fi
      for pkg in "${missing[@]}"; do
        install_system_package "${pkg}" || warn "Couldn't install ${pkg}."
      done
    else
      warn "No sudo, so skipping: ${missing[*]}. Ask an admin to install them, then re-run."
    fi
  fi

  for pkg in git curl stow; do
    have "${pkg}" || fail "${pkg} is required. (On RHEL or Amazon Linux, stow comes from EPEL.)"
  done

  install_linux_tools
}

latest_tag() {
  local url
  url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest")"
  printf '%s\n' "${url##*/}"
}

# install_tarball <command> <url of a .tar.gz> <path of the binary inside it>
install_tarball() {
  local tmp
  tmp="$(mktemp -d)"
  log "Installing $1 into ~/.local/bin"
  curl -fsSL "$2" | tar -xz -C "${tmp}"
  install -m 755 "${tmp}/$3" "${LOCAL_BIN}/$1"
  rm -rf "${tmp}"
}

need() { [[ ! -x "${LOCAL_BIN}/$1" ]]; }

# Removes a downloaded tool that can't run here (its build needs a newer glibc).
check_runs() {
  "${LOCAL_BIN}/$1" --version >/dev/null 2>&1 && return 0
  rm -f "${LOCAL_BIN}/$1"
  warn "$1 doesn't run on this system (needs glibc $2 or newer). $3"
}

# Linux tools come from their GitHub releases: distro packages are often too
# old (Neovim, fzf) or renamed (fd), and this needs no sudo. To update one,
# delete it from ~/.local/bin and re-run.
install_linux_tools() {
  # Each project spells the CPU type differently in its download names.
  local tag arch go_arch=amd64 short_arch=x64 alt_arch=x86_64
  case "$(uname -m)" in
    x86_64 | amd64) arch=x86_64 ;;
    aarch64 | arm64) arch=aarch64 go_arch=arm64 short_arch=arm64 alt_arch=arm64 ;;
    *)
      warn "No prebuilt tools for $(uname -m); install nvim, fzf, rg, fd, glow, lazygit and tree-sitter yourself."
      return 0
      ;;
  esac

  if need nvim; then
    log "Installing nvim into ~/.local/bin"
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${alt_arch}.tar.gz" |
      tar -xz -C "${HOME}/.local/share"
    ln -sf "${HOME}/.local/share/nvim-linux-${alt_arch}/bin/nvim" "${LOCAL_BIN}/nvim"
    check_runs nvim 2.34 "The Neovim config needs Neovim 0.12+."
  fi

  if need fzf; then
    tag="$(latest_tag junegunn/fzf)"
    install_tarball fzf \
      "https://github.com/junegunn/fzf/releases/download/${tag}/fzf-${tag#v}-linux_${go_arch}.tar.gz" fzf
  fi

  if need rg; then
    tag="$(latest_tag BurntSushi/ripgrep)"
    install_tarball rg \
      "https://github.com/BurntSushi/ripgrep/releases/download/${tag}/ripgrep-${tag}-${arch}-unknown-linux-musl.tar.gz" \
      "ripgrep-${tag}-${arch}-unknown-linux-musl/rg"
  fi

  if need fd; then
    tag="$(latest_tag sharkdp/fd)"
    install_tarball fd \
      "https://github.com/sharkdp/fd/releases/download/${tag}/fd-${tag}-${arch}-unknown-linux-musl.tar.gz" \
      "fd-${tag}-${arch}-unknown-linux-musl/fd"
  fi

  if need glow; then
    tag="$(latest_tag charmbracelet/glow)"
    install_tarball glow \
      "https://github.com/charmbracelet/glow/releases/download/${tag}/glow_${tag#v}_Linux_${alt_arch}.tar.gz" \
      "glow_${tag#v}_Linux_${alt_arch}/glow"
  fi

  if need lazygit; then
    tag="$(latest_tag jesseduffield/lazygit)"
    install_tarball lazygit \
      "https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${tag#v}_linux_${alt_arch}.tar.gz" lazygit
  fi

  if need tree-sitter; then
    log "Installing tree-sitter into ~/.local/bin"
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-${short_arch}.gz" |
      gunzip >"${LOCAL_BIN}/tree-sitter"
    chmod +x "${LOCAL_BIN}/tree-sitter"
    check_runs tree-sitter 2.39 "Neovim uses its regular syntax highlighting instead."
  fi
}

# ── Both ──────────────────────────────────────────────────────────────────

# clone_plugins <folder> <git url>...
clone_plugins() {
  local dir="$1" url
  shift
  for url in "$@"; do
    [[ -d "${dir}/${url##*/}" ]] && continue
    log "Cloning ${url##*/}"
    git clone --quiet --depth 1 "${url}" "${dir}/${url##*/}"
  done
}

link_dotfiles() {
  local pkg file target packages=("${STOW_PACKAGES[@]}")
  if [[ "${OS}" == macos ]]; then
    packages+=(ghostty)
  fi

  # Move real files out of the way so stow can link over them.
  for pkg in "${packages[@]}"; do
    while IFS= read -r file; do
      target="${HOME}/${file#"${REPO_ROOT}/${pkg}/"}"
      [[ -e "${target}" && ! -L "${target}" ]] || continue
      # Already a file in this repo, reached through a linked folder.
      [[ "$(cd "$(dirname "${target}")" && pwd -P)/" == "${REPO_ROOT}/"* ]] && continue
      mkdir -p "$(dirname "${BACKUP_DIR}/${target#"${HOME}/"}")"
      mv "${target}" "${BACKUP_DIR}/${target#"${HOME}/"}"
      log "Moved ~/${target#"${HOME}/"} to ${BACKUP_DIR}"
    done < <(find "${REPO_ROOT}/${pkg}" -type f)
  done

  log "Linking ${packages[*]} into ~"
  stow --restow --dir "${REPO_ROOT}" --target "${HOME}" "${packages[@]}"

  # Have macOS pick up the Quick Actions (ghostty/Library/Services) now
  # instead of at the next login.
  if [[ "${OS}" == macos ]]; then
    /System/Library/CoreServices/pbs -update
  fi
}

# Plugins at the versions in lazy-lock.json, plus treesitter parsers. Language
# servers install the first time Neovim opens with a window (Mason skips
# headless runs).
install_nvim_plugins() {
  have nvim || return 0
  log "Installing Neovim plugins"
  nvim --headless "+Lazy! restore" +qa >/dev/null ||
    warn "Installing Neovim plugins failed; open nvim to see why."
}

use_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh)" || return 0
  [[ "${SHELL:-}" == */zsh ]] && return 0

  log "Making zsh your login shell"
  if ! grep -qxF "${zsh_path}" /etc/shells && can_sudo; then
    echo "${zsh_path}" | as_root tee -a /etc/shells >/dev/null
  fi
  if can_sudo && as_root chsh -s "${zsh_path}" "$(id -un)"; then
    return 0
  fi
  chsh -s "${zsh_path}" ||
    warn "Couldn't change your login shell. Run 'chsh -s ${zsh_path}', or add 'exec zsh -l' to the end of ~/.bashrc."
}

main() {
  case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux) OS=linux ;;
    *) fail "Unsupported system: $(uname -s)" ;;
  esac
  export PATH="${LOCAL_BIN}:${PATH}"
  log "Setting up ${OS} from ${REPO_ROOT}"

  # Create these before stow runs, so stow links the files inside ~/.zsh and
  # ~/.tmux one by one instead of turning those folders into links to this repo
  # (the plugins would then be cloned into the repo).
  mkdir -p "${LOCAL_BIN}" "${HOME}/.local/share" "${HOME}/.zsh/plugins" "${HOME}/.tmux/plugins"

  if [[ "${OS}" == macos ]]; then
    setup_macos
  else
    setup_linux
  fi

  clone_plugins "${HOME}/.zsh/plugins" "${ZSH_PLUGINS[@]}"
  clone_plugins "${HOME}/.tmux/plugins" "${TMUX_PLUGINS[@]}"
  link_dotfiles
  install_nvim_plugins
  use_zsh
  log "Done. Open a new terminal, or run: exec zsh -l"
}

main "$@"
