# docker/ -- Style Guide

Authoritative for Dockerfile + per-app Makefile code in this directory.
Self-contained.

---

## 1. File header

Every `Dockerfile` opens with a box header:

```
# -------------------------------------------------------------------------------
# <Image Name> -- <Short Role>
#
# Project: Munchbox / Author: Alex Freidah
#
# 2-4 sentences describing what the image is for, what it ships, and any
# important caveats. Stay factual -- no migration narration, no bug history.
# -------------------------------------------------------------------------------
```

Same shape for the per-app `Makefile` (use `#` as comment char).

Rules:
- 79-char `#-` divider.
- Title line: `<Image Name> -- <Short Role>`.
- `Project: Munchbox / Author: Alex Freidah` on its own line.

---

## 2. Comments -- strict binary rule

Same as every other style guide in the repo. **Two acceptable shapes; no
middle form.**

### (a) Single-line markers

```dockerfile
# --- Go (for building tools) ---
RUN set -eux; \
    curl -fsSL https://go.dev/dl/go1.23.4.linux-${ARCH_DL}.tar.gz | tar -C /usr/local -xz
```

- `# --- text ---` form.
- ~60 chars max content. Promote to a box if longer.

### (b) Section box

```dockerfile
# ------------------------------------------------------------------------------
# Stage 1: builder -- fetch/compile CLI binaries
# ------------------------------------------------------------------------------

FROM debian:trixie-slim AS builder
...
```

- 79-char divider for major sections (typically one per `FROM` stage).
- One blank line after the closing divider.

### Forbidden

- Multi-line `# foo / # bar` blocks (the middle form).
- Migration narration.
- Bug history.

---

## 3. Dockerfile conventions

### Base images

- Pin to an explicit tag, never `:latest`. Prefer slim/bookworm variants
  for size.
- For multi-stage builds: label stages (`AS builder`, `AS runtime`).
- Use upstream official images when possible (`postgres:18-bookworm`,
  `debian:trixie-slim`).

### Multi-arch

- Use `ARG TARGETOS` + `ARG TARGETARCH` in stages that pull
  arch-specific binaries.
- Map `TARGETARCH` to whatever the upstream binary uses
  (`ENV ARCH_DL=${TARGETARCH}`).
- Push targets `linux/amd64,linux/arm64`.

### RUN blocks

- One concern per `RUN`. Don't pile apt install + go build + cleanup
  into a single layer if a later edit will invalidate the entire chunk.
- Use `set -eux; \` at the top of multi-line RUNs so failures are loud
  and intermediate steps are visible.
- Clean up apt lists in the same RUN: `rm -rf /var/lib/apt/lists/*`.

### Final image hygiene

- `USER` a non-root account where the upstream image allows.
- No build tools in the final stage -- copy artifacts out of `builder`.
- No secrets baked in. Anything sensitive comes via Nomad templates at
  runtime.

---

## 4. Makefile conventions

Each per-app Makefile must offer at minimum:

| Target | Purpose |
|---|---|
| `help` (default goal) | List targets |
| `build` | Local-arch build for testing |
| `build-multiarch` | Current platform via buildx (with `--load`) |
| `push` | Multi-arch build + push to registry |
| `clean` | `docker rmi` local tags |

`ops-build-image/Makefile` also has a `test` target that validates the
tool versions baked in -- worth copying for any toolchain image.

Rules:

- `REGISTRY := registry.munchbox.cc` and `IMAGE := <name>` declared at
  the top.
- `BUILDER_NAME := munchbox-builder` (shared across apps; reuse).
- Always `--driver-opt network=host` on the builder so it can resolve
  internal registry DNS.
- Caching: prefer `--cache-from type=registry,ref=$(IMAGE):cache` +
  `--cache-to type=registry,ref=$(IMAGE):cache,mode=max` -- keeps
  caches centralized in the registry, not on the workstation.

---

## 5. Tagging

- `latest` -- the most recent push (Nomad jobs generally pin to a
  specific tag, not `latest`).
- `<concern>` tags for stable variants (e.g. `pg18`, `pg18-patroni4.0.4`).
- Always push at least the explicit version tag alongside `latest`.

---

## 6. Security

- `cosign` signing via Vault Transit for production images. Patroni does
  this; new images should too.
- Trivy scans run by the Temporal `trivy-scan-worker` after deploy --
  don't gate builds locally on a slow Trivy pass.
- No baked-in passwords, tokens, or keys. Period.

---

## 7. Common ops

```bash
# from the app dir
make build              # local-arch
make build-multiarch    # current platform via buildx
make push               # multi-arch + push
make clean              # rm local tags
```

After `make push`, bump the tag in the Nomad job spec and `make run
JOB=<service>` from `nomad/` to roll the new version.

---

## 8. Quick checklist

Before pushing a new version of an image:

- [ ] Dockerfile header banner matches convention.
- [ ] Base image pinned to an explicit tag.
- [ ] `TARGETARCH` plumbed through for any arch-specific download.
- [ ] No secrets baked in.
- [ ] Final image uses non-root `USER` where upstream allows.
- [ ] Image actually tested locally (`make build` runs clean).
- [ ] `make test` passes for toolchain images (`ops-build-image`).
- [ ] Tag bumped in the consuming Nomad job spec before `make run`.
