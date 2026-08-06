{ config, pkgs, ... }:

{
  # --- Boot / basics -------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "scrapy"; # <-- change if you like
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Paris"; # <-- adjust to your timezone
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Nix settings ----------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true; # jellyfin's ffmpeg wants some unfree codecs

  # --- User account ----------------------------------------------------
  # Set a real password after first boot with: passwd enexolgort
  users.users.enexolgort = {
    isNormalUser = true;
    description = "Media server admin";
    extraGroups = [ "wheel" "jellyfin" "docker" ];
    shell = pkgs.bash;
    initialPassword = "changeme"; # CHANGE THIS on first login
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
    "d /data/media 0775 jellyfin enexolgort -"
    "d /data/media/movies 0775 jellyfin enexolgort -"
    "d /data/media/shows 0775 jellyfin enexolgort -"
    "d /data/media/music 0775 jellyfin enexolgort -"
    "d /data/sftp 0755 root root -"
    "d /data/sftp/upload 0755 root root -"
  ];

  # ======================================================================
  # OBSIDIAN SYNC — via the "Self-hosted LiveSync" community plugin,
  # backed by CouchDB. Obsidian's official paid Sync service is NOT
  # self-hostable; this is the community-standard alternative.
  # Reachable only via your tailnet at http://<tailscale-ip>:5984
  # ======================================================================
  services.couchdb = {
    enable = true;
    bindAddress = "0.0.0.0"; # firewall (trustedInterfaces) restricts real exposure
    adminUser = "admin";
    adminPass = "changeme-couchdb"; # CHANGE THIS — see note in README about secrets
    extraConfig = ''
      [chttpd]
      enable_cors = true

      [cors]
      origins = app://obsidian.md, capacitor://localhost, http://localhost
      credentials = true
      headers = accept, authorization, content-type, origin, referer
      methods = GET,PUT,POST,HEAD,DELETE
      max_age = 3600
    '';
  };

  # ======================================================================
  # DOCKER
  # ======================================================================
  virtualisation.docker.enable = true;

  # ======================================================================
  # SFTP — dedicated, chrooted, tailnet-only upload user (separate from
  # your normal "enexolgort" account). Drops files straight into /data/media.
  # ======================================================================
  fileSystems."/data/sftp/upload" = {
    device = "/data/media";
    options = [ "bind" ];
  };

  users.groups.sftponly = {};
  users.users.sftpuser = {
    isSystemUser = true;
    group = "sftponly";
    extraGroups = [ "sftponly" ];
    shell = "${pkgs.shadow}/bin/nologin";
    openssh.authorizedKeys.keys = [
      # Replace with your own public key, e.g. contents of ~/.ssh/id_ed25519.pub
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... replace-with-your-key sftpuser@yourlaptop"
    ];
  };

  services.openssh.extraConfig = ''
    Match Group sftponly
      ChrootDirectory /data/sftp
      ForceCommand internal-sftp
      AllowTcpForwarding no
      X11Forwarding no
      PasswordAuthentication no
  '';

  # --- Optional: Samba share for LAN devices (unrelated to Tailscale) --
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "scrapy";
        security = "user";
      };
      media = {
        path = "/data/media";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "enexolgort";
        "force group" = "enexolgort";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };
  # Set the samba password once, after first boot: sudo smbpasswd -a enexolgort

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
