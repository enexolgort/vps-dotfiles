# Overview

## One machine, one repo
Single-host NixOS config for `vps` — a Hostinger VPS. Everything sensitive (Obsidian sync via CouchDB, self-hosted git via Forgejo, local AI via Ollama/Open WebUI, n8n, SSH beyond the bootstrap window) is locked to your Tailscale tailnet.

This was scaffolded from a larger multi-machine dotfiles repo — the module-per-concern structure under `nixOS/common/` is unchanged, but everything host-specific has been collapsed down to just this one VPS profile, folding in what used to be a separate `headless` machine's services (Obsidian sync, git server, n8n) directly onto `vps`.

## Repository layout
```
vps-dotfiles/
├── nixOS/
│   ├── flake.nix                  # builds nixosConfigurations.vps
│   ├── configuration.nix          # real-machine base (bootloader, extraMounts)
│   ├── home.nix                   # user-level config
│   ├── treefmt.nix
│   ├── hosts/
│   │   ├── defaults.nix           # shared/generic defaults
│   │   └── vps/
│   │       ├── vars.nix           # everything specific to this VPS
│   │       └── hardware-configuration.nix   # placeholder — see doc/deploy-real-machine.md
│   └── common/                    # shared service modules, one file per concern
│       ├── default.nix
│       ├── base.nix
│       ├── storage.nix
│       ├── networking.nix         # Tailscale + firewall lockdown
│       ├── jellyfin.nix           # present, off (jellyfinEnable = false)
│       ├── couchdb.nix            # Obsidian sync backend
│       ├── forgejo.nix            # self-hosted git server
│       ├── ai.nix                 # Ollama + Open WebUI
│       ├── n8n.nix                # workflow automation, via Docker
│       ├── docker.nix
│       ├── sftp.nix                # present, off (sftpEnable = false)
│       ├── backups.nix            # present, off (backupEnable = false)
│       ├── monitoring.nix
│       └── packages.nix
├── dotfiles/
│   └── doom/                      # tracked Doom Emacs config
├── scripts/
│   ├── install.sh                 # deploys nixOS/ to /etc/nixos, clones projectRepos
│   ├── post-install.sh
│   └── check-remote.sh
└── doc/
```

## What's in here
- **hosts/defaults.nix** — generic, safe-for-anyone defaults (timezone, media paths, backup/secrets state).
- **hosts/vps/vars.nix** — this machine specifically: hostname, username, bootloader/disk device, which services run, and `projectRepos`.
- **flake.nix** — merges `defaults.nix` with `hosts/vps/vars.nix` and builds a single `nixosConfigurations.vps`.
- **common/** — every service module, gated behind its own toggle (`obsidianEnable`, `gitServerEnable`, `aiEnable`, `n8nEnable`, …) so nothing runs unless `vars.nix` actually asks for it.
- **configuration.nix** — the real-machine base (bootloader, extra disks). Imports `./common`.
- **home.nix** — user-level config: Emacs (native-comp, pgtk, daemonized) + auto-bootstraps Doom Emacs, neofetch, shell helpers (`move`/`copy`/`rename`/`doom`/`rebuild`/`update-server`/`backup --nixVars`/`restore --nixVars`).
- **scripts/install.sh** — copies the whole `nixOS/` tree into `/etc/nixos`, protecting any real `hardware-configuration.nix` already in place, then clones `projectRepos`.
- **scripts/post-install.sh** — run once after `nixos-rebuild switch` succeeds (linger, Doom sync).
- **scripts/check-remote.sh** — client-side health check (also what the automated monitoring timer runs on the server itself).
- **treefmt.nix** — `nix fmt` formats every `.nix` file (via `treefmt` + `alejandra`).

## Formatting
```bash
cd nixOS && nix fmt
```

## Doc index
- [configuration.md](./configuration.md) — `hosts/defaults.nix` + `hosts/vps/vars.nix` reference, design assumptions
- [deploy-real-machine.md](./deploy-real-machine.md) — first-time install on the Hostinger VPS
- [boot-and-updates.md](./boot-and-updates.md) — what auto-starts, and how to apply future changes
- [first-boot-setup.md](./first-boot-setup.md) — Tailscale, Obsidian sync, git server, n8n, local AI, Doom Emacs
- [secrets.md](./secrets.md) — sops-nix one-time setup, what it does and doesn't cover
- [backups.md](./backups.md) — restic setup, checking it's working, restore instructions

## Common follow-ups
- **Real HTTPS via Tailscale** for CouchDB/Forgejo/n8n (`tailscale serve`)
- **CouchDB admin password still plaintext-in-store** even with sops-nix on — see [secrets.md](./secrets.md) for why (a real nixpkgs module limitation, not an oversight)
- **Offsite backups** — `backupRepo` isn't set by default; a single VPS has no second disk to fall back on, so this really does need a remote target, see [backups.md](./backups.md)
- **Jellyfin/SFTP** — modules are present but off; flip `jellyfinEnable`/`sftpEnable` in `vars.nix` if you ever want them on this box
