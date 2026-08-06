{ config, pkgs, lib, vars, ... }:

{
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";
  home.stateVersion = "24.11";

  # --- Emacs itself --------------------------------------------------
  # pgtk build = native Wayland/X11 GTK, with native-comp for speed.
  # Doom Emacs is NOT packaged here as a nix derivation; instead we let
  # it manage itself the normal way (git clone + doom sync), which is
  # far less likely to break on Doom updates than a nixified version.
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
  };

  # --- Run Emacs as a background daemon ------------------------------
  # Socket-activated: systemd starts it on first `emacsclient` connection
  # rather than unconditionally at login, and keeps it running after —
  # so Doom's (slower) startup cost only happens once, not on every
  # `emacs` invocation. Requires `loginctl enable-linger <username>`
  # (see README) if you want it to keep running with no session open.
  services.emacs = {
    enable = true;
    client.enable = true;
    defaultEditor = true;
    socketActivation.enable = true;
  };

  # --- Tools Doom Emacs expects to find on PATH -----------------------
  home.packages = with pkgs; [
    git
    ripgrep
    fd
    coreutils
    imagemagick
    sqlite            # org-roam
    fontconfig
    nerd-fonts.jetbrains-mono # patched font for doom's modeline icons
    gnutls             # emacs package.el / straight.el needs this for https
    unzip
  ];

  # --- Auto-bootstrap Doom Emacs on first home-manager activation ----
  home.activation.installDoomEmacs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    DOOM_DIR="$HOME/.config/emacs"
    DOOM_CONF="$HOME/.config/doom"

    if [ ! -d "$DOOM_DIR" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone --depth 1 \
        https://github.com/doomemacs/doomemacs "$DOOM_DIR"
    fi

    if [ ! -d "$DOOM_CONF" ]; then
      $DRY_RUN_CMD "$DOOM_DIR/bin/doom" install --no-env --no-fonts -! \
        || echo "doom install failed - run 'doom install' manually as the ${vars.username} user"
    fi
  '';

  # Put doom's bin on PATH
  home.sessionPath = [ "$HOME/.config/emacs/bin" ];

  programs.bash = {
    enable = true;

    # --- Named-flag move/copy/rename, e.g.:
    #   move --source /src/file --destination /dst/file
    #   copy --source /src/dir  --destination /dst/dir
    #   rename --source /old/name --destination /new/name
    # Functions, not aliases — aliases can't parse --flags.
    initExtra = ''
      _parse_source_dest() {
        # sets $__src and $__dst from --source/--destination, or prints
        # usage and returns 1 if either is missing.
        local fn_name="$1"; shift
        __src=""
        __dst=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --source) __src="$2"; shift 2 ;;
            --destination) __dst="$2"; shift 2 ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
          esac
        done
        if [[ -z "$__src" || -z "$__dst" ]]; then
          echo "Usage: $fn_name --source <path> --destination <path>" >&2
          return 1
        fi
      }

      move() {
        _parse_source_dest move "$@" || return 1
        mv -- "$__src" "$__dst"
      }

      copy() {
        _parse_source_dest copy "$@" || return 1
        cp -r -- "$__src" "$__dst"
      }

      rename() {
        _parse_source_dest rename "$@" || return 1
        mv -- "$__src" "$__dst"
      }
    '';
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = vars.username;
      email = vars.gitEmail; # <-- set your real email in vars.nix
    };
  };
}
