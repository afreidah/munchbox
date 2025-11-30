#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# fetch-images.sh
#
# Project: Munchbox / Author: Alex Freidah
#
# Downloads service icons for the Hugo dashboard into assets/icons. Uses public
# dashboard icon collections and official project assets where possible. Icons
# are stored locally so the dashboard does not depend on third-party CDNs at
# runtime.
# -------------------------------------------------------------------------------

set -euo pipefail

# --- Resolve project root (directory containing this script) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="${SCRIPT_DIR}/assets/icons"

mkdir -p "${ICON_DIR}"

# --- Icon URL map ---
# Key   = local filename used in data/config.yaml
# Value = remote URL to download from
declare -A ICON_URLS=(
  # HashiCorp stack
  ["nomad.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/hashicorp-nomad.png"
  ["consul.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/hashicorp-consul.png"
  ["waypoint.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/hashicorp-waypoint.png"

  # Monitoring
  ["grafana.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/grafana.png"
  ["prometheus.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/prometheus.png"
  ["alertmanager.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/alertmanager.png"

  # Media / downloads
  ["emby.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/emby.png"
  ["deluge.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/deluge.png"

  # Registry UI (use Docker icon)
  ["registry-ui.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/docker.png"

  # Temporal UI
  ["temporal-ui.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/temporal.png"

  # Resume site (generic user icon from Dashboard Icons)
  ["resume-site.png"]="https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/dashboard-icons.png"

  # k3s health checker (use k3s brand icon from Simple Icons, SVG)
  ["k3s-health-checker.svg"]="https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/k3s.svg"
)

# --- Download helper ---
download_icon() {
  local name="$1"
  local url="$2"
  local dest="${ICON_DIR}/${name}"

  echo "Downloading ${name} ..."
  curl -fsSL "${url}" -o "${dest}"
}

# --- Main loop ---
for name in "${!ICON_URLS[@]}"; do
  url="${ICON_URLS[${name}]}"

  if [[ -f "${ICON_DIR}/${name}" ]]; then
    echo "Skipping ${name} (already exists)"
    continue
  fi

  if ! download_icon "${name}" "${url}"; then
    echo "ERROR: Failed to download ${name} from ${url}" >&2
  fi
done

echo
echo "Icons written to: ${ICON_DIR}"

