# Secrets (sops-nix)

Off by default (`vars.secretsEnabled = false`) — the plaintext values already in `hosts/vps/vars.nix` (`initialPassword`, `backupPassword`) keep working exactly as before until you complete this setup and flip it on. Nothing breaks if you never do this.

## What this does and doesn't cover
- **Covered**: your login password (`initialPassword` → a proper hashed password, sops-managed) and the restic backup encryption password.
- **NOT covered**: `couchdbAdminPass`. The nixpkgs CouchDB module's `adminPass` option only accepts a literal Nix string, not a file path — so it always ends up readable in the Nix store (by any local user who can read the store) regardless of sops-nix. Mitigation: CouchDB is already tailnet-only, so exposure is limited to "another local user account on this VPS could read it" — low-risk on a single-user server.

## One-time setup

1. **Install `sops` and `age`**:
   ```bash
   nix-shell -p sops age
   ```

2. **Generate an age key** on the server:
   ```bash
   mkdir -p ~/.config/sops/age
   age-keygen -o ~/.config/sops/age/keys.txt
   ```
   Prints a public key starting with `age1...` — copy it, you need it in step 4.

3. **Move the key to where `common/base.nix` expects it**:
   ```bash
   sudo mkdir -p /var/lib/sops-nix
   sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt
   sudo chmod 600 /var/lib/sops-nix/key.txt
   ```

4. **Create `.sops.yaml`** at your repo root (not inside `nixOS/`):
   ```yaml
   keys:
     - &vps age1yourpublickeyfromstep2...
   creation_rules:
     - path_regex: secrets\.yaml$
       key_groups:
         - age:
             - *vps
   ```

5. **Generate a proper password hash** for your login password:
   ```bash
   mkpasswd -m sha-512
   ```
   (`nix-shell -p mkpasswd` if not available)

6. **Create and encrypt `secrets.yaml`** at your repo root:
   ```bash
   cd ~/dotFiles
   sops secrets.yaml
   ```
   Put in:
   ```yaml
   userPasswordHash: $6$yourhashfromstep5...
   backupPassword: some-long-random-string-here
   ```
   Once saved, `secrets.yaml` is encrypted on disk — safe to commit to git.

7. **Flip the switch** — in `nixOS/hosts/vps/vars.nix`:
   ```nix
   secretsEnabled = true;
   ```

8. **Rebuild**:
   ```bash
   cd ~/dotFiles
   git add .sops.yaml secrets.yaml nixOS/hosts/vps/vars.nix
   git commit -m "Enable sops-nix secrets"
   ./scripts/install.sh
   sudo nixos-rebuild switch --flake /etc/nixos#vps
   ```

## Rotating a secret later
```bash
cd ~/dotFiles
sops secrets.yaml   # edit, save (re-encrypts automatically)
sudo nixos-rebuild switch --flake /etc/nixos#vps
```

[← back to overview](./overview.md)
