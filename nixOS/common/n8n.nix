# common/n8n.nix — self-hosted workflow automation (Zapier-style), pairs
# naturally with local AI on the same host. Off unless vars.n8nEnable =
# true.
#
# NOT using the native nixpkgs services.n8n package here — it builds
# n8n's entire TypeScript monorepo from source via pnpm/turbo, which
# reliably OOMs during the build on lower-memory machines (a real
# problem on a budget VPS specifically). Using the official pre-built
# Docker image instead: zero local compilation.
#
# NETWORKING NOTE: deliberately using Docker's --network=host mode, NOT
# a port mapping (`ports = [ "5678:5678" ]`). A port mapping goes
# through Docker's own NAT/port-publishing, which can bypass the NixOS
# firewall's trustedInterfaces restriction entirely. Host networking
# means n8n binds directly on this machine's real network stack, same
# as any native service, so it stays genuinely tailnet-only.
{ config, pkgs, lib, vars, ... }:

lib.mkIf vars.n8nEnable {
  virtualisation.oci-containers.backend = "docker";

  virtualisation.oci-containers.containers.n8n = {
    image = "docker.n8n.io/n8nio/n8n:latest";
    autoStart = true;
    extraOptions = [ "--network=host" ];
    volumes = [ "/var/lib/n8n:/home/node/.n8n" ];
    environment = {
      N8N_PORT = "5678";
      # n8n defaults to expecting HTTPS and sets a secure-only cookie,
      # which breaks over plain HTTP. Same reasoning as every other
      # service in this repo: Tailscale's own WireGuard encryption
      # already covers the transport layer, and this is never exposed
      # beyond the tailnet.
      N8N_SECURE_COOKIE = "false";
      # Execute Command node is disabled by default since n8n 2.0 (real
      # security advisory: it's arbitrary shell execution inside the
      # container). N8N_NODES_INCLUDE is the officially documented
      # re-enable variable, but there are confirmed community reports
      # (n8n-io/n8n#23439) of it not reliably working. NODES_EXCLUDE set
      # to an empty list is the fallback that reportedly works when
      # INCLUDE doesn't.
      NODES_EXCLUDE = "[]";
      # Code node blocks all module imports by default (separate
      # restriction from the Execute Command node above). Broad set of
      # genuinely useful built-ins, deliberately EXCLUDING child_process
      # and vm, since either would recreate the same arbitrary-shell-
      # execution risk the Execute Command node's own security gate
      # exists to contain.
      NODE_FUNCTION_ALLOW_BUILTIN = "net,crypto,fs,path,util,querystring,url,os,stream,zlib,dns,http,https,buffer,assert";
    };
  };

  systemd.tmpfiles.rules = [
    # 1000 = the "node" user's UID *inside* the official n8n container.
    # This is a bind mount, not a Docker-managed volume, so there's no
    # UID remapping — the container's internal non-root user genuinely
    # needs to own this directory on the host side to write to it at
    # all. root:root here causes a hard EACCES crash-loop on first run.
    "d /var/lib/n8n 0755 1000 1000 -"
  ];

  systemd.services.docker-n8n = {
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
  };
}
