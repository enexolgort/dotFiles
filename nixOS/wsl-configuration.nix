# wsl-configuration.nix
# The WSL target — requires NixOS-WSL (https://github.com/nix-community/NixOS-WSL),
# a real NixOS system running as its own WSL2 distro. This is NOT the same
# as "Nix installed on top of Ubuntu-WSL" — that setup has no NixOS
# underneath it and can't run nixos-rebuild at all, which is what you hit
# earlier. See README for how to actually install NixOS-WSL first.
#
# No bootloader, no disk partitioning, no hardware-configuration.nix here —
# the wsl.nix module (from the nixos-wsl input) handles all of that, since
# WSL2 owns the underlying virtual disk and boot process itself.
{ config, pkgs, lib, vars, nixos-wsl, ... }:

{
  imports = [
    nixos-wsl.nixosModules.wsl
    ./common.nix
  ];

  wsl = {
    enable = true;
    defaultUser = vars.username;
    # Lets Docker/Tailscale-style tools work normally inside WSL2.
    startMenuLaunchers = true;
  };

  # WSL2 provides its own network stack via the Windows host — no
  # NetworkManager needed (unlike the real-machine target).
}
