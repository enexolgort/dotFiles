# Overview

## Two targets: real machine + WSL
This flake builds **two separate systems** from the same shared config:
- **`scrapy`** — a real machine or VM (VirtualBox, bare metal, etc.) with an actual disk and bootloader.
- **`scrapy-wsl`** — the same services running inside **NixOS-WSL**, a real NixOS system that runs as its own WSL2 distro on Windows.

They share everything that matters (`common.nix`: Tailscale, Jellyfin, CouchDB, Docker, SFTP, backups, monitoring, the user account) and differ only in the hardware/boot-specific bits — real machine gets a bootloader, NetworkManager, and Samba; WSL gets the `nixos-wsl` module instead.

**Important distinction, since this tripped things up before**: NixOS-WSL is *not* the same as "installing Nix on top of Ubuntu-WSL" — the latter gives you the `nix`/`nix-shell` commands but no actual NixOS system underneath, so `nixos-rebuild` has nothing to manage (no `fileSystems."/"`, no systemd services it controls, nothing). NixOS-WSL replaces the whole WSL distro with real NixOS. See [deploy-wsl.md](./deploy-wsl.md) if you haven't done this yet.

## What's in here
- **vars.nix** — every value you're likely to want to change (hostname, username, timezone, paths, passwords, keys, backups, monitoring...) lives here. Everything else reads from it. See [configuration.md](./configuration.md).
- **flake.nix** — entrypoint. Defines both `nixosConfigurations.scrapy` and `nixosConfigurations.scrapy-wsl`, threading `vars` into every module. WSL gets a distinct hostname (`<hostname>-wsl`) automatically, so the two can coexist on your tailnet without colliding.
- **common.nix** — everything shared between both targets: Tailscale, Jellyfin, CouchDB, Docker, SFTP, firewall, the main user, automatic Nix garbage collection, restic backups, sops-nix secrets, and the periodic health-check monitor.
- **configuration.nix** — real-machine-only: bootloader, NetworkManager, Samba, extra storage drives. Imports `common.nix`.
- **wsl-configuration.nix** — WSL-only: the `nixos-wsl` module (`wsl.enable`, `wsl.defaultUser`). Imports `common.nix`. No bootloader/disk config — WSL2 owns that layer itself.
- **home.nix** — user-level config: Emacs (native-comp, pgtk, daemonized) + auto-bootstraps Doom Emacs on first activation, neofetch, shell helpers (`move`/`copy`/`rename`/`doom`/`rebuild`/`update-server`). Shared by both targets.
- **hardware-configuration.nix** — **placeholder, you must replace this** — real-machine only, not used by the WSL target at all.
- **install.sh** — lives at the root of your dotfiles repo (not inside `nixOS/`); copies the files above from `nixOS/` into `/etc/nixos` (on whichever system you run it on), and clones your project repos into `projectsDir` (default `/data/projects`, see `vars.nix`). Run it as `./install.sh` from the repo root.
- **post-install.sh** — also at the repo root; run once after `nixos-rebuild switch` succeeds, on either target. Enables `loginctl linger` for your user, deploys your Doom config, runs `doom sync`.
- **check-remote.sh** — client-side health check (also what the automated monitoring timer runs on the server itself).

## Doc index
- [configuration.md](./configuration.md) — `vars.nix` reference, design assumptions
- [deploy-real-machine.md](./deploy-real-machine.md) — installing on a real machine/VM
- [deploy-wsl.md](./deploy-wsl.md) — installing NixOS-WSL
- [boot-and-updates.md](./boot-and-updates.md) — what auto-starts, and how to apply future changes on each machine
- [first-boot-setup.md](./first-boot-setup.md) — Tailscale, Jellyfin, Obsidian sync, SFTP, Docker, Doom Emacs
- [secrets.md](./secrets.md) — sops-nix one-time setup, what it does and doesn't cover
- [backups.md](./backups.md) — restic setup, checking it's working, restore instructions

## Common follow-ups
- **Real HTTPS via Tailscale** for Jellyfin/CouchDB (`tailscale serve`)
- **CouchDB admin password still plaintext-in-store** even with sops-nix on — see [secrets.md](./secrets.md) for why (a real nixpkgs module limitation, not an oversight)
- **Exit node / subnet router** if you want the server to route LAN traffic into your tailnet
- **GPU transcoding** later — say which GPU and I'll add it
- **Samba on WSL** — deliberately not enabled there at all (nmbd crashes on WSL2's NAT networking rather than just being unreachable); if you want it anyway, you'd need WSL2 "mirrored" networking mode (Windows 11) plus adding the Samba block to `wsl-configuration.nix` yourself
- **Offsite backups** — `backupRepo` defaults to a local placeholder path; point it at a remote target (SFTP, S3, B2, rest-server) for real disaster protection, see [backups.md](./backups.md)