# -------------------------------------------------------------------------------
# Temporal Backup Worker/Trigger - Container Image
#
# Project: Munchbox / Author: Alex Freidah
#
# Multi-stage build for Temporal backup worker and trigger binaries with
# HashiCorp CLI tools (nomad, consul, vault) for snapshot operations. Produces
# a single image that runs as either a long-running worker service or a
# one-shot trigger batch job based on the entrypoint argument.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------
# STAGE 1: Build Go Binaries
# -------------------------------------------------------------------------

FROM golang:1.25-alpine AS builder

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Copy go module files and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY *.go ./

# Build worker binary
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -tags worker \
    -o temporal-backup-worker \
    .

# Build trigger binary
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -tags trigger \
    -o temporal-backup-trigger \
    .

# -------------------------------------------------------------------------
# STAGE 2: Runtime Image with CLI Tools
# -------------------------------------------------------------------------

FROM alpine:3.21

# Install runtime dependencies (gcompat for HashiCorp binaries)
RUN apk add --no-cache \
    ca-certificates \
    curl \
    bash \
    unzip \
    gcompat \
    postgresql16-client \
    tar \
    gzip

# Install Nomad CLI
ARG NOMAD_VERSION=1.11.1
ARG TARGETARCH
RUN curl -fsSL https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${TARGETARCH}.zip -o nomad.zip \
    && unzip -o nomad.zip \
    && mv nomad /usr/local/bin/ \
    && rm -f nomad.zip LICENSE.txt \
    && chmod +x /usr/local/bin/nomad

# Install Consul CLI
ARG CONSUL_VERSION=1.22.1
RUN curl -fsSL https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${TARGETARCH}.zip -o consul.zip \
    && unzip -o consul.zip \
    && mv consul /usr/local/bin/ \
    && rm -f consul.zip LICENSE.txt \
    && chmod +x /usr/local/bin/consul

# Install Vault CLI
ARG VAULT_VERSION=1.21.1
RUN curl -fsSL https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip -o vault.zip \
    && unzip -o vault.zip \
    && mv vault /usr/local/bin/ \
    && rm -f vault.zip LICENSE.txt \
    && chmod +x /usr/local/bin/vault

# Install Trivy vulnerability scanner
ARG TRIVY_VERSION=0.67.0
RUN curl -fsSL https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-$(uname -m | sed 's/aarch64/ARM64/' | sed 's/x86_64/64bit/').tar.gz -o trivy.tar.gz \
    && tar -xzf trivy.tar.gz \
    && mv trivy /usr/local/bin/ \
    && rm -rf trivy.tar.gz LICENSE README.md contrib \
    && chmod +x /usr/local/bin/trivy

# Copy binaries from builder
COPY --from=builder /build/temporal-backup-worker /usr/local/bin/
COPY --from=builder /build/temporal-backup-trigger /usr/local/bin/

# Create backup and report directories (will be mounted as volumes)
RUN mkdir -p /mnt/gdrive/nomad-snapshots \
    && mkdir -p /mnt/gdrive/consul-snapshots \
    && mkdir -p /mnt/gdrive/postgres-backups \
    && mkdir -p /mnt/gdrive/registry-backups \
    && mkdir -p /mnt/gdrive/trivy-reports

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["worker"]
