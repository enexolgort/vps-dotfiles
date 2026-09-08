# common/jellyfin.nix — reachable only via your tailnet at
# http://<tailscale-ip>:8096. Media directory layout is in storage.nix.
# Off by default on this host (vars.jellyfinEnable = false) — flip it on
# if you ever want to run it here too.
{ config, pkgs, lib, vars, ... }:

{
  services.jellyfin = {
    enable = vars.jellyfinEnable;
    openFirewall = false; # do NOT open on the public interface; tailscale0 is trusted (see networking.nix)
  };

  systemd.services.jellyfin = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
