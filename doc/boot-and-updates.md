# Boot behavior & applying future changes

## Boot behavior
Every service in this config (Tailscale, Jellyfin, CouchDB, SSH, Docker, and Samba on the real machine) is set to **start automatically on every boot** — that's inherent to `services.X.enable = true;` in NixOS, not something extra you need to configure. Unlike Ubuntu/Debian, there's no separate "enable at startup" step.

The network-dependent ones (Tailscale, Jellyfin, CouchDB, Docker) are also explicitly told to wait for real connectivity (`network-online.target`) before starting, so a slow DHCP lease on first boot or after a power cut doesn't cause them to fail or bind incorrectly.

**The one thing that stays manual**: Tailscale needs an interactive login once (`sudo tailscale up --ssh`, see [first-boot-setup.md](./first-boot-setup.md)) to join your tailnet the first time. After that, its credentials persist on disk and it reconnects automatically on every subsequent boot with no further action — you don't need to re-run `tailscale up` again unless you explicitly log out or reset the node.

**Also worth knowing**: the Emacs daemon is a *user* systemd service, not a system one — by default it only runs while you're logged in (SSH session, etc). Run `./scripts/post-install.sh` once after your first successful rebuild (or just `sudo loginctl enable-linger <username>` directly) if you want it to persist across boots/logouts the same way the system services do.

If you ever want to double check any service actually came up after a reboot:
```bash
systemctl status jellyfin couchdb docker tailscaled sshd smbd
```

## Applying future changes
**Important: `/etc/nixos` is per-machine.** Each machine has its own separate copy, populated from your git repo by `scripts/install.sh`. Editing a file in the repo doesn't affect any machine until you've pulled and rebuilt *on that specific machine*:

```bash
# on whichever machine you want to update:
cd ~/dotFiles
git pull
./scripts/install.sh dusty        # or headless, or scrapy — whichever host this machine is
sudo nixos-rebuild switch --flake /etc/nixos#dusty
```

If you only changed something on one machine and haven't pushed yet, `git pull` obviously won't have anything new — push from wherever you edited first.

Once installed, a machine's own hostname always matches its host's `hostname` value, so you can usually drop the `#<name>` from `nixos-rebuild` specifically (though `install.sh` still needs the host argument, since it doesn't know which machine it's running on until you tell it):
```bash
sudo nixos-rebuild switch --flake /etc/nixos
```
The `rebuild` shell alias already does exactly this.

[← back to overview](./overview.md)
