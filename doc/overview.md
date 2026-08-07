# Overview

## Two targets: real machine + WSL
This flake builds **two separate systems** from the same shared config:
- **`scrapy`** — a real machine or VM (VirtualBox, bare metal, etc.) with an actual disk and bootloader.
- **`scrapy-wsl`** — the same services running inside **NixOS-WSL**, a real NixOS system that runs as its own WSL2 distro on Windows.

They share everything that matters (`common/`: Tailscale, Jellyfin, CouchDB, Forgejo, Docker, SFTP, backups, monitoring, the user account) and differ only in the hardware/boot-specific bits — real machine gets a bootloader, NetworkManager, and Samba; WSL gets the `nixos-wsl` module instead.

**Important distinction, since this tripped things up before**: NixOS-WSL is *not* the same as "installing Nix on top of Ubuntu-WSL" — the latter gives you the `nix`/`nix-shell` commands but no actual NixOS system underneath, so `nixos-rebuild` has nothing to manage (no `fileSystems."/"`, no systemd services it controls, nothing). NixOS-WSL replaces the whole WSL distro with real NixOS. See [deploy-wsl.md](./deploy-wsl.md) if you haven't done this yet.

## Repository layout
```
dotFiles/
├── nixOS/
│   ├── flake.nix
│   ├── vars.nix
│   ├── configuration.nix        # real machine only
│   ├── wsl-configuration.nix    # WSL only
│   ├── hardware-configuration.nix
│   ├── home.nix
│   └── common/                  # shared between both targets, one file per concern
│       ├── default.nix          # imports all the others
│       ├── base.nix             # hostname, locale, nix settings, secrets, user account
│       ├── storage.nix          # directory layout (media/sftp/projects)
│       ├── networking.nix       # Tailscale, firewall, base SSH
│       ├── jellyfin.nix
│       ├── couchdb.nix
│       ├── forgejo.nix
│       ├── docker.nix
│       ├── sftp.nix
│       ├── backups.nix
│       ├── monitoring.nix
│       └── packages.nix
├── doom/                        # tracked Doom Emacs config (init.el, config.el, packages.el)
├── scripts/
│   ├── install.sh
│   ├── post-install.sh
│   ├── check-remote.sh
│   ├── export-jellyfin-config.sh
│   └── restore-jellyfin-config.sh
├── doc/
├── treefmt.nix                  # nix fmt — see below
└── .github/workflows/ci.yml     # nix flake check + shellcheck on every push
```

## What's in here
- **vars.nix** — every value you're likely to want to change (hostname, username, timezone, paths, passwords, keys, backups, monitoring...) lives here. Everything else reads from it. See [configuration.md](./configuration.md).
- **flake.nix** — entrypoint. Defines both `nixosConfigurations.scrapy` and `nixosConfigurations.scrapy-wsl`, threading `vars` into every module. WSL gets a distinct hostname (`<hostname>-wsl`) automatically, so the two can coexist on your tailnet without colliding.
- **common/** — everything shared between both targets, split one file per concern (see layout above) rather than one large file. Import order doesn't matter — `default.nix` just pulls all of them in and NixOS merges the result.
- **configuration.nix** — real-machine-only: bootloader, NetworkManager, Samba, extra storage drives, GNOME (dormant by default). Imports `./common`.
- **wsl-configuration.nix** — WSL-only: the `nixos-wsl` module (`wsl.enable`, `wsl.defaultUser`). Imports `./common`. No bootloader/disk config — WSL2 owns that layer itself.
- **home.nix** — user-level config: Emacs (native-comp, pgtk, daemonized) + auto-bootstraps Doom Emacs on first activation, neofetch, shell helpers (`move`/`copy`/`rename`/`doom`/`rebuild`/`update-server`/`gui-start`/`gui-stop`). Shared by both targets.
- **hardware-configuration.nix** — **placeholder, you must replace this** — real-machine only, not used by the WSL target at all.
- **scripts/install.sh** — copies the nix files above into `/etc/nixos` (on whichever system you run it on), and clones your project repos into `projectsDir` (default `/data/projects`, see `vars.nix`). Run as `./scripts/install.sh` from the repo root.
- **scripts/post-install.sh** — run once after `nixos-rebuild switch` succeeds, on either target. Enables `loginctl linger` for your user, deploys your Doom config, runs `doom sync`.
- **scripts/check-remote.sh** — client-side health check (also what the automated monitoring timer runs on the server itself).
- **scripts/export-jellyfin-config.sh** / **scripts/restore-jellyfin-config.sh** — snapshot/restore Jellyfin's libraries, users, and config.
- **treefmt.nix** + **.github/workflows/ci.yml** — `nix fmt` formats every `.nix` file (alejandra); CI runs `nix flake check` and `shellcheck` on every push. See below.

## Formatting and CI
```bash
nix fmt
```
formats all `.nix` files under `nixOS/` (via `treefmt` + `alejandra`). Both run automatically in CI on every push via `.github/workflows/ci.yml`, alongside `shellcheck` on everything in `scripts/`.

CI checks formatting for both targets, but only **fully builds `scrapy-wsl`** — not `scrapy`. That's deliberate, not a gap: the real-machine target depends on `hardware-configuration.nix`, which is a placeholder in this repo on purpose (it's generated from actual hardware, and a CI runner has no way to genuinely satisfy that assertion). `scrapy-wsl` doesn't depend on it at all, and covers the vast majority of the actual config (everything in `common/`) — so it's the one target CI can meaningfully validate end-to-end. The real-machine target can only be validated by actually rebuilding on the real hardware.

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