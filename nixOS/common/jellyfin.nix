# common/jellyfin.nix — reachable only via your tailnet at
# http://<tailscale-ip>:8096. Media directory layout is in storage.nix.
{ config, pkgs, lib, vars, ... }:

{
  services.jellyfin = {
    enable = vars.jellyfinEnable;
    openFirewall = false; # do NOT open on the public interface; tailscale0 is trusted (see networking.nix)
  };

  systemd.services.jellyfin = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
