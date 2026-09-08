# common/storage.nix — directory layout for everything under
# vars.mediaDir / sftpDir / projectsDir.
{ config, pkgs, lib, vars, ... }:

{
  systemd.tmpfiles.rules =
    [
      # Media library. Jellyfin runs as the "jellyfin" user; "media" is a
      # dedicated shared group (see base.nix) that the admin user and
      # sftpuser are both members of, so they can actually write here too.
      "d ${vars.mediaDir} 0775 jellyfin media -"
      "d ${vars.mediaDir}/Movies 0775 jellyfin media -"
      "d ${vars.mediaDir}/Music 0775 jellyfin media -"
      "d ${vars.mediaDir}/Photo 0775 jellyfin media -"

      # Where install.sh clones vars.nix's projectRepos. /data itself is
      # root-owned by default, so this needs an explicit rule.
      "d ${vars.projectsDir} 0755 ${vars.username} users -"
    ]
    ++ lib.optionals vars.sftpEnable [
      # SFTP chroot root — must stay root:root (sshd's strict chroot
      # security check), actual writable content is the bind mount inside
      # it, see sftp.nix.
      "d ${vars.sftpDir} 0755 root root -"
      "d ${vars.sftpDir}/upload 0755 root root -"
    ];
}
