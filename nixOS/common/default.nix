# common/default.nix
# Everything shared between every target this flake can build for (the
# real machine / VM, and NixOS-WSL). Anything genuinely specific to one
# target — bootloader, disk hardware, WSL interop — lives in that
# target's own file (configuration.nix / wsl-configuration.nix) instead.
#
# This directory used to be a single common.nix; split into one file per
# concern so each is small enough to review/change in isolation. Import
# order doesn't matter — NixOS merges all of these together.
{
  imports = [
    ./base.nix
    ./storage.nix
    ./networking.nix
    ./jellyfin.nix
    ./couchdb.nix
    ./forgejo.nix
    ./ai.nix
    ./n8n.nix
    ./monitoring-hub.nix
    ./docker.nix
    ./sftp.nix
    ./backups.nix
    ./monitoring.nix
    ./packages.nix
  ];
}
