# Configuration — hosts/defaults.nix + hosts/vps/vars.nix

Fleet-wide-style defaults (kept separate mostly so it's obvious what's generic vs. VPS-specific) live in `nixOS/hosts/defaults.nix`:

```nix
{
  system = "x86_64-linux";
  timeZone = "UTC";
  locale = "en_US.UTF-8";
  keyMap = "us";

  initialPassword = "changeme";

  mediaDir = "/data/media";
  projectsDir = "/data/projects";

  sambaWorkgroup = "WORKGROUP";
  extraMounts = [ ];

  secretsEnabled = false;
  notifyWebhook = "";
}
```

Everything specific to this machine — hostname, username, bootloader, which services run, passwords, project repos — lives in `nixOS/hosts/vps/vars.nix`:
```nix
{
  hostname = "vps";
  username = "deploy";
  gitEmail = "...";
  bootloader = "grub";
  grubDevice = "/dev/vda";

  jellyfinEnable = false;
  obsidianEnable = true;
  gitServerEnable = true;
  aiEnable = true;
  sftpEnable = false;
  n8nEnable = true;

  aiModels = [ "qwen2.5:7b" ];
  couchdbAdminUser = "admin";
  couchdbAdminPass = "changeme-couchdb";
  gitAdminUser = "gituser";
  gitAdminPass = "changeme-git";

  backupEnable = false;
  projectRepos = [ ];
}
```
The final config is `defaults.nix` merged with `hosts/vps/vars.nix` — the latter wins on any overlap.

## Extra storage drives
For volumes beyond the boot disk, add them to `extraMounts` (either file):
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
Find the UUID with `sudo blkid` once the volume is attached. `nofail` is deliberate and set by default — without it, a missing/disconnected volume would block boot entirely.

## Backups, secrets, and monitoring
Three opt-in features, all off by default:
- **Backups** (restic) — see [backups.md](./backups.md). Which paths get backed up is automatically conditional on `jellyfinEnable`/`obsidianEnable`/`gitServerEnable`.
- **Secrets** (sops-nix) — see [secrets.md](./secrets.md)
- **Monitoring** — runs `check-remote.sh` every 15 minutes from the server itself; set `notifyWebhook` to get notified on failure

## Before you deploy — replace these placeholders
| Variable | Where | What to change |
|---|---|---|
| `couchdbAdminPass`, `gitAdminPass` | `hosts/vps/vars.nix` | real passwords |
| `hostname`, `username`, `gitEmail` | `hosts/vps/vars.nix` | your actual identity |
| `grubDevice` | `hosts/vps/vars.nix` | confirm via `lsblk`/`parted` — Hostinger's VPS usually is `/dev/vda`, but verify |

**On secrets:** `initialPassword`, `couchdbAdminPass`, `gitAdminPass` land in plaintext in the Nix store (world-readable) until `secretsEnabled` is turned on — see [secrets.md](./secrets.md).

## Assumptions / design choices made
- **Everything sensitive is locked to your tailnet.** The firewall trusts only the `tailscale0` interface — CouchDB, Forgejo, Ollama/Open WebUI, n8n, and SFTP are not reachable from the public internet, only from devices in your Tailscale network. SSH stays open on the public interface too, deliberately — a VPS has no physical console fallback, so port 22 needs to survive until Tailscale SSH is confirmed working (see [first-boot-setup.md](./first-boot-setup.md)).
- **Obsidian sync**: Obsidian's own paid Sync service can't be self-hosted. CouchDB + the community plugin **"Self-hosted LiveSync"** is the standard self-hosted alternative, tailnet-only.
- **Local AI**: Ollama + Open WebUI, both real NixOS modules, CPU-only by default — check `nproc`/`free -h` on this VPS before picking bigger models.
- **n8n**: runs via the official Docker image (not the native `services.n8n` module) — building n8n from source reliably OOMs on lower-memory VPS plans.

[← back to overview](./overview.md)
