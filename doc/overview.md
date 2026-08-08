# Overview

## Multiple machines, one repo
This flake builds a **separate NixOS system for every machine profile** under `nixOS/hosts/`. Right now that's three:
- **`dusty`** — real machine. Jellyfin, clones `transmission-webUi`.
- **`headless`** — NixOS-WSL. Obsidian sync (CouchDB), self-hosted git server (Forgejo), clones `transmission-API`.
- **`scrapy`** — real machine. Local AI models (Ollama) + a web UI (Open WebUI).

Adding a fourth machine means adding a fourth `hosts/<name>/` directory — nothing else changes. See [hosts.md](./hosts.md) for the full reference.

They all share everything that matters (`common/`: Tailscale, Docker, SFTP, backups, monitoring, the user account — plus whichever of Jellyfin/CouchDB/Forgejo/Ollama that specific host turns on) and differ only in which services are enabled and whether they're a real machine or WSL.

**Important distinction, since this tripped things up before**: NixOS-WSL is *not* the same as "installing Nix on top of Ubuntu-WSL" — the latter gives you the `nix`/`nix-shell` commands but no actual NixOS system underneath, so `nixos-rebuild` has nothing to manage (no `fileSystems."/"`, no systemd services it controls, nothing). NixOS-WSL replaces the whole WSL distro with real NixOS. See [deploy-wsl.md](./deploy-wsl.md) if you haven't done this yet.

## Repository layout
```
dotFiles/
├── nixOS/
│   ├── flake.nix                  # dynamically builds a nixosConfiguration per hosts/* directory
│   ├── configuration.nix          # real-machine base (bootloader, Samba, GNOME, extraMounts)
│   ├── wsl-configuration.nix      # WSL base
│   ├── home.nix                   # user-level config, shared by every host
│   ├── treefmt.nix
│   ├── hosts/
│   │   ├── defaults.nix           # shared values every host inherits
│   │   ├── dusty/
│   │   │   ├── vars.nix
│   │   │   └── hardware-configuration.nix
│   │   ├── headless/
│   │   │   └── vars.nix           # WSL — no hardware-configuration.nix needed
│   │   └── scrapy/
│   │       ├── vars.nix
│   │       └── hardware-configuration.nix
│   └── common/                    # shared service modules, one file per concern
│       ├── default.nix
│       ├── base.nix
│       ├── storage.nix
│       ├── networking.nix
│       ├── jellyfin.nix
│       ├── couchdb.nix
│       ├── forgejo.nix
│       ├── ai.nix                 # Ollama + Open WebUI
│       ├── docker.nix
│       ├── sftp.nix
│       ├── backups.nix
│       ├── monitoring.nix
│       └── packages.nix
├── doom/                          # tracked Doom Emacs config
├── scripts/
│   ├── install.sh                 # picks a host, deploys it, clones its project repos
│   ├── post-install.sh
│   ├── check-remote.sh
│   ├── export-jellyfin-config.sh
│   └── restore-jellyfin-config.sh
├── doc/
└── .github/workflows/ci.yml
```

## What's in here
- **hosts/defaults.nix** — every value shared across all machines (timezone, media paths, backup/secrets defaults, etc.). See [hosts.md](./hosts.md).
- **hosts/\<name\>/vars.nix** — what's actually specific to that one machine: hostname, username, `targetType` (`"real"` or `"wsl"`), which services it runs, and its `projectRepos` list.
- **flake.nix** — reads every directory under `hosts/`, merges `defaults.nix` with that host's `vars.nix`, and builds a `nixosConfigurations.<name>` for each — no manual registration needed when adding a host.
- **common/** — every service module, gated behind that host's own toggle (`jellyfinEnable`, `obsidianEnable`, `gitServerEnable`, `aiEnable`) so nothing runs unless a host actually asks for it.
- **configuration.nix** / **wsl-configuration.nix** — the two possible bases a host can pick via `targetType`. Both import `./common`.
- **home.nix** — user-level config: Emacs (native-comp, pgtk, daemonized) + auto-bootstraps Doom Emacs, neofetch, shell helpers (`move`/`copy`/`rename`/`doom`/`rebuild`/`update-server`/`gui-start`/`gui-stop`/`backup --nixVars`/`restore --nixVars`). Shared by every host.
- **scripts/install.sh** — `./scripts/install.sh <host>` (or no argument for an interactive menu). Copies the whole `nixOS/` tree into `/etc/nixos` (every host's files need to exist for the flake to evaluate, even though only one gets built), protecting any real `hardware-configuration.nix` already in place, then clones that host's `projectRepos`.
- **scripts/post-install.sh** — run once after `nixos-rebuild switch` succeeds, on any host. Detects which host it's on via the machine's actual hostname.
- **scripts/check-remote.sh** — client-side health check (also what the automated monitoring timer runs on the server itself).
- **scripts/export-jellyfin-config.sh** / **scripts/restore-jellyfin-config.sh** — snapshot/restore Jellyfin's libraries, users, and config.
- **treefmt.nix** + **.github/workflows/ci.yml** — `nix fmt` formats every `.nix` file; CI runs formatting checks + builds every WSL-type host + `shellcheck` on every push.

## Formatting and CI
```bash
cd nixOS && nix fmt
```
formats all `.nix` files (via `treefmt` + `alejandra`). Runs automatically in CI too, alongside `shellcheck` on everything in `scripts/`.

CI only **fully builds hosts with `targetType = "wsl"`** (currently just `headless`) — not real-machine hosts. That's deliberate: real-machine hosts depend on their own `hardware-configuration.nix`, which is a placeholder in this repo on purpose (generated from actual hardware; a CI runner has no way to genuinely satisfy that). WSL hosts don't depend on it at all, and cover the vast majority of the actual config (everything in `common/`) — so they're what CI can meaningfully validate end-to-end. Real-machine hosts can only be validated by actually rebuilding on the real hardware.

## Doc index
- [hosts.md](./hosts.md) — the multi-host system: adding a machine, choosing services, install-time selection
- [configuration.md](./configuration.md) — `hosts/defaults.nix` reference, design assumptions
- [deploy-real-machine.md](./deploy-real-machine.md) — installing on a real machine/VM
- [deploy-wsl.md](./deploy-wsl.md) — installing NixOS-WSL
- [boot-and-updates.md](./boot-and-updates.md) — what auto-starts, and how to apply future changes on each machine
- [first-boot-setup.md](./first-boot-setup.md) — Tailscale, Jellyfin, Obsidian sync, SFTP, Docker, Doom Emacs
- [secrets.md](./secrets.md) — sops-nix one-time setup, what it does and doesn't cover
- [backups.md](./backups.md) — restic setup, checking it's working, restore instructions

## Common follow-ups
- **Real HTTPS via Tailscale** for Jellyfin/CouchDB (`tailscale serve`)
- **CouchDB admin password still plaintext-in-store** even with sops-nix on — see [secrets.md](./secrets.md) for why (a real nixpkgs module limitation, not an oversight)
- **Exit node / subnet router** if you want a server to route LAN traffic into your tailnet
- **GPU transcoding / GPU acceleration for Ollama** — say which GPU on which host and I'll add it (`common/ai.nix`'s `acceleration` option, or Jellyfin's hardware transcoding)
- **Samba on WSL hosts** — deliberately not enabled there at all (nmbd crashes on WSL2's NAT networking); would need WSL2 "mirrored" networking mode (Windows 11) plus adding Samba to that host's config yourself
- **Offsite backups** — `backupRepo` defaults to a local placeholder path; point it at a remote target for real disaster protection, see [backups.md](./backups.md)
