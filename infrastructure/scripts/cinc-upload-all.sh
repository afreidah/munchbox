#!/bin/bash
# -------------------------------------------------------------------------------
# Upload every cinc artifact in the repo to cinc-server in one shot.
#
# Order matters: cookbooks first (roles/nodes reference them), then roles
# (nodes reference them), then nodes.
#
# Usage:
#   cinc-upload-all.sh                # everything (cookbooks + roles + nodes)
#   cinc-upload-all.sh --cookbooks    # cookbooks only
#   cinc-upload-all.sh --roles        # roles only
#   cinc-upload-all.sh --nodes        # nodes only
#   cinc-upload-all.sh --no-cookbooks # skip cookbooks (e.g. iterating on roles)
#   cinc-upload-all.sh consul nomad   # just the listed cookbooks/roles/nodes
#                                       (matched by file basename in each
#                                       category; safe to mix)
#
# Pre-reqs:
#   - source munchbox-env.sh           (knife on PATH, knife.rb pointed at our
#                                       cinc-server, validator key in vault)
# -------------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COOKBOOKS_DIR="$REPO_ROOT/infrastructure/cinc/cookbooks"
ROLES_DIR="$REPO_ROOT/infrastructure/cinc/roles"
NODES_DIR="$REPO_ROOT/infrastructure/cinc/nodes"

do_cookbooks=1
do_roles=1
do_nodes=1
SELECTED=()

while (( $# )); do
  case "$1" in
    --cookbooks)    do_cookbooks=1; do_roles=0; do_nodes=0; shift ;;
    --roles)        do_cookbooks=0; do_roles=1; do_nodes=0; shift ;;
    --nodes)        do_cookbooks=0; do_roles=0; do_nodes=1; shift ;;
    --no-cookbooks) do_cookbooks=0; shift ;;
    --no-roles)     do_roles=0; shift ;;
    --no-nodes)     do_nodes=0; shift ;;
    -h|--help)      sed -n '3,20p' "$0"; exit 0 ;;
    *)              SELECTED+=("$1"); shift ;;
  esac
done

command -v knife >/dev/null || { echo "error: knife not on PATH -- source munchbox-env.sh first" >&2; exit 1; }

# --- selected? returns 0 if name matches any --SELECTED filter (or none specified) ---
selected() {
  local target=$1
  (( ${#SELECTED[@]} == 0 )) && return 0
  local s
  for s in "${SELECTED[@]}"; do
    [[ "$s" == "$target" ]] && return 0
  done
  return 1
}

ok=0
fail=0
status() {
  if (( $? == 0 )); then
    printf '  OK   %s\n' "$1"
    ((ok++))
  else
    printf '  FAIL %s\n' "$1"
    ((fail++))
  fi
}

if (( do_cookbooks )); then
  echo "== cookbooks =="
  for d in "$COOKBOOKS_DIR"/*/; do
    name=$(basename "$d")
    selected "$name" || continue
    # --- set +e for the call so we can record fail and keep going ---
    set +e
    knife cookbook upload "$name"    rc=$?
    set -e
    ( exit $rc ); status "cookbook: $name"
  done
  echo
fi

if (( do_roles )); then
  echo "== roles =="
  for f in "$ROLES_DIR"/*.rb; do
    name=$(basename "$f" .rb)
    selected "$name" || continue
    set +e
    knife role from file "$f"    rc=$?
    set -e
    ( exit $rc ); status "role: $name"
  done
  echo
fi

if (( do_nodes )); then
  echo "== nodes =="
  for f in "$NODES_DIR"/*.json; do
    name=$(basename "$f" .json)
    selected "$name" || continue
    set +e
    knife node from file "$f"    rc=$?
    set -e
    ( exit $rc ); status "node: $name"
  done
  echo
fi

echo "done: $ok ok, $fail failed"
(( fail == 0 ))
