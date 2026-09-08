# First-boot setup

## Tailscale
```bash
sudo tailscale up --ssh
```
Follow the printed link to authenticate. This joins the tailnet **and** turns on Tailscale SSH, so from then on any device in your tailnet can run `ssh <username>@vps` (using your Tailscale identity, no SSH key needed) or `ssh <username>@<tailscale-ip>`.

Once confirmed working, remove `22` from `allowedTCPPorts` in `nixOS/common/networking.nix` and rebuild — that port is only there so the very first `tailscale up --ssh` has something to run inside before the tailnet exists.

Find the server's tailnet address any time with `tailscale ip -4`, or use its MagicDNS name (`vps` or `vps.<your-tailnet>.ts.net`) if MagicDNS is on in your Tailscale admin console.

## Obsidian sync (Self-hosted LiveSync)
1. In Obsidian, install the community plugin **"Self-hosted LiveSync"**.
2. In the plugin settings, set the remote database URI to:
   `http://<tailscale-ip>:5984/<any-database-name>`
   (pick any database name, e.g. `obsidian-vault` — CouchDB creates it on first sync)
3. Enter the CouchDB admin username/password from `hosts/vps/vars.nix`.
4. Since this is plain HTTP over your private tailnet, tick the plugin's "allow insecure (HTTP) connection" option.
5. Repeat on any other device in your tailnet to sync the same vault.

## Self-hosted git (Forgejo)
Browse to `http://<tailscale-ip>:3000` from a device in your tailnet. Log in with the `gitAdminUser`/`gitAdminPass` you set in `vars.nix` — that account already exists automatically (created declaratively on first boot), no setup wizard needed.

```bash
git clone http://<tailscale-ip>:3000/<gitAdminUser>/<repo-name>.git
```
Repos live at `/var/lib/forgejo` on the server — included in restic backups if enabled.

## n8n
Browse to `http://<tailscale-ip>:5678`. First visit prompts you to create the owner account (stored locally in `/var/lib/n8n`, not tied to anything else here).

## Local AI (Ollama + Open WebUI)
Browse to `http://<tailscale-ip>:8080` for the Open WebUI chat frontend. Models declared in `aiModels` (`vars.nix`) are pulled automatically on rebuild — first pull can take a while depending on model size and this VPS's bandwidth. Add more models by adding entries and rebuilding.

## Docker
```bash
docker run hello-world
```
Your main user is in the `docker` group, so no `sudo` needed after re-logging in.

## Doom Emacs
Bootstraps itself automatically on first `home-manager` activation. If it didn't run (e.g. no network at build time):
```bash
~/.config/emacs/bin/doom install
~/.config/emacs/bin/doom sync
```

Emacs runs as a background daemon (socket-activated) — connect with `emacsclient -c` or just `emacs`. On a server this needs one extra step the first time, since systemd user services normally only run while you have an active login session:
```bash
./scripts/post-install.sh
```
(or directly: `sudo loginctl enable-linger <username>`)

## Shell helpers
`move`, `copy`, and `rename` are available as shell functions in every new shell:
```bash
move --source /src/file --destination /dst/file
copy --source /src/dir --destination /dst/dir
rename --source /old/name --destination /new/name
```

## Checking everything's actually reachable
`check-remote.sh` is a client-side health check — run it from **any device on your tailnet**, not the server itself:
```bash
./scripts/check-remote.sh --host vps
```
Options:
- `--host <name-or-ip>` — target server (required)
- `--sftp-user <name> --sftp-key <path>` — do an actual SFTP login test, not just a port check (only meaningful once `sftpEnable = true`)

Exits `0` if everything passed, `1` if anything failed.

[← back to overview](./overview.md)
