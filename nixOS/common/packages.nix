# common/packages.nix — Nix garbage collection/store optimization, and
# system-wide (not user-specific) packages.
{ config, pkgs, lib, vars, ... }:

{
  # Without this, every rebuild leaves the old generation in the store
  # and disk usage only ever grows. Weekly GC keeps the last 2
  # generations, and store optimization deduplicates identical files
  # across packages/generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-generations +2";
  };
  nix.settings.auto-optimise-store = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    htop
    btop      # nicer/interactive alternative to htop
    ncdu      # find what's actually eating disk space
    jq        # parse JSON — handy for the couchdb/curl checks we've been doing by hand
    tmux      # persistent sessions over SSH — survives disconnects
    restic    # for manual backup/restore/inspection — see doc/backups.md
    ffmpeg
    docker-compose
    nodejs    # includes npm — no separate package needed
  ];
}
