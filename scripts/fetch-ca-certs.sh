#!/bin/bash
# -------------------------------------------------------------------------------
# Fetch Munchbox CA Certificates
#
# Project: Munchbox / Author: Alex Freidah
#
# Downloads CA certificates from the cluster for local CLI access. Run this
# after TLS is enabled on the cluster to configure local tooling.
# -------------------------------------------------------------------------------

set -e

MUNCHBOX_HOME="${MUNCHBOX_HOME:-$HOME/.munchbox}"
TLS_DIR="$MUNCHBOX_HOME/tls"

echo "Fetching Munchbox CA certificates..."
echo ""

# --- Create directory ---
mkdir -p "$TLS_DIR"

# --- Fetch Consul CA ---
echo "==> Fetching Consul CA certificate..."
scp root@stabler:/etc/consul.d/tls/ca.crt "$TLS_DIR/consul-ca.crt"
echo "    Saved to $TLS_DIR/consul-ca.crt"

# --- Fetch Nomad CA ---
echo "==> Fetching Nomad CA certificate..."
scp root@stabler:/etc/nomad.d/tls/ca.crt "$TLS_DIR/nomad-ca.crt"
echo "    Saved to $TLS_DIR/nomad-ca.crt"

# --- Verify certificates ---
echo ""
echo "==> Verifying certificates..."
for cert in consul-ca.crt nomad-ca.crt; do
  if openssl x509 -in "$TLS_DIR/$cert" -noout -subject 2>/dev/null; then
    echo "    $cert: OK"
  else
    echo "    $cert: INVALID"
  fi
done

echo ""
echo "CA certificates installed to $TLS_DIR"
echo ""
echo "Update ~/.bashrc and source it:"
echo "  cp ~/.bashrc ~/.bashrc.bak"
echo "  cp /path/to/bashrc-tls ~/.bashrc"
echo "  source ~/.bashrc"
echo ""
echo "Test connectivity:"
echo "  consul members"
echo "  nomad server members"
echo "  vault status"
