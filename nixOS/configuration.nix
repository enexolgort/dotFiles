# configuration.nix
# The REAL MACHINE / VM target — bare-metal or VirtualBox-style install
# with an actual disk and bootloader. Everything shared with the WSL
# target lives in ./common.nix instead.
{ config, pkgs, lib, vars, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10; # cap boot entries — the ESP has limited space
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  # ======================================================================
  # GNOME — installed and available, but does NOT auto-start at boot.
  # The system boots straight to a TTY console as normal; GNOME only
  # starts when you explicitly ask for it, and stops (freeing its
  # resources entirely) when you're done. Real-machine only — doesn't
  # apply to the WSL target, which has no physical display anyway.
  #
  # Current NixOS 25.11 syntax (this moved out of services.xserver.* in
  # this release — see doc/deploy-real-machine.md if troubleshooting
  # against older guides/examples that still show the old paths).
  # ======================================================================
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # NixOS normally makes graphical.target (which pulls in the display
  # manager/GNOME) the default boot target once a display manager is
  # enabled. Force it back to multi-user.target (text console) instead —
  # this is the actual mechanism that keeps GNOME from starting at boot.
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  # On-demand start/stop — see also the 'gui-start'/'gui-stop' shell
  # aliases in home.nix, which just wrap these same commands.
  #   sudo systemctl isolate graphical.target   # start GNOME
  #   sudo systemctl isolate multi-user.target  # stop it, back to TTY

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

  # --- Extra storage drives (SATA drives on the ZimaBoard, etc.) ------
  # Declared in vars.nix as a list — generated into real fileSystems
  # entries here. "nofail" is set per-entry in vars.nix by default so a
  # missing/disconnected drive doesn't block boot.
  fileSystems = builtins.listToAttrs (map
    (m: {
      name = m.mountPoint;
      value = {
        device = m.device;
        fsType = m.fsType or "ext4";
        options = m.options or [ "defaults" "nofail" ];
      };
    })
    vars.extraMounts);

  imports = [ ./common.nix ];
}
