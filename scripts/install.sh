#!/usr/bin/env bash
# install.sh
# Lives in the dotfiles repo's scripts/ folder; the actual nix files
# live in ../nixOS/ (repo-root/nixOS/, a sibling of scripts/).
#
# MULTI-HOST: this repo defines several machine profiles under
# nixOS/hosts/<name>/ (each with its own vars.nix; shared defaults live
# in hosts/defaults.nix). This script:
#   1. Lets you pick which host you're installing/updating right now —
#      pass it as an argument (`./install.sh dusty`) or get an
#      interactive menu if you don't.
#   2. Copies the WHOLE nixOS/ tree into /etc/nixos — every host's files
#      need to exist for the flake to evaluate at all, even though only
#      one host actually gets built right now. Each host's
#      hardware-configuration.nix is protected: never overwritten if a
#      real one already exists at the destination.
#   3. Clones the selected host's projectRepos into its projectsDir.

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

if ! command -v jq >/dev/null 2>&1; then
  echo "!! This script needs 'jq'. On a fresh machine before the first rebuild: nix-shell -p jq" >&2
  exit 1
fi

# --- 0. Pick which host --------------------------------------------------
HOST="${1:-}"

list_hosts() {
  find "$NIXOS_SRC_DIR/hosts" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

if [ -z "$HOST" ]; then
  mapfile -t AVAILABLE < <(list_hosts)
  if [ ${#AVAILABLE[@]} -eq 0 ]; then
    echo "!! No hosts found under $NIXOS_SRC_DIR/hosts" >&2
    exit 1
  fi
  if [ -t 0 ]; then
    echo "Which host are you installing/updating?"
    select choice in "${AVAILABLE[@]}"; do
      if [ -n "$choice" ]; then
        HOST="$choice"
        break
      fi
    done
  else
    echo "!! No host given and not an interactive terminal. Usage: $0 <host>" >&2
    echo "   Available hosts: ${AVAILABLE[*]}" >&2
    exit 1
  fi
fi

if [ ! -d "$NIXOS_SRC_DIR/hosts/$HOST" ]; then
  echo "!! Unknown host '$HOST' — no directory at $NIXOS_SRC_DIR/hosts/$HOST" >&2
  exit 1
fi

echo "==> Installing/updating host: $HOST"

# --- 0b. Warn if shared default passwords are still in hosts/defaults.nix ---
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

  grep -q 'gitAdminPass[[:space:]]*=[[:space:]]*"changeme-git"' "$vars_file" \
    && found_defaults+=("gitAdminPass ('changeme-git')")

  if [ ${#found_defaults[@]} -eq 0 ]; then
    return 0
  fi

  echo "!! WARNING: hosts/defaults.nix still has default placeholder password(s), shared by every host:"
  for d in "${found_defaults[@]}"; do
    echo "     - $d"
  done

  if [ ! -t 0 ]; then
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

check_default_passwords "$NIXOS_SRC_DIR/hosts/defaults.nix"

# --- 1. Copy the whole nixOS/ tree into /etc/nixos -----------------------
echo "==> Copying $NIXOS_SRC_DIR into $NIXOS_DIR"
sudo mkdir -p "$NIXOS_DIR"

# Preserve any existing REAL hardware-configuration.nix files (per host)
# before wiping — never let the repo's placeholders clobber a real one.
TMP_HW_BACKUP="$(mktemp -d)"
if [ -d "$NIXOS_DIR/hosts" ]; then
  for hostDir in "$NIXOS_DIR"/hosts/*/; do
    [ -d "$hostDir" ] || continue
    hwFile="$hostDir/hardware-configuration.nix"
    if [ -f "$hwFile" ]; then
      hostName="$(basename "$hostDir")"
      mkdir -p "$TMP_HW_BACKUP/$hostName"
      sudo cp "$hwFile" "$TMP_HW_BACKUP/$hostName/hardware-configuration.nix"
    fi
  done
fi

sudo rm -rf "$NIXOS_DIR"
sudo mkdir -p "$NIXOS_DIR"
sudo cp -r "$NIXOS_SRC_DIR"/. "$NIXOS_DIR"/

for hostNameDir in "$TMP_HW_BACKUP"/*/; do
  [ -d "$hostNameDir" ] || continue
  hostName="$(basename "$hostNameDir")"
  if [ -f "$hostNameDir/hardware-configuration.nix" ]; then
    sudo cp "$hostNameDir/hardware-configuration.nix" "$NIXOS_DIR/hosts/$hostName/hardware-configuration.nix"
    echo "==> Preserved existing real hardware-configuration.nix for host '$hostName'"
  fi
done
rm -rf "$TMP_HW_BACKUP"

# secrets.yaml (sops-nix) lives at the repo root, not inside nixOS/ —
# only present once you've done the doc/secrets.md setup.
SECRETS_SRC="$REPO_ROOT/secrets.yaml"
if [ -f "$SECRETS_SRC" ]; then
  sudo cp "$SECRETS_SRC" "$NIXOS_DIR/secrets.yaml"
  echo "==> Copied secrets.yaml"
fi

# --- 2. Clone this host's project repos ----------------------------------
PROJECTS_DIR="$(nix --extra-experimental-features 'nix-command' eval --raw --file "$NIXOS_SRC_DIR/hosts/defaults.nix" projectsDir 2>/dev/null || echo "/data/projects")"

mapfile -t REPOS < <(
  nix --extra-experimental-features 'nix-command' eval --json \
    --file "$NIXOS_SRC_DIR/hosts/$HOST/vars.nix" projectRepos 2>/dev/null \
    | jq -r '.[]' 2>/dev/null || true
)

if [ ${#REPOS[@]} -eq 0 ]; then
  echo "==> No projectRepos declared for host '$HOST', skipping project cloning"
else
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
fi

echo "==> Done."
echo "    Run: sudo nixos-rebuild switch --flake $NIXOS_DIR#$HOST"
