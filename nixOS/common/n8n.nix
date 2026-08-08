# common/n8n.nix — self-hosted workflow automation (Zapier-style),
# pairs naturally with local AI on the same host. Off unless a host sets
# n8nEnable = true. Real NixOS module
# (nixos/modules/services/misc/n8n.nix), not something built from
# scratch. Default port 5678.
{ config, pkgs, lib, vars, ... }:

lib.mkIf vars.n8nEnable {
  services.n8n = {
    enable = true;
    # Explicit rather than trusting the default — we've now hit two
    # other services (CouchDB, Open WebUI) that silently bound to
    # 127.0.0.1-only. Cheaper to be explicit here than debug a third one.
    environment = {
      N8N_HOST = "0.0.0.0";
      N8N_LISTEN_ADDRESS = "0.0.0.0";
      N8N_PORT = "5678";
    };
  };

  systemd.services.n8n = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
