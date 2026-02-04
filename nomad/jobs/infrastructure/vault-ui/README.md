# Vault UI

Lightweight NGINX redirect that sends `vault-ui.munchbox.cc` requests to
the built-in Vault web interface at `vault.munchbox.cc:8200/ui`. Exists
because the old third-party vault-ui image (djenriquez/vault-ui) had
critical vulnerabilities and is no longer maintained. HashiCorp Vault
includes a capable UI natively, so this job just provides a convenient
redirect behind OAuth.

## Notable Configuration

- Protected by oauth2-proxy for access control
- Returns a simple 302 redirect rather than proxying traffic
