# Backups (restic)

Off by default (`vars.backupEnable = false`). Backs up three things daily:
- `mediaDir` — your media library
- `/var/lib/couchdb` — CouchDB's actual data directory, i.e. your real Obsidian notes. Easy to forget since it's not the thing you'd naturally think of as "the media server data," but it's genuinely irreplaceable in a way ripped media usually isn't.
- `/home/<username>/dotFiles` — your config repo (lower priority since it's already in git on GitHub, but doesn't hurt)

## Setup

1. **Decide where backups actually go.** `vars.backupRepo` defaults to `/mnt/backup/restic-repo` — a placeholder. For this to be a real backup (not just "a second copy on the same disk that dies with it"), point it somewhere physically separate:
   - A second drive added via `extraMounts` in `vars.nix` (see that section) — set `backupRepo` to a path under wherever you mounted it
   - A remote server over SFTP: `sftp:user@host:/path/to/repo`
   - A `rest-server` instance, B2, S3, etc. — restic supports all of these; see [restic's own docs](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html) for the exact repository URL format for your backend

2. **Set a real backup password** in `vars.nix` (`backupPassword`) — or better, once you've done the [sops-nix setup](./secrets.md), it's already wired to use the sops-managed one automatically instead.

3. **Flip it on**:
   ```nix
   backupEnable = true;
   ```

4. **Rebuild**:
   ```bash
   cd ~/dotFiles
   ./install.sh
   sudo nixos-rebuild switch --flake /etc/nixos
   ```
   The repository initializes automatically on first run (`initialize = true` in the config) — no separate `restic init` needed.

## Checking it's actually working
```bash
sudo systemctl status restic-backups-mediaserver.service
sudo journalctl -u restic-backups-mediaserver.service -f
```
Runs daily via a systemd timer (`OnCalendar = "daily"`) — check `systemctl list-timers` to see the next scheduled run.

## Restoring

**List available snapshots:**
```bash
sudo restic -r <your-backupRepo-value> --password-file /etc/restic-backup-password snapshots
```
(swap the password-file path for wherever your sops secret actually resolves to, if `secretsEnabled` is on — check `sudo cat /run/secrets/backupPassword` won't work directly since it's a managed path; use `sops -d secrets.yaml` locally to see it, or just reference the same `passwordFile` restic itself uses)

**Restore a specific snapshot to a directory:**
```bash
sudo restic -r <your-backupRepo-value> --password-file /etc/restic-backup-password restore <snapshot-id> --target /tmp/restore-test
```
Restore to a scratch location first (like `/tmp/restore-test` above) and verify before overwriting anything live — don't restore directly over `/data/media` or `/var/lib/couchdb` without checking what you're getting back first.

**Restore a single file:**
```bash
sudo restic -r <your-backupRepo-value> --password-file /etc/restic-backup-password restore <snapshot-id> --target /tmp/restore-test --include /data/media/movies/somefile.mkv
```

## Retention
Keeps 7 daily, 4 weekly, 6 monthly snapshots (`pruneOpts` in `common.nix`) — older ones get pruned automatically. Adjust those numbers directly in `common.nix` if you want more/less history.

[← back to overview](./overview.md)