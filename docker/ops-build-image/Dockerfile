# filepath: ops-build-image/Dockerfile

# ------------------------------------------------------------------------------
# builder: fetch CLI binaries to copy into final image (multi-arch aware)
# ------------------------------------------------------------------------------
FROM debian:trixie-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Buildx provides these for each platform leg
ARG TARGETOS
ARG TARGETARCH

# Map Buildx TARGETARCH to release artifact arch tags
# (most upstreams use "amd64" / "arm64" already, so this is pass-through)
ENV ARCH_DL=${TARGETARCH}

RUN set -eux; \
  apt-get update; \
  apt-get -y install --no-install-recommends ca-certificates curl jq tar gzip unzip; \
  rm -rf /var/lib/apt/lists/*

RUN set -eux; mkdir -p /tmp/bin

# ------------------------------------------------------------------------------
# tflint (pinned version) - uses arch-specific zip
# ------------------------------------------------------------------------------
RUN set -eux; \
  TFLINT_VERSION="0.59.1"; \
  curl -sSfL "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${ARCH_DL}.zip" -o /tmp/tflint.zip; \
  unzip /tmp/tflint.zip -d /tmp; \
  install -m0755 /tmp/tflint /tmp/bin/tflint; \
  rm -f /tmp/tflint.zip /tmp/tflint; \
  test -x /tmp/bin/tflint

# ------------------------------------------------------------------------------
# terragrunt (latest release, pick correct linux_${ARCH_DL} asset)
# ------------------------------------------------------------------------------
RUN set -eux; \
  tg_url="$(curl -fsSL https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest \
    | jq -r --arg arch "${ARCH_DL}" '.assets[] | select(.name == ("terragrunt_linux_" + $arch)) | .browser_download_url' \
    | head -n1)"; \
  curl -fsSL "$tg_url" -o /tmp/bin/terragrunt; \
  chmod +x /tmp/bin/terragrunt; \
  test -x /tmp/bin/terragrunt

# ------------------------------------------------------------------------------
# Go & hclfmt (pinned Go, arch-specific tarball)
# ------------------------------------------------------------------------------
RUN set -eux; \
  GO_VERSION="1.25.2"; \
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH_DL}.tar.gz" -o /tmp/go.tgz; \
  tar -C /usr/local -xzf /tmp/go.tgz; rm -f /tmp/go.tgz
ENV PATH=/usr/local/go/bin:$PATH GOPATH=/go
RUN set -eux; \
  GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0 \
  go install github.com/hashicorp/hcl/v2/cmd/hclfmt@latest; \
  install -m0755 /go/bin/hclfmt /tmp/bin/hclfmt; \
  /tmp/bin/hclfmt -h >/dev/null || true

# ------------------------------------------------------------------------------
# Terraform (pinned version) - arch-specific zip
# ------------------------------------------------------------------------------
RUN set -eux; \
  TF_VERSION="1.13.3"; \
  curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH_DL}.zip" -o /tmp/terraform.zip; \
  unzip -d /tmp /tmp/terraform.zip; \
  install -m0755 /tmp/terraform /tmp/bin/terraform; \
  rm -f /tmp/terraform /tmp/terraform.zip

# ------------------------------------------------------------------------------
# OpenTofu (pinned version) - arch-specific tarball
# ------------------------------------------------------------------------------
RUN set -eux; \
  TOFU_VERSION="1.10.3"; \
  curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_${ARCH_DL}.tar.gz" -o /tmp/tofu.tgz; \
  tar -xzf /tmp/tofu.tgz -C /tmp tofu; \
  install -m0755 /tmp/tofu /tmp/bin/tofu; \
  rm -f /tmp/tofu /tmp/tofu.tgz

# ------------------------------------------------------------------------------
# final: toolchain image (multi-arch aware)
# ------------------------------------------------------------------------------
FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Buildx target info for this stage too
ARG TARGETOS
ARG TARGETARCH
ENV ARCH_DL=${TARGETARCH}

# ------------------------------------------------------------------------------
# base OS packages
# ------------------------------------------------------------------------------
RUN set -eux; \
  apt-get update; \
  apt-get -y dist-upgrade; \
  apt-get -y install --no-install-recommends \
    ca-certificates curl gnupg git jq make unzip tar xz-utils \
    build-essential python3 python3-pip python3-venv pipx; \
  update-ca-certificates; \
  rm -rf /var/lib/apt/lists/*

ENV PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
RUN set -eux; mkdir -p "$PIPX_HOME" && pipx ensurepath

# ------------------------------------------------------------------------------
# Go (runtime - pinned version, arch-specific tarball)
# ------------------------------------------------------------------------------
ENV GOPATH=/go PATH=/usr/local/go/bin:/go/bin:/usr/local/bin:$PATH
RUN set -eux; \
  GO_VERSION="1.25.2"; \
  curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH_DL}.tar.gz" -o /tmp/go.tgz; \
  rm -rf /usr/local/go; \
  tar -C /usr/local -xzf /tmp/go.tgz; \
  rm -f /tmp/go.tgz; \
  go version

# ------------------------------------------------------------------------------
# Node.js 24.x + CDKTF (pinned npm version)
# ------------------------------------------------------------------------------
RUN set -eux; \
  install -d -m 0755 /etc/apt/keyrings; \
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
  chmod a+r /etc/apt/keyrings/nodesource.gpg; \
  echo "Types: deb" > /etc/apt/sources.list.d/nodesource.sources; \
  echo "URIs: https://deb.nodesource.com/node_24.x" >> /etc/apt/sources.list.d/nodesource.sources; \
  echo "Suites: nodistro" >> /etc/apt/sources.list.d/nodesource.sources; \
  echo "Components: main" >> /etc/apt/sources.list.d/nodesource.sources; \
  echo "Signed-By: /etc/apt/keyrings/nodesource.gpg" >> /etc/apt/sources.list.d/nodesource.sources; \
  apt-get update; \
  apt-get -y install --no-install-recommends nodejs; \
  npm i -g npm@11.6.2 cdktf-cli@latest; \
  npm cache clean --force || true; \
  rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# copy CLI binaries from builder
# ------------------------------------------------------------------------------
COPY --from=builder /tmp/bin/terraform   /usr/local/bin/terraform
COPY --from=builder /tmp/bin/tofu        /usr/local/bin/tofu
COPY --from=builder /tmp/bin/tflint      /usr/local/bin/tflint
COPY --from=builder /tmp/bin/terragrunt  /usr/local/bin/terragrunt
COPY --from=builder /tmp/bin/hclfmt      /usr/local/bin/hclfmt

# ------------------------------------------------------------------------------
# Cinc (client + auditor)
# ------------------------------------------------------------------------------
RUN set -eux; \
  curl -fsSL https://omnitruck.cinc.sh/install.sh | bash -s -- -P cinc -c stable; \
  curl -fsSL https://omnitruck.cinc.sh/install.sh | bash -s -- -P cinc-auditor -c stable

# ------------------------------------------------------------------------------
# remove Cinc specs, tests, and ALL key/certificate fixtures
# ------------------------------------------------------------------------------
RUN set -eux; \
  for base in /opt/cinc/embedded/lib/ruby/gems /opt/cinc-auditor/embedded/lib/ruby/gems; do \
    if [ -d "$base" ]; then \
      find "$base" -type d -name "spec" -print0 | xargs -0 -r rm -rf; \
      find "$base" -type d -name "test" -print0 | xargs -0 -r rm -rf; \
      find "$base" -type d -name "examples" -print0 | xargs -0 -r rm -rf; \
      find "$base" -type d -name "features" -print0 | xargs -0 -r rm -rf; \
    fi; \
  done

# ------------------------------------------------------------------------------
# security / lint / qa tools
# ------------------------------------------------------------------------------
RUN set -eux; \
  pipx install checkov && checkov --version; \
  pipx inject checkov 'asteval>=1.0.6' && \
  pipx runpip checkov list | grep asteval

RUN set -eux; curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin; trivy --version
RUN set -eux; curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh -s -- -b /usr/local/bin; infracost --version
RUN set -eux; curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b /usr/local/bin; golangci-lint version

# --- Go-based CLIs (multi-arch safe; disable CGO so no gcc '-m64' on arm64) ---
ENV GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=0
RUN set -eux; go install honnef.co/go/tools/cmd/staticcheck@latest
RUN set -eux; go install github.com/rakyll/gotest@latest; go install gotest.tools/gotestsum@latest

# ------------------------------------------------------------------------------
# sanity checks & version display
# ------------------------------------------------------------------------------
RUN set -eux; \
  echo "=== Tool Versions ===" && \
  echo "Node.js: $(node --version)" && \
  echo "npm: $(npm --version)" && \
  echo "cdktf: $(cdktf --version 2>&1 | head -n1)" && \
  echo "Go: $(go version)" && \
  echo "Python: $(python3 --version)" && \
  echo "Terraform: $(terraform version | head -n1)" && \
  echo "OpenTofu: $(tofu version | head -n1)" && \
  echo "TFLint: $(tflint --version)" && \
  echo "Terragrunt: $(terragrunt --version)" && \
  echo "hclfmt: $(hclfmt -version 2>&1 || echo 'hclfmt installed')" && \
  echo "Trivy: $(trivy --version | head -n1)" && \
  echo "Checkov: $(checkov --version)" && \
  echo "Infracost: $(infracost --version)" && \
  echo "golangci-lint: $(golangci-lint version --short)" && \
  echo "staticcheck: $(staticcheck -version)" && \
  echo "Cinc Client: $(cinc-client --version | head -n1)" && \
  echo "Cinc Auditor: $(cinc-auditor version)" && \
  echo "==================="

# ------------------------------------------------------------------------------
# non-root runtime user
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# healthcheck
# ------------------------------------------------------------------------------
HEALTHCHECK --interval=30m --timeout=30s --start-period=5m --retries=3 \
  CMD bash -lc 'terraform -version >/dev/null 2>&1 \
    && tofu version >/dev/null 2>&1 \
    && terragrunt --version >/dev/null 2>&1 \
    && hclfmt -help >/dev/null 2>&1 \
    && cdktf --version >/dev/null 2>&1 \
    || exit 1'
