#!/bin/bash
# --------------------------------------------------------------------
# Job Organization Migration Script
# File: scripts/organize-jobs.sh
#
# Purpose:
#   Reorganizes flat nomad-jobs/ directory into categorized subdirectories
#   based on service type and function.
#
# Usage:
#   ./scripts/organize-jobs.sh
#
# Directory Structure (Before):
#   nomad-jobs/
#     ├── prometheus.nomad.hcl
#     ├── grafana.nomad.hcl
#     ├── traefik.nomad.hcl
#     └── ... (all jobs in one directory)
#
# Directory Structure (After):
#   nomad-jobs/
#     ├── monitoring/
#     │   ├── prometheus.nomad.hcl
#     │   ├── grafana.nomad.hcl
#     │   └── ...
#     ├── infrastructure/
#     │   ├── traefik.nomad.hcl
#     │   └── ...
#     └── ... (organized by category)
#
# Categories:
#   - monitoring: Prometheus, Grafana, Alertmanager, exporters
#   - infrastructure: Traefik, Cloudflared, Nginx
#   - media: Emby, Deluge
#   - development: GitLab, Registry
#   - backup: Snapshot jobs
#   - utility: Placeholder/reservation jobs
#
# Safety:
#   - Uses 'mv' command (will fail if destination exists)
#   - Creates directories before moving files
#   - Preserves do-not-run directory
#   - Shows directory tree after completion
# --------------------------------------------------------------------
set -e

echo "🚀 Reorganizing Nomad jobs by category..."

# Base directory - relative to where script is run from
JOBS_DIR="nomad-jobs"

# Verify we're in the right place
if [ ! -d "$JOBS_DIR" ]; then
    echo "❌ Error: nomad-jobs directory not found"
    echo "   Please run this script from cdktf/munchbox-core/"
    exit 1
fi

# Create category directories
echo "📁 Creating category directories..."
mkdir -p "$JOBS_DIR"/{monitoring,infrastructure,media,development,backup,utility}

# Function to move file if it exists
move_if_exists() {
    local file="$1"
    local dest="$2"

    if [ -f "$JOBS_DIR/$file" ]; then
        mv "$JOBS_DIR/$file" "$JOBS_DIR/$dest/"
        echo "  ✅ $file → $dest/"
    else
        echo "  ⚠️  $file not found or already moved"
    fi
}

# Move monitoring jobs
echo "📦 Moving monitoring jobs..."
move_if_exists "prometheus.nomad.hcl" "monitoring"
move_if_exists "grafana.nomad.hcl" "monitoring"
move_if_exists "alertmanager.nomad.hcl" "monitoring"
move_if_exists "node-exporter.nomad.hcl" "monitoring"
move_if_exists "blackbox-exporter.nomad.hcl" "monitoring"

# Move infrastructure jobs
echo "📦 Moving infrastructure jobs..."
move_if_exists "traefik.nomad.hcl" "infrastructure"
move_if_exists "cloudflared-tunnel.nomad.hcl" "infrastructure"
move_if_exists "nginx-resume.nomad.hcl" "infrastructure"

# Move media jobs
echo "📦 Moving media jobs..."
move_if_exists "emby.nomad.hcl" "media"
move_if_exists "deluge.nomad.hcl" "media"

# Move development jobs
echo "📦 Moving development jobs..."
move_if_exists "gitlab.nomad.hcl" "development"
move_if_exists "gitlab-backup.nomad.hcl" "development"
move_if_exists "registry.nomad.hcl" "development"

# Move backup jobs
echo "📦 Moving backup jobs..."
move_if_exists "consul-snapshot.nomad.hcl" "backup"
move_if_exists "nomad-snapshot.nomad.hcl" "backup"

# Move utility jobs
echo "📦 Moving utility jobs..."
move_if_exists "reserve-k3s-capacity-dummy.nomad.hcl" "utility"

# Keep do-not-run as-is
# Keep .semgrep.yml, Makefile, README.md at root

echo ""
echo "✅ Jobs reorganized by category"
echo ""
echo "📊 New directory structure:"
tree -L 2 "$JOBS_DIR" 2>/dev/null || find "$JOBS_DIR" -maxdepth 2 -type f -name "*.nomad.hcl" | sort

echo ""
echo "ℹ️  Notes:"
echo "  - do-not-run/ directory preserved"
echo "  - Makefile, README.md kept at root"
echo "  - Run 'make validate' to verify all jobs"
echo ""
echo "🎉 Migration complete!"
