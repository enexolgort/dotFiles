# configuration.nix
# The REAL MACHINE / VM target — bare-metal or VirtualBox-style install
# with an actual disk and bootloader. Everything shared with the WSL
# target lives in ./common.nix instead.
{ config, pkgs, vars, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  # --- Samba share for LAN devices (unrelated to Tailscale) -----------
  # Real-machine only — nmbd needs UDP broadcast networking that WSL2's
  # virtualized NAT adapter doesn't support (it crashes outright there,
  # not just fails to be reachable), so this lives here rather than in
  # common.nix.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = vars.sambaWorkgroup;
        "server string" = vars.hostname;
        security = "user";
      };
      media = {
        path = vars.mediaDir;
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = vars.username;
        "force group" = vars.username;
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };
  # Set the samba password once, after first boot: sudo smbpasswd -a <username>

  imports = [ ./common.nix ];
}
