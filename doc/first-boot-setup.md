# First-boot setup

## Tailscale
```bash
sudo tailscale up --ssh
```
Follow the printed link to authenticate. This joins the tailnet **and** turns on Tailscale SSH, so from then on any device in your tailnet can run `ssh <username>@<hostname>` (using your Tailscale identity, no SSH key needed) or `ssh <username>@<tailscale-ip>`.

Find the server's tailnet address any time with `tailscale ip -4`, or use its MagicDNS name (`<hostname>` or `<hostname>.<your-tailnet>.ts.net`) if MagicDNS is on in your Tailscale admin console.

## Jellyfin
Browse to `http://<tailscale-ip-or-magicdns-name>:8096` from a device in your tailnet, run the setup wizard, point it at `mediaDir` (default `/data/media`).

## Obsidian sync (Self-hosted LiveSync)
1. In Obsidian, install the community plugin **"Self-hosted LiveSync"**.
2. In the plugin settings, set the remote database URI to:
   `http://<tailscale-ip>:5984/<any-database-name>`
   (pick any database name, e.g. `obsidian-vault` — CouchDB creates it on first sync)
3. Enter the CouchDB admin username/password from `vars.nix`.
4. Since this is plain HTTP over your private tailnet, tick the plugin's "allow insecure (HTTP) connection" option.
5. Repeat on any other device in your tailnet to sync the same vault.

*(If you'd rather have real HTTPS with a proper cert instead of plain HTTP, Tailscale's `tailscale serve` can front CouchDB/Jellyfin with automatic TLS via MagicDNS — worth doing later.)*

## SFTP
From your laptop:
```bash
sftp -i ~/.ssh/id_ed25519 sftpuser@<tailscale-ip>
```
You'll land directly in `mediaDir`. Only works with the key you set as `sftpPublicKey` in `vars.nix`.

## Docker
```bash
docker run hello-world
```
Your main user is in the `docker` group, so no `sudo` needed after re-logging in.

## Doom Emacs
Bootstraps itself automatically on first `home-manager` activation (clones `doomemacs/doomemacs`, runs `doom install`). If it didn't run (e.g. no network at build time):
```bash
~/.config/emacs/bin/doom install
~/.config/emacs/bin/doom sync
```

Emacs also runs as a background daemon (`services.emacs`, socket-activated) so Doom's startup cost only happens once instead of on every `emacs` invocation — connect to it with `emacsclient -c` (or just `emacs`, since it's set as the default editor and will use the daemon automatically once running).

**On a server, this needs one extra step the first time**, since systemd user services normally only run while you have an active login session:
```bash
./post-install.sh
```
(or directly: `sudo loginctl enable-linger <username>`)
Without this, the Emacs daemon (and its socket) disappears the moment your SSH session ends, and the next `emacsclient` call has to start a fresh one from scratch. With linger enabled, it stays up in the background permanently, same as any system service.

Your `~/.config/doom/*.el` files are untouched by Nix either way.

## Shell helpers
`move`, `copy`, and `rename` are available as shell functions (not aliases) in every new shell:
```bash
move --source /src/file --destination /dst/file
copy --source /src/dir --destination /dst/dir
rename --source /old/name --destination /new/name
```

## Checking everything's actually reachable
`check-remote.sh` (repo root) is a client-side health check — run it from **any device on your tailnet**, not the server itself, to verify SSH, SFTP, Jellyfin, and CouchDB are all actually reachable in one shot instead of manually `curl`/`ping`-ing each one:

```bash
./check-remote.sh --host scrapy-wsl
```

Options:
- `--host <name-or-ip>` — target server (defaults to `scrapy`, or `scrapy-wsl` if `tailscale status` shows it)
- `--sftp-user <name> --sftp-key <path>` — do an actual SFTP login test, not just a port check
- `--samba` — also check Samba's port 445 (real-machine target only; skip entirely on WSL)

Exits `0` if everything passed, `1` if anything failed — usable in scripts/cron if you want periodic monitoring, not just manual checks.

[← back to overview](./overview.md)