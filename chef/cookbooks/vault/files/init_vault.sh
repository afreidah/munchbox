#!/bin/bash
# setup-vault-arm6.sh
# Installs and configures HashiCorp Vault as a systemd service (file backend, no TLS, UI enabled)
# Make sure your vault binary is available at ./vault or update VAULT_BIN below

set -euo pipefail

# ---- Configurable section ----
VAULT_USER=vault
VAULT_GROUP=vault
VAULT_HOME=/opt/vault
VAULT_DATA=$VAULT_HOME/data
VAULT_CONFIG_DIR=/etc/vault.d
VAULT_CONFIG_FILE=$VAULT_CONFIG_DIR/vault.hcl
VAULT_BIN=./vault         # Path to your built Vault binary for ARMv6
VAULT_BIN_DEST=/usr/local/bin/vault
SYSTEMD_UNIT=/etc/systemd/system/vault.service

# ---- 1. Create Vault user/group and directories ----
if ! id -u "$VAULT_USER" >/dev/null 2>&1; then
  useradd --system --home "$VAULT_HOME" --shell /bin/false "$VAULT_USER"
fi

mkdir -p "$VAULT_HOME" "$VAULT_DATA" "$VAULT_CONFIG_DIR"
chown -R "$VAULT_USER":"$VAULT_GROUP" "$VAULT_HOME" "$VAULT_CONFIG_DIR"

# ---- 2. Install the Vault binary ----
if [ ! -f "$VAULT_BIN" ]; then
  echo "Vault binary not found at $VAULT_BIN. Please provide your arm6 build."
  exit 1
fi
install -m 755 "$VAULT_BIN" "$VAULT_BIN_DEST"

# ---- 3. Write Vault config file ----
cat > "$VAULT_CONFIG_FILE" <<EOF
storage "file" {
  path = "$VAULT_DATA"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

disable_mlock = true
ui = true
EOF

chown "$VAULT_USER":"$VAULT_GROUP" "$VAULT_CONFIG_FILE"
chmod 640 "$VAULT_CONFIG_FILE"

# ---- 4. Create systemd service unit ----
cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=HashiCorp Vault - ARMv6
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target

[Service]
User=$VAULT_USER
Group=$VAULT_GROUP
ExecStart=$VAULT_BIN_DEST server -config=$VAULT_CONFIG_FILE
ExecReload=/bin/kill --signal HUP \$MAINPID
Restart=on-failure
LimitNOFILE=65536
ProtectSystem=full
ProtectHome=read-only
CapabilityBoundingSet=CAP_IPC_LOCK
AmbientCapabilities=CAP_IPC_LOCK
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

# ---- 5. Reload systemd and enable/start Vault ----
systemctl daemon-reload
systemctl enable vault
systemctl restart vault

echo "Vault setup complete."
echo "Check status: sudo systemctl status vault"
echo "Vault should now be listening on http://0.0.0.0:8200"
echo "To initialize: export VAULT_ADDR='http://127.0.0.1:8200' && vault operator init"


