#!/bin/bash
# -------------------------------------------------------------------------------
# Run cinc-client on every node in the cluster.
#
# bare-metal + proxmox + VMs: ssh as root.
# Oracle nodes: ssh as ubuntu + sudo (no root login by default).
#
# Workaround for `knife ssh` failing against the SSH-CA cert auth path. Until
# nodes get tags (GH #132), the node lists are hardcoded here.
#
# Usage:
#   cinc-client-all.sh                  # all nodes, parallel (8 at a time)
#   cinc-client-all.sh -s               # sequential, one host at a time
#   cinc-client-all.sh nomad-client-01  # just the named node(s)
# -------------------------------------------------------------------------------

set -euo pipefail

ROOT_NODES=(
  goren stabler nomad-server-03
  nomad-client-01 nomad-client-02 nomad-client-03 nomad-client-04 nomad-client-05
  cabot mccoy fontana rubirosa
  cinc-server.munchbox.cc
)

ORACLE_NODES=(
  oracle-node-1 oracle-node-2 oracle-arm-1 oracle-arm-2
)

PARALLEL=1
SELECTED=()

while (( $# )); do
  case "$1" in
    -s|--serial)   PARALLEL=0; shift ;;
    -h|--help)     sed -n '3,15p' "$0"; exit 0 ;;
    *)             SELECTED+=("$1"); shift ;;
  esac
done

# --- pick which hosts to run against ---
if (( ${#SELECTED[@]} )); then
  HOSTS=("${SELECTED[@]}")
else
  HOSTS=("${ROOT_NODES[@]}" "${ORACLE_NODES[@]}")
fi

TOTAL=${#HOSTS[@]}
PROGRESS_DIR=$(mktemp -d -t cinc-all.XXXXXX)
trap 'rm -rf "$PROGRESS_DIR"' EXIT
export PROGRESS_DIR TOTAL
export ORACLE_NODES_STR="${ORACLE_NODES[*]}"

# --- run cinc-client on one node; prints start + done lines with running counter ---
run_one() {
  local host=$1 user cmd start end dur done out rc=0
  if [[ " $ORACLE_NODES_STR " == *" $host "* ]]; then
    user=ubuntu; cmd='sudo cinc-client'
  else
    user=root;   cmd='cinc-client'
  fi
  start=$(date +%s)
  printf '  >> %s: starting\n' "$host"
  if out=$(ssh -n -o ConnectTimeout=5 -o BatchMode=yes "$user@$host" "$cmd" 2>&1); then
    end=$(date +%s); dur=$((end - start))
    : > "$PROGRESS_DIR/${host}.ok"
  else
    rc=$?
    end=$(date +%s); dur=$((end - start))
    : > "$PROGRESS_DIR/${host}.fail"
  fi
  done=$(ls -1 "$PROGRESS_DIR" 2>/dev/null | wc -l)
  local last
  last=$(printf '%s' "$out" | tail -1 | head -c 80)
  if (( rc == 0 )); then
    printf '  OK [%2d/%d] %-20s %3ds  %s\n' "$done" "$TOTAL" "$host" "$dur" "$last"
  else
    printf '  ## [%2d/%d] %-20s %3ds  FAIL: %s\n' "$done" "$TOTAL" "$host" "$dur" "$last"
    return 1
  fi
}
export -f run_one

echo "cinc-client across $TOTAL node(s)$( ((PARALLEL)) && echo ' (parallel, 8)')"
echo

failures=0
if (( PARALLEL )); then
  # --- stdbuf forces line-buffering so xargs flushes each completion immediately ---
  printf '%s\n' "${HOSTS[@]}" \
    | stdbuf -oL xargs -P 8 -I {} bash -c 'run_one "$@"' _ {} \
    || failures=$?
else
  for h in "${HOSTS[@]}"; do
    run_one "$h" || (( ++failures ))
  done
fi

echo
ok_count=$(ls -1 "$PROGRESS_DIR"/*.ok 2>/dev/null | wc -l)
fail_count=$(ls -1 "$PROGRESS_DIR"/*.fail 2>/dev/null | wc -l)
echo "done: $ok_count ok, $fail_count failed (of $TOTAL)"
(( fail_count == 0 ))
