#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_DIR="${XDG_CONFIG_HOME:-"$HOME/.config"}"

log()  { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "!!  $*" >&2; }
die()  { printf '%s\n' "ERR: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  install-environment.sh [--dwm|--qtile|--both] [--copy] [--no-backup] [--no-sync]

Notes:
  - Default is interactive if no WM flag is provided.
  - By default configs are symlinked into ~/.config (easy to update).
  - --copy copies files instead of symlinking.
  - --no-sync skips NvChad plugin sync (headless nvim).
EOF
}

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

pm_detect() {
  if command -v pacman >/dev/null 2>&1; then
    PM=pacman
  elif command -v apt-get >/dev/null 2>&1; then
    PM=apt
  elif command -v dnf >/dev/null 2>&1; then
    PM=dnf
  else
    die "unsupported distro (need pacman/apt-get/dnf)"
  fi
}

pm_update() {
  case "$PM" in
    pacman) sudo pacman -Syu --noconfirm ;;
    apt)    sudo apt-get update -y && sudo apt-get upgrade -y ;;
    dnf)    sudo dnf upgrade -y ;;
  esac
}

pm_install() {
  local pkgs=("$@")
  case "$PM" in
    pacman) sudo pacman -S --needed --noconfirm "${pkgs[@]}" ;;
    apt)    sudo apt-get install -y "${pkgs[@]}" ;;
    dnf)    sudo dnf install -y "${pkgs[@]}" ;;
  esac
}

maybe_aur() {
  # Optional: install AUR packages if user has yay/paru
  local pkg="$1"
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm "$pkg"
  elif command -v paru >/dev/null 2>&1; then
    paru -S --needed --noconfirm "$pkg"
  else
    warn "AUR helper not found (yay/paru). skipping: $pkg"
  fi
}

backup() {
  local ts dest
  ts="$(date +%Y%m%d_%H%M%S)"
  dest="$HOME/.config_backup_$ts"
  mkdir -p -- "$dest"

  local p
  for p in alacritty rofi nvim qtile dwm picom; do
    if [[ -e "$CONFIG_DIR/$p" ]]; then
      cp -a -- "$CONFIG_DIR/$p" "$dest/" || true
    fi
  done
  [[ -f "$CONFIG_DIR/starship.toml" ]] && cp -a -- "$CONFIG_DIR/starship.toml" "$dest/" || true
  log "backup: $dest"
}

link_item() {
  # link_item <src> <dst>
  local src="$1" dst="$2"
  mkdir -p -- "$(dirname -- "$dst")"

  if [[ -L "$dst" ]]; then
    # If it already points to us, keep it.
    local cur
    cur="$(readlink -- "$dst")" || true
    [[ "$cur" == "$src" ]] && return 0
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    mv -f -- "$dst" "$dst.bak.$(date +%s)"
  fi

  ln -s -- "$src" "$dst"
}

copy_item() {
  # copy_item <src> <dst>
  local src="$1" dst="$2"
  mkdir -p -- "$(dirname -- "$dst")"
  if [[ -e "$dst" || -L "$dst" ]]; then
    mv -f -- "$dst" "$dst.bak.$(date +%s)"
  fi
  cp -a -- "$src" "$dst"
}

install_cfg() {
  # install_cfg <name>
  local name="$1"
  local src="$SCRIPT_DIR/$name"
  local dst="$CONFIG_DIR/$name"
  [[ -e "$src" ]] || die "missing in repo: $src"

  if [[ "$MODE" == "copy" ]]; then
    copy_item "$src" "$dst"
  else
    link_item "$src" "$dst"
  fi
}

install_common() {
  log "deps: common"
  case "$PM" in
    pacman)
      pm_install git base-devel curl wget unzip \
        alacritty rofi neovim starship picom feh \
        ripgrep fd nodejs npm python python-pip \
        xclip xsel ttf-nerd-fonts-symbols-mono
      ;;
    apt)
      pm_install git curl wget unzip \
        alacritty rofi neovim picom feh \
        ripgrep fd-find nodejs npm python3 python3-pip \
        xclip xsel
      ;;
    dnf)
      pm_install git curl wget unzip \
        alacritty rofi neovim picom feh \
        ripgrep fd-find nodejs npm python3 python3-pip \
        xclip xsel
      ;;
  esac

  if ! command -v starship >/dev/null 2>&1; then
    log "install: starship (official script)"
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi
}

install_dwm_deps() {
  log "deps: dwm"
  case "$PM" in
    pacman) pm_install libx11 libxft libxinerama imlib2 ;;
    apt)    pm_install libx11-dev libxft-dev libxinerama-dev libimlib2-dev ;;
    dnf)    pm_install libX11-devel libXft-devel libXinerama-devel imlib2-devel ;;
  esac
}

