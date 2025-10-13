#!/usr/bin/env bash
# =============================================================================
# Pi-hole Sync Runner (nebula-sync) — NO PREP, NO PROMPTS
# -----------------------------------------------------------------------------
# Usage:
#   export PIHOLE_PASSWORD_GREEN=...   # required
#   export PIHOLE_PASSWORD_LOGAN=...   # required
#   # optional:
#   # export PRIMARY_HOST="http://green.munchbox"
#   # export REPLICA_LOGAN_HOST="http://logan.munchbox"
#   ./sync-pihole.sh
#
# Behavior:
#   - If Docker needs root, re-execs with sudo and **preserves the needed env**.
#   - Never prompts. If env vars are missing, exits with a clear error.
#   - Creates temp secrets (URL|password) for nebula-sync *_FILE inputs.
#   - Cleans temp files/dir on exit (shreds if available).
#   - Runs container as root so strict file perms are readable in-container.
# =============================================================================
set -euo pipefail

# ---- Defaults (override via env if needed) -----------------------------------
PRIMARY_HOST="${PRIMARY_HOST:-http://green.munchbox}"
REPLICA_LOGAN_HOST="${REPLICA_LOGAN_HOST:-http://logan.munchbox}"

# ---- Require env secrets (no prompts) ----------------------------------------
: "${PIHOLE_PASSWORD_GREEN:?Set PIHOLE_PASSWORD_GREEN in your env}"
: "${PIHOLE_PASSWORD_LOGAN:?Set PIHOLE_PASSWORD_LOGAN in your env}"
case "$PIHOLE_PASSWORD_GREEN" in *"|"*) echo "ERROR: PIHOLE_PASSWORD_GREEN contains '|' (delimiter)."; exit 1;; esac
case "$PIHOLE_PASSWORD_LOGAN" in *"|"*) echo "ERROR: PIHOLE_PASSWORD_LOGAN contains '|' (delimiter)."; exit 1;; esac

# ---- Re-exec with sudo if Docker access requires it, preserving env ----------
need_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then return 1; fi
  if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    return 1
  fi
  return 0
}
if need_sudo; then
  exec sudo --preserve-env=PIHOLE_PASSWORD_GREEN,PIHOLE_PASSWORD_LOGAN,PRIMARY_HOST,REPLICA_LOGAN_HOST -- "$0" "$@"
fi

# ---- Temp secrets dir + auto cleanup -----------------------------------------
SECDIR="$(mktemp -d -t pihole-sync.XXXXXXXX)"
chmod 700 "$SECDIR" || true
secure_cleanup() {
  if [[ -d "$SECDIR" ]]; then
    if command -v shred >/dev/null 2>&1; then
      find "$SECDIR" -type f -exec chmod u+w {} \; -exec shred -u -z {} \; 2>/dev/null || true
    fi
    chmod -R u+w "$SECDIR" 2>/dev/null || true
    rm -rf "$SECDIR" 2>/dev/null || true
  fi
}
trap secure_cleanup EXIT

# ---- Write nebula-sync *_FILE inputs (URL|password) --------------------------
umask 077
printf '%s|%s\n' "${PRIMARY_HOST}"       "${PIHOLE_PASSWORD_GREEN}" > "${SECDIR}/primary.txt"
printf '%s|%s\n' "${REPLICA_LOGAN_HOST}" "${PIHOLE_PASSWORD_LOGAN}" > "${SECDIR}/replicas.txt"
chmod 400 "${SECDIR}/primary.txt" "${SECDIR}/replicas.txt"

# ---- Run nebula-sync (root inside container to read 0700/0400) ---------------
docker run --rm --name nebula-sync \
  --user 0:0 \
  -e PRIMARY_FILE=/run/secrets/primary.txt \
  -e REPLICAS_FILE=/run/secrets/replicas.txt \
  -e FULL_SYNC=true \
  -e RUN_GRAVITY=true \
  -v "${SECDIR}:/run/secrets:ro" \
  ghcr.io/lovelaze/nebula-sync:latest

