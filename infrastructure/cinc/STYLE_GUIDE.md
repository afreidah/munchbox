# infrastructure/cinc/ -- Style Guide

Authoritative for cinc/chef code in this repo. Self-contained.

The guide is broken up by file type / concern. Comment rules, naming, and
testing standards are stated next to the patterns they apply to so you can
read one section and write the right thing.

---

## 1. File header / preamble

Every Ruby file in `cookbooks/` opens the same way:

```ruby
# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: <cookbook_name>
# Resource:: <resource_name>           # or Recipe:: / Attributes:: / Library::
#
# 2-4 sentences describing what this file does, key properties or behaviours,
# and any important caveats. Stay factual -- no migration narration ("was
# previously X, now Y"), no bug history.
# -------------------------------------------------------------------------------
```

Rules:
- `# frozen_string_literal: true` is **always** the first line.
- One blank line, then the file header box.
- Header dividers are **79 `-` chars** (column-aligned with `#`).
- `Cookbook::` is mandatory. The second line is `Resource::` / `Recipe::` /
  `Attributes::` / `Library::` as appropriate.
- Description: 2-4 sentences. If it's a complex resource, also list
  properties -- see #3.
- Header purpose is "what this file IS", not "what's planned next".

**File-type minimums:**

| File | Header must say |
|---|---|
| `metadata.rb` | What the cookbook is, who runs it, what its job is |
| `recipes/default.rb` | "Intentionally empty. Consumers cherry-pick..." |
| `recipes/<name>.rb` | What this sub-recipe converges, what resource it calls |
| `resources/<name>.rb` | What the resource does + a Properties: block listing inputs |
| `attributes/default.rb` | What namespace it sets defaults under |

---

## 2. Comments -- strict binary rule

There are **two** acceptable comment shapes. No middle form.

### (a) Single-line markers

```ruby
# --- drop upstream AAAA; cluster is v4-only ---
property :filter_aaaa, [true, false], default: true
```

- One `# --- text ---` line.
- ~60 chars max content. If you can't compress to that, promote to a box (b).
- No blank line after a single-line marker.

### (b) Section box

```ruby
# -------------------------------------------------------------------------------
# Action :install  --  Drop each cert, notify a single update-ca-certificates run
# -------------------------------------------------------------------------------

action :install do
  ...
end
```

- 79-char `# ---` divider (file header) or 73-char (in-file sections).
- One blank line **after** the closing divider.
- Used for: file headers, action sections in custom resources, major
  logical chunks inside a long recipe.

### Wrong (multi-line `# foo / # bar`)

```ruby
action :configure do
  # apt_repository shells out to gpg to verify the signing key
  # and may also need https transport. Install both first.
  package %w(gnupg apt-transport-https ca-certificates)
end
```

This form is forbidden. Compress to one line, or promote to a box.

### Right

```ruby
action :configure do
  # --- apt_repository needs gpg + https transport at compile time ---
  package %w(gnupg apt-transport-https ca-certificates)
end
```

### Forbidden comment content

- Bug history (`# was broken in v0.8.1 before...`)
- Migration narration (`# was ansible, now chef`)
- Restating what the code says
- `TODO`/`FIXME` in code; open a GH issue instead

---

## 3. Custom resources (`resources/*.rb`)

This is where the actual work lives. Recipes call these resources; they
don't do work themselves.

```ruby
# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Resource:: munchbox_base_pki_trust
#
# Installs Munchbox internal-PKI CA certificates into the system trust store.
# Each cert is shipped as a cookbook_file under files/default/<name>.crt; this
# resource drops them under /usr/local/share/ca-certificates/ and runs
# `update-ca-certificates` only when a file actually changes.
#
# Properties:
#   certs - Array of cookbook_file basenames to install (.crt extension
#           preserved). Defaults to the standard Munchbox root + intermediate.
# -------------------------------------------------------------------------------

unified_mode true

provides :munchbox_base_pki_trust

property :certs, Array, default: %w(munchbox-root-ca.crt munchbox-intermediate-ca.crt)

default_action :install

# -------------------------------------------------------------------------------
# Action :install  --  Drop each cert, notify a single update-ca-certificates run
# -------------------------------------------------------------------------------

action :install do
  # --- :nothing -- only runs when at least one cookbook_file below notifies it ---
  execute 'update-ca-certificates' do
    command 'update-ca-certificates'
    action :nothing
  end

  new_resource.certs.each do |basename|
    cookbook_file "/usr/local/share/ca-certificates/#{basename}" do
      source basename
      cookbook 'munchbox_base'
      owner    'root'
      group    'root'
      mode     '0644'
      notifies :run, 'execute[update-ca-certificates]', :delayed
    end
  end
end
```

