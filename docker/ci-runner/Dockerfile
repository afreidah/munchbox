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

FROM myoung34/github-runner:2.337.0-ubuntu-jammy

# TARGETARCH is auto-populated by BuildKit/buildx per target platform (amd64|arm64).
# Do NOT give it a default -- a default overrides the per-platform value and every
# arch ends up with amd64 binaries.
ARG TARGETARCH
ARG TERRAFORM_VERSION=1.15.4
ARG TERRAGRUNT_VERSION=1.1.0
ARG NOMAD_VERSION=2.0.3
ARG NOMAD_PACK_VERSION=0.4.1
ARG CONSUL_VERSION=2.0.1
ARG VAULT_VERSION=2.0.3

USER root

# pipefail so a failed `curl` in the `curl … | bash` installers below aborts the
# build instead of being masked by the piped shell's exit status (hadolint DL4006).
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl unzip git python3-pip; \
    # --- Terraform / Terragrunt / Nomad / Nomad Pack / Consul / Vault
    #     (pinned to the versions the cluster actually runs) ---
    curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/terraform.zip terraform -d /usr/local/bin; \
    curl -fsSLo /usr/local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_${TARGETARCH}"; \
    chmod +x /usr/local/bin/terragrunt; \
    curl -fsSLo /tmp/nomad.zip "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/nomad.zip nomad -d /usr/local/bin; \
    curl -fsSLo /tmp/nomad-pack.zip "https://releases.hashicorp.com/nomad-pack/${NOMAD_PACK_VERSION}/nomad-pack_${NOMAD_PACK_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/nomad-pack.zip nomad-pack -d /usr/local/bin; \
    curl -fsSLo /tmp/consul.zip "https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/consul.zip consul -d /usr/local/bin; \
    curl -fsSLo /tmp/vault.zip "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip -o /tmp/vault.zip vault -d /usr/local/bin; \
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
    consul version; \
    vault version; \
    trivy --version; \
    checkov --version
