{
  hostname = "shadow";
  username = "enexolgort";
  gitEmail = "enexolgort@shadow.local";
  targetType = "real";

  jellyfinEnable = false;
  obsidianEnable = false;
  gitServerEnable = false;
  aiEnable = false;
  sftpEnable = false;
  n8nEnable = false;

  # New toggle — shadow runs services (Prometheus, Grafana, a restic
  # REST server) that don't exist as their own options yet. See
  # common/monitoring-hub.nix.
  monitoringHubEnable = true;

  # shadow is a backup *target* for dusty/headless/scrapy (via
  # common/monitoring-hub.nix's restic REST server), not a client
  # backing itself up — don't conflate the two.
  backupEnable = false;

  # Physical clone of scrapy's hardware — will need its own data volume
  # for Prometheus/Grafana/restic-server storage. NOT filling this in
  # with invented UUIDs — genuinely don't know them yet. Once shadow is
  # actually installed, run `lsblk -f` on it and add real entries here,
  # same pattern as hosts/dusty/vars.nix's extraMounts.
  extraMounts = [ ];

  # Nothing to clone here yet — ask before assuming a repo exists for
  # Grafana dashboard provisioning or the webhook receiver (the latter
  # is likely a small Docker container, not a native NixOS module — see
  # the note in common/monitoring-hub.nix).
  projectRepos = [ ];
}
