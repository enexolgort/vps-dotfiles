# common/monitoring.nix — runs check-remote.sh against this machine's
# own tailscale IP every 15 minutes, logs the result, and POSTs to
# vars.notifyWebhook on failure if one's configured.
{ config, pkgs, lib, vars, ... }:

{
  systemd.services.healthcheck = {
    description = "Periodic health check of remote-facing services";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = vars.username;
    };
    path = [ pkgs.curl pkgs.bash pkgs.tailscale ];
    script = ''
      set -uo pipefail
      SCRIPT="/home/${vars.username}/dotFiles/scripts/check-remote.sh"

      if [ ! -x "$SCRIPT" ]; then
        echo "check-remote.sh not found or not executable at $SCRIPT — skipping"
        exit 0
      fi

      TSIP="$(tailscale ip -4)"
      OUTPUT="$("$SCRIPT" --host "$TSIP" 2>&1)"
      STATUS=$?
      echo "$OUTPUT"

      if [ $STATUS -ne 0 ] && [ -n "${vars.notifyWebhook}" ]; then
        MESSAGE="Health check FAILED on ${vars.hostname}:"$'\n'"$OUTPUT"
        curl -fsS -X POST -H "Content-Type: text/plain" \
          --data "$MESSAGE" "${vars.notifyWebhook}" || true
      fi

      exit $STATUS
    '';
  };

  systemd.timers.healthcheck = {
    description = "Run healthcheck.service every 15 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";
      Persistent = true;
    };
  };
}
