# github-runner-moat-vm

Self-hosted GitHub Actions runner for the `moat` repository, KVM
variant. Sister pool to `github-runner-moat`; identical except this
one advertises `vm,kvm,moat` labels and gets `/dev/kvm` plus
`/dev/net/tun` passed through so workflows that need real
virtualization (Packer-qemu, kitchen-vagrant, load tests) run
natively. Nested virt is already enabled on every amd64 Nomad client
at the Proxmox layer.

## Image

`registry.munchbox.cc/moat-runner-vm:1.0.3`

## Hostname / exposure

- No inbound exposure (runner outbound only)
- Service registered for visibility; tags `ci,github-actions,runner,moat,vm`

## Placement

- amd64 only -- excluded from `goren` and `stabler` (arm64 Pi5s)
- `node_pool = default`, single instance, unlimited reschedule for
  ephemeral-runner recycling

## Dependencies

- Vault path `secret/data/github/moat-runner` (`token`, `repo_url`,
  optional `runner_group`)
- Docker socket mounted (`/var/run/docker.sock`) for dind workflows
- `/dev/kvm` and `/dev/net/tun` from the host

## Notable configuration

- `privileged = true`, `cpu_hard_limit = true`
- `EPHEMERAL=true` and `DISABLE_AUTO_UPDATE=true` -- one job per
  alloc, runner self-deregisters after each run
- Labels exposed to GitHub: `nomad,self-hosted,linux,x64,docker,kvm,vm`
- Workflows opt in with `runs-on: [self-hosted, linux, x64, vm, moat]`
- 6000 MHz CPU / 4512 MiB memory reservation for the heavier KVM jobs
