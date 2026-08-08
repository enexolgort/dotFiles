# PLACEHOLDER — DO NOT USE AS-IS.
#
# IMPORTANT: dusty is already installed and running. Don't regenerate
# this with nixos-generate-config — instead, copy dusty's REAL, existing
# hardware-configuration.nix here:
#
#   cp /etc/nixos/hardware-configuration.nix hosts/dusty/hardware-configuration.nix
#
# (run that ON dusty itself, then commit the result)
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
}
