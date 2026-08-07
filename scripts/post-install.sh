#!/usr/bin/env bash
# post-install.sh
# One-time manual steps to run after `nixos-rebuild switch` succeeds.
# These aren't things NixOS can set declaratively (loginctl linger state
# isn't managed by a nix option, tailscale/passwd need interactive input),
# so they live here instead of in configuration.nix.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VARS_FILE="$REPO_ROOT/nixOS/vars.nix"

if [ -f "$VARS_FILE" ]; then
  USERNAME="$(nix eval --raw --file "$VARS_FILE" username)"
else
  echo "!! Could not find $VARS_FILE, falling back to \$USER ($USER)"
  USERNAME="$USER"
fi

echo "==> Enabling linger for $USERNAME (keeps user services, e.g. the Emacs daemon, running without an active login session)"
sudo loginctl enable-linger "$USERNAME"

# --- Doom Emacs: bootstrap if needed, deploy your tracked config from
# the repo's doom/ folder, then sync. Safe to re-run any time — copying
# is a plain overwrite and `doom sync` is idempotent.
DOOM_BIN="$HOME/.config/emacs/bin/doom"
DOOM_CONF="$HOME/.config/doom"
DOOM_SRC_DIR="$REPO_ROOT/doom"

if [ -x "$DOOM_BIN" ]; then
  if [ ! -d "$DOOM_CONF" ]; then
    echo "==> Doom not bootstrapped yet, running 'doom install' first"
    "$DOOM_BIN" install --no-env --no-fonts -!
  fi

  if [ -d "$DOOM_SRC_DIR" ]; then
    echo "==> Deploying tracked Doom config from $DOOM_SRC_DIR to $DOOM_CONF"
    mkdir -p "$DOOM_CONF"
    for f in init.el config.el packages.el; do
      if [ -f "$DOOM_SRC_DIR/$f" ]; then
        cp "$DOOM_SRC_DIR/$f" "$DOOM_CONF/$f"
        echo "    copied $f"
      fi
    done
  else
    echo "!! No doom/ folder found at $DOOM_SRC_DIR — leaving \$DOOM_CONF as-is"
    echo "   (run 'mkdir ~/dotFiles/doom && cp ~/.config/doom/*.el ~/dotFiles/doom/' to start tracking it)"
  fi

  echo "==> Running 'doom sync' to install/update packages and apply config"
  "$DOOM_BIN" sync
else
  echo "!! $DOOM_BIN not found — Emacs/Doom may not have been cloned yet."
  echo "   Run 'sudo nixos-rebuild switch' again first, or check ~/.config/emacs exists."
fi

echo "==> Done."
echo
echo "Still manual (not scriptable, need interactive input):"
echo "  - sudo tailscale up --ssh        # one-time tailnet login"
echo "  - passwd                          # replace the initial placeholder password"
echo "  - sudo smbpasswd -a $USERNAME     # only if you're using the Samba share"
