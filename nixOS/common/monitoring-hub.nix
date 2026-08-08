# common/monitoring-hub.nix — Prometheus + Grafana + a restic REST
# server acting as the offsite backup target for dusty/headless/scrapy's
# backupRepo values. Off unless a host sets monitoringHubEnable = true
# (currently just shadow).
#
# NOTE: the webhook receiver (for aggregating the other hosts'
# notifyWebhook health-check failures) is deliberately NOT in this
# file — it's very likely going to be a small Docker container rather
# than a native NixOS module, same pattern as
# transmission-API/transmission-webUi (docker-compose, cloned via this
# host's projectRepos into projectsDir), not something that belongs
# here. Wire that up separately once there's an actual repo/image for it.
{ config, pkgs, lib, vars, ... }:

lib.mkIf vars.monitoringHubEnable {
  services.prometheus = {
    enable = true;
    # Confirmed this module's own default is already "0.0.0.0" — set
    # explicitly anyway, for consistency with the rest of this file and
    # given how many *other* services in this repo have silently
    # defaulted to 127.0.0.1-only (CouchDB, Open WebUI, Grafana below).
    listenAddress = "0.0.0.0";
    port = 9090;
  };

  services.grafana = {
    enable = true;
    # Unlike Prometheus, this DOES default to "127.0.0.1" (confirmed via
    # the NixOS wiki's own Grafana page) — same bug class as CouchDB/
    # Open WebUI before it. Explicit here is not optional.
    settings.server = {
      http_addr = "0.0.0.0";
      http_port = 3000;
    };
  };

  # Restic REST server — the actual offsite target dusty/headless/
  # scrapy's backupRepo values should point at, e.g.
  # "rest:http://<shadow-tailscale-ip>:8000/<hostname>"
  services.restic.server = {
    enable = true;
    dataDir = "/data/restic-server";
    # TODO / VERIFY ON FIRST REBUILD: unlike prometheus.listenAddress and
    # grafana.settings.server.http_addr, I could not directly confirm
    # this is the correct option name for binding externally on this
    # specific module — its default port (8000) comes from a
    # systemd-socket-activated unit, and I didn't find explicit
    # documentation of how the bind address itself is exposed as a NixOS
    # option. After rebuilding, run:
    #   sudo ss -tlnp | grep 8000
    # If it still shows 127.0.0.1 instead of 0.0.0.0, this is the
    # setting to fix — check `nixos-option services.restic.server` or
    # the module source directly for the real option name.
    listenAddress = "0.0.0.0";
    # Append-only: clients can push new backups but can't delete/modify
    # existing ones. Meaningful defense here specifically because this
    # is a backup *target* for other machines — if one of them (dusty,
    # headless, scrapy) is ever compromised, an attacker with its restic
    # credentials still can't destroy the backups already stored here.
    appendOnly = true;
    # No htpasswd-file configured yet — anyone reachable on the tailnet
    # can currently read/write this repo. Fine given everything here is
    # already tailnet-only by design, but worth locking down further if
    # you want defense in depth — ask if you want that wired up.
  };

  systemd.services.prometheus = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
  systemd.services.grafana = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
  systemd.services.restic-rest-server = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
