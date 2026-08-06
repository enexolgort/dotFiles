#!/usr/bin/env bash
# install.sh
# Run from inside the dotfiles repo's nixOS/ subfolder.
#
# 1. Symlinks flake.nix, configuration.nix, home.nix from this repo into
#    /etc/nixos, so `nixos-rebuild` always uses the version in your repo.
#    hardware-configuration.nix is left alone if a real one already
#    exists at /etc/nixos (it's machine-specific, never something you
#    want overwritten by the placeholder in git).
# 2. Creates ~/projects and clones transmission-API + transmission-webUi
#    into it (skips any repo that's already cloned).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="/etc/nixos"

# --- 1. Link the NixOS config into /etc/nixos --------------------------
echo "==> Linking NixOS config from $SCRIPT_DIR into $NIXOS_DIR"
sudo mkdir -p "$NIXOS_DIR"

for f in flake.nix configuration.nix home.nix vars.nix; do
  src="$SCRIPT_DIR/$f"
  dst="$NIXOS_DIR/$f"

  if [ ! -f "$src" ]; then
    echo "!! $src not found, skipping $f"
    continue
  fi

  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "==> $f already linked, skipping"
    continue
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "==> Backing up existing $dst -> $dst.bak"
    sudo mv "$dst" "$dst.bak"
  fi

  sudo ln -sf "$src" "$dst"
  echo "==> Linked $f"
done

# hardware-configuration.nix: only put ours in place if there ISN'T
# already a real one (e.g. very first run, right after nixos-generate-config
# hasn't been merged in yet). Never clobber a real machine-specific one.
if [ ! -e "$NIXOS_DIR/hardware-configuration.nix" ]; then
  echo "==> No hardware-configuration.nix at $NIXOS_DIR — copying placeholder from repo"
  echo "    Replace this with your real generated one before installing/rebuilding!"
  sudo cp "$SCRIPT_DIR/hardware-configuration.nix" "$NIXOS_DIR/hardware-configuration.nix"
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

echo "==> Done. Run 'sudo nixos-rebuild switch --flake $NIXOS_DIR#scrapy' to apply."
