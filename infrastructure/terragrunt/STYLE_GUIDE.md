# infrastructure/terragrunt/ -- Style Guide

Authoritative for terraform + terragrunt code in this repo. Self-contained.

Organized by file type / concern. Comment rules, naming, and testing
standards are stated next to the patterns they apply to.

---

## 1. File header / preamble

Every `.tf` and `.hcl` file opens with a box header:

```hcl
# -----------------------------------------------------------------------------
# <COMPONENT> <ROLE>
# -----------------------------------------------------------------------------
#
# 2-4 sentences describing what this file owns, key inputs/outputs, and any
# important caveats. Stay factual -- no migration narration, no bug history.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------
```

### Header brevity scales with file complexity

The form above is the **ceiling**, not the floor. Simple files get a
title-only banner:

| File | Header form |
|---|---|
| `versions.tf` | Title only -- `# X Module Version Requirements` |
| `Makefile` (one-liner) | Title only |
| `providers.tf` | Title only |
| `outputs.tf` (small) | Title only |
| `main.tf` | Full form (title + Author/Project + 2-4 sentence description) |
| Complex `outputs.tf` | Full form |
| Module `variables.tf` | Title only is fine unless there's real grouping logic to explain |
| `_env_helpers/<x>.hcl` (non-trivial) | Full form |
| `_env_helpers/<x>.hcl` (thin pass-through) | Title only is acceptable |
| `global/<leaf>/terragrunt.hcl` | **Always at minimum a title-only banner**, even though the body is two includes |

Rules:
- Divider is **79 `#-` chars**.
- `Author: Alex Freidah / Project: Munchbox` appears once per file in the
  full header form.
- Header purpose is "what this file IS", not "what was here before".

---

## 2. Comments -- strict binary rule

Same as the chef cookbooks. **Two acceptable shapes; no middle form.**

### (a) Single-line markers

```hcl
# --- configuration_aliases lets the parent leaf wire its own providers ---
configuration_aliases = [pihole.primary, pihole.secondary]
```

- `# --- text ---` form.
- ~60 chars max. Promote to a box if longer.
- No blank line after.

### (b) Section box

```hcl
# -----------------------------------------------------------------------------
# DNS A RECORDS - PRIMARY (green)
# -----------------------------------------------------------------------------

resource "pihole_dns_record" "primary" {
  ...
}
```

- 79-char divider for file-level / major sections.
- 73-char divider for in-file logical chunks.
- One blank line **after** the closing divider.

### Wrong (multi-line `#` form)

```hcl
# Account-scoped rulesets require Account:Account Rulesets:Edit on the
# CLOUDFLARE_API_TOKEN, which the current token lacks. Refresh fails
# with Authentication error (10000) and blocks every plan. Empty map
# disables Terraform management until the token scope is widened.
rate_limiting_rulesets = {}
```

### Right (compress)

```hcl
# --- disabled: CF token lacks Account:Rulesets:Edit ---
rate_limiting_rulesets = {}
```

Or, if it genuinely needs more space, promote to a box.

### Forbidden content

- Migration narration (`# was ansible, now terragrunt`)
- Bug history (`# was broken in 1.5.4, see commit abc123`)
- Restating what the code says
- `TODO`/`FIXME`; open a GH issue instead

---

## 3. Leaves (`global/<x>/terragrunt.hcl` and friends)

The strict rule: **a leaf is exactly two `include` blocks plus a header.**
Nothing else.

```hcl
# -----------------------------------------------------------------------------
# PI-HOLE CONFIG LEAF
# -----------------------------------------------------------------------------

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "pihole-config" {
  path   = "${get_repo_root()}/infrastructure/terragrunt/_env_helpers/pihole-config.hcl"
  expose = true
}
```

If you want to add `dependency {}`, `locals {}`, `inputs {}`, or
`generate {}` to a leaf -- **all of it belongs in the env_helper**. No
exceptions.

For per-host fan-out (e.g. `global/pihole-consul/{green,logan}/`), the
leaf is still two includes -- the env_helper does the path-keyed lookup.

---

## 4. env_helpers (`_env_helpers/<module>.hcl`)

**One env_helper per module.** The env_helper bridges `root.hcl` locals
and `get_env()` calls to the module's `inputs`.

