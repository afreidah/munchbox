# docker/

Source for the container images Munchbox builds and pushes to its private
registry (`registry.munchbox.cc`). Two apps live here today:

| Dir | Image | Consumed by |
|---|---|---|
| `patroni/` | `registry.munchbox.cc/patroni:pg18` | `nomad/jobs/infrastructure/patroni/` (HA PG18 + Patroni 4.0.4, cosign-signed via Vault Transit) |
| `ops-build-image/` | `registry.munchbox.cc/ops-build-image:latest` | `nomad/jobs/infrastructure/forgejo-runner/` (CI toolchain for `ops`-labeled Forgejo Actions jobs) |

> **Style guide:** [STYLE_GUIDE.md](./STYLE_GUIDE.md) -- Dockerfile +
> Makefile conventions used here.

---

## Anatomy

Each app dir is the same shape:

```
docker/<app>/
+-- Dockerfile     # multi-stage where it matters
+-- Makefile       # local + multi-arch + push targets via docker buildx
```

There is no umbrella build orchestrator. Each app's `Makefile` stands on
its own with `docker buildx` -- no Waypoint, no shared scripts.

---

## Common ops

From any app dir:

```bash
make help               # list targets
make build              # local-arch build (for testing)
make build-multiarch    # current platform via buildx
make push               # multi-arch build + push to registry.munchbox.cc
make clean              # rm local images
```

For `ops-build-image` only:

```bash
make test               # validates the tool versions baked in (nomad, terraform, consul, vault, go, ...)
```

The `munchbox-builder` buildx instance is created on first run and reused.
Multi-arch pushes target `linux/amd64,linux/arm64`.

---

## Adding a new image

1. `mkdir docker/<name>/` plus a `Dockerfile` and a `Makefile`
   following the existing two as templates.
2. Pin `REGISTRY := registry.munchbox.cc` and `IMAGE := <name>` in the
   Makefile.
3. From the dir: `make push`.
4. Wire it into a Nomad job using `registry.munchbox.cc/<name>:<tag>` as
   the image.
5. **Image bumps**: update the tag in the Nomad job spec when you push a
   new version. The registry doesn't auto-pull `:latest` for running
   allocs.

---

## Registry access

- The registry runs in Nomad on `stabler`, registered as
  `registry.service.consul:5000`.
- Docker daemons trust it as `insecure_registries =
  registry.service.consul:5000` via the `docker` Chef cookbook's
  `daemon.json`.
- External pushes go through Traefik at `registry.munchbox.cc` (HTTPS).
- The Temporal `registry-gc-trigger` runs weekly to garbage-collect
  unreferenced layers.

---

## Related

- [STYLE_GUIDE.md](./STYLE_GUIDE.md) -- Dockerfile + Makefile conventions.
- [`nomad/jobs/infrastructure/registry/`](../nomad/jobs/infrastructure/registry/)
  -- the registry itself.
- [`infrastructure/cinc/cookbooks/docker/`](../infrastructure/cinc/cookbooks/docker/)
  -- docker daemon setup on each node (including the insecure-registries
  trust).
