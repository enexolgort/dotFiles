# Configuration — vars.nix

This is the single place to edit for routine changes:

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

Change the hostname, rename the user, swap the SSH key, whatever — edit `vars.nix`, run `nixos-rebuild switch`, done. No more hunting across three files (that's exactly how the group-ownership bug happened during an early rename — this is the fix for that class of mistake).

## Before you deploy — replace these placeholders in vars.nix
| Variable | What to change |
|---|---|
| `couchdbAdminPass` | a real password |
| `sftpPublicKey` | your actual SSH public key |
| `hostname` / `username` / `timeZone` / `keyMap` | if desired |
| `gitEmail` | your real email |

**On secrets:** `initialPassword` and `couchdbAdminPass` land in plaintext in the Nix store (world-readable). That's fine to get started, but for a server you'll keep long-term, look into [sops-nix](https://github.com/Mic92/sops-nix) or [agenix](https://github.com/ryantm/agenix) to encrypt them instead.

## Assumptions / design choices made
- Media server: **Jellyfin**, CPU-only transcoding, no *arr stack (as decided earlier)
- **Everything sensitive is locked to your tailnet.** The firewall trusts only the `tailscale0` interface — Jellyfin, CouchDB, and SSH/SFTP are not reachable from your LAN or the internet, only from devices logged into your Tailscale network. Samba is the one exception, left open on the LAN — but only on the real-machine target; it's not enabled on WSL at all (nmbd crashes on WSL2's NAT networking).
- **Obsidian sync**: Obsidian's own paid Sync service can't be self-hosted. I set up **CouchDB** instead, which pairs with the community plugin **"Self-hosted LiveSync"** — this is the standard self-hosted alternative and is reachable only via Tailscale.
- **SFTP**: a separate, unprivileged `sftpuser` account, chrooted to `sftpDir`, which is bind-mounted to `mediaDir/upload` — so it can only ever write into your media folder, nothing else on the system. Key-based auth only (no password).
- **Tailscale SSH**: enabled via a one-time `tailscale up --ssh` command (see [first-boot-setup.md](./first-boot-setup.md)) — gives you keyless, identity-based SSH login to your main account from any device in your tailnet, no SSH keys required.

[← back to overview](./overview.md)