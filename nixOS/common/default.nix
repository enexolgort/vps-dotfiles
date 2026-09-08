# common/default.nix — everything this VPS actually needs, one file per
# concern. Every service module below is gated on its own vars.*Enable
# flag, so importing all of them here is safe even for the ones this
# host has turned off. Import order doesn't matter — NixOS merges them.
{
  imports = [
    ./base.nix
    ./storage.nix
    ./networking.nix
    ./jellyfin.nix
    ./couchdb.nix
    ./forgejo.nix
    ./ai.nix
    ./n8n.nix
    ./docker.nix
    ./sftp.nix
    ./backups.nix
    ./monitoring.nix
    ./packages.nix
  ];
}
