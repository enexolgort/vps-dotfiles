# common/sftp.nix — dedicated, chrooted, tailnet-only upload user
# (separate from your normal admin account). Directory layout itself is
# in storage.nix. Off unless vars.sftpEnable = true.
{ config, pkgs, lib, vars, ... }:

lib.mkIf vars.sftpEnable {
  fileSystems."${vars.sftpDir}/upload" = {
    device = vars.mediaDir;
    options = [ "bind" ];
  };

  users.groups.sftponly = {};
  users.users.sftpuser = {
    isSystemUser = true;
    group = "sftponly";
    # mediaDir is owned jellyfin:media, mode 0775 — this is what actually
    # grants write access. "media" here is a real, explicitly created
    # shared group (see base.nix).
    extraGroups = [ "sftponly" "media" ];
    shell = "${pkgs.shadow}/bin/nologin";
    openssh.authorizedKeys.keys = vars.sftpPublicKeys;
  };

  services.openssh.extraConfig = ''
    Match Group sftponly
      ChrootDirectory ${vars.sftpDir}
      ForceCommand internal-sftp
      AllowTcpForwarding no
      X11Forwarding no
      PasswordAuthentication no
  '';
}
