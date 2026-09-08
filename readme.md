# vps — NixOS config for a Hostinger VPS

A single-host NixOS config (26.05) for a Hostinger VPS running Obsidian sync (CouchDB), a self-hosted git server (Forgejo), local AI (Ollama + Open WebUI), n8n workflow automation, and Docker — all locked down to your Tailscale tailnet, plus Doom Emacs for a comfortable shell.

Scaffolded from a larger multi-machine dotfiles setup; folded in what used to be a separate `headless` machine's services (Obsidian sync, git server, n8n) directly onto this one VPS host, and dropped everything unrelated to a headless server (desktop environment, WSL target).

Full documentation lives in [`doc/`](./doc/overview.md):

- **[doc/overview.md](./doc/overview.md)** — start here: architecture, repository layout, file-by-file breakdown
- **[doc/configuration.md](./doc/configuration.md)** — `hosts/defaults.nix` + `hosts/vps/vars.nix` reference, design assumptions
- **[doc/deploy-real-machine.md](./doc/deploy-real-machine.md)** — first-time install on the Hostinger VPS
- **[doc/boot-and-updates.md](./doc/boot-and-updates.md)** — what auto-starts at boot, and how to apply future changes
- **[doc/first-boot-setup.md](./doc/first-boot-setup.md)** — one-time setup: Tailscale, Obsidian sync, git server, n8n, local AI, Doom Emacs, shell helpers

## Quick start
```bash
git clone <your-repo-url> ~/dotFiles
cd ~/dotFiles
./scripts/install.sh
sudo nixos-rebuild switch --flake /etc/nixos#vps
./scripts/post-install.sh
```
See the deploy guide above for first-time setup on the fresh VPS.

## Checking everything's actually reachable
`check-remote.sh` runs from **any client device on your tailnet** (your laptop, phone via Termux, etc.) — not the server itself — and tests SSH, SFTP, CouchDB, Forgejo, n8n, and Open WebUI all in one go:
```bash
./scripts/check-remote.sh --host vps
```
See [doc/first-boot-setup.md](./doc/first-boot-setup.md) for full usage and flags.
