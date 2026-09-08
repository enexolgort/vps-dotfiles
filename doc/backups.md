# Backups (restic)

Off by default (`vars.backupEnable = false`). When enabled, backs up daily:
- `mediaDir` — media library (unused on this host, jellyfinEnable = false)
- `/var/lib/couchdb` — CouchDB's actual data directory, i.e. your real Obsidian notes. Easy to forget since it's not the thing you'd naturally think of as "server data," but it's genuinely irreplaceable.
- `/var/lib/forgejo` — your self-hosted git repos
- `/home/<username>/dotFiles` — this config repo (lower priority since it's already in git on GitHub, but doesn't hurt)

## Setup

1. **Decide where backups actually go.** `backupRepo` needs to be set in `hosts/vps/vars.nix`. For this to be a real backup (not just "a second copy on the same disk that dies with it"), point it somewhere physically separate:
   - A remote server over SFTP: `sftp:user@host:/path/to/repo`
   - A `rest-server` instance, B2, S3, etc. — see [restic's own docs](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html) for the exact repository URL format
   - A second attached volume, via `extraMounts` in `vars.nix`

   A single VPS with no second disk has no truly local option worth trusting — an off-box target is the point here.

2. **Set a real backup password** in `vars.nix` (`backupPassword`) — or, once you've done the [sops-nix setup](./secrets.md), it's already wired to use the sops-managed one automatically instead.

3. **Add and flip on**:
   ```nix
   backupEnable = true;
   backupRepo = "sftp:user@remote-host:/path/to/repo";
   backupPassword = "...";
   ```

4. **Rebuild**:
   ```bash
   cd ~/dotFiles
   ./scripts/install.sh
   sudo nixos-rebuild switch --flake /etc/nixos#vps
   ```
   The repository initializes automatically on first run (`initialize = true`) — no separate `restic init` needed.

## Checking it's actually working
```bash
sudo systemctl status restic-backups-vps.service
sudo journalctl -u restic-backups-vps.service -f
```
Runs daily via a systemd timer — check `systemctl list-timers` to see the next scheduled run.

## Restoring

**List available snapshots:**
```bash
sudo restic -r <your-backupRepo-value> --password-file /etc/restic-backup-password snapshots
```

**Restore a specific snapshot to a directory:**
```bash
sudo restic -r <your-backupRepo-value> --password-file /etc/restic-backup-password restore <snapshot-id> --target /tmp/restore-test
```
Restore to a scratch location first and verify before overwriting anything live.

## Retention
Keeps 7 daily, 4 weekly, 6 monthly snapshots (`pruneOpts` in `common/backups.nix`) — older ones get pruned automatically.

[← back to overview](./overview.md)
