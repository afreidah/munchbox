# -------------------------------------------------------------------------------
# Ops Build Image - CI/CD Toolchain
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
  GO_VERSION="1.23.4"; \
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH_DL}.tar.gz" -o /tmp/go.tgz; \
  tar -C /usr/local -xzf /tmp/go.tgz; rm -f /tmp/go.tgz
ENV PATH=/usr/local/go/bin:$PATH GOPATH=/go

# --- Terraform ---
RUN set -eux; \
  TF_VERSION="1.10.3"; \
  curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH_DL}.zip" -o /tmp/tf.zip; \
  unzip -o -d /tmp /tmp/tf.zip; \
  install -m0755 /tmp/terraform /tmp/bin/terraform; \
  rm -f /tmp/terraform /tmp/tf.zip

# --- OpenTofu ---
RUN set -eux; \
  TOFU_VERSION="1.9.0"; \
  curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${ARCH_DL}.tar.gz" -o /tmp/tofu.tgz; \
  tar -xzf /tmp/tofu.tgz -C /tmp tofu; \
  install -m0755 /tmp/tofu /tmp/bin/tofu; \
  rm -f /tmp/tofu /tmp/tofu.tgz

# --- TFLint ---
RUN set -eux; \
  TFLINT_VERSION="0.54.0"; \
  curl -sSfL "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${ARCH_DL}.zip" -o /tmp/tflint.zip; \
  unzip /tmp/tflint.zip -d /tmp; \
  install -m0755 /tmp/tflint /tmp/bin/tflint; \
  rm -f /tmp/tflint.zip /tmp/tflint

# --- Terragrunt ---
RUN set -eux; \
  TG_VERSION="0.69.1"; \
  curl -fsSL "https://github.com/gruntwork-io/terragrunt/releases/download/v${TG_VERSION}/terragrunt_linux_${ARCH_DL}" -o /tmp/bin/terragrunt; \
  chmod +x /tmp/bin/terragrunt

# --- Nomad ---
RUN set -eux; \
  NOMAD_VERSION="1.9.3"; \
  curl -fsSL "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${ARCH_DL}.zip" -o /tmp/nomad.zip; \
  unzip -o -d /tmp /tmp/nomad.zip; \
  install -m0755 /tmp/nomad /tmp/bin/nomad; \
  rm -f /tmp/nomad /tmp/nomad.zip

# --- Nomad Pack ---
RUN set -eux; \
  PACK_VERSION="0.1.2"; \
  curl -fsSL "https://releases.hashicorp.com/nomad-pack/${PACK_VERSION}/nomad-pack_${PACK_VERSION}_linux_${ARCH_DL}.zip" -o /tmp/pack.zip; \
  unzip -o -d /tmp /tmp/pack.zip; \
  install -m0755 /tmp/nomad-pack /tmp/bin/nomad-pack; \
  rm -f /tmp/nomad-pack /tmp/pack.zip

# --- Consul ---
RUN set -eux; \
  CONSUL_VERSION="1.20.1"; \
  curl -fsSL "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${ARCH_DL}.zip" -o /tmp/consul.zip; \
  unzip -o -d /tmp /tmp/consul.zip; \
  install -m0755 /tmp/consul /tmp/bin/consul; \
  rm -f /tmp/consul /tmp/consul.zip

# --- Vault ---
RUN set -eux; \
  VAULT_VERSION="1.18.3"; \
  curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH_DL}.zip" -o /tmp/vault.zip; \
  unzip -o -d /tmp /tmp/vault.zip; \
  install -m0755 /tmp/vault /tmp/bin/vault; \
  rm -f /tmp/vault /tmp/vault.zip

# --- hclfmt ---
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
  GOOS=linux GOARCH=${TARGETARCH} CGO_ENABLED=0 \
  go install github.com/hashicorp/hcl/v2/cmd/hclfmt@latest; \
  install -m0755 /go/bin/hclfmt /tmp/bin/hclfmt

# --- Go linting/testing tools (pre-compiled) ---
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eux; \
  GOOS=linux GOARCH=${TARGETARCH} CGO_ENABLED=0 \
  go install honnef.co/go/tools/cmd/staticcheck@latest && \
  go install github.com/rakyll/gotest@latest && \
  go install gotest.tools/gotestsum@latest && \
  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
  install -m0755 /go/bin/staticcheck /tmp/bin/staticcheck && \
  install -m0755 /go/bin/gotest /tmp/bin/gotest && \
  install -m0755 /go/bin/gotestsum /tmp/bin/gotestsum && \
  install -m0755 /go/bin/golangci-lint /tmp/bin/golangci-lint

# --- Trivy ---
RUN set -eux; \
  TRIVY_VERSION="0.58.0"; \
  if [ "$ARCH_DL" = "arm64" ]; then TRIVY_ARCH="ARM64"; else TRIVY_ARCH="64bit"; fi; \
  curl -fsSL "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" -o /tmp/trivy.tgz; \
  tar -xzf /tmp/trivy.tgz -C /tmp trivy; \
  install -m0755 /tmp/trivy /tmp/bin/trivy; \
  rm -f /tmp/trivy /tmp/trivy.tgz

# ------------------------------------------------------------------------------
# Stage 2: final - slim runtime image
# ------------------------------------------------------------------------------
FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETARCH
ENV ARCH_DL=${TARGETARCH}

# --- Base packages (minimal) ---
RUN set -eux; \
  apt-get update; \
  apt-get -y install --no-install-recommends \
    ca-certificates curl git jq make openssh-client; \
  rm -rf /var/lib/apt/lists/*

# --- Copy all binaries from builder ---
COPY --from=builder /tmp/bin/ /usr/local/bin/

# --- Go runtime (needed for go test in CI) ---
COPY --from=builder /usr/local/go /usr/local/go
ENV PATH=/usr/local/go/bin:/usr/local/bin:$PATH GOPATH=/go

# --- Python + checkov (optional - comment out to save ~300MB) ---
RUN set -eux; \
  apt-get update; \
  apt-get -y install --no-install-recommends python3 python3-pip python3-venv pipx; \
  rm -rf /var/lib/apt/lists/*
ENV PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/pipx \
    set -eux; \
  mkdir -p "$PIPX_HOME"; \
  pipx install checkov

# --- Sanity check ---
RUN set -eux; \
  echo "=== Tool Versions ===" && \
  terraform --version && \
  tofu --version && \
  nomad --version && \
  nomad-pack version && \
  consul --version && \
  vault --version && \
  tflint --version && \
  terragrunt --version && \
  trivy --version && \
  golangci-lint version --format short && \
  go version && \
  checkov --version && \
  echo "==================="

# --- Non-root user ---
ARG USERNAME=ci-runner
ARG UID=10001
ARG GID=10001
RUN set -eux; \
  addgroup --gid "$GID" "$USERNAME"; \
  adduser --disabled-password --gecos "" --uid "$UID" --gid "$GID" "$USERNAME"; \
  mkdir -p /workspace "$GOPATH"; \
  chown -R "$USERNAME:$USERNAME" /workspace "$GOPATH"

WORKDIR /workspace
USER $USERNAME
