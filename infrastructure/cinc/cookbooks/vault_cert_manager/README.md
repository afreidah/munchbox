# vault_cert_manager

Installs + configures `vault-cert-manager` — the long-running daemon that lifecycles infra TLS certs (consul / nomad / vault server certs) out of Vault PKI.

## Recipes

| Recipe | Purpose |
|---|---|
| `default` | Empty; opt in via role. |
| `install` | apt package from the munchbox aptly repo + config dir + cert-owner prereq users (consul, nomad, etc.). |
| `configure` | AppRole creds + `config.yaml` + systemd drop-in + consul service registration + service start. |

## Testing

```
make lint
make test
make kitchen     # install-only suite (debian-12)
```

### Why kitchen only covers install

The `configure` recipe needs:
- Live Vault to `vault_fetch` the AppRole `secret_id`.
- The cert-manager daemon to actually be able to issue certs (Vault PKI mount + policy in place).

Neither is available in a fresh kitchen guest. Configure changes are tested live on a node (`cinc-client -W` dry-run + service reload).
