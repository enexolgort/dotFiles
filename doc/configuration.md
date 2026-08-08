# Configuration — hosts/defaults.nix + per-host vars.nix

Shared values (edit for changes that apply to every machine) live in `nixOS/hosts/defaults.nix`:

```nix
{
  system = "x86_64-linux";
  timeZone = "Europe/Paris";
  locale = "en_US.UTF-8";
  keyMap = "fr";                 # AZERTY. "be" for Belgian AZERTY, "us" for QWERTY

  initialPassword = "changeme";

  mediaDir = "/data/media";
  sftpDir = "/data/sftp";
  projectsDir = "/data/projects";

  sftpPublicKeys = [ "ssh-ed25519 AAAA... your-key" ];

  couchdbAdminUser = "admin";
  couchdbAdminPass = "changeme-couchdb";

  gitAdminUser = "gituser";
  gitAdminPass = "changeme-git";

  sambaWorkgroup = "WORKGROUP";
  extraMounts = [ ];

  backupEnable = false;
  backupRepo = "/mnt/backup/restic-repo";
  backupPassword = "changeme-restic-backup-password";

  secretsEnabled = false;
  notifyWebhook = "";
}
```

Per-machine values (hostname, username, which services run, project repos) live in `nixOS/hosts/<name>/vars.nix` — see [hosts.md](./hosts.md) for the full multi-host reference. Example (`hosts/dusty/vars.nix`):
```nix
{
  hostname = "dusty";
  username = "enexolgort";
  gitEmail = "enexolgort@dusty.local";
  targetType = "real";

  jellyfinEnable = true;
  obsidianEnable = false;
  gitServerEnable = false;
  aiEnable = false;

  projectRepos = [ "https://github.com/enexolgort/transmission-webUi" ];
}
```
The final config for a host is `defaults.nix` merged with that host's own file — the host's values win on any overlap.

## Extra storage drives (real machine hosts only)
For physical drives beyond the boot disk, add them to `extraMounts` — in `hosts/defaults.nix` if every real-machine host should see it, or in a specific host's own `vars.nix` if it's just for that machine:
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
Find the UUID with `sudo blkid` once the drive is physically connected. `nofail` is deliberate and set by default — without it, a missing or disconnected drive would block boot entirely. With it, the system just comes up without that mount if the drive isn't there.

This only applies to `targetType = "real"` hosts — WSL doesn't have physical drives to mount this way.

## Backups, secrets, and monitoring
Three more opt-in features, all off by default in `hosts/defaults.nix`:
- **Backups** (restic) — see [backups.md](./backups.md). Which paths get backed up is automatically conditional on that host's own `jellyfinEnable`/`obsidianEnable`/`gitServerEnable`.
- **Secrets** (sops-nix) — see [secrets.md](./secrets.md)
- **Monitoring** — runs `check-remote.sh` every 15 minutes from each server itself; set `notifyWebhook` to get notified on failure

## Before you deploy — replace these placeholders
| Variable | Where | What to change |
|---|---|---|
| `couchdbAdminPass`, `gitAdminPass` | `hosts/defaults.nix` | real passwords |
| `sftpPublicKeys` | `hosts/defaults.nix` | your actual SSH public key(s) |
| `hostname`, `username`, `gitEmail` | each `hosts/<name>/vars.nix` | per machine |

**On secrets:** `initialPassword`, `couchdbAdminPass`, `gitAdminPass` land in plaintext in the Nix store (world-readable) until `secretsEnabled` is turned on — see [secrets.md](./secrets.md).

## Assumptions / design choices made
- **Everything sensitive is locked to your tailnet.** The firewall trusts only the `tailscale0` interface — Jellyfin, CouchDB, Forgejo, Ollama/Open WebUI, and SSH/SFTP are not reachable from your LAN or the internet, only from devices in your Tailscale network. Samba is the one exception, left open on the LAN — but only on real-machine hosts; not enabled on WSL at all (nmbd crashes on WSL2's NAT networking).
- **Obsidian sync**: Obsidian's own paid Sync service can't be self-hosted. CouchDB + the community plugin **"Self-hosted LiveSync"** is the standard self-hosted alternative, tailnet-only.
- **SFTP**: a separate, unprivileged `sftpuser` account, chrooted to `sftpDir`, bind-mounted to `mediaDir/upload` — can only ever write into the media folder. Key-based auth only.
- **Local AI (`scrapy`)**: Ollama + Open WebUI, both real NixOS modules, CPU-only by default.
- **Tailscale SSH**: enabled via a one-time `tailscale up --ssh` command per machine (see [first-boot-setup.md](./first-boot-setup.md)).

[← back to overview](./overview.md)
