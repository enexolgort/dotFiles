# PLACEHOLDER — DO NOT USE AS-IS.
#
# This file is unique to each physical machine (disk UUIDs, filesystems,
# CPU microcode, etc). On the target machine, after booting the NixOS
# installer, run:
#
#   nixos-generate-config --root /mnt
#
# Then copy the generated /mnt/etc/nixos/hardware-configuration.nix
# over this file before running nixos-rebuild.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Example content — replace entirely with your generated version:
  # boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "sd_mod" ];
  # fileSystems."/" = { device = "/dev/disk/by-uuid/XXXX"; fsType = "ext4"; };
  # swapDevices = [ ];
  # hardware.cpu.intel.updateMicrocode = true; # or amd.updateMicrocode
}
