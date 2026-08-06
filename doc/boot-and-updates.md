# Boot behavior & applying future changes

## Boot behavior
Every service in this config (Tailscale, Jellyfin, CouchDB, SSH, Samba, Docker) is set to **start automatically on every boot** — that's inherent to `services.X.enable = true;` in NixOS, not something extra you need to configure. Unlike Ubuntu/Debian, there's no separate "enable at startup" step.

The network-dependent ones (Tailscale, Jellyfin, CouchDB, Docker) are also explicitly told to wait for real connectivity (`network-online.target`) before starting, so a slow DHCP lease on first boot or after a power cut doesn't cause them to fail or bind incorrectly.

**The one thing that stays manual**: Tailscale needs an interactive login once (`sudo tailscale up --ssh`, see [first-boot-setup.md](./first-boot-setup.md)) to join your tailnet the first time. After that, its credentials persist on disk and it reconnects automatically on every subsequent boot with no further action — you don't need to re-run `tailscale up` again unless you explicitly log out or reset the node.

**Also worth knowing**: the Emacs daemon is a *user* systemd service, not a system one — by default it only runs while you're logged in (SSH session, etc). Run `./post-install.sh` once after your first successful rebuild (or just `sudo loginctl enable-linger <username>` directly) if you want it to persist across boots/logouts the same way the system services do.

If you ever want to double check any service actually came up after a reboot:
```bash
systemctl status jellyfin couchdb docker tailscaled sshd smbd
```

## Applying future changes
**Important: `/etc/nixos` is per-machine.** Each system (the real machine and WSL) has its own separate copy, populated from your git repo by `install.sh`. Editing a file in the repo doesn't affect either machine until you've pulled and rebuilt *on that specific machine*:

```bash
# on whichever machine you want to update:
cd ~/dotFiles
git pull
./install.sh
sudo nixos-rebuild switch --flake /etc/nixos#scrapy       # or #scrapy-wsl on WSL
```

If you only changed something on one machine and haven't pushed yet, `git pull` obviously won't have anything new — push from wherever you edited first.

Once installed, on the real machine the system's own hostname matches `vars.hostname`, so you can usually drop the `#scrapy` there specifically:
```bash
sudo nixos-rebuild switch --flake /etc/nixos
```
(WSL's hostname is `<vars.hostname>-wsl`, so you'll generally want to keep the explicit `#scrapy-wsl` there.)

[← back to overview](./overview.md)