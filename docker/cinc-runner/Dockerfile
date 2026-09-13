# -------------------------------------------------------------------------------
# cinc-runner -- knife for the Forgejo workflow that uploads to the cinc server
#
# Project: Munchbox / Author: Alex Freidah
#
# Carries cinc-workstation and nothing else. It is a separate image rather than
# another layer on ops-build-image because workstation is a ~120 MB download
# that every image build would otherwise pull without ever calling knife -- the
# same reason ansible was taken back out of that image.
#
# Node is here for the runner itself: Forgejo executes JavaScript actions like
# actions/checkout inside the workflow container, and they need a node binary.
# -------------------------------------------------------------------------------

FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

ARG TARGETARCH

# --- Base packages. git for the checkout, node for JavaScript actions. ---
RUN set -eux; \
  apt-get update; \
  apt-get -y install --no-install-recommends \
    ca-certificates curl git jq make openssh-client nodejs npm; \
  rm -rf /var/lib/apt/lists/*

# --- cinc-workstation (knife). Pinned: the project publishes per-version .deb
#     artefacts rather than an apt repo, so an upgrade is a deliberate bump. ---
ARG CINC_WORKSTATION_VERSION="26.2.3"
RUN set -eux; \
  url="https://downloads.cinc.sh/files/stable/cinc-workstation/${CINC_WORKSTATION_VERSION}/debian/12/cinc-workstation_${CINC_WORKSTATION_VERSION}-1_${TARGETARCH}.deb"; \
  curl -fsSL "$url" -o /tmp/cinc-workstation.deb; \
  apt-get update; \
  apt-get -y install --no-install-recommends /tmp/cinc-workstation.deb; \
  rm -f /tmp/cinc-workstation.deb; \
  rm -rf /var/lib/apt/lists/*

# --- Fail the build if knife is missing or broken ---
RUN set -eux; \
  knife --version; \
  node --version; \
  git --version
