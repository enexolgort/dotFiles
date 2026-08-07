# Configuration — vars.nix

This is the single place to edit for routine changes:

```nix
{
  system = "x86_64-linux";
  hostname = "scrapy";
  timeZone = "Europe/Paris";
  locale = "en_US.UTF-8";
  keyMap = "fr";                 # AZERTY. "be" for Belgian AZERTY, "us" for QWERTY

  username = "enexolgort";
  initialPassword = "changeme";
  gitEmail = "enexolgort@scrapy.local";

  mediaDir = "/data/media";
  sftpDir = "/data/sftp";
  sftpPublicKey = "ssh-ed25519 AAAA... your-key";

  couchdbAdminUser = "admin";
  couchdbAdminPass = "changeme-couchdb";

  sambaWorkgroup = "WORKGROUP";

  extraMounts = [ ];              # extra physical drives — see below

  backupEnable = false;           # restic backups — see backups.md
  backupRepo = "/mnt/backup/restic-repo";
  backupPassword = "changeme-restic-backup-password";

  secretsEnabled = false;         # sops-nix — see secrets.md

  notifyWebhook = "";             # health-check failure notifications
}
```

## Extra storage drives (real machine only)
For physical drives beyond the boot disk (e.g. SATA drives on the ZimaBoard), add them to `vars.nix`'s `extraMounts` list rather than editing `configuration.nix` directly:
```nix
extraMounts = [
  {
    device = "/dev/disk/by-uuid/XXXX-XXXX-XXXX-XXXX";
    mountPoint = "/mnt/storage1";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  }
];
```
Find the UUID with `sudo blkid` once the drive is physically connected. `nofail` is deliberate and set by default — without it, a missing or disconnected drive would block boot entirely (the exact kind of hang you'd want to avoid). With it, the system just comes up without that mount if the drive isn't there, instead of hanging indefinitely.

This only applies to the real-machine target (`configuration.nix`) — WSL doesn't have physical drives to mount this way.

## Backups, secrets, and monitoring
Three more opt-in features, all off by default so nothing changes until you deliberately turn them on:
- **Backups** (restic) — see [backups.md](./backups.md)
- **Secrets** (sops-nix, replacing the plaintext passwords in this file) — see [secrets.md](./secrets.md)
- **Monitoring** — runs `check-remote.sh` every 15 minutes from the server itself; set `notifyWebhook` to a URL (ntfy.sh, Discord webhook, etc.) to get notified on failure, or leave it blank to just log results (`journalctl -u healthcheck.service`)

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