# -------------------------------------------------------------------------------
# Ops Build Image — CI/CD Toolchain
#
# Project: Munchbox / Author: Alex Freidah
#
# Multi-arch build image with infrastructure tools for CI pipelines.
# Uses multi-stage build to minimize final image size.
# -------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Stage 1: builder - fetch/compile CLI binaries
# ------------------------------------------------------------------------------
FROM debian:trixie-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETOS=linux
ARG TARGETARCH
ENV ARCH_DL=${TARGETARCH}

RUN set -eux; \
  apt-get update; \
  apt-get -y install --no-install-recommends ca-certificates curl jq tar gzip unzip; \
  rm -rf /var/lib/apt/lists/*

RUN mkdir -p /tmp/bin

# --- Go (for building tools) ---
RUN set -eux; \
  GO_VERSION="1.27.0"; \
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH_DL}.tar.gz" -o /tmp/go.tgz; \
  tar -C /usr/local -xzf /tmp/go.tgz; rm -f /tmp/go.tgz
ENV PATH=/usr/local/go/bin:$PATH GOPATH=/go

# --- Download all binaries in parallel (much faster).
#
#     Every download is waited on BY PID and its status checked. A bare `wait`
#     returns 0 no matter how the children exited, so `set -e` never sees a
#     failed curl -- a dead URL then surfaces ~100s later as "command not found"
#     in the sanity check below, pointing at the wrong thing entirely. That is
#     exactly how the deleted trivy 0.58.0 release presented.
#
#     HashiCorp CLIs track the running cluster, not just latest. ---
RUN set -eux; \
  TF_VERSION="1.16.0"; \
  TG_VERSION="1.1.4"; \
  NOMAD_VERSION="2.0.5"; \
  PACK_VERSION="0.4.2"; \
  CONSUL_VERSION="2.0.3"; \
  VAULT_VERSION="2.0.4"; \
  TFLINT_VERSION="0.64.0"; \
  TRIVY_VERSION="0.74.0"; \
  COSIGN_VERSION="3.1.3"; \
  if [ "$ARCH_DL" = "arm64" ]; then TRIVY_ARCH="ARM64"; else TRIVY_ARCH="64bit"; fi; \
  \
  pids=""; \
  dl() { curl -fsSL "$1" -o "$2" & pids="$pids $!:$1"; }; \
  dl "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH_DL}.zip" /tmp/tf.zip; \
  dl "https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VERSION}/terragrunt_linux_${ARCH_DL}" /tmp/bin/terragrunt; \
  dl "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${ARCH_DL}.zip" /tmp/nomad.zip; \
  dl "https://releases.hashicorp.com/nomad-pack/${PACK_VERSION}/nomad-pack_${PACK_VERSION}_linux_${ARCH_DL}.zip" /tmp/pack.zip; \
  dl "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${ARCH_DL}.zip" /tmp/consul.zip; \
  dl "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH_DL}.zip" /tmp/vault.zip; \
  dl "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${ARCH_DL}.zip" /tmp/tflint.zip; \
  dl "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" /tmp/trivy.tgz; \
  dl "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH_DL}" /tmp/bin/cosign; \
  rc=0; \
  for p in $pids; do \
    if ! wait "${p%%:*}"; then echo "download failed: ${p#*:}" >&2; rc=1; fi; \
  done; \
  [ "$rc" -eq 0 ] || { echo "one or more downloads failed" >&2; exit 1; }; \
  \
  chmod +x /tmp/bin/terragrunt /tmp/bin/cosign; \
  unzip -o -d /tmp /tmp/tf.zip && install -m0755 /tmp/terraform /tmp/bin/terraform; \
  unzip -o -d /tmp /tmp/nomad.zip && install -m0755 /tmp/nomad /tmp/bin/nomad; \
  unzip -o -d /tmp /tmp/pack.zip && install -m0755 /tmp/nomad-pack /tmp/bin/nomad-pack; \
  unzip -o -d /tmp /tmp/consul.zip && install -m0755 /tmp/consul /tmp/bin/consul; \
  unzip -o -d /tmp /tmp/vault.zip && install -m0755 /tmp/vault /tmp/bin/vault; \
  unzip -o -d /tmp /tmp/tflint.zip && install -m0755 /tmp/tflint /tmp/bin/tflint; \
  tar -xzf /tmp/trivy.tgz -C /tmp trivy && install -m0755 /tmp/trivy /tmp/bin/trivy; \
  rm -f /tmp/*.zip /tmp/*.tgz /tmp/terraform /tmp/nomad /tmp/nomad-pack /tmp/consul /tmp/vault /tmp/tflint /tmp/trivy

# --- Go linting/testing tools ---
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
  GOOS=linux GOARCH=${TARGETARCH} CGO_ENABLED=0 \
  go install honnef.co/go/tools/cmd/staticcheck@latest && \
  go install github.com/rakyll/gotest@latest && \
  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
  install -m0755 /go/bin/staticcheck /tmp/bin/staticcheck && \
  install -m0755 /go/bin/gotest /tmp/bin/gotest && \
  install -m0755 /go/bin/golangci-lint /tmp/bin/golangci-lint

# ------------------------------------------------------------------------------
# Stage 2: final - slim runtime image
# ------------------------------------------------------------------------------
FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETARCH
ENV ARCH_DL=${TARGETARCH}

# --- Base packages + Python for Ansible + Node.js for GitHub Actions ---
RUN set -eux; \
  apt-get update; \
  apt-get -y install --no-install-recommends \
    ca-certificates curl git jq make openssh-client \
    python3 python3-pip pipx nodejs npm; \
  rm -rf /var/lib/apt/lists/*

# --- Docker CLI (official static binary) ---
ARG DOCKER_VERSION="29.7.2"
RUN set -eux; \
  curl -fsSL "https://download.docker.com/linux/static/stable/$(uname -m)/docker-${DOCKER_VERSION}.tgz" -o /tmp/docker.tgz; \
  tar -xzf /tmp/docker.tgz -C /tmp; \
  install -m0755 /tmp/docker/docker /usr/local/bin/docker; \
  rm -rf /tmp/docker /tmp/docker.tgz

# --- Copy all binaries from builder ---
COPY --from=builder /tmp/bin/ /usr/local/bin/

# --- Go runtime (needed for go test in CI) ---
COPY --from=builder /usr/local/go /usr/local/go
ENV PATH=/usr/local/go/bin:/usr/local/bin:$PATH GOPATH=/go

# --- Ansible + ansible-lint ---
ENV PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/pipx \
    set -eux; \
  mkdir -p "$PIPX_HOME"; \
  pipx install --include-deps ansible; \
  pipx install ansible-lint

# --- Sanity check ---
RUN set -eux; \
  echo "=== Tool Versions ===" && \
  terraform --version && \
  nomad --version && \
  nomad-pack version && \
  consul --version && \
  vault --version && \
  tflint --version && \
  terragrunt --version && \
  trivy --version && \
  cosign version && \
  docker --version && \
  golangci-lint version --format short && \
  go version && \
  node --version && \
  ansible --version | head -n1 && \
  ansible-lint --version && \
  echo "==================="

# --- Non-root user ---
ARG APP_USER=ci-runner
ARG UID=10001
ARG GID=10001
RUN set -eux; \
  addgroup --gid "$GID" "$APP_USER"; \
  adduser --disabled-password --gecos "" --uid "$UID" --gid "$GID" "$APP_USER"; \
  mkdir -p /workspace "$GOPATH"; \
  chown -R "$APP_USER:$APP_USER" /workspace "$GOPATH"

WORKDIR /workspace
USER $APP_USER
