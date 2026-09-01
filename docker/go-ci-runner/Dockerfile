# -------------------------------------------------------------------------------
# go-ci-runner -- self-hosted GitHub Actions runner for Go repositories
#
# Project: Munchbox / Author: Alex Freidah
#
# A reusable runner for the CI a Go repo runs on every PR: build, vet, race
# tests, golangci-lint, sqlc codegen, a Node-built web asset step, and GoReleaser
# .deb packaging + lintian. Ships that toolchain on top of the base GitHub runner
# and NOTHING heavier -- deliberately no Cinc/Chef, Packer, or KVM (those live on
# moat-runner-standard / moat-runner-vm), and no Docker socket or privileged mode,
# because none of these jobs build images or run VMs. That keeps it small, cheap
# to schedule, and unprivileged.
#
# Used by any repo whose Go CI jobs `runs-on` a label this image advertises (e.g.
# moat's ci.yml after it moves off the heavy `moat` pool). Dispatched on demand
# by the Temporal ci-runner-scaler; the per-repo Nomad job supplies the runner's
# registration credential.
#
# Tool versions are ARG-pinned where a repo cares about reproducibility; Go tracks
# the go.mod line (bump GO_VERSION on a toolchain bump). goreleaser + sqlc default
# to the latest release at build time -- pass the ARG to pin them.
# -------------------------------------------------------------------------------

FROM myoung34/github-runner:2.337.0-ubuntu-jammy

# TARGETARCH is auto-populated by BuildKit/buildx per target platform (amd64|arm64).
# Do NOT give it a default -- a default overrides the per-platform value and every
# arch ends up with amd64 binaries.
ARG TARGETARCH
ARG GO_VERSION=1.27.0
ARG GOLANGCI_LINT_VERSION=2.13.2
ARG NODE_MAJOR=24
# goreleaser: empty => latest at build time; pass a tag to lock. sqlc: pinned
# because `sqlc generate` stamps its version into committed code, so it must
# match what consuming repos generated with (moat: v1.30.0).
ARG GORELEASER_VERSION=
ARG SQLC_VERSION=1.31.1

USER root

# pipefail so a failed `curl` in a `curl … | bash` installer below aborts the
# build instead of being masked by the piped shell's exit status (hadolint DL4006).
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    # --- base build tooling: git/make for the repo's Makefile, build-essential
    #     for `go test -race` (needs a C compiler), lintian + dpkg-dev for the
    #     .deb lint job. Cross-arch cgo (arm64 .deb with CGO) would also need
    #     gcc-aarch64-linux-gnu; omitted on the assumption of CGO_ENABLED=0 builds. ---
    apt-get install -y --no-install-recommends \
    ca-certificates curl git make gnupg xz-utils \
    build-essential \
    lintian dpkg-dev fakeroot; \
    # --- Node.js (web asset build in `make build`) via NodeSource ---
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    # --- Go toolchain (matches the repo's go.mod line) ---
    curl -fsSLo /tmp/go.tgz "https://go.dev/dl/go${GO_VERSION}.linux-${TARGETARCH}.tar.gz"; \
    tar -C /usr/local -xzf /tmp/go.tgz; \
    # --- golangci-lint (pinned) ---
    curl -fsSL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
    | sh -s -- -b /usr/local/bin "v${GOLANGCI_LINT_VERSION}"; \
    # --- goreleaser (latest unless GORELEASER_VERSION is passed) ---
    gr_ver="${GORELEASER_VERSION:-$(curl -fsSL https://api.github.com/repos/goreleaser/goreleaser/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')}"; \
    case "${TARGETARCH}" in amd64) gr_arch=x86_64 ;; arm64) gr_arch=arm64 ;; *) gr_arch="${TARGETARCH}" ;; esac; \
    curl -fsSLo /tmp/goreleaser.tgz "https://github.com/goreleaser/goreleaser/releases/download/${gr_ver}/goreleaser_Linux_${gr_arch}.tar.gz"; \
    tar -C /usr/local/bin -xzf /tmp/goreleaser.tgz goreleaser; \
    # --- sqlc (latest unless SQLC_VERSION is passed) ---
    sqlc_ver="${SQLC_VERSION:-$(curl -fsSL https://api.github.com/repos/sqlc-dev/sqlc/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+' | sed 's/^v//')}"; \
    curl -fsSLo /tmp/sqlc.tgz "https://downloads.sqlc.dev/sqlc_${sqlc_ver}_linux_${TARGETARCH}.tar.gz"; \
    tar -C /usr/local/bin -xzf /tmp/sqlc.tgz sqlc; \
    # --- Cleanup ---
    rm -f /tmp/*.tgz; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# GOPATH/GOCACHE live in a world-writable dir: jobs run as the non-root `runner`
# user, which can't write a cache under /root.
ENV GOPATH="/opt/go"
ENV GOCACHE="/opt/go/.cache"
ENV PATH="/usr/local/go/bin:/opt/go/bin:${PATH}"
RUN mkdir -p /opt/go/bin /opt/go/.cache && chmod -R 0777 /opt/go

# --- Fail the build if any tool is missing or broken ---
RUN set -eux; \
    go version; \
    node --version; \
    npm --version; \
    golangci-lint version; \
    goreleaser --version; \
    sqlc version; \
    lintian --version
