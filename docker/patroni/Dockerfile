# -------------------------------------------------------------------------------
# Patroni + PostgreSQL 18 — High Availability PostgreSQL
#
# Project: Munchbox / Author: Alex Freidah
#
# Minimal Patroni image with PostgreSQL 18 and Consul DCS support.
# Based on official postgres:18 image with Patroni installed via pip.
# -------------------------------------------------------------------------------

FROM postgres:18-bookworm

LABEL maintainer="Alex Freidah"
LABEL description="Patroni HA PostgreSQL 18 with Consul support"

# --- Environment ---
ENV PATRONI_VERSION=4.0.4
ENV DEBIAN_FRONTEND=noninteractive

# --- Install dependencies ---
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        libpq-dev \
        curl \
        jq \
        netcat-openbsd \
        procps \
        iputils-ping \
        dnsutils \
    ; \
    rm -rf /var/lib/apt/lists/*

# --- Create virtual environment for Patroni ---
ENV VIRTUAL_ENV=/opt/patroni
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# --- Install Patroni with Consul support ---
RUN set -eux; \
    pip install --no-cache-dir \
        "patroni[consul]==${PATRONI_VERSION}" \
        psycopg[binary] \
        python-consul2 \
    ; \
    # Verify installation
    patroni --version

# --- Create patroni user (use postgres user/group) ---
RUN set -eux; \
    mkdir -p /etc/patroni /home/postgres/data; \
    chown -R postgres:postgres /etc/patroni /home/postgres

# --- Patroni configuration directory ---
VOLUME ["/home/postgres/data"]

# --- Expose ports ---
# 5432: PostgreSQL
# 8008: Patroni REST API
EXPOSE 5432 8008

# --- Health check ---
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:8008/health || exit 1

# --- Run as postgres user ---
USER postgres
WORKDIR /home/postgres

# --- Default entrypoint ---
ENTRYPOINT ["patroni"]
CMD ["/etc/patroni/patroni.yml"]
