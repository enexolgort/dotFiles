# NixOS Multimedia Server (Jellyfin + Doom Emacs + Tailscale + Docker + SFTP)

## What's in here
- **vars.nix** — every value you're likely to want to change (hostname, username, timezone, paths, passwords, keys...) lives here. Everything else reads from it — you shouldn't need to touch the other files for routine changes.
- **flake.nix** — entrypoint, pulls in nixpkgs 24.11 + home-manager, threads `vars` into every module
- **configuration.nix** — system config: Tailscale, Jellyfin, CouchDB (for Obsidian sync), Docker, chrooted SFTP, Samba, firewall, the main user
- **home.nix** — user-level config: Emacs (native-comp, pgtk) + auto-bootstraps Doom Emacs on first activation
- **hardware-configuration.nix** — **placeholder, you must replace this** (see below) — the one file that's genuinely machine-specific and can't live in `vars.nix`
- **install.sh** — symlinks the above into `/etc/nixos` and clones your project repos into `~/projects`

## Configuration — vars.nix
This is the single place to edit:

```nix
{
  system = "x86_64-linux";
  hostname = "scrapy";
  timeZone = "Europe/Paris";
  locale = "en_US.UTF-8";
  keyMap = "us";                 # "fr" for AZERTY, etc.

  username = "enexolgort";
  initialPassword = "changeme";
  gitEmail = "enexolgort@scrapy.local";

  mediaDir = "/data/media";
  sftpDir = "/data/sftp";
  sftpPublicKey = "ssh-ed25519 AAAA... your-key";

  couchdbAdminUser = "admin";
  couchdbAdminPass = "changeme-couchdb";

  sambaWorkgroup = "WORKGROUP";
}
```

