# NixOS Multimedia Server (Jellyfin + Doom Emacs + Tailscale + Docker + SFTP)

Jellyfin, Tailscale (with Tailscale SSH), Docker, chrooted SFTP, CouchDB-backed Obsidian sync, Samba, and Doom Emacs — all locked down to your tailnet, deployable to a real machine/VM or NixOS-WSL from the same config.

Full documentation lives in [`doc/`](./doc/overview.md):

- **[doc/overview.md](./doc/overview.md)** — start here: what's in the repo, the two-target (real machine + WSL) architecture, file-by-file breakdown
- **[doc/configuration.md](./doc/configuration.md)** — `vars.nix` reference (the one file you edit for routine changes) and design assumptions
- **[doc/deploy-real-machine.md](./doc/deploy-real-machine.md)** — installing on a real machine or VM
- **[doc/deploy-wsl.md](./doc/deploy-wsl.md)** — installing NixOS-WSL
- **[doc/boot-and-updates.md](./doc/boot-and-updates.md)** — what auto-starts at boot, and how to apply future changes on each machine
- **[doc/first-boot-setup.md](./doc/first-boot-setup.md)** — one-time setup: Tailscale, Jellyfin, Obsidian sync, SFTP, Docker, Doom Emacs, shell helpers

## Quick start
```bash
git clone <your-dotfiles-repo-url> ~/dotFiles
cd ~/dotFiles
./install.sh
sudo nixos-rebuild switch --flake /etc/nixos#scrapy       # or #scrapy-wsl on WSL
./post-install.sh
```
See [doc/overview.md](./doc/overview.md) for what each step actually does, and the deploy guides above for first-time setup on a fresh machine.

## Checking everything's actually reachable
`check-remote.sh` runs from **any client device on your tailnet** (your laptop, phone via Termux, etc.) — not the server itself — and tests SSH, SFTP, Jellyfin, CouchDB, and optionally Samba all in one go:
```bash
./check-remote.sh --host scrapy-wsl
```
See [doc/first-boot-setup.md](./doc/first-boot-setup.md) for full usage and flags.