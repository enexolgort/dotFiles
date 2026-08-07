# common/backups.nix — off by default, see doc/backups.md for setup and
# restore instructions. Backs up: media library, CouchDB's actual data
# directory (your Obsidian notes — easy to forget, genuinely
# irreplaceable), Jellyfin's config/library database, your Forgejo git
# repos, and your dotfiles/projects.
{
  config,
  pkgs,
  lib,
  vars,
  ...
}: {
  services.restic.backups.mediaserver = lib.mkIf vars.backupEnable {
    initialize = true;
    repository = vars.backupRepo;
    passwordFile =
      if vars.secretsEnabled
      then config.sops.secrets.backupPassword.path
      else "/etc/restic-backup-password"; # written below when secrets aren't set up yet
    paths = [
      vars.mediaDir
      "/var/lib/couchdb"
      "/var/lib/jellyfin"
      "/var/lib/forgejo"
      "/home/${vars.username}/dotFiles"
      vars.projectsDir
    ];
    exclude = [
      # Regenerable / often huge — not meaningfully "config", skip them
      "/var/lib/jellyfin/cache"
      "/var/lib/jellyfin/metadata"
      "/var/lib/jellyfin/transcodes"
    ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  # Fallback plaintext password file for restic when sops-nix isn't set
  # up yet — same plaintext-in-store caveat as everything else in
  # vars.nix until secretsEnabled is flipped on. Not created at all if
  # backups are disabled.
  environment.etc."restic-backup-password" = lib.mkIf (vars.backupEnable && !vars.secretsEnabled) {
    text = vars.backupPassword;
    mode = "0400";
  };
}
