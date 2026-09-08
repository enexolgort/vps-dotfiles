#!/usr/bin/env bash
# install.sh
# Lives in the dotfiles repo's scripts/ folder; the actual nix files
# live in ../nixOS/ (repo-root/nixOS/, a sibling of scripts/).
#
# Single-host repo: this always targets the "vps" nixosConfiguration.
#   1. Optionally regenerates hardware-configuration.nix from this
#      machine's actual current hardware — pass --regen-hardware. Off by
#      default: this OVERWRITES the repo's copy, discarding any manual
#      edits — only pass this when you actually want a fresh capture.
#   2. Copies the WHOLE nixOS/ tree into /etc/nixos. The existing
#      hardware-configuration.nix is protected: never overwritten if a
#      real one already exists at the destination (unless
#      --regen-hardware updated the repo's own copy first).
#   3. Clones vars.nix's projectRepos into projectsDir.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NIXOS_SRC_DIR="$REPO_ROOT/nixOS"
NIXOS_DIR="/etc/nixos"
HOST="vps"
VARS_FILE="$NIXOS_SRC_DIR/hosts/$HOST/vars.nix"

if [ ! -d "$NIXOS_SRC_DIR" ]; then
  echo "!! Expected nix files at $NIXOS_SRC_DIR but that folder doesn't exist."
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "!! This script needs 'jq'. On a fresh machine before the first rebuild: nix-shell -p jq" >&2
  exit 1
fi

REGEN_HARDWARE=false
for arg in "$@"; do
  case "$arg" in
    --regen-hardware) REGEN_HARDWARE=true ;;
    *) echo "!! Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

echo "==> Installing/updating host: $HOST"

# --- 0. Warn if shared default passwords are still set --------------------
check_default_passwords() {
  local found_defaults=()

  grep -q 'initialPassword[[:space:]]*=[[:space:]]*"changeme"' "$NIXOS_SRC_DIR/hosts/defaults.nix" 2>/dev/null \
    && found_defaults+=("initialPassword ('changeme')")

  grep -q 'couchdbAdminPass[[:space:]]*=[[:space:]]*"changeme-couchdb"' "$VARS_FILE" 2>/dev/null \
    && found_defaults+=("couchdbAdminPass ('changeme-couchdb')")

  grep -q 'gitAdminPass[[:space:]]*=[[:space:]]*"changeme-git"' "$VARS_FILE" 2>/dev/null \
    && found_defaults+=("gitAdminPass ('changeme-git')")

  if [ ${#found_defaults[@]} -eq 0 ]; then
    return 0
  fi

  echo "!! WARNING: default placeholder password(s) still in use:"
  for d in "${found_defaults[@]}"; do
    echo "     - $d"
  done

  if [ ! -t 0 ]; then
    echo "   (non-interactive shell, continuing anyway — fix this before relying on the server)"
    return 0
  fi

  read -rp "   Continue anyway with these default passwords? [y/N] " reply
  case "$reply" in
    [yY]|[yY][eE][sS]) ;;
    *)
      echo "Aborted. Edit $VARS_FILE / hosts/defaults.nix to set real passwords, then re-run this script."
      exit 1
      ;;
  esac
}

check_default_passwords

# --- 0b. Optionally regenerate hardware-configuration.nix -----------------
if [ "$REGEN_HARDWARE" = true ]; then
  echo "==> Regenerating hardware-configuration.nix from this machine's actual hardware..."
  sudo nixos-generate-config
  sudo cp /etc/nixos/hardware-configuration.nix "$NIXOS_SRC_DIR/hosts/$HOST/hardware-configuration.nix"
  sudo chown "$(id -u):$(id -g)" "$NIXOS_SRC_DIR/hosts/$HOST/hardware-configuration.nix"
  echo "==> Updated $NIXOS_SRC_DIR/hosts/$HOST/hardware-configuration.nix"
  echo "    Review it, then commit it to git once the rebuild below succeeds."
fi

# --- 1. Copy the whole nixOS/ tree into /etc/nixos -----------------------
echo "==> Copying $NIXOS_SRC_DIR into $NIXOS_DIR"
sudo mkdir -p "$NIXOS_DIR"

# Preserve an existing REAL hardware-configuration.nix before wiping —
# never let the repo's placeholder clobber a real one.
TMP_HW_BACKUP="$(mktemp -d)"
HW_DEST="$NIXOS_DIR/hosts/$HOST/hardware-configuration.nix"
if [ -f "$HW_DEST" ]; then
  sudo cp "$HW_DEST" "$TMP_HW_BACKUP/hardware-configuration.nix"
fi

sudo rm -rf "$NIXOS_DIR"
sudo mkdir -p "$NIXOS_DIR"
sudo cp -r "$NIXOS_SRC_DIR"/. "$NIXOS_DIR"/

if [ -f "$TMP_HW_BACKUP/hardware-configuration.nix" ]; then
  sudo cp "$TMP_HW_BACKUP/hardware-configuration.nix" "$HW_DEST"
  echo "==> Preserved existing real hardware-configuration.nix"
fi
rm -rf "$TMP_HW_BACKUP"

# secrets.yaml (sops-nix) lives at the repo root, not inside nixOS/ —
# only present once you've done the doc/secrets.md setup.
SECRETS_SRC="$REPO_ROOT/secrets.yaml"
if [ -f "$SECRETS_SRC" ]; then
  sudo cp "$SECRETS_SRC" "$NIXOS_DIR/secrets.yaml"
  echo "==> Copied secrets.yaml"
fi

# --- 2. Clone this host's project repos ----------------------------------
PROJECTS_DIR="$(nix --extra-experimental-features 'nix-command' eval --raw --file "$NIXOS_SRC_DIR/hosts/defaults.nix" projectsDir 2>/dev/null || echo "/data/projects")"

mapfile -t REPOS < <(
  nix --extra-experimental-features 'nix-command' eval --json \
    --file "$VARS_FILE" projectRepos 2>/dev/null \
    | jq -r '.[]' 2>/dev/null || true
)

if [ ${#REPOS[@]} -eq 0 ]; then
  echo "==> No projectRepos declared, skipping project cloning"
else
  sudo mkdir -p "$PROJECTS_DIR"
  sudo chown "$(id -u):$(id -g)" "$PROJECTS_DIR"
  echo "==> Projects dir: $PROJECTS_DIR"

  for repo_url in "${REPOS[@]}"; do
    name="$(basename "$repo_url")"
    target="$PROJECTS_DIR/$name"

    if [ -d "$target/.git" ]; then
      echo "==> $name already cloned, skipping (run 'git -C \"$target\" pull' to update)"
      continue
    fi

    echo "==> Cloning $name..."
    git clone "$repo_url" "$target"
  done
fi

echo "==> Done."
echo "    Run: sudo nixos-rebuild switch --flake $NIXOS_DIR#$HOST"
