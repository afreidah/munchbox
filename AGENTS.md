# Repository Guidelines

## Project Structure & Module Organization
- `cdktf/cloudflare`: Go CDKTF stack for Cloudflare DNS.
- `cdktf/munchbox-core`: Go CDKTF stack for Nomad/Consul/Vault plus HCL jobs, policies, and tokens.
- `chef/`: Cookbooks with Cookstyle, RSpec (ChefSpec), and Test Kitchen.
- `docker/`: Image build contexts (e.g., `deluge-vpn`, `ops-build-image`).
- `scripts/`: Utility scripts used in local or CI flows.
- `k3s/`: Cluster-related manifests/configs.
- See `ARCHITECTURE.md` for an overview before making changes.

## Build, Test, and Development Commands
- Root tasks: `make` runs CDKTF tests, Nomad job validation, Chef lint/spec, and selected Docker builds.
- Targeted: `make cdktf` | `make nomad` | `make chef` | `make docker`.
- CDKTF (from a stack dir): `go build`; synth/diff/deploy with `cdktf synth`, `cdktf diff`, `cdktf deploy <stack>` (e.g., `nomad`, `cf`).
- Nomad jobs QA: `make -C cdktf/munchbox-core/nomad-jobs validate` | `fmt` | `lint`.
- Chef: `bundle install` then `cookstyle`, `bundle exec rspec`, or `bundle exec rake kitchen:test`.

## Coding Style & Naming Conventions
- Go: format with `gofmt`; idiomatic names; keep `*_test.go` adjacent.
- HCL: format with `hclfmt`; job files as `*.nomad.hcl`; policies/tokens under `nomad-policy/`, `nomad-token/`, `vault-policy/`.
- Chef Ruby: follow Cookstyle defaults; keep specs under `cookbooks/*/spec`.

## Testing Guidelines
- Go: add/update unit tests under `cdktf/**` as `*_test.go`; run `go test ./...`.
- Nomad: validate every changed job with `nomad job validate` (or `make validate`).
- Chef: prefer ChefSpec (`bundle exec rspec`) and use Kitchen for integration (`bundle exec rake kitchen:test`).
- PRs should keep existing tests green and add coverage for behavior changes.

## Commit & Pull Request Guidelines
- Commits: short, present-tense subjects; include scope when helpful (e.g., `nomad:`, `chef:`, `cdktf:`). Provide a brief body for context.
- PRs: describe the what/why; list impacted paths; link issues; include screenshots/logs for operational changes. Ensure `make` passes locally.

## Security & Configuration Tips
- Do not commit secrets. Use env vars (e.g., `CLOUDFLARE_API_TOKEN`, `CONSUL_HTTP_TOKEN`) and Vault/Consul for sensitive data.
- Avoid committing local artifacts (e.g., `.kitchen/`, synthesized `cdktf.out` unless intended).
- Review `ARCHITECTURE.md` and prefer existing patterns before introducing new ones.

