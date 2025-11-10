FROM myoung34/github-runner:debian-trixie

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

USER root

RUN set -eux; \
  apt-get update; \
  apt-get -y install --no-install-recommends curl netcat-openbsd unzip; \
  rm -rf /var/lib/apt/lists/*; \
  \
  WAYPOINT_VERSION="0.11.4"; \
  curl -fsSL "https://releases.hashicorp.com/waypoint/${WAYPOINT_VERSION}/waypoint_${WAYPOINT_VERSION}_linux_amd64.zip" -o /tmp/waypoint.zip; \
  unzip -d /usr/local/bin /tmp/waypoint.zip; \
  rm /tmp/waypoint.zip; \
  waypoint version

USER runner

HEALTHCHECK --interval=5m --timeout=30s --start-period=1m --retries=3 \
  CMD waypoint version >/dev/null 2>&1 && nc -h >/dev/null 2>&1 || exit 1
