# -------------------------------------------------------------------------------
#  Waypoint Bootstrap — Batch Job (run manually to bootstrap server & store token)
#
#  Project: Munchbox
#  Author: Alex Freidah
#
#  One-time job to bootstrap the waypoint-server, extract the auth token,
#  and store it in OpenBao. Run with: nomad job run waypoint-bootstrap.nomad.hcl
#
#  If token already exists in Vault, this will overwrite it.
# -------------------------------------------------------------------------------

job "waypoint-bootstrap" {
  region      = "global"
  datacenters = ["pi-dc"]
  type        = "batch"
  node_pool   = "core"

  # --- Job metadata ---
  meta {
    version     = "0.11.4"
    owner       = "alex.freidah"
    category    = "development"
    description = "One-time bootstrap job: generate waypoint token and store in Vault"
  }

  # --- Placement constraints ---
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }

  # ---------------------------------------------------------------------------
  #  Bootstrap Group
  # ---------------------------------------------------------------------------

  group "bootstrap" {
    count = 1

    # --- Network configuration ---
    network {
      mode = "host"
    }

    # -----------------------------------------------------------------------
    #  Waypoint Bootstrap Task
    # -----------------------------------------------------------------------

    task "bootstrap" {
      driver = "docker"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image        = "docker-mirror.service.consul:5000/ops-waypoint-image:latest"
        network_mode = "host"
        entrypoint   = ["/bin/bash", "-lc"]
        args         = ["/local/bootstrap.sh"]
      }

      template {
        destination = "local/bootstrap.sh"
        perms       = "0755"
        change_mode = "noop"
        data        = <<-BOOTSTRAP_EOF
#!/usr/bin/env bash
set -euo pipefail

echo "=== Waypoint Bootstrap Job ==="
echo "Time: $$(date)"

# --- Wait for waypoint-server gRPC to be reachable ---
echo "Waiting for waypoint-server gRPC on 127.0.0.1:9701..."
for i in $$(seq 1 300); do
  if nc -z 127.0.0.1 9701 2>/dev/null; then
    echo "✓ gRPC is reachable"
    break
  fi
  if [ $$((i % 30)) -eq 0 ]; then echo "  Still waiting... ($$i/300s)"; fi
  sleep 1
done

if ! nc -z 127.0.0.1 9701 2>/dev/null; then
  echo "✗ Timeout: waypoint-server gRPC never became reachable"
  exit 1
fi

# --- Run bootstrap ---
echo "Running waypoint server bootstrap..."
set +e
BOOTSTRAP_OUT="$$(waypoint server bootstrap -server-addr=127.0.0.1:9701 -server-tls-skip-verify 2>&1)"
BOOTSTRAP_RC=$$?
set -e

echo "$$BOOTSTRAP_OUT"
if [ "$$BOOTSTRAP_RC" -ne 0 ]; then
  echo "✗ Bootstrap failed with rc=$$BOOTSTRAP_RC"
  exit 1
fi

# --- Extract token (last line) ---
TOKEN="$$(printf "%s\n" "$$BOOTSTRAP_OUT" | awk 'NF{last=$$0} END{print last}' | tr -d '\r\n')"
if [ -z "$$TOKEN" ]; then
  echo "✗ Failed to parse token from bootstrap output"
  exit 1
fi

echo "✓ Token extracted: $${TOKEN:0:20}..."

# --- Verify Vault connectivity ---
if [ -z "$${VAULT_ADDR}" ] || [ -z "$${VAULT_TOKEN}" ]; then
  echo "✗ VAULT_ADDR or VAULT_TOKEN not present"
  exit 1
fi

echo "Vault address: $${VAULT_ADDR}"

# --- Write token to Vault KV v2 ---
echo "Writing token to Vault..."
PAYLOAD=$$(printf '{"data":{"token":"%s"}}' "$$TOKEN")

if curl -sSf \
  -H "X-Vault-Token: $${VAULT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$$PAYLOAD" \
  "$${VAULT_ADDR}/v1/secret/data/system-services/waypoint_server_token" >/dev/null; then
  echo "✓ Token stored in Vault"
else
  echo "✗ Failed to write token to Vault"
  exit 1
fi

# --- Verify the token was stored ---
echo "Verifying token in Vault..."
if curl -sSf \
  -H "X-Vault-Token: $${VAULT_TOKEN}" \
  "$${VAULT_ADDR}/v1/secret/data/system-services/waypoint_server_token" | grep -q "waypoint_server_token"; then
  echo "✓ Token verified in Vault"
else
  echo "✗ Failed to verify token in Vault"
  exit 1
fi

echo ""
echo "=== Bootstrap Complete ==="
echo "Token is now available for waypoint-runner to use"
BOOTSTRAP_EOF
      }

      env {
        VAULT_ADDR        = "https://192.168.68.63:8200"
        VAULT_SKIP_VERIFY = "true"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      restart {
        attempts = 0
        mode     = "fail"
      }
    }
  }
}
