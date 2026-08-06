# common.nix
# Everything shared between every target this flake can build for
# (the real machine / VM, and NixOS-WSL). Anything genuinely specific to
# one target — bootloader, disk hardware, WSL interop — lives in that
# target's own file (configuration.nix / wsl-configuration.nix) instead.
{ config, pkgs, vars, ... }:

{
  networking.hostName = vars.hostname;

  time.timeZone = vars.timeZone;
  i18n.defaultLocale = vars.locale;
  console.keyMap = vars.keyMap;

  # --- Nix settings ----------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true; # jellyfin's ffmpeg wants some unfree codecs
  # These are pinned to exact version strings from nixos-24.11's emacs
  # build — after bumping to nixos-25.11, the default Emacs is likely a
  # newer version (e.g. 30.x), so these specific strings may no longer
  # match anything (harmless if so) OR a *new* insecure-package error
  # may appear with a different version string that needs adding here
  # instead. Check on first rebuild after the nixpkgs bump.
  nixpkgs.config.permittedInsecurePackages = [
    "emacs-pgtk-with-packages-29.4"
    "emacs-pgtk-29.4"
  ];

  # --- User account ----------------------------------------------------
  # Set a real password after first boot with: passwd <username>
  users.users.${vars.username} = {
    isNormalUser = true;
    description = "Media server admin";
    extraGroups = [ "wheel" "jellyfin" "docker" ];
    shell = pkgs.bash;
    initialPassword = vars.initialPassword; # CHANGE on first login
  };

  # ======================================================================
  # BOOT RELIABILITY — every `services.X.enable = true` below already
  # means "start automatically on every boot" (that's how NixOS works;
  # no separate `systemctl enable` step needed, unlike Ubuntu/Debian).
  # This section just makes the network-dependent services explicitly
  # wait for real connectivity first, so they don't race a slow DHCP
  # lease on first boot or after a power loss.
  # ======================================================================
  systemd.services.tailscaled = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
  systemd.services.jellyfin = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
  systemd.services.couchdb = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
  systemd.services.docker = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

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

  # --- Lock the server down: everything below is reachable ONLY via
  # Tailscale. Nothing (Jellyfin, CouchDB, SFTP) is exposed on your LAN
  # or the public internet — only devices in your tailnet can reach them.
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ]; # tailnet traffic bypasses the firewall
    allowedUDPPorts = [ 41641 ];          # lets Tailscale establish direct (non-relayed) connections
    # No allowedTCPPorts here on purpose — SSH/Jellyfin/CouchDB/SFTP are
    # all only reachable through tailscale0 above.
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true; # fine since SSH itself is tailnet-only
  };

  # ======================================================================
  # JELLYFIN — reachable only via your tailnet (http://<tailscale-ip>:8096)
  # ======================================================================
  services.jellyfin = {
    enable = true;
    openFirewall = false; # do NOT open on the public interface; tailscale0 is trusted above
  };

  # Media library location. Jellyfin runs as the "jellyfin" user/group.
  systemd.tmpfiles.rules = [
    "d ${vars.mediaDir} 0775 jellyfin ${vars.username} -"
    "d ${vars.mediaDir}/movies 0775 jellyfin ${vars.username} -"
    "d ${vars.mediaDir}/shows 0775 jellyfin ${vars.username} -"
    "d ${vars.mediaDir}/music 0775 jellyfin ${vars.username} -"
    "d ${vars.sftpDir} 0755 root root -"
    "d ${vars.sftpDir}/upload 0755 root root -"
  ];

  # ======================================================================
  # OBSIDIAN SYNC — via the "Self-hosted LiveSync" community plugin,
  # backed by CouchDB. Obsidian's official paid Sync service is NOT
  # self-hostable; this is the community-standard alternative.
  # Reachable only via your tailnet at http://<tailscale-ip>:5984
  # ======================================================================
  services.couchdb = {
    enable = true;
    bindAddress = "0.0.0.0"; # legacy [httpd] section — CouchDB 3.x doesn't actually serve from here
    adminUser = vars.couchdbAdminUser;
    adminPass = vars.couchdbAdminPass; # CHANGE in vars.nix — see README about secrets
    extraConfig = {
      chttpd = {
        enable_cors = "true";
        bind_address = "0.0.0.0"; # the section CouchDB 3.x's real listener actually reads
      };
      cors = {
        origins = "app://obsidian.md, capacitor://localhost, http://localhost";
        credentials = "true";
        headers = "accept, authorization, content-type, origin, referer";
        methods = "GET,PUT,POST,HEAD,DELETE";
        max_age = "3600";
      };
    };
  };

  # ======================================================================
  # DOCKER
  # ======================================================================
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29; # default (docker_28) is unmaintained/insecure as of nixos-25.11
  };

  # ======================================================================
  # SFTP — dedicated, chrooted, tailnet-only upload user (separate from
  # your normal admin account). Drops files straight into the media dir.
  # ======================================================================
  fileSystems."${vars.sftpDir}/upload" = {
    device = vars.mediaDir;
    options = [ "bind" ];
  };

  users.groups.sftponly = {};
  users.users.sftpuser = {
    isSystemUser = true;
    group = "sftponly";
    extraGroups = [ "sftponly" ];
    shell = "${pkgs.shadow}/bin/nologin";
    openssh.authorizedKeys.keys = [ vars.sftpPublicKey ];
  };

  services.openssh.extraConfig = ''
    Match Group sftponly
      ChrootDirectory ${vars.sftpDir}
      ForceCommand internal-sftp
      AllowTcpForwarding no
      X11Forwarding no
      PasswordAuthentication no
  '';

  # --- Optional: Samba share for LAN devices (unrelated to Tailscale) --
  # NOTE: under WSL, this is only reachable from other LAN devices if
  # you're on WSL2 "mirrored" networking mode (Windows 11) — WSL2's
  # default NAT networking hides it from anything outside the Windows
  # host itself. Jellyfin/Tailscale/SSH are unaffected either way since
  # they only need to be reachable via tailscale0.
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

  # --- System packages (system-wide, not user-specific) -------------
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    htop
    ffmpeg
    docker-compose
  ];

  system.stateVersion = "24.11"; # do not change after initial install
}
