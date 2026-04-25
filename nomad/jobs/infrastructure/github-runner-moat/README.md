# GitHub Actions Runners — moat

Self-hosted GitHub Actions runners scoped to the private `moat` repo. Three
ephemeral runners on the amd64 Proxmox VMs (nomad-client-0X), each registered
via a fine-grained PAT pulled from Vault. Plain Nomad job (not the
`munchbox-service` pack) — the registration env is rendered inline via
the task's `template` block.

## Why

`moat` is private — running its CI on github.com hosted runners costs money
once free minutes are exhausted. These self-hosted runners take that pipeline
in-house. The arm64 `.deb` is still produced via goreleaser cross-compile, so
amd64 placement is sufficient.

## Prerequisites

A fine-grained PAT for the `moat` repo with **Administration: Read and write**.
The repo owner generates it (see project notes) and the token is stored at:

```
vault kv put secret/github/moat-runner \
  token='github_pat_…' \
  repo_url='https://github.com/<owner>/moat'
```

The `nomad-workloads` Vault policy is granted `read` on `secret/data/github/moat-runner`
via the `workload_secrets` list in `infrastructure/terragrunt/root.hcl`. After editing
that list, apply with `terragrunt run-all apply` from `infrastructure/terragrunt/`.

## GitHub-side repository secrets

These are configured on the **moat repo itself** (Settings → Secrets and
variables → Actions), not in Vault — they're consumed by workflow steps via
`${{ secrets.NAME }}` and are independent of the runner.

| Secret | Used by | Notes |
|---|---|---|
| `PROJECT_TOKEN` | `.github/workflows/project-sync.yml` | Classic PAT with `project` + `repo` scope, owned by whoever owns `https://github.com/users/afreidah/projects/1`. Reuse of the existing `secret/github/project-issues-pat` value is fine — just install it on the repo. |

If/when Packer, Kitchen, or Chef workflows start hitting real cloud APIs,
add their creds either as GitHub repo secrets or as additional Vault paths +
env templates wired into this job.

## Deploy

```bash
source munchbox-env.sh && cd nomad && make run JOB=github-runner-moat
```

## Workflow targeting

In `moat`'s workflows, set `runs-on` to one of the runner labels:

```yaml
runs-on: [self-hosted, linux, x64, moat]
```

## Notes

- Runs on amd64 only (`attr.cpu.arch == amd64`) — excludes goren/stabler/oracle-arm.
- `EPHEMERAL=true` — each job gets a fresh runner, then exits and is replaced.
- Docker socket is mounted; runners are `privileged` so workflow steps can
  build images and run containers.
- Token rotation: fine-grained PATs cap at 1 year; refresh in Vault before
  expiry or registration silently 401s.
