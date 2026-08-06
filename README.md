# NixOS Multimedia Server (Jellyfin + Doom Emacs + Tailscale + Docker + SFTP)

## What's in here
- **flake.nix** — entrypoint, pulls in nixpkgs 24.11 + home-manager
- **configuration.nix** — system config: Tailscale, Jellyfin, CouchDB (for Obsidian sync), Docker, chrooted SFTP, Samba, firewall, the `enexolgort` user
- **home.nix** — user-level config: Emacs (native-comp, pgtk) + auto-bootstraps Doom Emacs on first activation
- **hardware-configuration.nix** — **placeholder, you must replace this** (see below)

## Assumptions / design choices made
- Media server: **Jellyfin**, CPU-only transcoding, no *arr stack (as decided earlier)
- **Everything sensitive is locked to your tailnet.** The firewall trusts only the `tailscale0` interface — Jellyfin, CouchDB, and SSH/SFTP are not reachable from your LAN or the internet, only from devices logged into your Tailscale network. Samba is the one exception, left open on the LAN as before.
- **Obsidian sync**: Obsidian's own paid Sync service can't be self-hosted. I set up **CouchDB** instead, which pairs with the community plugin **"Self-hosted LiveSync"** — this is the standard self-hosted alternative and is reachable only via Tailscale.
- **SFTP**: a separate, unprivileged `sftpuser` account, chrooted to `/data/sftp`, which is bind-mounted to `/data/media/upload` — so it can only ever write into your media folder, nothing else on the system. Key-based auth only (no password).
- **Tailscale SSH**: enabled via a one-time `tailscale up --ssh` command (see below) — gives you keyless, identity-based SSH login to the `enexolgort` account from any device in your tailnet, no SSH keys required.

## Deploy steps

1. **Boot the NixOS installer**, partition/mount disks, then:
   ```bash
   nixos-generate-config --root /mnt
   ```
   Copy the generated `/mnt/etc/nixos/hardware-configuration.nix` over the placeholder here.

2. **Copy this folder** to `/mnt/etc/nixos/`.

3. **Edit to taste** — see the "Before you deploy" checklist below.

4. **Install**:
   ```bash
   nixos-install --flake /mnt/etc/nixos#scrapy
   ```
   Set the root password, reboot.

5. Log in as `enexolgort` (password `changeme` — **change it immediately** with `passwd`).

## Before you deploy — replace these placeholders
| File | What to change |
|---|---|
| `configuration.nix` | `adminPass = "changeme-couchdb"` → a real password |
| `configuration.nix` | `sftpuser`'s `openssh.authorizedKeys.keys` → your actual SSH public key |
| `configuration.nix` | hostname / timezone if desired |
| `home.nix` | your git email |

**On secrets:** `initialPassword` and `adminPass` above land in plaintext in the Nix store (world-readable). That's fine to get started, but for a server you'll keep long-term, look into [sops-nix](https://github.com/Mic92/sops-nix) or [agenix](https://github.com/ryantm/agenix) to encrypt them instead — happy to set that up if you want.

## First-boot setup

### Tailscale
```bash
sudo tailscale up --ssh
```
Follow the printed link to authenticate. This joins the tailnet **and** turns on Tailscale SSH, so from then on any device in your tailnet can run `ssh enexolgort@scrapy` (using your Tailscale identity, no SSH key needed) or `ssh enexolgort@<tailscale-ip>`.

Find the server's tailnet address any time with `tailscale ip -4`, or use its MagicDNS name (`scrapy` or `scrapy.<your-tailnet>.ts.net`) if MagicDNS is on in your Tailscale admin console.

### Jellyfin
Browse to `http://<tailscale-ip-or-magicdns-name>:8096` from a device in your tailnet, run the setup wizard, point it at `/data/media`.

### Obsidian sync (Self-hosted LiveSync)
1. In Obsidian, install the community plugin **"Self-hosted LiveSync"**.
2. In the plugin settings, set the remote database URI to:
   `http://<tailscale-ip>:5984/<any-database-name>`
   (pick any database name, e.g. `obsidian-vault` — CouchDB creates it on first sync)
3. Enter the CouchDB admin username/password you set in `configuration.nix`.
4. Since this is plain HTTP over your private tailnet, tick the plugin's "allow insecure (HTTP) connection" option.
5. Repeat on any other device in your tailnet to sync the same vault.

*(If you'd rather have real HTTPS with a proper cert instead of plain HTTP, Tailscale's `tailscale serve` can front CouchDB/Jellyfin with automatic TLS via MagicDNS — worth doing later; ask me and I'll wire it in.)*

### SFTP
From your laptop:
```bash
sftp -i ~/.ssh/id_ed25519 sftpuser@<tailscale-ip>
```
You'll land directly in `/data/media`. Only works with the key you put in `configuration.nix`.

### Docker
```bash
docker run hello-world
```
The `enexolgort` user is in the `docker` group, so no `sudo` needed after re-logging in.

### Doom Emacs
Bootstraps itself automatically on first `home-manager` activation (clones `doomemacs/doomemacs`, runs `doom install`). If it didn't run (e.g. no network at build time):
```bash
~/.config/emacs/bin/doom install
~/.config/emacs/bin/doom sync
```
Then just run `emacs`. Your `~/.config/doom/*.el` files are untouched by Nix.

## Applying future changes
```bash
sudo nixos-rebuild switch --flake /etc/nixos#scrapy
```

## Common follow-ups
- **Real HTTPS via Tailscale** for Jellyfin/CouchDB (`tailscale serve`)
- **Encrypted secrets** (sops-nix/agenix) instead of plaintext passwords
- **Exit node / subnet router** if you want the server to route LAN traffic into your tailnet
- **GPU transcoding** later — say which GPU and I'll add it