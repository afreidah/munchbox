#!/bin/bash
# -------------------------------------------------------------------------------
# Cinc-Client Scheduled-Run Toggle
#
# Project: Munchbox / Author: Alex Freidah
#
# Flips the cinc-client.timer on every registered node so a controlled cookbook
# rollout isn't interrupted by a scheduled converge firing on a node you haven't
# promoted yet.
#
#   cinc-timer.sh disable   # stop + disable the timer everywhere (freeze)
#   cinc-timer.sh enable    # enable + start the timer everywhere (thaw)
#   cinc-timer.sh status    # show timer state per node
#
# `knife node list` enumerates the fleet; the command runs over the system ssh
# client (not knife's net-ssh) so it honors the SSH-CA host trust. Login is root
# everywhere except the oracle nodes, which are reached by their public-IP
# /etc/hosts aliases (oraclenode1 -> oracle-node-1) as ubuntu + sudo. Pass a
# grep -E pattern as the 2nd arg to narrow the set.
# -------------------------------------------------------------------------------

set -euo pipefail

TIMER="cinc-client.timer"
ACTION="${1:-}"
FILTER="${2:-.}"

case "$ACTION" in
  disable) SUB="disable --now $TIMER" ;;
  enable)  SUB="enable --now $TIMER" ;;
  status)  SUB="is-enabled $TIMER; systemctl is-active $TIMER" ;;
  *)
    echo "usage: $(basename "$0") {disable|enable|status} [node-filter-regex]" >&2
    exit 1
    ;;
esac

# --- Resolve a knife node name to (ssh target, systemctl prefix). Oracle nodes
#     use their dashed public-IP /etc/hosts alias, login ubuntu, needs sudo;
#     everything else resolves by name, logs in as root, runs systemctl direct. ---
for node in $(knife node list | grep -Ev '^cinc-server' | grep -E "$FILTER"); do
  NODES+=("$node")
done

echo "==> ${ACTION} $TIMER on: ${NODES[*]}"
echo

# --- Fan out in parallel; each line is prefixed with its node so failures are
#     attributable. ConnectTimeout keeps a dead node from stalling the batch. ---
for node in "${NODES[@]}"; do
  {
    if [[ "$node" == oracle* ]]; then
      alias=$(echo "$node" | sed -E 's/^oracle(node|arm)([0-9]+)$/oracle-\1-\2/')
      target="ubuntu@$alias"
      cmd="sudo systemctl $SUB"
    else
      target="root@$node"
      cmd="systemctl $SUB"
    fi
    out=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$target" "$cmd" 2>&1) \
      && printf '[ok]   %-20s %s\n' "$node" "$(echo "$out" | paste -sd' ')" \
      || printf '[FAIL] %-20s %s\n' "$node" "$(echo "$out" | paste -sd' ')"
  } &
done
wait
