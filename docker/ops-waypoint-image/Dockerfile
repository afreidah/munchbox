# filepath: docker/ops-waypoint-image/Dockerfile

# ------------------------------------------------------------------------------
#  ops-waypoint-image — Waypoint CLI (verified), lean runtime, non-root
# ------------------------------------------------------------------------------

FROM debian:trixie-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ENV WAYPOINT_VERSION=0.11.4

RUN set -eux; \
  apt-get update; \
  apt-get -y install --no-install-recommends ca-certificates curl unzip gnupg; \
  update-ca-certificates; \
  rm -rf /var/lib/apt/lists/*

RUN set -eux; \
  ARCH_IN="${TARGETARCH:-$(dpkg --print-architecture)}"; \
  case "${ARCH_IN}" in \
    amd64|x86_64)  WP_ARCH="amd64" ;; \
    arm64|aarch64) WP_ARCH="arm64" ;; \
    *) echo "Unsupported arch: ${ARCH_IN}"; exit 1 ;; \
  esac; \
  mkdir -p /tmp/wp /out; \
  base="https://releases.hashicorp.com/waypoint/${WAYPOINT_VERSION}"; \
  zipname="waypoint_${WAYPOINT_VERSION}_linux_${WP_ARCH}.zip"; \
  curl -fsSLo "/tmp/wp/${zipname}"   "${base}/${zipname}"; \
  curl -fsSLo /tmp/wp/SHA256SUMS     "${base}/waypoint_${WAYPOINT_VERSION}_SHA256SUMS"; \
  curl -fsSLo /tmp/wp/SHA256SUMS.sig "${base}/waypoint_${WAYPOINT_VERSION}_SHA256SUMS.sig"; \
  curl -fsSLo /tmp/wp/hashicorp.asc  https://keybase.io/hashicorp/pgp_keys.asc; \
  gpg --import /tmp/wp/hashicorp.asc; \
  gpg --verify /tmp/wp/SHA256SUMS.sig /tmp/wp/SHA256SUMS; \
  (cd /tmp/wp && grep " ${zipname}\$" SHA256SUMS | sha256sum -c -); \
  unzip -d /tmp/wp "/tmp/wp/${zipname}"; \
  install -m0755 /tmp/wp/waypoint /out/waypoint.bin; \
  rm -rf /tmp/wp

FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
  apt-get update; \
  apt-get -y dist-upgrade; \
  apt-get -y install --no-install-recommends ca-certificates curl netcat-openbsd bash adduser; \
  update-ca-certificates; \
  rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/waypoint.bin /usr/local/bin/waypoint

ARG USERNAME=ops
ARG UID=10001
ARG GID=10001
RUN set -eux; \
  addgroup --gid "$GID" "$USERNAME"; \
  adduser --disabled-password --gecos "" --uid "$UID" --gid "$GID" "$USERNAME"; \
  install -d -m 0755 -o "$UID" -g "$GID" /workspace

USER $USERNAME
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/waypoint"]
CMD ["version"]

