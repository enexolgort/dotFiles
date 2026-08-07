{
  # ==== System ============================================================
  system = "x86_64-linux"; # aarch64-linux if on ARM
  hostname = "scrapy";
  timeZone = "Europe/Paris";
  locale = "en_US.UTF-8";
  keyMap = "fr"; # AZERTY. Use "be" for Belgian AZERTY, "us" for QWERTY

  # ==== Optional services ===================================================
  # scripts/install.sh prompts for these interactively (Enter keeps the
  # current value) — or just edit them directly here. All default to
  # enabled.
  jellyfinEnable = true;
  obsidianEnable = true; # CouchDB backend for Obsidian Self-hosted LiveSync
  gitServerEnable = true; # Forgejo

  # ==== Main user ==========================================================
  username = "enexolgort";
  initialPassword = "changeme"; # change on first login with: passwd <username>
  gitEmail = "enexolgort@scrapy.local";

  # ==== Storage paths ======================================================
  mediaDir = "/data/media";
  sftpDir = "/data/sftp";
  projectsDir = "/data/projects"; # where install.sh clones your project repos

  # ==== SFTP ===============================================================
  sftpPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... replace-with-your-key sftpuser@yourlaptop";

  # ==== CouchDB / Obsidian LiveSync =======================================
  couchdbAdminUser = "admin";
  couchdbAdminPass = "changeme-couchdb"; # plaintext in the Nix store — see README re: secrets

  # ==== Git server (Forgejo) ================================================
  # NOTE: "admin" itself is a reserved username in Forgejo — pick anything else.
  gitAdminUser = "gituser";
  gitAdminPass = "changeme-git"; # plaintext until secretsEnabled — see doc/secrets.md

  # ==== Samba ==============================================================
  sambaWorkgroup = "WORKGROUP";

  # ==== Extra storage drives (real machine only, e.g. SATA drives on the
  # ZimaBoard) — mounted automatically at boot. Find the UUID with
  # `sudo blkid` once the drive is connected. "nofail" is deliberate: a
  # missing/disconnected drive won't block boot (or cause the kind of
  # initrd hang you were just fighting) — the system just comes up
  # without that mount instead of hanging indefinitely waiting for it.
  extraMounts = [
    # {
    #   device = "/dev/disk/by-uuid/XXXX-XXXX-XXXX-XXXX";
    #   mountPoint = "/mnt/storage1";
    #   fsType = "ext4";
    #   options = [ "defaults" "nofail" ];
    # }
  ];

  # ==== Backups (restic) ===================================================
  # Off by default — flip to true once backupRepo actually points
  # somewhere real. See doc/backups.md for setup and restore instructions.
  backupEnable = false;
  backupRepo = "/mnt/backup/restic-repo"; # ideally a separate physical drive, not the same disk as the data being backed up
  backupPassword = "changeme-restic-backup-password"; # encrypts the restic repo — see doc/secrets.md once sops-nix is set up

  # ==== Secrets (sops-nix) =================================================
  # Off by default — the plaintext values above (initialPassword,
  # backupPassword) keep working until you complete the one-time sops-nix
  # setup in doc/secrets.md and flip this on. couchdbAdminPass is NOT
  # covered — see doc/secrets.md for why.
  secretsEnabled = false;

  # ==== Monitoring ==========================================================
  # Runs check-remote.sh every 15 minutes from the server itself. Leave
  # blank to just log results; set to a webhook URL (ntfy.sh, Discord,
  # generic POST endpoint) to also get notified on failure.
  notifyWebhook = "";
}
