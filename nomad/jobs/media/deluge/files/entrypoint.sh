#!/bin/sh
set -euo pipefail

# Provide defaults
if [ -z "${PUID:-}" ]; then PUID=1001; fi
if [ -z "${PGID:-}" ]; then PGID=1001; fi

# Force-write daemon auth from Vault template
if [ -f /secrets/auth ]; then
  install -m 600 -o "$PUID" -g "$PGID" /secrets/auth /config/auth
else
  echo "ERROR: /secrets/auth not rendered; check Vault secret" >&2
  exit 1
fi

# One-time Web UI reset
if [ ! -f /config/.web_state_initialized ]; then
  rm -f /config/web.conf \
        /config/hostlist.conf \
        /config/hostlist.conf.1.2 \
        /config/deluge/web.conf \
        /config/deluge/hostlist.conf \
        /config/deluge/hostlist.conf.1.2 || true
  : > /config/.web_state_initialized
  chown "$PUID:$PGID" /config/.web_state_initialized
fi

# Set web UI password if DELUGE_WEB_PASSWORD is provided
if [ -n "${DELUGE_WEB_PASSWORD:-}" ]; then
  SALT=$(head -c 32 /dev/urandom | sha1sum | cut -d' ' -f1)
  PWD_HASH=$(echo -n "${SALT}${DELUGE_WEB_PASSWORD}" | sha1sum | cut -d' ' -f1)
  
  if [ -f /config/web.conf ]; then
    sed -i "s/\"pwd_salt\": \"[^\"]*\"/\"pwd_salt\": \"$SALT\"/" /config/web.conf
    sed -i "s/\"pwd_sha1\": \"[^\"]*\"/\"pwd_sha1\": \"$PWD_HASH\"/" /config/web.conf
  fi
  chown "$PUID:$PGID" /config/web.conf 2>/dev/null || true
fi

# Hand over to original init
exec /init
