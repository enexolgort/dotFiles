# Deploy: real machine / VM host

For a WSL host instead, see [deploy-wsl.md](./deploy-wsl.md) — there's no partitioning/`nixos-install` step, since WSL2 already provides the disk and NixOS-WSL comes pre-installed from the tarball.

This covers first-time install of a `targetType = "real"` host (currently `dusty` or `scrapy`) — see [hosts.md](./hosts.md) if you're adding a new one rather than deploying an existing profile.

1. **Boot the NixOS installer**, partition/mount disks, then:
   ```bash
   nixos-generate-config --root /mnt
   ```
   Copy the generated `/mnt/etc/nixos/hardware-configuration.nix` over the placeholder at `nixOS/hosts/<name>/hardware-configuration.nix` in this repo (e.g. `hosts/scrapy/hardware-configuration.nix`).

2. **Edit `nixOS/hosts/<name>/vars.nix`** to taste (username, SSH key, passwords, services — see [hosts.md](./hosts.md) and [configuration.md](./configuration.md)).

3. **Copy the whole `nixOS/` folder** to `/mnt/etc/nixos/` (every host needs to be present for the flake to evaluate, even though you're only installing this one).

4. **Install**:
   ```bash
   nixos-install --flake /mnt/etc/nixos#<hostname>
   ```
   (e.g. `#dusty` or `#scrapy` — matches that host's `hostname` in its `vars.nix`). Set the root password, reboot.

5. Log in as the username from that host's `vars.nix` (password `initialPassword` from `hosts/defaults.nix` — **change it immediately** with `passwd`).

6. Continue with [first-boot-setup.md](./first-boot-setup.md).

[← back to overview](./overview.md)
