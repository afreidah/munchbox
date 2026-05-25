# cni

Installs the containernetworking/plugins CNI binaries under `/opt/cni/bin`. Required for Nomad bridge networking and Consul Connect on every nomad server + client.

## Recipes

| Recipe | Purpose |
|---|---|
| `default` | Empty; opt in via run_list. |
| `install` | Downloads + extracts the plugins tarball; arch-aware (amd64 / arm64). |

## Testing

```
make lint
make test
make kitchen     # full converge+verify cycle in a debian-12 libvirt VM
```
