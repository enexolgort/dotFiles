# Secrets (sops-nix)

Off by default (`vars.secretsEnabled = false`) — the plaintext values already in `vars.nix` (`initialPassword`, `backupPassword`) keep working exactly as before until you complete this setup and flip it on. Nothing breaks if you never do this.

## What this does and doesn't cover
- **Covered**: your login password (`initialPassword` → a proper hashed password, sops-managed) and the restic backup encryption password.
- **NOT covered**: `couchdbAdminPass`. The nixpkgs CouchDB module's `adminPass` option only accepts a literal Nix string, not a file path — so it always ends up readable in the Nix store (by any local user who can read the store) regardless of sops-nix. This is a real limitation in that module, not something worth working around with a hacky patch script. Mitigation: CouchDB is already tailnet-only (never exposed to your LAN or the internet), so the actual exposure is limited to "another local user account on this machine could read it" — a low-risk scenario on a single-user server, but worth knowing.

## One-time setup

1. **Install `sops` and `age`** (not yet in this config's packages — install ad-hoc for this one-time setup):
   ```bash
   nix-shell -p sops age
   ```

2. **Generate an age key** on the server:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```
   This prints a public key starting with `age1...` — copy it, you need it in step 4.

3. **Move the key to where `common.nix` expects it** (matches `sops.age.keyFile` in the config):
   ```bash
   sudo mkdir -p /var/lib/sops-nix
   sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt
   sudo chmod 600 /var/lib/sops-nix/key.txt
   ```

4. **Create `.sops.yaml`** at your repo root (not inside `nixOS/`):
   ```yaml
   keys:
     - &server age1yourpublickeyfromstep2...
   creation_rules:
     - path_regex: secrets\.yaml$
       key_groups:
         - age:
             - *server
   ```

5. **Generate a proper password hash** for your login password (sops stores the *hash*, not the plaintext):
   ```bash
   mkpasswd -m sha-512
   ```
   (prompts for a password, prints the hash — if `mkpasswd` isn't available: `nix-shell -p mkpasswd`)

6. **Create and encrypt `secrets.yaml`** at your repo root:
   ```bash
   cd ~/dotFiles
   sops secrets.yaml
   ```
   This opens an editor (encrypts on save). Put in:
   ```yaml
   userPasswordHash: $6$yourhashfromstep5...
   backupPassword: some-long-random-string-here
   ```
   Once saved, `secrets.yaml` is encrypted on disk — safe to commit to git.

7. **Flip the switch** — in `vars.nix`:
   ```nix
   secretsEnabled = true;
   ```

8. **Rebuild**:
   ```bash
   cd ~/dotFiles
   git add .sops.yaml secrets.yaml nixOS/vars.nix
   git commit -m "Enable sops-nix secrets"
   ./install.sh
   sudo nixos-rebuild switch --flake /etc/nixos
   ```

## Rotating a secret later
```bash
cd ~/dotFiles
sops secrets.yaml   # edit, save (re-encrypts automatically)
sudo nixos-rebuild switch --flake /etc/nixos
```

## If you ever run this on a second machine
Each machine needs its own age key (step 2-3) added to `.sops.yaml`'s `key_groups` (step 4) so it can decrypt `secrets.yaml` too — sops supports multiple recipient keys per file.

[← back to overview](./overview.md)