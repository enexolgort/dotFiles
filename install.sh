#!/usr/bin/env bash
# install.sh
# Lives at the root of the dotfiles repo; the actual nix files live in
# ./nixOS/ next to it.
#
# 1. Copies flake.nix, configuration.nix, home.nix, vars.nix from
#    ./nixOS/ into /etc/nixos. hardware-configuration.nix is left alone
#    if a real one already exists at /etc/nixos (it's machine-specific,
#    never something you want overwritten by the placeholder in git).
#    NOTE: these are plain copies, not symlinks — editing files in the
#    repo won't take effect until you re-run this script.
# 2. Creates ~/projects and clones transmission-API + transmission-webUi
#    into it (skips any repo that's already cloned).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_SRC_DIR="$SCRIPT_DIR/nixOS"
NIXOS_DIR="/etc/nixos"

if [ ! -d "$NIXOS_SRC_DIR" ]; then
  echo "!! Expected nix files at $NIXOS_SRC_DIR but that folder doesn't exist."
  echo "   Adjust NIXOS_SRC_DIR at the top of this script if your repo layout differs."
  exit 1
fi

# --- 0. Warn if vars.nix still has default/placeholder passwords --------
check_default_passwords() {
  local vars_file="$1"
  local found_defaults=()

  if [ ! -f "$vars_file" ]; then
    return 0
  fi

  grep -q 'initialPassword[[:space:]]*=[[:space:]]*"changeme"' "$vars_file" \
    && found_defaults+=("initialPassword ('changeme')")

  grep -q 'couchdbAdminPass[[:space:]]*=[[:space:]]*"changeme-couchdb"' "$vars_file" \
    && found_defaults+=("couchdbAdminPass ('changeme-couchdb')")

  if [ ${#found_defaults[@]} -eq 0 ]; then
    return 0
  fi

  echo "!! WARNING: vars.nix still has default placeholder password(s):"
  for d in "${found_defaults[@]}"; do
    echo "     - $d"
  done
  echo "   These are plaintext, publicly-known defaults from the template."

  if [ ! -t 0 ]; then
    # Not an interactive terminal (e.g. piped/non-interactive run) — can't
    # prompt, so just warn loudly and continue rather than hang or abort.
    echo "   (non-interactive shell, continuing anyway — fix this before relying on the server)"
    return 0
  fi

  read -rp "   Continue anyway with these default passwords? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *)
      echo "Aborted. Edit $vars_file to set real passwords, then re-run this script."
      exit 1
      ;;
  esac
}

check_default_passwords "$NIXOS_SRC_DIR/vars.nix"

# --- 1. Copy the NixOS config into /etc/nixos ---------------------------
echo "==> Copying NixOS config from $NIXOS_SRC_DIR into $NIXOS_DIR"
sudo mkdir -p "$NIXOS_DIR"

for f in flake.nix configuration.nix common.nix wsl-configuration.nix home.nix vars.nix; do
  src="$NIXOS_SRC_DIR/$f"
  dst="$NIXOS_DIR/$f"

  if [ ! -f "$src" ]; then
    echo "!! $src not found, skipping $f"
    continue
  fi

  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    echo "==> $f already up to date, skipping"
    continue
  fi

  if [ -e "$dst" ]; then
    echo "==> Backing up existing $dst -> $dst.bak"
    sudo cp "$dst" "$dst.bak"
  fi

  sudo cp "$src" "$dst"
  echo "==> Copied $f"
done

# hardware-configuration.nix: only put ours in place if there ISN'T
# already a real one (e.g. very first run, right after nixos-generate-config
# hasn't been merged in yet). Never clobber a real machine-specific one.
if [ ! -e "$NIXOS_DIR/hardware-configuration.nix" ]; then
  echo "==> No hardware-configuration.nix at $NIXOS_DIR — copying placeholder from repo"
  echo "    Replace this with your real generated one before installing/rebuilding!"
  sudo cp "$NIXOS_SRC_DIR/hardware-configuration.nix" "$NIXOS_DIR/hardware-configuration.nix"
else
  echo "==> Existing hardware-configuration.nix found at $NIXOS_DIR, leaving it untouched"
fi

# --- 2. Set up ~/projects and clone the repos ---------------------------
PROJECTS_DIR="$HOME/projects"
REPOS=(
  "https://github.com/enexolgort/transmission-API"
  "https://github.com/enexolgort/transmission-webUi"
)

mkdir -p "$PROJECTS_DIR"
echo "==> Projects dir: $PROJECTS_DIR"

for repo_url in "${REPOS[@]}"; do
  name="$(basename "$repo_url")"
  target="$PROJECTS_DIR/$name"

  if [ -d "$target/.git" ]; then
    echo "==> $name already cloned, skipping (run 'git -C \"$target\" pull' to update)"
    continue
  fi

  echo "==> Cloning $name..."
  git clone "$repo_url" "$target"
done

echo "==> Done."
echo "    Real machine: sudo nixos-rebuild switch --flake $NIXOS_DIR#scrapy"
echo "    NixOS-WSL:    sudo nixos-rebuild switch --flake $NIXOS_DIR#scrapy-wsl"