install_qtile_deps() {
  log "deps: qtile"
  case "$PM" in
    pacman) pm_install qtile python-psutil python-xcffib python-cairocffi python-dbus-next ;;
    apt)    pm_install qtile python3-psutil python3-xcffib python3-cairocffi ;;
    dnf)    pm_install qtile python3-psutil python3-xcffib python3-cairocffi ;;
  esac

  if ! command -v qtile >/dev/null 2>&1; then
    warn "qtile not in repos; installing via pip (user)"
    if command -v python3 >/dev/null 2>&1; then
      python3 -m pip install --user qtile
    else
      python -m pip install --user qtile
    fi
  fi
}

setup_starship_init() {
  # Keep it conservative: only append if not present.
  local f

  f="$HOME/.bashrc"
  if [[ -f "$f" ]] && ! grep -q 'starship init bash' "$f"; then
    printf '\n# starship\n' >>"$f"
    printf 'eval "$(starship init bash)"\n' >>"$f"
  fi

  f="$HOME/.zshrc"
  if [[ -f "$f" ]] && ! grep -q 'starship init zsh' "$f"; then
    printf '\n# starship\n' >>"$f"
    printf 'eval "$(starship init zsh)"\n' >>"$f"
  fi

  f="$HOME/.config/fish/config.fish"
  if [[ -f "$f" ]] && ! grep -q 'starship init fish' "$f"; then
    printf '\n# starship\n' >>"$f"
    printf 'starship init fish | source\n' >>"$f"
  fi
}

build_dwm() {
  local dir="$CONFIG_DIR/dwm/chadwm"
  [[ -d "$dir" ]] || die "expected: $dir"
  ( cd "$dir" && make clean && sudo make install )
}

fix_perms() {
  [[ -d "$CONFIG_DIR/dwm/scripts" ]] && chmod +x "$CONFIG_DIR/dwm/scripts/"*.sh 2>/dev/null || true
  [[ -f "$CONFIG_DIR/dwm/scripts/fetch" ]] && chmod +x "$CONFIG_DIR/dwm/scripts/fetch" 2>/dev/null || true
  [[ -f "$CONFIG_DIR/qtile/autostart.sh" ]] && chmod +x "$CONFIG_DIR/qtile/autostart.sh" 2>/dev/null || true
}

sync_nvchad() {
  command -v nvim >/dev/null 2>&1 || return 0
  nvim --headless "+Lazy! sync" +qa || warn "nvim sync failed (run :Lazy sync manually)"
}

interactive_pick() {
  printf '%s\n' "Select WM to install:"
  printf '%s\n' "  1) dwm"
  printf '%s\n' "  2) qtile"
  printf '%s\n' "  3) both"
  printf '%s'   "> "
  local c
  read -r c
  case "$c" in
    1) WM=dwm ;;
    2) WM=qtile ;;
    3) WM=both ;;
    *) die "invalid choice" ;;
  esac
}

main() {
  [[ "${EUID:-$(id -u)}" -ne 0 ]] || die "do not run as root"
  need git

  WM=""
  MODE="link"
  DO_BACKUP=1
  DO_SYNC=1

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dwm) WM=dwm ;;
      --qtile) WM=qtile ;;
      --both) WM=both ;;
      --copy) MODE=copy ;;
      --no-backup) DO_BACKUP=0 ;;
      --no-sync) DO_SYNC=0 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown arg: $1 (use --help)" ;;
    esac
    shift
  done

  [[ -n "$WM" ]] || interactive_pick

  pm_detect
  log "pm: $PM"
  log "mode: $MODE"
  log "wm: $WM"

  (( DO_BACKUP )) && backup

  pm_update
  install_common

  # configs
  install_cfg alacritty
  install_cfg rofi
  install_cfg nvim
  install_cfg picom || true
  [[ -f "$SCRIPT_DIR/starship.toml" ]] && install_cfg starship.toml || true

  setup_starship_init

  case "$WM" in
    dwm)
      install_dwm_deps
      install_cfg dwm
      fix_perms
      build_dwm
      ;;
    qtile)
      install_qtile_deps
      install_cfg qtile
      fix_perms
      ;;
    both)
      install_dwm_deps
      install_qtile_deps
      install_cfg dwm
      install_cfg qtile
      fix_perms
      build_dwm
      ;;
    *) die "invalid WM: $WM" ;;
  esac

  (( DO_SYNC )) && sync_nvchad

  log "done"
  warn "if starship doesn't show up: restart your shell"
}

main "$@"
