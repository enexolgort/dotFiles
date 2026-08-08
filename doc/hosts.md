# Multi-host setup

## How it works
`flake.nix` reads every subdirectory of `nixOS/hosts/` and builds a `nixosConfigurations.<name>` for each one, automatically — there's no list to maintain by hand. Each host's final config is `hosts/defaults.nix` merged with that host's own `hosts/<name>/vars.nix`, with the host's own values winning on conflict.

Current hosts:

| Host | targetType | Services | Project repos |
|---|---|---|---|
| `dusty` | `real` | Jellyfin | `transmission-webUi` |
| `headless` | `wsl` | Obsidian (CouchDB), Forgejo | `transmission-API` |
| `scrapy` | `real` | Ollama + Open WebUI (local AI) | — |

## Installing/updating a specific host
```bash
cd ~/dotFiles
./scripts/install.sh dusty        # or headless, or scrapy
```
Omit the argument for an interactive menu instead. This copies the whole `nixOS/` tree into `/etc/nixos` (every host's files need to exist for the flake to evaluate at all, even though only one host actually gets built) and clones that host's `projectRepos`.

Then, on that machine:
```bash
sudo nixos-rebuild switch --flake /etc/nixos#dusty
```
(swap in whichever host you're actually on)

`rebuild` (the shell alias from `home.nix`) still works without needing the host name explicitly — `nixos-rebuild` auto-detects it from the machine's own current hostname.

## Adding a new host
1. Create `nixOS/hosts/<name>/vars.nix`:
   ```nix
   {
     hostname = "yourhostname";
     username = "youruser";
     gitEmail = "you@yourhostname.local";
     targetType = "real"; # or "wsl"

     jellyfinEnable = false;
     obsidianEnable = false;
     gitServerEnable = false;
     aiEnable = false;

     projectRepos = [ ];
   }
   ```
2. If `targetType = "real"`, also add `nixOS/hosts/<name>/hardware-configuration.nix` — a placeholder until you run `nixos-generate-config` on that actual machine (see [deploy-real-machine.md](./deploy-real-machine.md)). WSL hosts don't need this file at all.
3. Only override what's actually different from `hosts/defaults.nix` — you don't need to repeat `mediaDir`, `sftpDir`, timezone, etc. unless this host genuinely needs something different.
4. `./scripts/install.sh <name>` on that machine, then the usual `nixos-rebuild switch --flake /etc/nixos#<name>`.

## Service toggles
Each host's `vars.nix` sets these directly — no interactive prompting, no shared on/off switch affecting every machine:
```nix
jellyfinEnable = true | false;
obsidianEnable = true | false;   # CouchDB backend for Obsidian Self-hosted LiveSync
gitServerEnable = true | false;  # Forgejo
aiEnable = true | false;         # Ollama + Open WebUI, see common/ai.nix
```
`common/backups.nix`'s restic paths are conditional on these too — a host with `jellyfinEnable = false` won't try backing up `/var/lib/jellyfin`, since it wouldn't exist there anyway.

## Project repos per host
```nix
projectRepos = [
  "https://github.com/enexolgort/transmission-webUi"
];
```
`install.sh` clones each of these into that host's `projectsDir` (from `hosts/defaults.nix`, default `/data/projects`) — only for the host you're actually installing, not every host's repos on every machine.

## Local AI (scrapy) specifically
`common/ai.nix` enables `services.ollama` (the model runner, port `11434`) and `services.open-webui` (the ChatGPT-style frontend for it, default port `8080`) — both real, existing NixOS modules, not something built from scratch. Reachable at `http://<tailscale-ip>:8080` once `aiEnable = true` and rebuilt.

CPU-only by default (`acceleration = false` in `common/ai.nix`). If `scrapy` has a compatible GPU, tell me which one and I'll wire up the right acceleration option — CPU inference works but is genuinely slow beyond small models.

[← back to overview](./overview.md)
