# common/n8n.nix — self-hosted workflow automation (Zapier-style),
# pairs naturally with local AI on the same host. Off unless a host sets
# n8nEnable = true.
#
# NOT using the native nixpkgs services.n8n package here — it builds
# n8n's entire TypeScript monorepo from source via pnpm/turbo, which
# reliably OOMs during the build on lower-memory machines (confirmed:
# tripling headless's available WSL2 memory did not help at all, which
# means it's Node's own internal V8 heap ceiling being hit, not a real
# system-memory shortage — more system RAM was never going to fix it).
#
# Using the official pre-built Docker image instead: zero local
# compilation, so this whole class of problem disappears regardless of
# root cause.
#
# NETWORKING NOTE: deliberately using Docker's --network=host mode, NOT
# a port mapping (`ports = [ "5678:5678" ]`). A port mapping goes
# through Docker's own NAT/port-publishing, which can bypass the NixOS
# firewall's trustedInterfaces restriction entirely — exactly the risk
# flagged and avoided earlier in this project for the
# transmission-webUi container. Host networking means n8n binds
# directly on this machine's real network stack, same as any native
# service, so it stays genuinely tailnet-only like everything else here.
{ config, pkgs, lib, vars, ... }:

lib.mkIf vars.n8nEnable {
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.n8n = {
    image = "docker.n8n.io/n8nio/n8n:latest";
    autoStart = true;
    extraOptions = [ "--network=host" ];
    volumes = [ "/var/lib/n8n:/home/node/.n8n" ];
    environment = {
      N8N_PORT = "5678";
      # n8n defaults to expecting HTTPS and sets a secure-only cookie,
      # which breaks over plain HTTP. Same reasoning as every other
      # service in this repo (Jellyfin, CouchDB, Forgejo, Open WebUI):
      # Tailscale's own WireGuard encryption already covers the
      # transport layer, and this is never exposed beyond the tailnet.
      N8N_SECURE_COOKIE = "false";
    };
  };

  systemd.tmpfiles.rules = [
    # 1000 = the "node" user's UID *inside* the official n8n container.
    # This is a bind mount, not a Docker-managed volume, so there's no
    # UID remapping — the container's internal non-root user genuinely
    # needs to own this directory on the host side to write to it at
    # all. root:root here caused a hard EACCES crash-loop on first run.
    "d /var/lib/n8n 0755 1000 1000 -"
  ];

  systemd.services.docker-n8n = {
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
  };
}
