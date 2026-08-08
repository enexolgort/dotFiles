{
  hostname = "dusty";
  username = "enexolgort";
  gitEmail = "enexolgort@dusty.local";
  targetType = "real";

  jellyfinEnable = true;
  obsidianEnable = false;
  gitServerEnable = false;
  aiEnable = false;
  sftpEnable = true;

  # sftpEnable = true, so these need to actually be here.
  sftpDir = "/data/sftp";
  sftpPublicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPfCPT1zuWITFVKSAOmkLAr4wpXkHLDxzNUVptgI88lf sftp-laptop" # filezila@laptop
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIITDNIuGEqX2bs89Tv+BWZcFCI3CLOM9xQCj89G/eumc transmission-api push" # transmission-API@headless
  ];

  # dusty's two physical drives — this was missing from the new
  # multi-host vars.nix entirely (would've silently left both drives
  # unmounted). Real UUIDs, not placeholders.
  extraMounts = [
    {
      device = "/dev/disk/by-uuid/fae138ec-cca2-4d6a-ad07-583494d934a7"; # media drive (sdb)
      mountPoint = "/data/media";
      fsType = "ext4";
      options = [ "defaults" "nofail" ];
    }
    {
      device = "/dev/disk/by-uuid/00208e9d-d9d2-4993-b92c-85b2ff15ed33"; # backup drive (sda)
      mountPoint = "/data/backup";
      fsType = "ext4";
      options = [ "defaults" "nofail" ];
    }
  ];

  # dusty is the host that actually has the second drive set up for
  # restic — see doc/backups.md.
  backupEnable = true;
  backupRepo = "/data/backup/restic-repo";
  backupPassword = "changeme-restic-backup-password"; # CHANGE THIS

  projectRepos = [
    "https://github.com/enexolgort/transmission-webUi"
  ];
}
