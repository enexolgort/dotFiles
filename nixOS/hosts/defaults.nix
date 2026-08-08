# hosts/defaults.nix
# Shared across every machine profile. Each host's own hosts/<name>/vars.nix
# only needs to declare what's actually different for that machine —
# flake.nix merges these defaults underneath it.
#
# Deliberately NOT here: anything specific to one particular service
# (sftpPublicKeys/sftpDir, couchdbAdminUser/Pass, gitAdminUser/Pass,
# backupEnable/Repo/Password). Those live in whichever host's vars.nix
# actually turns that service on — see hosts/dusty, hosts/headless.
{
  system = "x86_64-linux"; # aarch64-linux if on ARM

  timeZone = "Europe/Paris";
  locale = "en_US.UTF-8";
  keyMap = "fr"; # AZERTY. Use "be" for Belgian AZERTY, "us" for QWERTY

  initialPassword = "changeme"; # change on first login with: passwd <username>

  mediaDir = "/data/media";
  projectsDir = "/data/projects"; # where install.sh clones a host's projectRepos

  sambaWorkgroup = "WORKGROUP";

  extraMounts = [ ];

  secretsEnabled = false;

  notifyWebhook = "";

  # --- Per-host essentials (every host's own vars.nix MUST set these) ----
  # hostname          = "...";
  # username          = "...";
  # gitEmail          = "...";
  # targetType        = "real" | "wsl";
  # jellyfinEnable    = true | false;
  # obsidianEnable    = true | false;
  # gitServerEnable   = true | false;
  # aiEnable          = true | false;   # Ollama + Open WebUI, see common/ai.nix
  # n8nEnable         = true | false;   # workflow automation, see common/n8n.nix
  # monitoringHubEnable = true | false; # Prometheus+Grafana+restic REST server, see common/monitoring-hub.nix
  # sftpEnable        = true | false;   # chrooted upload account, see common/sftp.nix
  # projectRepos      = [ "https://..." ... ];  # cloned into projectsDir by install.sh
  #
  # --- Per-host, only needed if the matching *Enable above is true -------
  # sftpDir           = "/data/sftp";                    # if sftpEnable
  # sftpPublicKeys    = [ "ssh-ed25519 ..." ];            # if sftpEnable
  # couchdbAdminUser  = "admin";                          # if obsidianEnable
  # couchdbAdminPass  = "...";                            # if obsidianEnable
  # gitAdminUser      = "gituser"; # "admin" is reserved   # if gitServerEnable
  # gitAdminPass      = "...";                            # if gitServerEnable
  # backupEnable      = true | false;
  # backupRepo        = "/mnt/backup/restic-repo";        # if backupEnable
  # backupPassword    = "...";                            # if backupEnable
}
