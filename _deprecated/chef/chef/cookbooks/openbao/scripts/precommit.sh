#!/bin/bash
# --------------------------------------------------------------------------------
# Wrapper to run cookbook pre-commit checks (cookstyle, chefspec, etc)
# Uses current RVM context — no need to source or hack path
# --------------------------------------------------------------------------------

set -euo pipefail

# --- Ensure we're in the repo root ---
cd "$(dirname "$0")/.."

# --- Run Cookstyle ---
echo "🔍 Running lint..."
bundle exec rake lint

# --- Run Chefspec ---
# echo "🧪 Running spec..."
# bundle exec rake spec