Change the hostname, rename the user, swap the SSH key, whatever — edit `vars.nix`, run `nixos-rebuild switch`, done. No more hunting across three files (that's exactly how the group-ownership bug happened during the last rename — this is the fix for that class of mistake).

## Assumptions / design choices made
- Media server: **Jellyfin**, CPU-only transcoding, no *arr stack (as decided earlier)
- **Everything sensitive is locked to your tailnet.** The firewall trusts only the `tailscale0` interface — Jellyfin, CouchDB, and SSH/SFTP are not reachable from your LAN or the internet, only from devices logged into your Tailscale network. Samba is the one exception, left open on the LAN as before.
- **Obsidian sync**: Obsidian's own paid Sync service can't be self-hosted. I set up **CouchDB** instead, which pairs with the community plugin **"Self-hosted LiveSync"** — this is the standard self-hosted alternative and is reachable only via Tailscale.
- **SFTP**: a separate, unprivileged `sftpuser` account, chrooted to `sftpDir`, which is bind-mounted to `mediaDir/upload` — so it can only ever write into your media folder, nothing else on the system. Key-based auth only (no password).
- **Tailscale SSH**: enabled via a one-time `tailscale up --ssh` command (see below) — gives you keyless, identity-based SSH login to your main account from any device in your tailnet, no SSH keys required.

## Deploy steps

1. **Boot the NixOS installer**, partition/mount disks, then:
   ```bash
   nixos-generate-config --root /mnt
   ```
   Copy the generated `/mnt/etc/nixos/hardware-configuration.nix` over the placeholder here.

2. **Edit `vars.nix`** to taste (hostname, username, SSH key, passwords — see checklist below).

3. **Copy this folder** to `/mnt/etc/nixos/`.

4. **Install**:
   ```bash
   nixos-install --flake /mnt/etc/nixos#<hostname-from-vars.nix>
   ```
   (defaults to `#scrapy` unless you changed `vars.hostname`). Set the root password, reboot.

5. Log in as the username you set in `vars.nix` (password `initialPassword` from `vars.nix` — **change it immediately** with `passwd`).

## Before you deploy — replace these placeholders in vars.nix
| Variable | What to change |
|---|---|
| `couchdbAdminPass` | a real password |
| `sftpPublicKey` | your actual SSH public key |
| `hostname` / `username` / `timeZone` / `keyMap` | if desired |
| `gitEmail` | your real email |

**On secrets:** `initialPassword` and `couchdbAdminPass` land in plaintext in the Nix store (world-readable). That's fine to get started, but for a server you'll keep long-term, look into [sops-nix](https://github.com/Mic92/sops-nix) or [agenix](https://github.com/ryantm/agenix) to encrypt them instead — happy to set that up if you want.

## Boot behavior
Every service in this config (Tailscale, Jellyfin, CouchDB, SSH, Samba, Docker) is set to **start automatically on every boot** — that's inherent to `services.X.enable = true;` in NixOS, not something extra you need to configure. Unlike Ubuntu/Debian, there's no separate "enable at startup" step.

The network-dependent ones (Tailscale, Jellyfin, CouchDB, Docker) are also explicitly told to wait for real connectivity (`network-online.target`) before starting, so a slow DHCP lease on first boot or after a power cut doesn't cause them to fail or bind incorrectly.

**The one thing that stays manual**: Tailscale needs an interactive login once (`sudo tailscale up --ssh`, see below) to join your tailnet the first time. After that, its credentials persist on disk and it reconnects automatically on every subsequent boot with no further action — you don't need to re-run `tailscale up` again unless you explicitly log out or reset the node.

If you ever want to double check any service actually came up after a reboot:
```bash
systemctl status jellyfin couchdb docker tailscaled sshd smbd
```

## First-boot setup

### Tailscale
```bash
sudo tailscale up --ssh
```
Follow the printed link to authenticate. This joins the tailnet **and** turns on Tailscale SSH, so from then on any device in your tailnet can run `ssh <username>@<hostname>` (using your Tailscale identity, no SSH key needed) or `ssh <username>@<tailscale-ip>`.

Find the server's tailnet address any time with `tailscale ip -4`, or use its MagicDNS name (`<hostname>` or `<hostname>.<your-tailnet>.ts.net`) if MagicDNS is on in your Tailscale admin console.

### Jellyfin
Browse to `http://<tailscale-ip-or-magicdns-name>:8096` from a device in your tailnet, run the setup wizard, point it at `mediaDir` (default `/data/media`).

### Obsidian sync (Self-hosted LiveSync)
1. In Obsidian, install the community plugin **"Self-hosted LiveSync"**.
2. In the plugin settings, set the remote database URI to:
   `http://<tailscale-ip>:5984/<any-database-name>`
   (pick any database name, e.g. `obsidian-vault` — CouchDB creates it on first sync)
3. Enter the CouchDB admin username/password from `vars.nix`.
4. Since this is plain HTTP over your private tailnet, tick the plugin's "allow insecure (HTTP) connection" option.
5. Repeat on any other device in your tailnet to sync the same vault.

*(If you'd rather have real HTTPS with a proper cert instead of plain HTTP, Tailscale's `tailscale serve` can front CouchDB/Jellyfin with automatic TLS via MagicDNS — worth doing later; ask me and I'll wire it in.)*

### SFTP
From your laptop:
```bash
sftp -i ~/.ssh/id_ed25519 sftpuser@<tailscale-ip>
```
You'll land directly in `mediaDir`. Only works with the key you set as `sftpPublicKey` in `vars.nix`.

### Docker
```bash
docker run hello-world
```
Your main user is in the `docker` group, so no `sudo` needed after re-logging in.

### Doom Emacs
Bootstraps itself automatically on first `home-manager` activation (clones `doomemacs/doomemacs`, runs `doom install`). If it didn't run (e.g. no network at build time):
```bash
~/.config/emacs/bin/doom install
~/.config/emacs/bin/doom sync
```
Then just run `emacs`. Your `~/.config/doom/*.el` files are untouched by Nix.

## Applying future changes
```bash
sudo nixos-rebuild switch --flake /etc/nixos#<hostname-from-vars.nix>
```
Once installed, the system's own hostname matches `vars.hostname`, so you can usually drop the `#<hostname>` entirely:
```bash
sudo nixos-rebuild switch --flake /etc/nixos
```

## Common follow-ups
- **Real HTTPS via Tailscale** for Jellyfin/CouchDB (`tailscale serve`)
- **Encrypted secrets** (sops-nix/agenix) instead of plaintext passwords in `vars.nix`
- **Exit node / subnet router** if you want the server to route LAN traffic into your tailnet
- **GPU transcoding** later — say which GPU and I'll add it
- **Per-machine vars.nix** if you ever run this config on more than one box (e.g. `vars-scrapy.nix`, `vars-laptop.nix`, selected in `flake.nix`)
