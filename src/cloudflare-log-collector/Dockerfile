# -------------------------------------------------------------------------------
# Cloudflare Log Collector - Container Image
#
# Author: Alex Freidah
#
# Multi-stage Alpine build. Polls Cloudflare GraphQL API for firewall events
# and HTTP traffic, ships to Loki and Prometheus.
# -------------------------------------------------------------------------------

FROM --platform=$BUILDPLATFORM golang:1.26.1-alpine AS builder

ARG VERSION=dev
ARG TARGETOS
ARG TARGETARCH

WORKDIR /build

# --- Install build dependencies ---
RUN apk add --no-cache git ca-certificates

# --- Copy go module files and download dependencies ---
COPY go.mod go.sum ./
RUN go mod download

# --- Copy source code ---
COPY cmd/ cmd/
COPY internal/ internal/

# --- Build binary (native cross-compilation, no QEMU needed) ---
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
    -ldflags="-s -w -X github.com/afreidah/cloudflare-log-collector/internal/telemetry.Version=${VERSION}" \
    -o cloudflare-log-collector ./cmd/cloudflare-log-collector

# -------------------------------------------------------------------------
# Runtime Image
# -------------------------------------------------------------------------

FROM alpine:3.21

ARG VERSION=dev

LABEL org.opencontainers.image.title="cloudflare-log-collector" \
      org.opencontainers.image.description="Cloudflare analytics collector for Loki and Prometheus" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://github.com/afreidah/cloudflare-log-collector"

RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates && \
    adduser -D -u 10001 appuser

COPY --from=builder /build/cloudflare-log-collector /usr/local/bin/

USER appuser

EXPOSE 9101

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:9101/health || exit 1

ENTRYPOINT ["cloudflare-log-collector"]
CMD ["-config", "/etc/cloudflare-log-collector/config.yaml"]
