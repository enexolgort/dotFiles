# common/forgejo.nix — self-hosted, tailnet-only git server. No firewall
# changes needed at all: trustedInterfaces in networking.nix already
# covers this port automatically, same as Jellyfin/CouchDB.
# Lightweight (single Go binary, SQLite by default) — fine for modest
# hardware. Reachable at http://<tailscale-ip>:3000
{ config, pkgs, lib, vars, ... }:

{
  services.forgejo = {
    enable = vars.gitServerEnable;
    settings.server = {
      HTTP_ADDR = "0.0.0.0"; # firewall (trustedInterfaces) restricts real exposure
      HTTP_PORT = 3000;
      ROOT_URL = "http://${vars.hostname}:3000/";
    };
    settings.service.DISABLE_REGISTRATION = true; # single-user server — no public signup
  };

  # Declaratively ensures your admin account exists — idempotent (`|| true`
  # means it doesn't fail on every subsequent rebuild once already
  # created). This is the officially documented pattern from the NixOS
  # wiki's own Forgejo page. NOTE: "admin" itself is a reserved username
  # in Forgejo — that's why vars.gitAdminUser isn't literally "admin".
  systemd.services.forgejo.preStart = ''
    ${lib.getExe config.services.forgejo.package} admin user create \
      --admin --username ${vars.gitAdminUser} --password "${vars.gitAdminPass}" \
      --email "${vars.gitAdminUser}@${vars.hostname}.local" || true
  '';

  systemd.services.forgejo.after = [ "network-online.target" ];
  systemd.services.forgejo.wants = [ "network-online.target" ];
}
