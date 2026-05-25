# oracle

Oracle Cloud node tweaks: the watchdog daemon (consul session heartbeat for the oracle node's health signal) and the persistent OCI block-volume mount for MinIO.

## Recipes

| Recipe | Purpose |
|---|---|
| `default` | Empty; opt in via role. |
| `watchdog` | `oracle-watchdog` package + config.yaml + systemd Environment override (CONSUL_HTTP_ADDR + ACL token from Vault) + consul service registration. Work lives in `oracle_watchdog`. |
| `minio_mount` | UUID-based fstab entry for the OCI block volume labeled `minio-data` (sweeps the legacy `/dev/sdb` entry). Work lives in `oracle_minio_mount`. |

## Testing

```
make lint
make test
```

### Why no `make kitchen` suite

Both recipes need live infrastructure to mean anything:

- `watchdog` reads the consul ACL token from Vault and notifies a running consul daemon to reload its service catalog.
- `minio_mount` expects an OCI block volume labeled `minio-data` to be attached to the guest. libvirt can't provide that.

Specs cover the resource shape exhaustively (step_into both `oracle_watchdog` and `oracle_minio_mount`). Real verification: `cinc-client -W` dry-run against a target oracle node.
