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
        ca-certificates \
        curl \
        jq \
        netcat-openbsd \
        procps \
        iputils-ping \
        dnsutils \
        postgresql-18-pgvector \
    ; \
    rm -rf /var/lib/apt/lists/*

# --- wal-g, for physical base backups and WAL archiving to s3-orchestrator.
#     The 20.04 build links an older glibc than trixie ships, which is the
#     direction that stays portable; a newer-glibc build would not run here. ---
ARG WALG_VERSION=v3.0.9
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) walg_arch=amd64 ;; \
      arm64) walg_arch=aarch64 ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    name="wal-g-pg-20.04-${walg_arch}"; \
    url="https://github.com/wal-g/wal-g/releases/download/${WALG_VERSION}"; \
    curl -fsSL "${url}/${name}.tar.gz" -o /tmp/walg.tgz; \
    curl -fsSL "${url}/${name}.tar.gz.sha256" -o /tmp/walg.sha256; \
    printf '%s  %s\n' "$(cut -d' ' -f1 /tmp/walg.sha256)" /tmp/walg.tgz >/tmp/walg.check; \
    sha256sum -c /tmp/walg.check; \
    tar -xzf /tmp/walg.tgz -C /tmp; \
    install -m0755 "/tmp/${name}" /usr/local/bin/wal-g; \
    rm -f /tmp/walg.tgz /tmp/walg.sha256 /tmp/walg.check "/tmp/${name}"; \
    wal-g --version

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