### Thin pass-through (one leaf, no logic)

```hcl
# -----------------------------------------------------------------------------
# PI-HOLE CONFIG ENV HELPER
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules//pihole-config"
}

locals {
  root = read_terragrunt_config(find_in_parent_folders("root.hcl"))
}

inputs = {
  pihole_primary_url        = local.root.locals.pihole_primary_url
  pihole_password_primary   = get_env("TF_VAR_pihole_password_primary", "")
  max_db_days               = 7
  db_interval               = 600
}
```

### Path-keyed (one helper, multiple leaves)

When multiple leaves share the same module with different inputs, the
env_helper switches on `basename(get_terragrunt_dir())` and looks up the
per-leaf slice in a `root.hcl` map:

```hcl
locals {
  root      = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  leaf_name = basename(get_terragrunt_dir())
  config    = local.root.locals.remote_files_configs[local.leaf_name]
}

inputs = {
  targets = local.config.targets
  bundles = local.config.bundles
}
```

The leaf dir name is the routing key. Per-leaf config goes into a path-
keyed map in `root.hcl` (e.g. `remote_files_configs`,
`block_volume_oci_configs`).

### Inline switches inside an env_helper

If the module serves shapes that diverge (e.g. some leaves ship static
files, others ship templated files), the env_helper does the divergence
with `local.is_<flavor>` flags and ternary expressions for inputs.
**Don't spawn a sibling helper** -- keep one env_helper per module, with
documented branches inside.

### Generate blocks

If a module is called with `count` from a parent module, those child
modules **cannot** have their own `provider {}` blocks. Move the providers
up to the env_helper via `generate "providers"`. See `_env_helpers/
bootstrap.hcl` and `_env_helpers/networking-oci.hcl` for canonical
examples.

### Dependency mocks

```hcl
dependency "network_source" {
  config_path = "..."

  mock_outputs = {
    subnet_id         = "mock-subnet-id"
    security_group_id = "mock-security-group-id"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}
```

**Always** include `init` and `plan` (not just `validate`) in the allow
list. Init alone needs mocks to bootstrap when the dependency hasn't been
applied yet.

---

## 5. Modules (`modules/<name>/`)

### versions.tf

Declare only the providers the module **actually uses**.

```hcl
# -----------------------------------------------------------------------------
# PIHOLE-CONFIG Module Version Requirements
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    pihole = {
      source  = "dklesev/pihole"
      version = "~> 1.0"
    }
  }
}
```

Rules:
- `required_version = ">= 1.5"` minimum.
- One provider per entry; no padding-align of `=` columns.
- **Don't declare third-party providers the module doesn't reference.**
  Issue #122 captures the historical "every module declared every
  provider" antipattern.

### providers.tf

