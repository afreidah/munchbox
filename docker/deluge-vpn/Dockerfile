# filepath: docker/deluge-vpn/Dockerfile
# ------------------------------------------------------------------------------
#  Deluge (linuxserver) — minimal, pinned, with healthcheck
#  Notes:
#    - linuxserver images use s6-overlay and drop privileges to user "abc"
#      at runtime based on PUID/PGID envs. Overriding USER here can break init.
# ------------------------------------------------------------------------------
# filepath: docker/deluge-vpn/Dockerfile

FROM linuxserver/deluge:2.2.0

# Bring Alpine base packages to fixed versions (e.g., busybox r24) to address CVEs
RUN set -eux; \
  if command -v apk >/dev/null 2>&1; then \
    apk update; \
    apk add --no-cache --upgrade busybox busybox-binsh ssl_client || apk upgrade --no-cache busybox busybox-binsh ssl_client; \
    rm -rf /var/cache/apk/*; \
  fi

# Run as non-root (linuxserver images map PUID/PGID to 'abc')
ENV PUID=1001 PGID=1001
USER abc

# Liveness check
HEALTHCHECK --interval=5m --timeout=10s --start-period=30s --retries=3 \
  CMD pgrep -x deluged >/dev/null || exit 1

