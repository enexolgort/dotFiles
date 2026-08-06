#!/usr/bin/env bash
# post-install.sh
# One-time manual steps to run after `nixos-rebuild switch` succeeds.
# These aren't things NixOS can set declaratively (loginctl linger state
# isn't managed by a nix option, tailscale/passwd need interactive input),
# so they live here instead of in configuration.nix.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARS_FILE="$SCRIPT_DIR/nixOS/vars.nix"

if [ -f "$VARS_FILE" ]; then
  USERNAME="$(nix eval --raw --file "$VARS_FILE" username)"
else
  echo "!! Could not find $VARS_FILE, falling back to \$USER ($USER)"
  USERNAME="$USER"
fi

echo "==> Enabling linger for $USERNAME (keeps user services, e.g. the Emacs daemon, running without an active login session)"
sudo loginctl enable-linger "$USERNAME"

echo "==> Done."
echo
echo "Still manual (not scriptable, need interactive input):"
echo "  - sudo tailscale up --ssh        # one-time tailnet login"
echo "  - passwd                          # replace the initial placeholder password"
echo "  - sudo smbpasswd -a $USERNAME     # only if you're using the Samba share"