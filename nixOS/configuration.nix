# configuration.nix
# The REAL MACHINE / VM target — bare-metal or VirtualBox-style install
# with an actual disk and bootloader. Everything shared with the WSL
# target lives in ./common.nix instead.
{ config, pkgs, vars, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  imports = [ ./common.nix ];
}
