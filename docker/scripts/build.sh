#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Waypoint Build Script
# ═══════════════════════════════════════════════════════════════════════════
# Purpose:
#   Generates waypoint.hcl by concatenating waypoint-header.hcl with all
#   */waypoint-app.hcl files, then runs waypoint build.
#
# Usage:
#   ./build.sh                           # Build all images
#   ./build.sh -app ops-build-image      # Build specific image
#   ./build.sh -app github-runner-waypoint  # Build runner image
#
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verify we're in docker directory
if [ ! -f "waypoint-header.hcl" ]; then
  echo -e "${RED}❌ Error: waypoint-header.hcl not found${NC}"
  echo "Run this script from docker/ directory"
  exit 1
fi

# Generate waypoint.hcl
echo -e "${YELLOW}🔧 Generating waypoint.hcl...${NC}"
{
  cat waypoint-header.hcl
  echo ""
  cat */waypoint-app.hcl 2>/dev/null || true
} > waypoint.hcl

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Generated waypoint.hcl${NC}"
else
  echo -e "${RED}❌ Failed to generate waypoint.hcl${NC}"
  exit 1
fi

# Run waypoint build with any passed arguments
echo -e "${YELLOW}🔨 Running waypoint build...${NC}"
waypoint build "$@"
