# -------------------------------------------------------------------------------
# ci-runner -- self-hosted GitHub Actions runner for munchbox's cluster-side CI
#
# Project: Munchbox / Author: Alex Freidah
#
# Thin runner for the CI jobs that must run on the cluster: terragrunt
# validate/plan against the Consul state backend + Vault, trivy/checkov with real
# leaf inputs, and `nomad job validate` against a Nomad server. Ships only that
# toolchain on top of the base GitHub runner -- deliberately NOT the heavy
# moat-runner-standard (Go/Node/Cinc/...), which these jobs never use.
# -------------------------------------------------------------------------------

FROM myoung34/github-runner:2.334.0-ubuntu-jammy

# TARGETARCH is set by buildx (amd64|arm64); default keeps plain `docker build` working.
ARG TARGETARCH=amd64
ARG TERRAFORM_VERSION=1.15.4
ARG TERRAGRUNT_VERSION=1.0.6
ARG NOMAD_VERSION=1.9.7
ARG NOMAD_PACK_VERSION=0.4.1

USER root

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl unzip git python3-pip; \
    # --- Terraform / Terragrunt / Nomad / Nomad Pack (pinned to match CI) ---
    curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/terraform.zip terraform -d /usr/local/bin; \
    curl -fsSLo /usr/local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${TARGETARCH}"; \
    chmod +x /usr/local/bin/terragrunt; \
    curl -fsSLo /tmp/nomad.zip "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/nomad.zip nomad -d /usr/local/bin; \
    curl -fsSLo /tmp/nomad-pack.zip "https://releases.hashicorp.com/nomad-pack/${NOMAD_PACK_VERSION}/nomad-pack_${NOMAD_PACK_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/nomad-pack.zip nomad-pack -d /usr/local/bin; \
    # --- tflint + trivy (latest; official installers detect arch) ---
    curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; \
    curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin; \
    # --- checkov (system pip; ubuntu-jammy does not enforce PEP 668) ---
    pip3 install --no-cache-dir checkov; \
    # --- Cleanup ---
    rm -f /tmp/*.zip; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# --- Fail the build if any tool is missing or broken ---
RUN set -eux; \
    terraform version; \
    terragrunt --version; \
    tflint --version; \
    nomad version; \
    nomad-pack version; \
    trivy --version; \
    checkov --version
