#!/usr/bin/env bash
# check-remote.sh
# Run from ANY client device on your tailnet (laptop, phone via Termux,
# another server) to verify every remotely-controlled service on the vps
# is actually up and reachable. Does not need to run on the server
# itself, and does not need the dotfiles repo present.
#
# Usage:
#   ./check-remote.sh [--host <tailscale-ip-or-name>] [--sftp-user <name>] [--sftp-key <path>]
#
#   --host        Target server (required — e.g. vps, or a tailscale IP)
#   --sftp-user   Attempt an actual SFTP login test (default: skip, port-only check)
#   --sftp-key    Private key to use for the SFTP login test
#
# Exit code: 0 if everything checked passed, 1 if anything failed.

set -uo pipefail

HOST=""
SFTP_USER=""
SFTP_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --sftp-user) SFTP_USER="$2"; shift 2 ;;
    --sftp-key) SFTP_KEY="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^#//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -t 1 ]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
fi

PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  ${GREEN}✓${RESET} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  ${RED}✗${RESET} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo "  ${YELLOW}!${RESET} $1"; }
section() { echo; echo "${BOLD}$1${RESET}"; }

if [ -z "$HOST" ]; then
  echo "!! --host is required, e.g.: $0 --host vps" >&2
  exit 1
fi

check_port() {
  local host="$1" port="$2" label="$3"
  if timeout 5 bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
    exec 3<&- 3>&- 2>/dev/null
    pass "$label (port $port open)"
    return 0
  else
    fail "$label (port $port unreachable — timeout or refused)"
    return 1
  fi
}

echo "${BOLD}Checking remote services on: $HOST${RESET}"

# ======================================================================
# 1. Tailscale reachability itself
# ======================================================================
section "Tailscale"
if command -v tailscale >/dev/null 2>&1; then
  if tailscale ping -c 1 "$HOST" >/dev/null 2>&1; then
    pass "tailscale ping to $HOST succeeded"
  else
    fail "tailscale ping to $HOST failed — check Tailscale is connected on this device"
  fi
else
  warn "tailscale CLI not found on this client — skipping ping test, falling back to plain TCP checks only"
fi

# ======================================================================
# 2. SSH
# ======================================================================
section "SSH"
check_port "$HOST" 22 "SSH"

# ======================================================================
# 3. SFTP — same port as SSH; optionally do a real login test
# ======================================================================
section "SFTP"
if [ -n "$SFTP_USER" ] && [ -n "$SFTP_KEY" ]; then
  if [ ! -f "$SFTP_KEY" ]; then
    fail "SFTP key not found at $SFTP_KEY"
  elif timeout 10 sftp -o StrictHostKeyChecking=accept-new -o BatchMode=yes \
        -i "$SFTP_KEY" "$SFTP_USER@$HOST" <<< "pwd" >/dev/null 2>&1; then
    pass "SFTP login as $SFTP_USER succeeded"
  else
    fail "SFTP login as $SFTP_USER failed (bad key, wrong user, or chroot misconfigured)"
  fi
else
  warn "No --sftp-user/--sftp-key given — skipping actual login test (port already checked above via SSH)"
fi

# ======================================================================
# 4. CouchDB (Obsidian sync backend)
# ======================================================================
section "CouchDB / Obsidian sync"
if command -v curl >/dev/null 2>&1; then
  body="$(curl -s --max-time 5 "http://$HOST:5984" 2>/dev/null)"
  if echo "$body" | grep -q '"couchdb":"Welcome"'; then
    pass "CouchDB responding correctly at http://$HOST:5984"
  else
    fail "CouchDB not responding as expected at http://$HOST:5984"
  fi
else
  check_port "$HOST" 5984 "CouchDB"
fi

# ======================================================================
# 5. Forgejo (git server)
# ======================================================================
section "Forgejo / git server"
if command -v curl >/dev/null 2>&1; then
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$HOST:3000" 2>/dev/null)"
  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    pass "Forgejo responding (HTTP $code) at http://$HOST:3000"
  else
    fail "Forgejo not responding as expected (got HTTP '${code:-no response}') at http://$HOST:3000"
  fi
else
  check_port "$HOST" 3000 "Forgejo"
fi

# ======================================================================
# 6. n8n
# ======================================================================
section "n8n"
check_port "$HOST" 5678 "n8n"

# ======================================================================
# 7. Open WebUI (local AI)
# ======================================================================
section "Open WebUI"
check_port "$HOST" 8080 "Open WebUI"

# ======================================================================
# Summary
# ======================================================================
echo
echo "${BOLD}Summary: $PASS_COUNT passed, $FAIL_COUNT failed${RESET}"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
