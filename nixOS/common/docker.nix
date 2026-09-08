# common/docker.nix
{ config, pkgs, lib, vars, ... }:

{
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29; # default (docker_28) is unmaintained/insecure as of nixos-25.11
  };

  systemd.services.docker = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
