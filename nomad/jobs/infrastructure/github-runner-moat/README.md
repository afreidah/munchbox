# github-runner-moat

Self-hosted GitHub Actions runners scoped to the private `moat` repo. Two
ephemeral runners on the amd64 Proxmox VMs, each registered via a
fine-grained PAT pulled from Vault. Plain Nomad job (not the
`munchbox-service` pack) -- registration env rendered inline via the task's
`template` block.

## Image

`registry.munchbox.cc/moat-runner-standard:1.0.3`

## Hostname / exposure

- Internal-only Consul service `github-runner-moat` (no Traefik, no port)
- Script check that pgreps `Runner.Listener` / `run.sh`

## Placement

- `count = 2` with `distinct_hosts = true`
- Excludes `goren` and `stabler` (arm64 Pi5s); lands on the amd64
  Proxmox `nomad-client-0X` VMs
- `node_pool = default`

## Dependencies

- Vault `secret/data/github/moat-runner` (token, repo_url, optional
  runner_group) via `nomad-workloads` role / workload identity
- Docker socket mount on the host (`/var/run/docker.sock`)
- Internal registry for the runner image

## Notable configuration

- `EPHEMERAL=true` -- each job gets a fresh runner, then exits and is replaced
- Labels: `nomad,self-hosted,linux,x64,docker,moat`
- Privileged container with hard CPU limit (6000 MHz / 2176 MiB)
- 120s kill timeout to let in-flight jobs unwind
- Token rotation: fine-grained PATs cap at 1 year; refresh in Vault before
  expiry or registration silently 401s
- Vault policy access to `secret/data/github/moat-runner` is granted via the
  `workload_secrets` list in `infrastructure/terragrunt/root.hcl`
