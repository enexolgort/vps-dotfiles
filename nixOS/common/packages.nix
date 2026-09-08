# common/packages.nix — Nix garbage collection/store optimization, and
# system-wide packages.
{ config, pkgs, lib, vars, ... }:

{
  # Without this, every rebuild leaves the old generation in the store
  # and disk usage only ever grows — worth being deliberate about this
  # on a VPS, where disk is usually the tightest resource. Weekly GC
  # keeps the last 2 generations, and store optimization deduplicates
  # identical files across packages/generations.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-generations +2";
  };
  nix.settings.auto-optimise-store = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    htop
    btop
    ncdu      # find what's actually eating disk space
    jq        # parse JSON — handy for couchdb/curl checks
    tmux      # persistent sessions over SSH — survives disconnects
    restic    # for manual backup/restore/inspection — see doc/backups.md
    docker-compose
    nodejs    # includes npm — no separate package needed
  ];
}
