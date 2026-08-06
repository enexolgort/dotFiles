# Overview

## Two targets: real machine + WSL
This flake builds **two separate systems** from the same shared config:
- **`scrapy`** — a real machine or VM (VirtualBox, bare metal, etc.) with an actual disk and bootloader.
- **`scrapy-wsl`** — the same services running inside **NixOS-WSL**, a real NixOS system that runs as its own WSL2 distro on Windows.

They share everything that matters (`common.nix`: Tailscale, Jellyfin, CouchDB, Docker, SFTP, Samba, the user account) and differ only in the hardware/boot-specific bits, which live in `configuration.nix` (real machine) or `wsl-configuration.nix` (WSL) respectively.

**Important distinction, since this tripped things up before**: NixOS-WSL is *not* the same as "installing Nix on top of Ubuntu-WSL" — the latter gives you the `nix`/`nix-shell` commands but no actual NixOS system underneath, so `nixos-rebuild` has nothing to manage (no `fileSystems."/"`, no systemd services it controls, nothing). NixOS-WSL replaces the whole WSL distro with real NixOS. See [deploy-wsl.md](./deploy-wsl.md) if you haven't done this yet.

## What's in here
- **vars.nix** — every value you're likely to want to change (hostname, username, timezone, paths, passwords, keys...) lives here. Everything else reads from it. See [configuration.md](./configuration.md).
- **flake.nix** — entrypoint. Defines both `nixosConfigurations.scrapy` and `nixosConfigurations.scrapy-wsl`, threading `vars` into every module. WSL gets a distinct hostname (`<hostname>-wsl`) automatically, so the two can coexist on your tailnet without colliding.
- **common.nix** — everything shared between both targets: Tailscale, Jellyfin, CouchDB, Docker, SFTP, Samba, firewall, the main user.
- **configuration.nix** — real-machine-only: bootloader, NetworkManager. Imports `common.nix`.
- **wsl-configuration.nix** — WSL-only: the `nixos-wsl` module (`wsl.enable`, `wsl.defaultUser`). Imports `common.nix`. No bootloader/disk config — WSL2 owns that layer itself.
- **home.nix** — user-level config: Emacs (native-comp, pgtk, daemonized) + auto-bootstraps Doom Emacs on first activation. Shared by both targets.
- **hardware-configuration.nix** — **placeholder, you must replace this** — real-machine only, not used by the WSL target at all.
- **install.sh** — lives at the root of your dotfiles repo (not inside `nixOS/`); copies the files above from `nixOS/` into `/etc/nixos` (on whichever system you run it on), and clones your project repos into `~/projects`. Run it as `./install.sh` from the repo root.
- **post-install.sh** — also at the repo root; run once after `nixos-rebuild switch` succeeds, on either target. Enables `loginctl linger` for your user.

## Doc index
- [configuration.md](./configuration.md) — `vars.nix` reference, design assumptions
- [deploy-real-machine.md](./deploy-real-machine.md) — installing on a real machine/VM
- [deploy-wsl.md](./deploy-wsl.md) — installing NixOS-WSL
- [boot-and-updates.md](./boot-and-updates.md) — what auto-starts, and how to apply future changes on each machine
- [first-boot-setup.md](./first-boot-setup.md) — Tailscale, Jellyfin, Obsidian sync, SFTP, Docker, Doom Emacs

## Common follow-ups
- **Real HTTPS via Tailscale** for Jellyfin/CouchDB (`tailscale serve`)
- **Encrypted secrets** (sops-nix/agenix) instead of plaintext passwords in `vars.nix`
- **Exit node / subnet router** if you want the server to route LAN traffic into your tailnet
- **GPU transcoding** later — say which GPU and I'll add it
- **WSL2 mirrored networking** (Windows 11) if you want the Samba share reachable from other LAN devices while on the WSL target