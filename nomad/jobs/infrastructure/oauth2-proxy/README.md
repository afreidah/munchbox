# OAuth2 Proxy

Google OAuth forward authentication proxy that protects internal cluster
services. Traefik routes requests through oauth2-proxy as a forward auth
middleware, requiring Google account authentication before granting access.
Only email addresses listed in Vault are permitted.

## Architecture

OAuth2 Proxy operates as a standalone service that Traefik consults via
forward auth. When an unauthenticated user hits a protected service,
Traefik's `oauth2-proxy` middleware redirects them to `auth.munchbox.cc`
for Google OAuth login. After authentication, a session cookie grants
access to all `*.munchbox.cc` services sharing the cookie domain.

Services that handle their own authentication (Vaultwarden API, Forgejo
git operations, Nextcloud sync clients, Immich) bypass oauth2-proxy
using higher-priority Traefik router rules.

## Notable Configuration

- Colocated with Traefik on goren to minimize forward auth latency
- Static upstream (`static://202`) -- oauth2-proxy only validates auth,
  never proxies actual traffic
- Cookie domain set to `.munchbox.cc` for cross-subdomain SSO
- Authenticated emails file managed in Vault, not hardcoded
- Dual routers handle both direct HTTPS and Cloudflare tunnel paths

## Dependencies

- **Traefik** -- invokes oauth2-proxy as a forward auth middleware
- **Vault** -- Google OAuth client credentials and allowed email list
