# ------------------------------------------------------------------------------
#  Dockerfile — CI/CD Toolchain for Terraform/Terragrunt/OpenTofu/CDKTF/Go/Cinc
#
#  This image installs "latest" (at build time) of:
#    • Terraform, OpenTofu, Terragrunt
#    • CDK for Terraform (cdktf)
#    • Go toolchain
#    • Cinc (client) and Cinc Auditor (InSpec)
#    • Linters/Security/QA: hclfmt, checkov, trivy, infracost, tflint, terrascan,
#      staticcheck, golangci-lint, gotest+gotestsum
#    • (Optional) openinfraquote — gated behind ARG since origin is unclear
#
#  Notes:
#    • “Latest” means whatever upstream exposes during docker build.
#    • Defaults assume linux/amd64; adjust asset selectors for arm64 if needed.
#    • Piped installers are used for velocity; pin versions in your CI if desired.
# ------------------------------------------------------------------------------

FROM debian:bookworm-slim

# ------------------------------------------------------------------------------
#  Base OS & Shell Setup
# ------------------------------------------------------------------------------
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------------------------
#  OS Packages
#    - Core build/test deps + convenience CLI tools
# ------------------------------------------------------------------------------
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg lsb-release \
    git jq make unzip tar xz-utils \
    build-essential python3 python3-pip python3-venv pipx \
    openssh-client; \
  update-ca-certificates; \
  rm -rf /var/lib/apt/lists/*

# Ensure pipx installs into a root-writable prefix that’s on PATH
ENV PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
RUN set -eux; mkdir -p "$PIPX_HOME" && pipx ensurepath

# ------------------------------------------------------------------------------
#  Go (latest stable)
#    - Dynamically fetches latest version string and installs from go.dev
# ------------------------------------------------------------------------------
ENV GOPATH=/go PATH=/usr/local/go/bin:/go/bin:$PATH
RUN set -eux; \
  ver="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)"; \
  curl -fsSL "https://go.dev/dl/${ver}.linux-amd64.tar.gz" -o /tmp/go.tgz; \
  rm -rf /usr/local/go; \
  tar -C /usr/local -xzf /tmp/go.tgz; \
  rm -f /tmp/go.tgz; \
  go version

# ------------------------------------------------------------------------------
#  Node.js (for CDKTF) + CDKTF CLI
# ------------------------------------------------------------------------------
RUN set -eux; \
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -; \
  apt-get update; \
  apt-get install -y --no-install-recommends nodejs; \
  npm i -g npm@latest; \
  npm i -g cdktf-cli@latest; \
  rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
#  HashiCorp Terraform (latest from apt repo)
# ------------------------------------------------------------------------------
RUN set -eux; \
  install -d /usr/share/keyrings; \
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg; \
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo $VERSION_CODENAME) main" \
    > /etc/apt/sources.list.d/hashicorp.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends terraform; \
  rm -rf /var/lib/apt/lists/*; \
  terraform -version

# ------------------------------------------------------------------------------
#  OpenTofu (latest from official apt repo)
# ------------------------------------------------------------------------------
RUN set -eux; \
  install -d /usr/share/keyrings; \
  curl -fsSL https://packages.opentofu.org/opentofu/opentofu/gpg | gpg --dearmor -o /usr/share/keyrings/opentofu-archive-keyring.gpg; \
  echo "deb [signed-by=/usr/share/keyrings/opentofu-archive-keyring.gpg] https://packages.opentofu.org/opentofu/opentofu/apt/ $(. /etc/os-release && echo $VERSION_CODENAME) main" \
    > /etc/apt/sources.list.d/opentofu.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends opentofu; \
  rm -rf /var/lib/apt/lists/*; \
  tofu version

# ------------------------------------------------------------------------------
#  Terragrunt (latest GitHub release)
# ------------------------------------------------------------------------------
RUN set -eux; \
  url="$(curl -fsSL https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest \
        | jq -r '.assets[] | select(.name | test("linux_amd64$|linux_amd64\\.exe$|linux_amd64\\.zip$|linux_amd64\\.tar\\.gz$")) | .browser_download_url' \
        | head -n1)"; \
  # Prefer the raw binary when available
  if [[ "$url" == *".tar.gz" ]]; then \
    curl -fsSL "$url" -o /tmp/tg.tgz; tar -xzf /tmp/tg.tgz -C /usr/local/bin; rm -f /tmp/tg.tgz; \
  elif [[ "$url" == *".zip" ]]; then \
    curl -fsSL "$url" -o /tmp/tg.zip; unzip -jo /tmp/tg.zip -d /usr/local/bin; rm -f /tmp/tg.zip; \
  else \
    curl -fsSL "$url" -o /usr/local/bin/terragrunt; chmod +x /usr/local/bin/terragrunt; \
  fi; \
  terragrunt --version

# ------------------------------------------------------------------------------
#  Cinc (Client) & Cinc Auditor (InSpec) — latest via omnitruck.cinc.sh
# ------------------------------------------------------------------------------
RUN set -eux; \
  curl -fsSL https://omnitruck.cinc.sh/install.sh | bash -s -- -P cinc -c stable; \
  curl -fsSL https://omnitruck.cinc.sh/install.sh | bash -s -- -P cinc-auditor -c stable; \
  cinc-client --version; \
  cinc-auditor version

# ------------------------------------------------------------------------------
#  Security / Lint / QA Tooling
#    - hclfmt, tflint, terrascan, checkov, trivy, infracost, golangci-lint,
#      staticcheck, gotest tools
# ------------------------------------------------------------------------------
# hclfmt (HashiCorp HCL v2 formatter)
RUN set -eux; go install github.com/hashicorp/hcl/v2/cmd/hclfmt@latest

# tflint (install script to /usr/local/bin)
RUN set -eux; \
  curl -sSfL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh \
    | bash -s -- -b /usr/local/bin; \
  tflint --version

# terrascan (latest GitHub release)
RUN set -eux; \
  ts_url="$(curl -fsSL https://api.github.com/repos/tenable/terrascan/releases/latest \
           | jq -r '.assets[] | select(.name | test("Linux_x86_64\\.tar\\.gz$")) | .browser_download_url' | head -n1)"; \
  curl -fsSL "$ts_url" -o /tmp/terrascan.tgz; \
  tar -xzf /tmp/terrascan.tgz terrascan -C /tmp; \
  install -m 0755 /tmp/terrascan /usr/local/bin/terrascan; \
  rm -f /tmp/terrascan.tgz /tmp/terrascan; \
  terrascan version

# checkov (Python; isolated via pipx)
RUN set -eux; pipx install checkov && checkov --version

# trivy (install script to /usr/local/bin)
RUN set -eux; \
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin; \
  trivy --version

# infracost (install script to /usr/local/bin)
RUN set -eux; \
  curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh \
    | sh -s -- -b /usr/local/bin; \
  infracost --version

# golangci-lint (install script to /usr/local/bin; latest)
RUN set -eux; \
  curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh \
    | sh -s -- -b /usr/local/bin; \
  golangci-lint version

# staticcheck (Go tool)
RUN set -eux; go install honnef.co/go/tools/cmd/staticcheck@latest

# gotest tools — both a nicer test runner and a summary tool
RUN set -eux; \
  go install github.com/rakyll/gotest@latest; \
  go install gotest.tools/gotestsum@latest

# Ensure Go-installed tools are on PATH
ENV PATH=/usr/local/go/bin:/go/bin:/usr/local/bin:$PATH

# ------------------------------------------------------------------------------
#  Optional: openinfraquote (disabled by default; set at build-time)
#    docker build --build-arg INSTALL_OPENINFRAQUOTE=true .
# ------------------------------------------------------------------------------
ARG INSTALL_OPENINFRAQUOTE=false
RUN set -eux; \
  if [ "$INSTALL_OPENINFRAQUOTE" = "true" ]; then \
    # TODO: replace with authoritative install source for openinfraquote
    # Example (Python): pipx install openinfraquote
    pipx install openinfraquote || true; \
  fi

# ------------------------------------------------------------------------------
#  Cleanup & Final Checks
# ------------------------------------------------------------------------------
RUN set -eux; \
  # lightweight smoke checks
  which terraform tofu terragrunt hclfmt tflint trivy infracost golangci-lint staticcheck gotest gotestsum >/dev/null; \
  echo "CI toolchain ready."

# Default working directory for pipelines
WORKDIR /workspace
