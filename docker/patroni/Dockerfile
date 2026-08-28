# -------------------------------------------------------------------------------
# Patroni + PostgreSQL 18 — High Availability PostgreSQL
#
# Project: Munchbox / Author: Alex Freidah
#
# Minimal Patroni image with PostgreSQL 18 and Consul DCS support.
# Multi-stage: the Patroni venv is compiled in a builder stage so the -dev and
# compiler packages never ship in the runtime image. Base is postgres:18-trixie
# (Debian 13, current stable). Images are signed with cosign using Vault Transit.
# -------------------------------------------------------------------------------

# --- Builder stage: compile the Patroni virtualenv ---
FROM postgres:18-trixie AS builder

ENV PATRONI_VERSION=4.0.4
ENV DEBIAN_FRONTEND=noninteractive

# --- Build-only dependencies (do not ship in the runtime image) ---
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        libpq-dev \
    ; \
    rm -rf /var/lib/apt/lists/*

# --- Build the virtualenv with Patroni + Consul support ---
ENV VIRTUAL_ENV=/opt/patroni
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN set -eux; \
    pip install --no-cache-dir \
        "patroni[consul]==${PATRONI_VERSION}" \
        psycopg[binary] \
        python-consul2 \
    ; \
    patroni --version

# -------------------------------------------------------------------------------
# Runtime stage
# -------------------------------------------------------------------------------
FROM postgres:18-trixie

LABEL maintainer="Alex Freidah"
LABEL description="Patroni HA PostgreSQL 18 with Consul support"

ENV DEBIAN_FRONTEND=noninteractive

# --- Patch base-preinstalled packages, then install runtime-only deps ---
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        python3 \
        curl \
        jq \
        netcat-openbsd \
        procps \
        iputils-ping \
        dnsutils \
        postgresql-18-pgvector \
    ; \
    rm -rf /var/lib/apt/lists/*

# --- Bring in the prebuilt Patroni virtualenv ---
ENV VIRTUAL_ENV=/opt/patroni
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
COPY --from=builder /opt/patroni /opt/patroni

# --- Create patroni directories (use postgres user/group) ---
RUN set -eux; \
    mkdir -p /etc/patroni /home/postgres/data; \
    chown -R postgres:postgres /etc/patroni /home/postgres

# --- Patroni data directory ---
VOLUME ["/home/postgres/data"]

# --- Expose ports ---
# 5432: PostgreSQL
# 8008: Patroni REST API
EXPOSE 5432 8008

# --- Health check ---
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD ["/bin/sh", "-c", "curl -sf http://localhost:8008/health || exit 1"]

# --- Run as postgres user ---
USER postgres
WORKDIR /home/postgres

# --- Default entrypoint ---
ENTRYPOINT ["patroni"]
CMD ["/etc/patroni/patroni.yml"]
