# common/networking.nix — Tailscale, the firewall lockdown, and base SSH.
# Everything else in this repo depends on the firewall policy set here:
# trustedInterfaces means any service that binds 0.0.0.0 is automatically
# tailnet-only with zero extra config, which is why none of the other
# service files (jellyfin.nix, couchdb.nix, forgejo.nix, sftp.nix) need
# any firewall rules of their own.
{
  config,
  pkgs,
  lib,
  vars,
  ...
}: {
  # ======================================================================
  # TAILSCALE
  # ======================================================================
  # Installs & runs tailscaled. After first boot, authenticate the node
  # and turn on Tailscale SSH (keyless, identity-based SSH login) with:
  #
  #   sudo tailscale up --ssh
  #
  # This opens a login link in your terminal the first time.
  services.tailscale.enable = true;

  systemd.services.tailscaled = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
  };

  # --- Lock the server down: everything below is reachable ONLY via
  # Tailscale. Nothing (Jellyfin, CouchDB, Forgejo, SFTP) is exposed on
  # your LAN or the public internet — only devices in your tailnet can
  # reach them.
  networking.firewall = {
    enable = true;
    trustedInterfaces = ["tailscale0"]; # tailnet traffic bypasses the firewall
    allowedUDPPorts = [41641]; # lets Tailscale establish direct (non-relayed) connections
    # No allowedTCPPorts here on purpose — SSH/Jellyfin/CouchDB/Forgejo/
    # SFTP are all only reachable through tailscale0 above.
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true; # fine since SSH itself is tailnet-only
  };
}
