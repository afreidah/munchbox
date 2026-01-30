# -------------------------------------------------------------------------------
# Oracle Watchdog - Container Build
#
# Project: Munchbox / Author: Alex Freidah
#
# Multi-stage build produces a minimal scratch container. Runs as non-root user
# for security. Supports both monitor and agent modes via command-line flags.
# -------------------------------------------------------------------------------

FROM golang:1.25-alpine AS builder

WORKDIR /build

# --- Dependencies first for layer caching ---
COPY go.mod go.sum ./
RUN go mod download

# --- Build static binary ---
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o oracle-watchdog ./cmd/watchdog

# -------------------------------------------------------------------------
# RUNTIME IMAGE
# -------------------------------------------------------------------------

FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /build/oracle-watchdog /oracle-watchdog

USER 65534:65534

ENTRYPOINT ["/oracle-watchdog"]
