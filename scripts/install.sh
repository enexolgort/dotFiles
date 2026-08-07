#!/usr/bin/env bash
# install.sh
# Lives in the dotfiles repo's scripts/ folder; the actual nix files
# live in ../nixOS/ (i.e. repo-root/nixOS/, a sibling of scripts/).
#
# 1. Copies flake.nix, configuration.nix, home.nix, vars.nix from
#    ../nixOS/ into /etc/nixos. hardware-configuration.nix is left alone
#    if a real one already exists at /etc/nixos (it's machine-specific,
#    never something you want overwritten by the placeholder in git).
#    NOTE: these are plain copies, not symlinks — editing files in the
#    repo won't take effect until you re-run this script.
# 2. Creates the projects dir (path from vars.nix's projectsDir, default
#    /data/projects) and clones transmission-API + transmission-webUi
#    into it (skips any repo that's already cloned).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NIXOS_SRC_DIR="$REPO_ROOT/nixOS"
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

# --- 0b. Prompt for which optional services to enable --------------------
# Edits vars.nix in place based on the answers, so the choice persists
# (not just for this run) — Enter keeps whatever's currently set.
_prompt_toggle() {
  local vars_file="$1" key="$2" question="$3"
  local current

  current="$(grep -E "^\s*${key}\s*=\s*(true|false)\s*;" "$vars_file" 2>/dev/null \
    | grep -oE '(true|false)' | head -1)"
  [ -z "$current" ] && current="true"

  local reply new
  read -rp "   $question [currently: $current] (y/n, Enter to keep) " reply
  case "$reply" in
    "") return 0 ;; # keep current
    [yY]|[yY][eE][sS]) new="true" ;;
    [nN]|[nN][oO]) new="false" ;;
    *) echo "   Unrecognized input, keeping current ($current)"; return 0 ;;
  esac

  if [ "$new" != "$current" ]; then
    sed -i "s/${key} = ${current};/${key} = ${new};/" "$vars_file"
    echo "   -> set $key = $new"
  fi
}

prompt_optional_services() {
  local vars_file="$1"

  if [ ! -f "$vars_file" ]; then
    return 0
  fi

  if [ ! -t 0 ]; then
    echo "==> Non-interactive shell — leaving jellyfinEnable/obsidianEnable/gitServerEnable in vars.nix as-is"
    return 0
  fi

  echo
  echo "==> Optional services (Enter keeps the current vars.nix setting):"
  _prompt_toggle "$vars_file" "jellyfinEnable" "Enable Jellyfin (media server)?"
  _prompt_toggle "$vars_file" "obsidianEnable" "Enable Obsidian sync backend (CouchDB)?"
  _prompt_toggle "$vars_file" "gitServerEnable" "Enable self-hosted git server (Forgejo)?"
  echo
}

prompt_optional_services "$NIXOS_SRC_DIR/vars.nix"

# --- 1. Copy the NixOS config into /etc/nixos ---------------------------
echo "==> Copying NixOS config from $NIXOS_SRC_DIR into $NIXOS_DIR"
sudo mkdir -p "$NIXOS_DIR"

for f in flake.nix configuration.nix wsl-configuration.nix home.nix vars.nix; do
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

# common/ is a directory (split into per-service .nix files) — sync it
# wholesale rather than file by file, since files can be added/removed
# there over time.
if [ -d "$NIXOS_SRC_DIR/common" ]; then
  if [ -d "$NIXOS_DIR/common" ] && diff -rq "$NIXOS_SRC_DIR/common" "$NIXOS_DIR/common" >/dev/null 2>&1; then
    echo "==> common/ already up to date, skipping"
  else
    if [ -e "$NIXOS_DIR/common" ]; then
      echo "==> Backing up existing $NIXOS_DIR/common -> $NIXOS_DIR/common.bak"
      sudo rm -rf "$NIXOS_DIR/common.bak"
      sudo cp -r "$NIXOS_DIR/common" "$NIXOS_DIR/common.bak"
    fi
    sudo rm -rf "$NIXOS_DIR/common"
    sudo cp -r "$NIXOS_SRC_DIR/common" "$NIXOS_DIR/common"
    echo "==> Copied common/"
  fi
else
  echo "!! $NIXOS_SRC_DIR/common not found, skipping"
fi

# secrets.yaml (sops-nix) lives at the repo root, not inside nixOS/ —
# only present once you've done the doc/secrets.md setup. Copied here
# too since /etc/nixos is where the flake actually evaluates from, so
# common/base.nix's relative path to it needs it to physically be here.
SECRETS_SRC="$REPO_ROOT/secrets.yaml"
if [ -f "$SECRETS_SRC" ]; then
  if [ -f "$NIXOS_DIR/secrets.yaml" ] && cmp -s "$SECRETS_SRC" "$NIXOS_DIR/secrets.yaml"; then
    echo "==> secrets.yaml already up to date, skipping"
  else
    sudo cp "$SECRETS_SRC" "$NIXOS_DIR/secrets.yaml"
    echo "==> Copied secrets.yaml"
  fi
fi

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

# --- 2. Set up the projects dir and clone the repos ---------------------
# Read the actual path from vars.nix rather than hardcoding it, so this
# stays correct if you ever change projectsDir.
if command -v nix >/dev/null 2>&1; then
  PROJECTS_DIR="$(nix eval --raw --file "$NIXOS_SRC_DIR/vars.nix" projectsDir 2>/dev/null || echo "")"
fi
if [ -z "${PROJECTS_DIR:-}" ]; then
  PROJECTS_DIR="/data/projects"
  echo "!! Could not read projectsDir from vars.nix (nix not available or eval failed), defaulting to $PROJECTS_DIR"
fi

REPOS=(
  "https://github.com/enexolgort/transmission-API"
  "https://github.com/enexolgort/transmission-webUi"
)

# /data is root-owned by default, so plain mkdir would fail here on a
# fresh machine before the first rebuild has run the tmpfiles rule that
# creates $PROJECTS_DIR with correct ownership. This makes it work
# either way — harmless no-op if the directory and ownership are already
# correct (the normal case, after at least one rebuild).
sudo mkdir -p "$PROJECTS_DIR"
sudo chown "$(id -u):$(id -g)" "$PROJECTS_DIR"
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
