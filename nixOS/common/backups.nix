# common/backups.nix — off by default, see doc/backups.md for setup and
# restore instructions. Which paths get backed up depends on which
# services are actually enabled (jellyfinEnable, obsidianEnable,
# gitServerEnable) — no point backing up /var/lib/jellyfin when this
# host doesn't run Jellyfin at all.
{ config, pkgs, lib, vars, ... }:

{
  services.restic.backups.vps = lib.mkIf vars.backupEnable {
    initialize = true;
    repository = vars.backupRepo;
    passwordFile =
      if vars.secretsEnabled
      then config.sops.secrets.backupPassword.path
      else "/etc/restic-backup-password"; # written below when secrets aren't set up yet
    paths = [
      vars.mediaDir
      "/home/${vars.username}/dotFiles"
      vars.projectsDir
    ]
    ++ lib.optional vars.obsidianEnable "/var/lib/couchdb"
    ++ lib.optional vars.jellyfinEnable "/var/lib/jellyfin"
    ++ lib.optional vars.gitServerEnable "/var/lib/forgejo";
    exclude = lib.optionals vars.jellyfinEnable [
      "/var/lib/jellyfin/cache"
      "/var/lib/jellyfin/metadata"
      "/var/lib/jellyfin/transcodes"
    ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };

  # Fallback plaintext password file for restic when sops-nix isn't set
  # up yet — same plaintext-in-store caveat as everything else in
  # vars.nix until secretsEnabled is flipped on. Not created at all if
  # backups are disabled.
  environment.etc."restic-backup-password" = lib.mkIf (vars.backupEnable && !vars.secretsEnabled) {
    text = vars.backupPassword;
    mode = "0400";
  };
}
