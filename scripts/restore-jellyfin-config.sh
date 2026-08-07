#!/usr/bin/env bash
# restore-jellyfin-config.sh
# Restores a snapshot created by export-jellyfin-config.sh back into
# /var/lib/jellyfin. Run this ON THE SERVER. Stops Jellyfin during the
# restore and restarts it after.
#
# Usage:
#   ./restore-jellyfin-config.sh [--input-dir <path>] [--force]
#
# --input-dir  Default: ./jellyfin (matches export-jellyfin-config.sh's
#              default --output-dir)
# --force      Skip the confirmation prompt (useful for scripting; still
#              backs up the current state first regardless)

set -euo pipefail

JELLYFIN_DATA_DIR="/var/lib/jellyfin"
INPUT_DIR="./jellyfin"
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input-dir) INPUT_DIR="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^#//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ ! -d "$INPUT_DIR/raw" ]; then
  echo "!! No $INPUT_DIR/raw found — nothing to restore from." >&2
  echo "   Expected the output of export-jellyfin-config.sh (--input-dir here should match its --output-dir)." >&2
  exit 1
fi

echo "==> This will STOP Jellyfin and REPLACE its current config/data/library-links/plugins"
echo "    with the contents of: $INPUT_DIR/raw"
echo "    The current live state will be backed up first (see below), but this is still"
echo "    a destructive operation on the running server."

if [ "$FORCE" != true ]; then
  if [ -t 0 ]; then
    read -rp "    Continue? [y/N] " reply
    case "$reply" in
      [yY]|[yY][eE][sS]) ;;
      *) echo "Aborted."; exit 1 ;;
    esac
  else
    echo "!! Not an interactive terminal and --force not given — aborting rather than guessing." >&2
    exit 1
  fi
fi

echo "==> Stopping Jellyfin"
sudo systemctl stop jellyfin

# Safety net: back up whatever's currently live before overwriting it,
# in case the restore itself needs undoing.
SAFETY_BACKUP="/var/lib/jellyfin.pre-restore.$(date +%Y%m%d-%H%M%S)"
echo "==> Backing up current live state to $SAFETY_BACKUP first"
sudo cp -r "$JELLYFIN_DATA_DIR" "$SAFETY_BACKUP"
echo "    (if anything goes wrong, restore it with: sudo systemctl stop jellyfin && sudo rm -rf $JELLYFIN_DATA_DIR && sudo mv $SAFETY_BACKUP $JELLYFIN_DATA_DIR && sudo systemctl start jellyfin)"

echo "==> Restoring from $INPUT_DIR/raw"
for sub in config data root plugins; do
  if [ -d "$INPUT_DIR/raw/$sub" ]; then
    sudo rm -rf "${JELLYFIN_DATA_DIR:?}/$sub"
    sudo cp -r "$INPUT_DIR/raw/$sub" "$JELLYFIN_DATA_DIR/$sub"
    echo "    restored $sub/"
  else
    echo "    (skipped $sub/ — not present in snapshot)"
  fi
done

echo "==> Fixing ownership back to jellyfin:jellyfin"
sudo chown -R jellyfin:jellyfin "$JELLYFIN_DATA_DIR"

echo "==> Starting Jellyfin"
sudo systemctl start jellyfin

sleep 2
if systemctl is-active --quiet jellyfin; then
  echo "==> Done. Jellyfin is running."
else
  echo "!! Jellyfin did not come back up cleanly — check: sudo journalctl -u jellyfin -e" >&2
  echo "   Your pre-restore state is still safe at: $SAFETY_BACKUP" >&2
  exit 1
fi
