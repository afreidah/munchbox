#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# adopt-existing-node.sh
#
# One-shot wrapper that runs the full chef-onboarding sequence end-to-end:
#
#   1. prepare-chef-bootstrap.sh <node>
#        Mints AppRole secret_id, uploads encrypted vault_agent data-bag
#        item, uploads the per-node node object from
#        infrastructure/cinc/nodes/<node>.rb (carries run_list + tags + attrs).
#
#   2. bootstrap-cinc-node.sh <ssh-target> <node>
#        Installs cinc-client on the node, drops validator key + the
#        cinc-server TLS cert + client.rb, runs the first cinc-client converge.
#        The node object uploaded in step 1 supplies the run_list.
#
# The two underlying scripts can also be run individually for rotations
# or partial reruns; this wrapper just composes them for the common case
# of "I have a node that ansible used to manage, take it from zero to
# chef-managed".
#
# Usage:
#   source munchbox-env.sh
#   infrastructure/scripts/adopt-existing-node.sh <ssh-target> <chef-node-name>
#
#   <ssh-target>      -- e.g. root@nomad-client-01
#   <chef-node-name>  -- chef-server node identity (e.g. nomad-client-01, oraclearm1)
#
# Example:
#   adopt-existing-node.sh root@nomad-client-01 nomad-client-01
# -------------------------------------------------------------------------------
set -euo pipefail

TARGET="${1:-}"
NODE="${2:-}"

if [[ -z "$TARGET" || -z "$NODE" ]]; then
  echo "usage: $0 <ssh-target> <chef-node-name>" >&2
  echo "  e.g. $0 root@nomad-client-01 nomad-client-01" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== adopt-existing-node :: prepare workstation/chef-server state ==="
"$SCRIPT_DIR/prepare-chef-bootstrap.sh" "$NODE"

echo
echo "=== adopt-existing-node :: bootstrap cinc-client on $TARGET ==="
"$SCRIPT_DIR/bootstrap-cinc-node.sh" "$TARGET" "$NODE"
