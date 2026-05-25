# nvidia

Installs the Debian-shipped NVIDIA proprietary driver and `nvidia-container-toolkit`. Required for the docker `nvidia` runtime (declared elsewhere via `docker.daemon.extra` on the GPU host's role).

Currently only `nomad-client-04` runs this (the media-stack node with GPU passthrough).

## Recipes

| Recipe | Purpose |
|---|---|
| `default` | Empty; opt in via role. |
| `install` | Debian non-free repo + nvidia toolkit repo + driver + toolkit packages. |

## Testing

```
make lint
make test
```

### Why no `make kitchen`

- The proprietary `nvidia-driver` requires real NVIDIA hardware; the libvirt guest doesn't have any.
- DKMS-style driver builds need matching kernel headers compiled against the running kernel; the kitchen guest's kernel is irrelevant.

Verify changes live on the GPU host: bump `version` in the role, push, `cinc-client`, then `nvidia-smi` + `docker info | grep -i runtime`.