Rules:
- **`unified_mode true`** on every custom resource. No exceptions.
- **`provides :name`** matches the file name and is namespaced by convention
  to `cookbookname_concern` (e.g. `munchbox_base_pki_trust`).
- **`default_action`** explicitly set, even if it's `:install` / `:create`.
- Each action gets its own 73-char box header with a one-line summary on the
  same line as the title (`# Action :install  --  Drop each cert, notify ...`).
- **`cookbook` property is shadowed inside `cookbook_file` / `template` /
  `file` blocks.** Pre-resolve `node[cookbook][...]` at the top of the
  recipe; inside those blocks, `cookbook` is the property name.
- Notifications use the form `notifies :action, 'resource[name]', :delayed`
  (or `:immediately` only when ordering genuinely demands it).
- A bare `vault_fetch(...)` in a resource property must be wrapped in
  `lazy { }` -- otherwise it races vault-agent on greenfield nodes.
- For `/sys` or `/proc` paths: use `execute` + `not_if` reading the value,
  not the `file` resource. `file` trips on trailing-newline diffs and
  re-writes every converge.

---

## 4. Recipes (`recipes/*.rb`)

Recipes are descriptive. They list custom resources that do the work.

```ruby
# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Recipe:: pki_trust
#
# Installs the Munchbox internal-PKI CA bundle into the system trust store.
# All logic lives in the munchbox_base_pki_trust resource.
# -------------------------------------------------------------------------------

munchbox_base_pki_trust 'install Munchbox PKI CA bundle'
```

Rules:
- **`recipes/default.rb` is always empty** (header only). Consumers cherry-
  pick sub-recipes via the run list. Attribute defaults are unaffected.
- **One concern per recipe.** Recipe name = the concern (`apt_repo.rb`,
  `journald.rb`, `sshd_ca.rb`).
- **No `ruby_block`, control flow, or multi-resource orchestration in
  recipes.** If you need it, write a custom resource and call that.
- **No cross-cookbook attribute reads** in recipes or templates. If cookbook
  A needs a value from cookbook B, B's recipe sets a node attribute under
  its OWN namespace and A reads it via `node['b_cookbook'][...]`.
- Resource names should describe intent ("install Munchbox PKI CA bundle"),
  not the action ("run update-ca-certificates").

---

## 5. Attributes (`attributes/default.rb`)

```ruby
# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Attributes:: default
#
# Defaults for the wide base cookbook. Every entry is keyed under the
# cookbook's namespace via `node[cookbook]`, so renaming the cookbook is a
# one-line change in metadata.rb.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Apt packages
#
# Set installed on every Munchbox node. Keep this short -- anything specific to
# a service belongs in that service's cookbook, not here.
# -------------------------------------------------------------------------------

default[cookbook]['packages'] = %w(
  apt-transport-https
  bind9-dnsutils
  ca-certificates
  curl
  git
  gnupg
)
```

Rules:
- **All defaults go here.** No derived attributes (no `node[cookbook]['x']
  = node['something_else']`). Derived values belong in the recipe or
  resource that consumes them.
- **Use `node[cookbook]` namespacing.** `cookbook` is a symbol from the
  `munchbox_lib` helper that resolves to the current cookbook name.
- **No cross-cookbook reads.** Each cookbook owns its namespace.

### Hash literal write-vs-read mismatch

Cookstyle forbids value-aligned hash literals. **Always one space after `:`**
when writing, but **always string keys** when reading:

```ruby
# Write (in attributes/default.rb)
default[cookbook]['retry_join'] = {
  primary: '192.168.68.60',     # <-- one space after the colon
  backup: '192.168.68.61',
}

# Read (in a recipe or resource)
node[cookbook]['retry_join']['primary']    # <-- string key, NOT [:primary]
```

The hash gets converted to string keys when chef merges the attribute. Using
`[:primary]` to read returns `nil`.

### Hash literals don't deep-merge from role default_attributes

A cookbook attribute written with a Hash literal:

```ruby
default[cookbook]['nomad']['client'] = { 'meta' => { 'role' => 'worker' } }
```

