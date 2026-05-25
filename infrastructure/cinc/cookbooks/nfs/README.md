# nfs

NFS client install + reusable `nfs_mount` resource, plus a server-side recipe for nodes that export shares (mccoy, rubirosa today).

## Recipes

| Recipe | Purpose |
|---|---|
| `default` | Empty; opt in via role. |
| `client` | `nfs-common` + materializes every entry in `node['nfs']['client']['mounts']` (and `extra_mounts`) via `nfs_mount`. |
| `server` | `nfs-kernel-server` + renders `/etc/exports` from `node['nfs']['server']['exports']`; empty list = no-op. |

## Testing

```
make lint
make test
make kitchen
```

The `client` kitchen suite intentionally has empty mounts: a kitchen guest can't reach a real NFS peer, so the suite only proves package install + mount-point dir shape. Real mount/unmount paths are covered by chefspec via attribute overrides.

The `server` suite installs `nfs-kernel-server`, renders `/etc/exports` with a 127.0.0.0/8 export of `/srv/nfs/test`, and runs `exportfs -ra`. Inspec verifies `/etc/exports` contents + service state.
