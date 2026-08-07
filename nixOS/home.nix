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
    neofetch
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

  # --- Neofetch: shown automatically on every interactive login -------
  # home-manager has no dedicated neofetch module, so this is a plain
  # package (above) + hand-written config.conf, in neofetch's own
  # bash-sourced config syntax rather than a Nix attrset.
  xdg.configFile."neofetch/config.conf".text = ''
    print_info() {
        info title
        info underline
        info "OS" distro
        info "Host" model
        info "Kernel" kernel
        info "Uptime" uptime
        info "Packages" packages
        info "Shell" shell
        info "Terminal" term
        info "CPU" cpu
        info "GPU" gpu
        info "Memory" memory
        info "Disk" disk
        info "Local IP" local_ip
        info "Locale" locale
        info cols
    }

    # NixOS snowflake logo, colored to match the distro automatically
    ascii_distro="auto"
    ascii_colors=(distro)
    ascii_bold="on"

    bold="on"
    underline_enabled="on"
    underline_char="-"
    separator=" ->"

    # colored blocks under the info, distro-themed
    color_blocks="on"
    block_range=(0 15)
    block_width=3
    block_height=1
    col_offset="auto"

    memory_percent="on"
    memory_unit="gib"

    disk_show=("/")
    disk_subtitle="mount"
    disk_percent="on"

    speed_type="bios_limit"
    cpu_brand="on"
    cpu_speed="on"
    cpu_cores="logical"
    cpu_temp="off"

    gpu_brand="on"
    gpu_type="all"

    image_backend="ascii"
  '';

  programs.bash = {
    enable = true;

    initExtra = ''
      # Neofetch on every interactive login (skipped for non-interactive
      # shells like scp/rsync/git-over-ssh, so it doesn't spam those).
      if [[ $- == *i* ]]; then
        neofetch
      fi

      # --- Named-flag move/copy/rename, e.g.:
      #   move --source /src/file --destination /dst/file
      #   copy --source /src/dir  --destination /dst/dir
      #   rename --source /old/name --destination /new/name
      # Functions, not aliases — aliases can't parse --flags.
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

      # 'doom' with no arguments launches Emacs in the terminal; 'doom
      # <anything else>' (sync, install, etc.) still forwards to the real
      # Doom CLI, so this doesn't break doom sync/doom install like a
      # plain alias would.
      doom() {
        if [ $# -eq 0 ]; then
          emacs -nw
        else
          "$HOME/.config/emacs/bin/doom" "$@"
        fi
      }

      # 'rebuild' — no explicit #attr needed, nixos-rebuild auto-detects
      # from this machine's own hostname (works for both scrapy and
      # scrapy-wsl automatically).
      alias rebuild='sudo nixos-rebuild switch --flake /etc/nixos'

      # 'update-server' — the full loop we've run by hand dozens of
      # times: pull latest config, sync it into /etc/nixos, rebuild,
      # then run post-install (Doom sync, linger, etc.). Adjust the repo
      # path below if yours differs from ~/dotFiles.
      update-server() {
        local repo="$HOME/dotFiles"
        if [ ! -d "$repo" ]; then
          echo "Repo not found at $repo — edit the 'update-server' function in home.nix if it lives elsewhere." >&2
          return 1
        fi
        (
          set -e
          cd "$repo"
          git pull
          ./scripts/install.sh
          sudo nixos-rebuild switch --flake /etc/nixos
          ./scripts/post-install.sh
        )
      }

      # GNOME is installed but doesn't auto-start at boot (see
      # configuration.nix) — these just wrap the systemd target switch
      # to start/stop it on demand, real-machine only.
      alias gui-start='sudo systemctl isolate graphical.target'
      alias gui-stop='sudo systemctl isolate multi-user.target'
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
