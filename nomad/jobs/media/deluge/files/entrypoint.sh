#!/bin/sh
set -euo pipefail

# Provide defaults without brace-style parameter expansion to avoid parser traps
if [ -z "$${PUID:-}" ]; then PUID=1001; fi
if [ -z "$${PGID:-}" ]; then PGID=1001; fi

# Ensure /config exists (should via volume), then force-write daemon auth.
if [ -f /local/auth ]; then
  install -m 600 -o "$PUID" -g "$PGID" /local/auth /config/auth
else
  echo "ERROR: /local/auth not rendered; check Vault secret kv/data/deluge" >&2
  exit 1
fi

# One-time Web UI reset (stale hostlist/web.conf causes auth mismatch)
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
if [ -n "$${DELUGE_WEB_PASSWORD:-}" ]; then
  # Generate salt and hash for Deluge web UI
  SALT=`head -c 32 /dev/urandom | sha1sum | cut -d' ' -f1`
  PWD_HASH=`echo -n "$${SALT}$${DELUGE_WEB_PASSWORD}" | sha1sum | cut -d' ' -f1`
  
  # Update or create web.conf with the new password
  if [ -f /config/web.conf ]; then
    # Use sed to update existing web.conf
    sed -i "s/\"pwd_salt\": \"[^\"]*\"/\"pwd_salt\": \"$SALT\"/" /config/web.conf
    sed -i "s/\"pwd_sha1\": \"[^\"]*\"/\"pwd_sha1\": \"$PWD_HASH\"/" /config/web.conf
  fi
  chown "$PUID:$PGID" /config/web.conf 2>/dev/null || true
fi

# Hand over to original init (linuxserver.io images use s6-overlay).
exec /init
