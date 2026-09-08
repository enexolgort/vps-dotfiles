# Boot behavior & applying future changes

## Boot behavior
Every service in this config (Tailscale, CouchDB, Forgejo, Ollama/Open WebUI, n8n, Docker, SSH) is set to **start automatically on every boot** — that's inherent to `services.X.enable = true;` in NixOS, not something extra you need to configure.

The network-dependent ones are also explicitly told to wait for real connectivity (`network-online.target`) before starting, so a slow DHCP lease on first boot or after a power cut doesn't cause them to fail or bind incorrectly.

**The one thing that stays manual**: Tailscale needs an interactive login once (`sudo tailscale up --ssh`, see [first-boot-setup.md](./first-boot-setup.md)) to join your tailnet the first time. After that, its credentials persist on disk and it reconnects automatically on every subsequent boot.

**Also worth knowing**: the Emacs daemon is a *user* systemd service, not a system one — by default it only runs while you're logged in. Run `./scripts/post-install.sh` once after your first successful rebuild (or `sudo loginctl enable-linger <username>` directly) if you want it to persist across boots/logouts.

Double check any service actually came up after a reboot:
```bash
systemctl status couchdb forgejo docker tailscaled sshd ollama open-webui docker-n8n
```

## Applying future changes
**Important: `/etc/nixos` is separate from your git checkout.** Editing a file in the repo doesn't affect the running system until you've pulled and rebuilt *on the VPS itself*:

```bash
cd ~/dotFiles
git pull
./scripts/install.sh
sudo nixos-rebuild switch --flake /etc/nixos#vps
```

Once installed, the machine's own hostname matches `hostname` in `vars.nix` ("vps"), so you can usually drop the `#vps` from `nixos-rebuild`:
```bash
sudo nixos-rebuild switch --flake /etc/nixos
```
The `rebuild` shell alias already does exactly this.

[← back to overview](./overview.md)
