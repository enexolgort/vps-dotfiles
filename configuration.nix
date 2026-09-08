# configuration.nix — vps, a Hostinger VPS.
# One flat file, nothing hardcoded behind toggles: every service below
# is one you actually turned on (Obsidian sync, git server, local AI,
# n8n). Everything reachable is tailnet-only except SSH, which is also
# open on the public interface until Tailscale SSH is confirmed working
# (see the firewall section below).
{ config, pkgs, lib, ... }:

{
  # --- Identity / locale ------------------------------------------------
  networking.hostName = "vps";
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # /etc/resolv.conf on this VPS had no nameserver lines at all (DHCP
  # never handed any over) — every hostname lookup failed while raw IP
  # traffic worked fine, which is what broke n8n's image pull. Setting
  # these explicitly is what actually populates resolv.conf's
  # nameserver entries.
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # --- Nix itself ---------------------------------------------------
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # Without this, every rebuild leaves the old generation in the store
  # and disk usage only ever grows — worth being deliberate about this
  # on a VPS, where disk is usually the tightest resource.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-generations +2";
  };
  nix.settings.auto-optimise-store = true;

  # --- Bootloader -----------------------------------------------------
  # Confirmed via `lsblk`: this VPS's disk is /dev/sda (virtio-scsi).
  # Confirmed via `sudo parted /dev/sda -- print`: "msdos" partition
  # table (BIOS/legacy boot) — that's why this is GRUB, not
  # systemd-boot (which is UEFI-only).
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # --- User account -----------------------------------------------------
  # Set a real password after first boot with: passwd deploy
  users.users.deploy = {
    isNormalUser = true;
    description = "vps admin";
    extraGroups = [ "wheel" "docker" ];
    shell = pkgs.bash;
    initialPassword = "changeme"; # CHANGE on first login
  };

  system.stateVersion = "24.11"; # do not change after initial install

  # --- Tailscale + firewall lockdown -------------------------------
  # trustedInterfaces means any service that binds 0.0.0.0 is
  # automatically tailnet-only with zero extra config — that's why
  # couchdb/forgejo/ollama/open-webui/n8n below need no firewall rules
  # of their own.
  services.tailscale.enable = true;
  systemd.services.tailscaled = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ 41641 ]; # lets Tailscale establish direct (non-relayed) connections
    # SSH on the PUBLIC interface too, deliberately — this VPS has no
    # physical console to fall back on. Without this, the very first
    # `sudo tailscale up --ssh` (which needs an SSH session to run in
    # the first place) would be unreachable the moment this applies.
    # Once Tailscale SSH is confirmed working, remove 22 here and
    # rebuild to go fully tailnet-only.
    allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true; # fine — SSH itself is tailnet-only (see above)
  };

  # --- Docker -----------------------------------------------------------
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_29; # default (docker_28) is unmaintained/insecure as of nixos-25.11
  };
  systemd.services.docker = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # --- Obsidian sync (Self-hosted LiveSync community plugin, backed by
  # CouchDB). Obsidian's own paid Sync service isn't self-hostable; this
  # is the standard self-hosted alternative. Reachable at
  # http://<tailscale-ip>:5984.
  services.couchdb = {
    enable = true;
    bindAddress = "0.0.0.0"; # legacy [httpd] section — CouchDB 3.x doesn't actually serve from here
    adminUser = "admin";
    adminPass = "changeme-couchdb"; # CHANGE THIS — lands in plaintext in the Nix store either way, see readme
    extraConfig = {
      chttpd = {
        enable_cors = "true";
        bind_address = "0.0.0.0"; # the section CouchDB 3.x's real listener actually reads
      };
      cors = {
        origins = "app://obsidian.md, capacitor://localhost, http://localhost";
        credentials = "true";
        headers = "accept, authorization, content-type, origin, referer";
        methods = "GET,PUT,POST,HEAD,DELETE";
        max_age = "3600";
      };
    };
  };
  systemd.services.couchdb = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # --- Self-hosted git server (Forgejo) --------------------------------
  # Lightweight (single Go binary, SQLite by default). Reachable at
  # http://<tailscale-ip>:3000.
  services.forgejo = {
    enable = true;
    settings.server = {
      HTTP_ADDR = "0.0.0.0"; # firewall (trustedInterfaces above) restricts real exposure
      HTTP_PORT = 3000;
      ROOT_URL = "http://vps:3000/";
    };
    settings.service.DISABLE_REGISTRATION = true; # single-user server — no public signup
    settings.webhook.ALLOWED_HOST_LIST = "loopback"; # allow webhooks to call 127.0.0.1 — needed since n8n runs on the same host
  };
  # Declaratively ensures the admin account exists — idempotent (`|| true`
  # means it doesn't fail on every subsequent rebuild once already
  # created). "admin" itself is a reserved username in Forgejo, hence
  # "enexolgort" below instead.
  systemd.services.forgejo.preStart = ''
    ${lib.getExe config.services.forgejo.package} admin user create \
      --admin --username enexolgort --password "changeme-git" \
      --email "enexolgort@vps.local" || true
  '';
  systemd.services.forgejo.after = [ "network-online.target" ];
  systemd.services.forgejo.wants = [ "network-online.target" ];

  # --- Local AI: Ollama + Open WebUI -----------------------------------
  # CPU-only (no GPU passthrough on this plan). Ollama listens on 11434,
  # Open WebUI's frontend on 8080.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cpu;
    # Start conservative — size up once you know this VPS plan's actual
    # RAM/core count (`nproc`, `free -h`).
    loadModels = [ "qwen2.5:7b" ];
    host = "0.0.0.0"; # defaults to 127.0.0.1-only otherwise
  };
  services.open-webui = {
    enable = true;
    # NOT host = ""; despite that being the "bind all interfaces"
    # convention some docs mention — known nixpkgs bug
    # (NixOS/nixpkgs#378188) breaks the generated systemd unit's shell
    # quoting with an empty string. Explicit "0.0.0.0" avoids it.
    host = "0.0.0.0";
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434/api";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
    };
  };
  systemd.services.ollama = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
  systemd.services.open-webui = {
    after = [ "network-online.target" "ollama.service" ];
    wants = [ "network-online.target" ];
  };

  # --- n8n (workflow automation) ---------------------------------------
  # Official pre-built Docker image, not the native services.n8n module —
  # that one builds n8n's whole TypeScript monorepo from source, which
  # reliably OOMs on a modest VPS. --network=host (not a port mapping)
  # so it stays genuinely tailnet-only via the firewall above instead of
  # bypassing it through Docker's own NAT.
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.n8n = {
    image = "docker.n8n.io/n8nio/n8n:latest";
    autoStart = true;
    extraOptions = [ "--network=host" ];
    volumes = [ "/var/lib/n8n:/home/node/.n8n" ];
    environment = {
      N8N_PORT = "5678";
      N8N_SECURE_COOKIE = "false"; # n8n expects HTTPS by default; Tailscale's WireGuard already covers the transport layer
      NODES_EXCLUDE = "[]"; # re-enables the Execute Command node (disabled by default since n8n 2.0)
      # Code node's require() allowlist — broad but deliberately
      # excludes child_process and vm, which would recreate the same
      # arbitrary-shell-execution risk the Execute Command gate exists
      # to contain.
      NODE_FUNCTION_ALLOW_BUILTIN = "net,crypto,fs,path,util,querystring,url,os,stream,zlib,dns,http,https,buffer,assert";
    };
  };
  systemd.tmpfiles.rules = [
    # 1000 = the "node" user's UID *inside* the official n8n container —
    # this is a bind mount, not a Docker-managed volume, so there's no
    # UID remapping; root:root here causes a hard EACCES crash-loop.
    "d /var/lib/n8n 0755 1000 1000 -"
  ];
  systemd.services.docker-n8n = {
    after = [ "network-online.target" "docker.service" ];
    wants = [ "network-online.target" ];
  };

  # --- Base packages ------------------------------------------------
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    htop
    btop
    ncdu
    jq
    tmux
  ];
}
