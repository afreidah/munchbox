#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# sonar-setup.sh -- create + bind the SonarCloud monorepo projects for munchbox.
#
# SonarCloud's "monorepo wizard" is just a few REST calls under the hood:
#   1. api/projects/create            -- create each component project
#   2. api/alm_settings/set_github_binding (monorepo=true) -- bind to the repo
#   3. api/new_code_periods/set       -- set the new-code definition
#
# Idempotent: re-running skips projects that already exist. Requires a SonarCloud
# token with "Create Projects" + admin on the org.
#
#   SONAR_TOKEN=xxxxx ./scripts/sonar-setup.sh
#
# Author: Alex Freidah / Project: Munchbox
# -------------------------------------------------------------------------------
set -euo pipefail

: "${SONAR_TOKEN:?set SONAR_TOKEN (org token with Create Projects permission)}"
HOST="https://sonarcloud.io"
ORG="afreidah"
REPO="afreidah/munchbox"
NCD_TYPE="PREVIOUS_VERSION" # new code definition

# --- component project key => display name (extend as areas get CI) ---
declare -A PROJECTS=(
  ["afreidah_munchbox_cinc"]="munchbox / cinc"
  # ["afreidah_munchbox_terragrunt"]="munchbox / terragrunt"
  # ["afreidah_munchbox_nomad"]="munchbox / nomad"
)

api() { # method path -- extra -d args follow
  local method=$1 path=$2
  shift 2
  curl -sS -u "${SONAR_TOKEN}:" -X "$method" "${HOST}${path}" "$@"
}

# --- resolve the GitHub ALM setting key for the org (needed for binding) ---
ALM_KEY=$(api GET "/api/alm_settings/list?organization=${ORG}" \
  | python3 -c 'import sys,json; s=[x for x in json.load(sys.stdin).get("almSettings",[]) if x.get("alm")=="github"]; print(s[0]["key"] if s else "")')
[ -n "$ALM_KEY" ] || { echo "ERROR: no GitHub ALM setting found for org ${ORG}; connect GitHub in the SonarCloud org first." >&2; exit 1; }
echo "GitHub ALM setting: ${ALM_KEY}"

for key in "${!PROJECTS[@]}"; do
  name="${PROJECTS[$key]}"
  echo "==> ${key} (${name})"

  # 1. create (ignore "key already exists")
  out=$(api POST "/api/projects/create" \
    -d "organization=${ORG}" -d "project=${key}" -d "name=${name}" -d "visibility=public" || true)
  echo "$out" | grep -qi 'already' && echo "   exists, skipping create" || echo "   created"

  # 2. bind to the repo as a monorepo project (PR decoration)
  api POST "/api/alm_settings/set_github_binding" \
    -d "almSetting=${ALM_KEY}" -d "project=${key}" -d "repository=${REPO}" \
    -d "monorepo=true" -d "summaryCommentEnabled=true" >/dev/null
  echo "   bound to ${REPO} (monorepo)"

  # 3. new code definition
  api POST "/api/new_code_periods/set" -d "project=${key}" -d "type=${NCD_TYPE}" >/dev/null
  echo "   new-code = ${NCD_TYPE}"
done

echo "Done. Verify in the SonarCloud UI; add SONAR_TOKEN to the repo's Actions secrets for CI."
