{ config, pkgs, ... }:

{
  # --- Boot / basics -------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mediaserver"; # <-- change if you like
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Paris"; # <-- adjust to your timezone
  i18n.defaultLocale = "en_US.UTF-8";

  # --- Nix settings ----------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true; # jellyfin's ffmpeg wants some unfree codecs

  # --- User account ----------------------------------------------------
  # Set a real password after first boot with: passwd media
  users.users.media = {
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
    "d /data/media 0775 jellyfin media -"
    "d /data/media/movies 0775 jellyfin media -"
    "d /data/media/shows 0775 jellyfin media -"
    "d /data/media/music 0775 jellyfin media -"
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
  # your normal "media" account). Drops files straight into /data/media.
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

  # ======================================================================
  # PROJECTS — clone github.com/enexolgort/transmission-API and
  # transmission-webUi into ~/projects, build their Docker images, and
  # run them as long-lived services, reachable only via your tailnet.
  #
  # SECURITY NOTE: transmission-webUi's own README suggests publishing
  # its port on 0.0.0.0 ("Docker exposes to all interfaces by default").
  # I'm deliberately NOT doing that: Docker manages its own iptables
  # rules and can bypass the `trustedInterfaces` firewall restriction
  # set up above, which would expose the container outside your tailnet
  # regardless of the NixOS firewall config. Instead, both containers'
  # published ports are bound explicitly to the host's Tailscale IP
  # address, so they're only reachable on tailscale0, full stop.
  #
  # transmission-API's repo is currently empty (no Dockerfile yet) — its
  # build/run services will log a warning and exit cleanly rather than
  # failing the whole system activation. Once you push real code, run:
  #   sudo systemctl restart transmission-api-build.service transmission-api.service
  # ======================================================================

  systemd.services.projects-clone = {
    description = "Clone transmission-API and transmission-webUi into ~/projects";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      Group = "users";
      WorkingDirectory = "/home/media";
    };
    path = [ pkgs.git ];
    script = ''
      set -eu
      mkdir -p /home/media/projects
      cd /home/media/projects

      if [ ! -d transmission-API/.git ]; then
        git clone https://github.com/enexolgort/transmission-API || echo "clone of transmission-API failed (repo may still be empty) — continuing"
      fi

      if [ ! -d transmission-webUi/.git ]; then
        git clone https://github.com/enexolgort/transmission-webUi
      fi
    '';
  };

  # --- Build: transmission-api ------------------------------------------
  systemd.services.transmission-api-build = {
    description = "Build transmission-api Docker image";
    after = [ "projects-clone.service" "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      RemainAfterExit = true;
    };
    path = [ pkgs.docker ];
    script = ''
      set -eu
      cd /home/media/projects/transmission-API
      if [ -f Dockerfile ]; then
        docker build -t transmission-api:local .
      else
        echo "transmission-API has no Dockerfile yet (empty repo) — skipping build"
      fi
    '';
  };

  # --- Build: transmission-webui -----------------------------------------
  systemd.services.transmission-webui-build = {
    description = "Build transmission-webui Docker image";
    after = [ "projects-clone.service" "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "media";
      RemainAfterExit = true;
    };
    path = [ pkgs.docker ];
    script = ''
      set -eu
      cd /home/media/projects/transmission-webUi
      docker build -t transmission-webui:local .
    '';
  };

  # --- Run: transmission-api (port 3000, tailnet-only) --------------------
  systemd.services.transmission-api = {
    description = "transmission-api container";
    after = [ "transmission-api-build.service" "tailscaled.service" "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "media";
      Restart = "always";
      RestartSec = "5s";
      ExecStartPre = "-${pkgs.docker}/bin/docker rm -f transmission-api";
      ExecStop = "${pkgs.docker}/bin/docker stop transmission-api";
    };
    path = [ pkgs.docker pkgs.tailscale ];
    script = ''
      set -eu
      if ! docker image inspect transmission-api:local >/dev/null 2>&1; then
        echo "transmission-api:local image not built yet (empty repo) — nothing to run, exiting cleanly"
        exit 0
      fi
      TSIP="$(tailscale ip -4)"
      exec docker run --rm --name transmission-api \
        -p "$TSIP:3000:3000" \
        transmission-api:local
    '';
  };

  # --- Run: transmission-webui (port 4173 -> 80, tailnet-only) ------------
  systemd.services.transmission-webui = {
    description = "transmission-webui container";
    after = [ "transmission-webui-build.service" "tailscaled.service" "docker.service" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "media";
      Restart = "always";
      RestartSec = "5s";
      ExecStartPre = "-${pkgs.docker}/bin/docker rm -f transmission-webui";
      ExecStop = "${pkgs.docker}/bin/docker stop transmission-webui";
    };
    path = [ pkgs.docker pkgs.tailscale ];
    script = ''
      set -eu
      TSIP="$(tailscale ip -4)"
      exec docker run --rm --name transmission-webui \
        -p "$TSIP:4173:80" \
        transmission-webui:local
    '';
  };

  # --- Optional: Samba share for LAN devices (unrelated to Tailscale) --
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "mediaserver";
        security = "user";
      };
      media = {
        path = "/data/media";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "media";
        "force group" = "media";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };
  # Set the samba password once, after first boot: sudo smbpasswd -a media

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
