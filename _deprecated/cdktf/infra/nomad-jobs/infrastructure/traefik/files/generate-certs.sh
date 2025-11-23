#!/bin/sh

# -----------------------------------------------------------------------------
# Self-signed cert generator for *.munchbox (runs as prestart task)
# -----------------------------------------------------------------------------

set -e

# Use /alloc/data which is shared between all tasks in the group
CERT_DIR=/alloc/data

# Check if valid certificates exist by actually validating them
if [ -f $CERT_DIR/munchbox.crt ] && [ -f $CERT_DIR/munchbox.key ]; then
  if openssl x509 -in $CERT_DIR/munchbox.crt -noout 2>/dev/null; then
    echo "Valid certificates already exist, skipping generation"
    exit 0
  else
    echo "Invalid certificates found, regenerating..."
    rm -f $CERT_DIR/munchbox.crt $CERT_DIR/munchbox.key
  fi
fi

echo "Generating self-signed certificate for *.munchbox..."
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout $CERT_DIR/munchbox.key \
  -out $CERT_DIR/munchbox.crt \
  -days 3650 \
  -subj "/CN=*.munchbox" \
  -addext "subjectAltName=DNS:*.munchbox,DNS:munchbox"

echo "Certificate generated successfully"
ls -la $CERT_DIR/munchbox.*

# Verify the certificates are valid PEM format
echo "Verifying certificate..."
openssl x509 -in $CERT_DIR/munchbox.crt -text -noout | head -5
