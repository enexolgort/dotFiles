# common/base.nix — the truly foundational stuff that doesn't belong to
# any single service: system identity, Nix itself, secrets, the user
# account.
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
  # around. Mitigated by: CouchDB is tailnet-only (see networking.nix),
  # so this isn't exposed to the internet either way.
  # ======================================================================
  sops = lib.mkIf vars.secretsEnabled {
    defaultSopsFile = ../secrets.yaml; # install.sh copies this into /etc/nixos too — see doc/secrets.md
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
  #
  # NOTE ON GROUPS: earlier versions of this config wrongly assumed
  # NixOS auto-creates a group with the same name as a normal user
  # (isNormalUser). It doesn't — the real default primary group is the
  # generic "users" (gid 100). That wrong assumption silently broke
  # mediaDir's ownership from the start (chown to a nonexistent group
  # fails). Fixed properly here with an explicit, dedicated "media"
  # group instead of relying on any assumption about the user's own
  # group name.
  users.groups.media = {};

  users.users.${vars.username} = {
    isNormalUser = true;
    description = "Media server admin";
    extraGroups = [ "wheel" "jellyfin" "docker" "media" ];
    shell = pkgs.bash;
  } // (if vars.secretsEnabled
    then { hashedPasswordFile = config.sops.secrets.userPasswordHash.path; }
    else { initialPassword = vars.initialPassword; }); # CHANGE on first login

  system.stateVersion = "24.11"; # do not change after initial install
}