cannot be deep-merged from a role's `default_attributes`. To override, EITHER
use `override_attributes` in the role, OR rewrite the cookbook attribute as
per-leaf assignments:

```ruby
default[cookbook]['nomad']['client']['meta']['role'] = 'worker'
```

---

## 6. Templates (`templates/*.erb`)

```erb
# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
# Template:: sshd-munchbox.conf.erb
#
# Hardened sshd config drop-in. Renders into /etc/ssh/sshd_config.d/.
# -------------------------------------------------------------------------------

<% @settings.each do |key, value| -%>
<%= key %> <%= value %>
<% end -%>
```

Rules:
- Same file header form as Ruby files (use `#` if the target file accepts it,
  or the target file's comment syntax wrapped in an ERB comment otherwise).
- **No logic beyond simple substitution.** No `Mixlib::ShellOut`, no
  conditional cross-cookbook reads. If the template needs computed values,
  compute them in the resource and pass via `variables(...)`.
- Variables passed in via `variables(foo: bar)` on the `template` resource;
  reference as `@foo` in the ERB.

---

## 7. Roles (`roles/*.rb`)

```ruby
# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Role:: proxmox_vm
#
# Proxmox-hosted VMs (nomad-client-01..05). NOT the hypervisors themselves
# -- those are role[proxmox_host] (cabot/fontana/mccoy/rubirosa).
# -------------------------------------------------------------------------------

name 'proxmox_vm'
description 'Proxmox-hosted nomad-client VM; runs base + cinc_client'

run_list(
  'role[base]',
  'role[cinc_client]',
  'role[vault_agent]',
  # --- SSH CA wiring; AFTER vault_agent so /run/vault-agent/token exists ---
  'recipe[munchbox_base::sshd_ca]',
  # --- Vault PKI intermediate CA -> /opt/nomad/tls + system trust ---
  'recipe[munchbox_base::vault_pki_trust]',
  'role[vault_cert_manager]',
  ...
)

# --- Shared per-fleet defaults. Per-node roles must set consul.config.bind_addr ---
default_attributes(
  consul: {
    config: {
      retry_join: ['192.168.68.60', '192.168.68.61', '192.168.68.58'],
    },
  },
  ...
)
```

Rules:
- One role file per role; file name == role name.
- **Each non-trivial entry in the run list gets a single-line `# --- ... ---`
  comment** explaining WHY ordering matters, what env vars / files are
  expected, or what assumption it relies on.
- Per-node roles live in `roles/nodes/<hostname>.rb` and ALWAYS include the
  shared fleet role first, then layer specific overrides.
- Use `default_attributes` for normal overrides. Switch to
  `override_attributes` when the cookbook attribute is a Hash literal (see #5).

---

## 8. metadata.rb

```ruby
# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: munchbox_base
#
# Project: Munchbox / Author: Alex Freidah
#
# Wide base cookbook. Runs on every node and owns OS-level prerequisites:
# packages, apt repo, time sync, journald, sshd hardening. Other cookbooks
# assume munchbox_base has already converged.
# -------------------------------------------------------------------------------

name             'munchbox_base'
maintainer       'Alex Freidah'
maintainer_email 'alex.freidah@gmail.com'
license          'MIT'
description      'OS-level prerequisites every Munchbox node needs'
version          '0.9.1'
chef_version     '>= 17'
issues_url       'https://github.com/afreidah/munchbox/issues'

depends 'munchbox_lib'
```

Rules:
- Header includes `Project: Munchbox / Author: Alex Freidah`.
- `chef_version '>= 17'` minimum.
- One `depends` per line; cookstyle enforces it.
- Version bumps are not committed in the same change that uploads to
  cinc-server (user does the upload separately).
- **No `CHANGELOG.md`** in cookbooks. Git log is authoritative for homelab
  scope.

---

## 9. Testing

Every cookbook ships:

```
spec/
+-- spec_helper.rb
+-- recipes/<recipe_name>_spec.rb     # one per non-empty recipe
+-- resources/<resource_name>_spec.rb # one per custom resource
+-- support/                          # shared stubs

test/integration/default/controls/    # InSpec for kitchen
```

### `make lint`

Cookstyle (rubocop with chef cops). **Must pass with zero offenses** before
upload. Common rules cookstyle enforces:

- No value-aligned hash literals (`key:  'value'` is wrong; `key: 'value'`
  is right).
- No unused variables.
- Frozen string literal magic comment on every file.

### `make test`

ChefSpec + RSpec.

**Setup gotchas:**

- `vault_fetch` must be stubbed via `module_eval`, not `allow_any_instance_of`.
- Every `not_if` / `only_if` shell guard needs a corresponding `stub_command`.
- `spec_helper.rb` requires the `cookbooks/` root via `two ..`s
  (`File.expand_path('../..', __dir__)`).

```ruby
# spec/support/vault.rb
Vault.module_eval do
  module_function

  def fetch(_path, _key)
    'mock-secret'
  end
end
```

### `make kitchen`

Test-Kitchen via vagrant-libvirt. Targets debian-12 by default. **Run
when**:

- The cookbook touches systemd units.
- The cookbook configures a real service that has runtime side effects
  (sshd, journald, vault-agent).
- A risky resource is added (anything that writes outside `/etc` or
  `/usr/local`).

A docker-based driver was tried and abandoned -- systemd-in-docker is too
flaky to be useful for our cookbooks.

### Idempotency

Kitchen runs with `enforce_idempotency: true`. The second converge must
report **zero updated resources**. Common breaks:

- `file` resource on `/sys` or `/proc` (use `execute` + `not_if`).
- Templates that re-render because a variable contains a random value or
  timestamp.
- Resources that don't use `:nothing` + notifications when they should.

---

## 10. Common ops

From any cookbook dir:

| Target | Effect |
|---|---|
| `make tools` | One-time host bootstrap of cinc-workstation + libvirt/vagrant. |
| `make lint` | Cookstyle. |
| `make test` | ChefSpec + RSpec. |
| `make kitchen` | Create + converge + verify + destroy. |
| `make verify` | InSpec only (VM already up). |
| `make destroy` | Tear the kitchen VM down. |
| `make login` | SSH into the running kitchen VM. |

**Never shortcut** into raw `cookstyle`, `rspec`, or `kitchen` calls. Always
go through `make` -- the Makefile wraps with the correct cinc-workstation
toolchain via `env -i` and absolute paths.

After editing a cookbook:

```
knife cookbook upload <name>
```

(User does the upload manually; do not auto-run after a commit.)

---

## 11. Secrets

- **Never bake secrets into cookbooks.** A 403 on a Vault read means the
  policy is wrong -- fix the policy in `vault-config` + terragrunt; do not
  `vault read | tee cookbook/files/...` as a workaround.
- Generated passwords / tokens go into `vault kv put secret/<...>`
  immediately with full metadata. Never echoed into chat or commit
  messages.
- Data-bag secrets are encrypted with the shared secret installed via
  `scripts/install-data-bag-secret.sh`.

---

## 12. Migration / refactor rules

- **Read live config before templating.** When a cookbook takes over a
  config file from ansible / a manual edit, the file currently on disk is
  the source of truth. Pull it, diff between peers if more than one node,
  template against THAT. Never trust the playbook that "should" have
  produced it.
- **Match existing config exactly on takeover.** Render bytes-identical to
  what's live, plus only user-approved additions. No speculative defaults.
- **Capture per-node `meta` blocks.** If you're taking over `nomad.hcl`,
  pull `client { meta { ... } }` from each node and reproduce per-host --
  losing this kills `system`-job allocs that constrain on `meta.role`.
- **Test risky recipes in one per-node role first.** Roll to the fleet
  role after one converge cycle confirms it.
- **No ansible leftovers.** When chef takes over a file, every ansible
  artifact for that file is removed in the same change. Never leave an
  ansible-rendered file in place "for now".

---

## 13. Quick reference: file checklist

When adding a new file under `cookbooks/<x>/`, verify before commit:

- [ ] `# frozen_string_literal: true` on line 1.
- [ ] Box header on line 3, including `Cookbook::` and what the file is.
- [ ] No multi-line `# foo / # bar` comments anywhere.
- [ ] No cross-cookbook attribute reads.
- [ ] If a resource: `unified_mode true`, `provides`, `default_action`,
      per-action box headers.
- [ ] If a recipe: one concern, calls custom resource(s), no logic.
- [ ] If attributes: `node[cookbook]` namespace, no derived values.
- [ ] Matching spec under `spec/`; passes `make test`.
- [ ] Matching InSpec control if the cookbook touches services
      (`test/integration/default/controls/`).
- [ ] `make lint` clean.
- [ ] If service-touching: `make kitchen` green and idempotent on second
      converge.
