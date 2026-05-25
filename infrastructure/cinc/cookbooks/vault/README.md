# vault

Installs + configures HashiCorp Vault **server** (consul storage backend, HA).

Not vault-agent (that's `vault_agent`). Not vault-cert-manager (that's `vault_cert_manager`).

## Recipes

| Recipe | Purpose |
|---|---|
| `default` | Empty; opt in via role run_list. |
| `install` | Vault binary, user/group, dirs. Idempotent on version drift. |
| `configure` | `vault.hcl` + `vault.service` systemd unit. Renders config but does **not** restart vault (see below). |

## Testing

```
make lint       # cookstyle
make test       # chefspec
make kitchen    # install recipe only -- configure + daemon-start are NOT under kitchen (see below)
```

### Why kitchen only covers install

The configure recipe + daemon start are intentionally excluded:

- `configure` fetches the consul storage ACL token via `vault_fetch` against a live Vault. There is no usable Vault in a fresh kitchen VM.
- Vault servers come up **shamir-sealed** (5/3). Any usable test would need the manual unseal flow, which is an operator workflow — not idempotent provisioning. Re-running kitchen would re-seal and stall.
- `restart_on_change` defaults to `false` for the same reason: a config edit shouldn't bounce a sealed daemon and lock out every tenant.

Test configure changes on a per-node role pointed at a staging vault (`chef-client -W` dry-run), or fold into a planned-maintenance window where the operator is standing by to unseal.

## Operational notes

- Version bump → push cookbook → operator runs `systemctl restart vault` + `vault operator unseal` ×3 per node.
- TLS cert rotation is handled out-of-band by `vault_cert_manager` (SIGHUP, no unseal needed).
- The install side adds `vault` to the `consul` group so vault can read `/etc/consul.d/tls/*` (consul-storage backend requires mTLS).
