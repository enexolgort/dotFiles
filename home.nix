{ config, pkgs, lib, ... }:

{
  home.username = "media";
  home.homeDirectory = "/home/media";
  home.stateVersion = "24.11";

  # --- Emacs itself --------------------------------------------------
  # pgtk build = native Wayland/X11 GTK, with native-comp for speed.
  # Doom Emacs is NOT packaged here as a nix derivation; instead we let
  # it manage itself the normal way (git clone + doom sync), which is
  # far less likely to break on Doom updates than a nixified version.
  programs.emacs = {
    enable = true;
    package = pkgs.emacs29-pgtk;
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
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; }) # patched font for doom's modeline icons
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
        || echo "doom install failed - run 'doom install' manually as the media user"
    fi
  '';

  # Put doom's bin on PATH
  home.sessionPath = [ "$HOME/.config/emacs/bin" ];

  programs.bash.enable = true;
  programs.git = {
    enable = true;
    userName = "Media Server";
    userEmail = "media@mediaserver.local"; # <-- change to your real email
  };
}