Used when the module needs auth wiring or provider aliases. Empty stubs
like `provider "null" {}` are NOT needed for hashicorp/* providers.

```hcl
# -----------------------------------------------------------------------------
# PIHOLE-DNS MODULE - PROVIDER CONFIG
# -----------------------------------------------------------------------------

provider "pihole" {
  alias    = "primary"
  url      = var.pihole_primary_url
  password = var.pihole_password_primary
}

provider "pihole" {
  alias    = "secondary"
  url      = var.pihole_secondary_url
  password = var.pihole_password_secondary
}
```

Rules:
- Auth comes from `var.*`, never `get_env()` (which is terragrunt-only).
- Aliases used to fan out across instances (primary/secondary, dev/prod).
- `default_tags` blocks go here, not in root.hcl.

### variables.tf

```hcl
variable "pihole_password_primary" {
  description = "Primary Pi-hole password; sourced from TF_VAR_pihole_password_primary."
  type        = string
  sensitive   = true
}

variable "dns_records" {
  description = "Map of DNS A records to create"
  type = map(object({
    domain = string
    ip     = string
  }))
  default = {}
}
```

Rules:
- `description` is mandatory.
- Mark secrets with `sensitive = true`.
- Use complex `type` definitions (`map(object({...}))`) instead of
  `map(any)` -- the type system is the documentation.
- Defaults only when there's a sane fleet-wide value; secrets and
  per-leaf knobs have no default.
- Validation blocks for fields with constrained values:
  ```hcl
  validation {
    condition     = contains(["standard", "vault", "cold", "smart"], var.storage_class)
    error_message = "Storage class must be standard, vault, cold, or smart."
  }
  ```

### main.tf

Box headers per logical resource group. `for_each` over input maps for
fan-out; `count = X ? 1 : 0` for optional resources.

```hcl
# -----------------------------------------------------------------------------
# DNS A RECORDS - PRIMARY (green)
# -----------------------------------------------------------------------------

resource "pihole_dns_record" "primary" {
  provider = pihole.primary
  for_each = var.dns_records

  domain = each.value.domain
  ip     = each.value.ip
}
```

Rules:
- One section per resource type / per-provider-alias pair.
- Prefer `for_each` over `count`. `for_each` keys stay stable through
  list reorderings; `count` indexes do not.
- Use explicit `provider = X.alias` on every resource that uses an
  aliased provider (terraform's inference is unreliable).
- `depends_on` is a last resort. If you find yourself adding it, ask
  whether the resource graph is wrong.

### outputs.tf

```hcl
output "dns_records" {
  description = "Map of DNS records created on the primary Pi-hole."
  value       = { for k, r in pihole_dns_record.primary : k => r.id }
}
```

Rules:
- `description` mandatory.
- Mark sensitive outputs (`sensitive = true`).
- Outputs are an API. Only expose what other leaves/modules need.

### Makefile

One-liner. Period.

```makefile
include ../_common.mk
```

`_common.mk` provides every target. Adding module-specific targets is
forbidden -- extend `_common.mk` instead.

---

## 6. root.hcl

The single source of truth for cross-leaf config.

Sections (preserve this order):

1. **Path parsing** -- `node_name`, `provider_type` from
   `get_original_terragrunt_dir()`. env_helpers key off these.
2. **Environment config** -- defaults read from optional `env.yaml`.
3. **Cluster + WireGuard + SSH** -- shared topology.
4. **Provider-specific defaults** -- `aws_defaults`, `oci_defaults`, etc.
5. **`proxmox_vm_groups`** -- VM source of truth, keyed by terragrunt dir.
6. **Per-leaf path-keyed maps** -- `remote_files_configs`,
   `block_volume_oci_configs`, etc.
7. **`remote_state`** -- Consul backend.
8. **`generate` blocks** -- checkov_config, trivy_ignore, providers (if
   re-enabled).

Rules:
- Box-section header before each numbered section above. 79-char dividers.
- Single-line `# --- ... ---` comments inline to explain non-obvious
  values.
- No derived locals that compute against other locals beyond simple
  string interpolation. If logic is needed, push it into an env_helper.
- Path-keyed maps use the leaf dir name as the key. The convention is
  hyphenated lowercase matching the actual dir name.

---

## 7. Secrets

- **Never commit secrets.** All secret values come from `get_env(...)` in
  env_helpers (sourced from `munchbox-env.sh` which reads Vault).
- **Always run `source munchbox-env.sh` first.** If a `TF_VAR_*` env var
  is empty, the provider will silently auth-fail rather than error
  cleanly (see issue trackers re: dklesev pihole). Verify with
  `env | grep TF_VAR_` after sourcing.
- Variable declarations get `sensitive = true` and a description that
  states the env var source: `"sourced from TF_VAR_X via env_helper"`.
- Generated passwords / tokens go into `vault kv put secret/<...>`
  immediately; never echoed into chat or commit messages.

---

## 8. Testing

Every module ships `tests/default.tftest.hcl`.

### File shape

```hcl
# -----------------------------------------------------------------------------
# pihole-dns module tests (plan-only)
#
# Project: Munchbox / Author: Alex Freidah
#
# Asserts the dual-provider fan-out: each DNS / CNAME record renders once on
# the primary Pi-hole and once on the secondary, ...
# -----------------------------------------------------------------------------

mock_provider "pihole" {
  alias = "primary"
}

mock_provider "pihole" {
  alias = "secondary"
}

variables {
  pihole_primary_url      = "http://mock-primary.test"
  pihole_password_primary = "mock-primary-pass"
  dns_records = {
    "alpha" = { domain = "alpha.test.cc", ip = "10.0.0.10" }
  }
}

# -------------------------------------------------------------------------
# DNS A records render on BOTH primary and secondary providers
# -------------------------------------------------------------------------

run "dns_records_dual_render" {
  command = plan

  # --- primary instance gets one record per input ---
  assert {
    condition     = length(pihole_dns_record.primary) == 2
    error_message = "two dns_records -> two primary A records"
  }
}
```

### Rules

- **`command = plan` always.** Never `apply`. Mocks can't fulfill
  apply-time computed values; tests that need them must be dropped.
- One `mock_provider` per provider the module references, including
  every alias.
- `variables {}` block at the top sets defaults; per-`run` blocks
  override.
- **Run blocks**:
  - Box header (`# ---` 73-char divider above, `---` divider below)
    stating what the run asserts in one sentence.
  - One concern per run block. Multiple concerns means multiple runs.
- **Asserts**:
  - Each `assert {}` gets a single-line `# --- ... ---` above it
    describing what's being checked.
  - `error_message` is human-readable; "two dns_records -> two primary
    A records" is right; "assertion failed" is wrong.
- **Edge cases as their own run**: empty maps, single entry, missing
  optional input.

### `make verify`

The standard gate. `fmt` + `validate` + `lint` (tflint) + `test`. Must
pass before any commit. `trivy` and `checkov` are plan-time hooks; run
ad-hoc.

---

## 9. Common ops

### From a leaf dir

```bash
source munchbox-env.sh        # ALWAYS first
terragrunt init               # cached unless backend changed
terragrunt init -reconfigure  # backend config changed
terragrunt plan
terragrunt apply
terragrunt destroy            # only when the env_helper guards missing inputs
```

### From a module dir

```bash
make verify        # standard gate: fmt + validate + lint + test
make test          # terraform test only
make trivy         # ad-hoc IaC misconfig scan
make checkov       # ad-hoc policy/compliance scan
make clean         # rm .terraform/ + lockfile
```

### State surgery

```bash
terragrunt state mv <old> <new>
terragrunt state rm '<resource>.<name>'
terragrunt state replace-provider <old/provider> <new/provider>
terragrunt import '<resource>.<name>' '<id>'
```

State migrations belong in their own PR if possible. Include the
commands in the PR description so reviewers can verify locally.

---

## 10. Migration / refactor rules

- **Match live config exactly on takeover.** Before terraform takes over
  a resource that already exists (DNS records, provider settings,
  whatever), pull the current values. Render bytes-identical to live,
  plus only user-approved changes.
- **Drop empty `provider "X" {}` blocks** in child modules called with
  `count`. Terraform's "legacy module" rule fires; move the provider
  config up to the env_helper via `generate "providers"`.
- **Eviction-on-rename**. Removing a `_env_helpers/<x>.hcl` entry or a
  `remote_files_configs[<key>]` entry breaks `terragrunt init` for
  existing leaves with that path. Use `try(...)` guards in env_helpers so
  destroy of orphaned leaves still works.
- **No state migration without testing**. State `mv` / `import` / `rm`
  operations get tested in a scratch workspace or with a state backup
  before running against real state.

---

## 11. Quick reference: file checklist

When adding a new `.tf` / `.hcl` file, verify before commit:

- [ ] Header banner matches file complexity (title-only for simple,
      full form for `main.tf`).
- [ ] No multi-line `# foo / # bar` comments anywhere.
- [ ] If `versions.tf`: declares only providers the module actually uses.
- [ ] If `providers.tf`: auth from `var.*`, not `get_env()`.
- [ ] If `variables.tf`: `description` mandatory, secrets marked
      `sensitive = true`.
- [ ] If `main.tf`: box sections per resource group; explicit `provider
      = X.alias` on aliased resources.
- [ ] If a leaf: exactly two `include` blocks, nothing else.
- [ ] If an env_helper: one helper per module, branches for shape
      variations (don't spawn siblings).
- [ ] If `tests/default.tftest.hcl`: `command = plan`, mock_provider for
      every alias, box headers per `run`, single-line comments per
      `assert`.
- [ ] `make verify` clean from the module dir.
- [ ] `terragrunt plan` clean from the leaf dir.
