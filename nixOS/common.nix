# common.nix
# Everything shared between every target this flake can build for
# (the real machine / VM, and NixOS-WSL). Anything genuinely specific to
# one target — bootloader, disk hardware, WSL interop — lives in that
# target's own file (configuration.nix / wsl-configuration.nix) instead.
{ config, pkgs, lib, vars, ... }:

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

  # ======================================================================
  # SECRETS (sops-nix) — see doc/secrets.md for one-time setup. Off by
  # default (vars.secretsEnabled = false); the plaintext values in
  # vars.nix keep working until you complete that setup and flip it on.
  #
  # LIMITATION: CouchDB's `adminPass` option only accepts a literal Nix
  # string, not a file path — so it always ends up readable in the Nix
  # store regardless of sops-nix. This is a real constraint in the
  # nixpkgs couchdb module, not something sops-nix config can work
  # around. Mitigated by: CouchDB is tailnet-only (see firewall config
  # below), so this isn't exposed to the internet either way.
  # ======================================================================
  sops = lib.mkIf vars.secretsEnabled {
    defaultSopsFile = ../secrets.yaml; # relative to this repo's root — see doc/secrets.md
    age.keyFile = "/var/lib/sops-nix/key.txt"; # generated once during setup, see doc/secrets.md
    secrets = {
      userPasswordHash = {};
      backupPassword = {};
    };
  };

  # --- User account ----------------------------------------------------
  # Set a real password after first boot with: passwd <username>
  # (or, once vars.secretsEnabled is true, the password comes from the
  # sops-managed hash instead — see doc/secrets.md)
  users.users.${vars.username} = {
    isNormalUser = true;
    description = "Media server admin";
    extraGroups = [ "wheel" "jellyfin" "docker" ];
    shell = pkgs.bash;
  } // (if vars.secretsEnabled
    then { hashedPasswordFile = config.sops.secrets.userPasswordHash.path; }
    else { initialPassword = vars.initialPassword; }); # CHANGE on first login

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

  # NOTE: Samba lives in configuration.nix (real-machine only), not here —
  # nmbd depends on UDP broadcast networking that WSL2's virtualized NAT
  # adapter doesn't support, which makes it crash outright on the WSL
  # target rather than just being unreachable.

  # --- Nix housekeeping: without this, every rebuild leaves the old
  # generation in the store and disk usage only ever grows. Weekly GC
  # keeps the last 2 generations, and store optimization deduplicates
  # identical files across packages/generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-generations +2";
  };
  nix.settings.auto-optimise-store = true;

  # ======================================================================
  # BACKUPS (restic) — off by default, see doc/backups.md for setup and
  # restore instructions. Backs up: media library, CouchDB's actual data
  # directory (your Obsidian notes — easy to forget, genuinely
  # irreplaceable), and your dotfiles repo.
  # ======================================================================
  services.restic.backups.mediaserver = lib.mkIf vars.backupEnable {
    initialize = true;
    repository = vars.backupRepo;
    passwordFile =
      if vars.secretsEnabled
      then config.sops.secrets.backupPassword.path
      else "/etc/restic-backup-password"; # written below when secrets aren't set up yet
    paths = [
      vars.mediaDir
      "/var/lib/couchdb"
      "/home/${vars.username}/dotFiles"
    ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  # Fallback plaintext password file for restic when sops-nix isn't set
  # up yet — same plaintext-in-store caveat as everything else in
  # vars.nix until secretsEnabled is flipped on. Not created at all if
  # backups are disabled.
  environment.etc."restic-backup-password" = lib.mkIf (vars.backupEnable && !vars.secretsEnabled) {
    text = vars.backupPassword;
    mode = "0400";
  };

  # ======================================================================
  # MONITORING — runs check-remote.sh against this machine's own
  # tailscale IP every 15 minutes, logs the result, and POSTs to
  # vars.notifyWebhook on failure if one's configured.
  # ======================================================================
  systemd.services.healthcheck = {
    description = "Periodic health check of remote-facing services";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = vars.username;
    };
    path = [ pkgs.curl pkgs.bash pkgs.tailscale ];
    script = ''
      set -uo pipefail
      SCRIPT="/home/${vars.username}/dotFiles/check-remote.sh"

      if [ ! -x "$SCRIPT" ]; then
        echo "check-remote.sh not found or not executable at $SCRIPT — skipping"
        exit 0
      fi

      TSIP="$(tailscale ip -4)"
      OUTPUT="$("$SCRIPT" --host "$TSIP" 2>&1)"
      STATUS=$?
      echo "$OUTPUT"

      if [ $STATUS -ne 0 ] && [ -n "${vars.notifyWebhook}" ]; then
        MESSAGE="Health check FAILED on ${vars.hostname}:"$'\n'"$OUTPUT"
        curl -fsS -X POST -H "Content-Type: text/plain" \
          --data "$MESSAGE" "${vars.notifyWebhook}" || true
      fi

      exit $STATUS
    '';
  };

  systemd.timers.healthcheck = {
    description = "Run healthcheck.service every 15 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";
      Persistent = true;
    };
  };

  # --- System packages (system-wide, not user-specific) -------------
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    htop
    btop      # nicer/interactive alternative to htop
    ncdu      # find what's actually eating disk space
    jq        # parse JSON — handy for the couchdb/curl checks we've been doing by hand
    tmux      # persistent sessions over SSH — survives disconnects
    restic    # for manual backup/restore/inspection — see doc/backups.md
    ffmpeg
    docker-compose
  ];

  system.stateVersion = "24.11"; # do not change after initial install
}
