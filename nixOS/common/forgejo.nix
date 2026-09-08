# common/forgejo.nix — self-hosted, tailnet-only git server. No firewall
# changes needed at all: trustedInterfaces in networking.nix already
# covers this port automatically, same as Jellyfin/CouchDB.
# Lightweight (single Go binary, SQLite by default) — fine for a modest
# VPS. Reachable at http://<tailscale-ip>:3000. Off unless
# vars.gitServerEnable = true.
{ config, pkgs, lib, vars, ... }:

lib.mkIf vars.gitServerEnable {
  services.forgejo = {
    enable = true;
    settings.server = {
      HTTP_ADDR = "0.0.0.0"; # firewall (trustedInterfaces) restricts real exposure
      HTTP_PORT = 3000;
      ROOT_URL = "http://${vars.hostname}:3000/";
    };
    settings.service.DISABLE_REGISTRATION = true; # single-user server — no public signup
    settings.webhook.ALLOWED_HOST_LIST = "loopback";   # allow webhooks to call 127.0.0.1 / localhost — needed since n8n runs on the same host
  };

  # Declaratively ensures your admin account exists — idempotent (`|| true`
  # means it doesn't fail on every subsequent rebuild once already
  # created). NOTE: "admin" itself is a reserved username in Forgejo —
  # that's why vars.gitAdminUser isn't literally "admin".
  systemd.services.forgejo.preStart = ''
    ${lib.getExe config.services.forgejo.package} admin user create \
      --admin --username ${vars.gitAdminUser} --password "${vars.gitAdminPass}" \
      --email "${vars.gitAdminUser}@${vars.hostname}.local" || true
  '';

  systemd.services.forgejo.after = [ "network-online.target" ];
  systemd.services.forgejo.wants = [ "network-online.target" ];
}
