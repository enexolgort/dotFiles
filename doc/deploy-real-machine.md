# Deploy: real machine / VM target

For the WSL target instead, see [deploy-wsl.md](./deploy-wsl.md) — there's no partitioning/`nixos-install` step, since WSL2 already provides the disk and NixOS-WSL comes pre-installed from the tarball.

1. **Boot the NixOS installer**, partition/mount disks, then:
   ```bash
   nixos-generate-config --root /mnt
   ```
   Copy the generated `/mnt/etc/nixos/hardware-configuration.nix` over the placeholder in this repo.

2. **Edit `vars.nix`** to taste (hostname, username, SSH key, passwords — see [configuration.md](./configuration.md)).

3. **Copy this folder** to `/mnt/etc/nixos/`.

4. **Install**:
   ```bash
   nixos-install --flake /mnt/etc/nixos#<hostname-from-vars.nix>
   ```
   (defaults to `#scrapy` unless you changed `vars.hostname`). Set the root password, reboot.

5. Log in as the username you set in `vars.nix` (password `initialPassword` from `vars.nix` — **change it immediately** with `passwd`).

6. Continue with [first-boot-setup.md](./first-boot-setup.md).

[← back to overview](./overview.md)
