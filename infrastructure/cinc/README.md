# infrastructure/cinc/

Cinc (Chef) cookbooks + roles that converge every Munchbox node. Cinc-client
runs on a systemd timer (hourly on the proxmox VMs, every 30 min on the
oracle ones) and pulls compiled cookbooks from `cinc-server.munchbox.cc`.

> **Style guide:** [STYLE_GUIDE.md](./STYLE_GUIDE.md) -- Ruby/Chef rules,
> resource/recipe layout, comment forms, testing standards. Self-contained;
> nothing else in the repo is authoritative for chef style.

---

## Layout

```
infrastructure/cinc/
+-- cookbooks/         # 17 cookbooks; one concern per cookbook
|   +-- munchbox_lib/    # Library helpers (cookbook() namespace shim, etc.)
|   +-- munchbox_base/   # OS-level baseline; runs on every node
|   +-- consul/          # Consul agent
|   +-- nomad/           # Nomad agent
|   +-- vault/           # Vault server
|   +-- vault_agent/     # Vault agent (client side, sidecars / templates)
|   +-- vault_cert_manager/
|   +-- docker/
|   +-- cni/
|   +-- wireguard/
|   +-- nfs/
|   +-- nvidia/
|   +-- oracle/          # Oracle-Linux / oracle-cloud specifics
|   +-- proxmox_host/    # Proxmox hypervisors only (cabot/fontana/mccoy/rubirosa)
|   +-- cinc_server/     # The chef-server itself
|   +-- cinc_client/     # Bootstrap of the client agent on new nodes
|
+-- roles/             # 14 shared fleet roles -- each one a stack of recipes
|   +-- base.rb
|   +-- cinc_client.rb
|   +-- consul_server.rb / consul_client.rb
|   +-- nomad_server.rb  / nomad_client.rb
|   +-- vault_server.rb  / vault_agent.rb / vault_cert_manager.rb
|   +-- proxmox_vm.rb    / proxmox_host.rb
|   +-- bare_metal_pi5.rb / oracle_node.rb
|   +-- cinc_server_host.rb
|
+-- nodes/             # Per-node chef node objects (`knife node from file`)
|                      # carry run_list + tags + per-node attribute overrides.
|                      # File name == chef-server node identity.
|
+-- scripts/           # One-shot bootstrap + ops helpers (see "Scripts" below)
```

---

## Cookbook anatomy

Every cookbook has the same shape (excluding `munchbox_lib`, which is
library-only):

```
cookbooks/<name>/
+-- metadata.rb
+-- Berksfile
+-- Berksfile.lock
+-- Makefile          # one-liner targets: lint / test / kitchen / verify
+-- kitchen.yml       # vagrant-libvirt; debian-12 by default
+-- README.md         # cookbook-specific docs (separate from this top-level)
+-- attributes/
|   +-- default.rb    # ALL defaults; never derived attributes in here
+-- recipes/
|   +-- default.rb    # ALWAYS empty header-only; opt in via the run_list
|   +-- <concern>.rb  # One sub-recipe per concern
+-- resources/        # Custom resources own the actual work
+-- templates/        # ERB only; no executable logic
+-- files/            # Static assets shipped via cookbook_file
+-- spec/
    +-- spec_helper.rb
    +-- recipes/      # ChefSpec for each non-empty recipe
    +-- resources/    # ChefSpec for each custom resource
    +-- support/      # Shared stubs (vault_fetch, stub_command, etc.)
+-- test/
    +-- integration/default/controls/    # InSpec controls (Test-Kitchen)
```

`munchbox_lib` only ships libraries (`libraries/cookbook.rb`) -- no recipes,
attributes, resources, or kitchen.

---

## How a node converges

1. **Pre-upload the node object.** `prepare-chef-bootstrap.sh <node>` uploads
   `nodes/<node>.rb` via `knife node from file`. That node object carries
   the run_list, the `tags` array, and any per-node attribute overrides.
2. **Bootstrap once.** A new VM/host runs `scripts/bootstrap-cinc-node.sh`
   (cloud-init or manual). That installs cinc-client, drops the validator
   key (fetched from Vault via the `install-data-bag-secret.sh` shape),
   and runs cinc-client. The first run authenticates with the validator
   key, fetches the pre-uploaded node object, and applies its run_list.
3. **Recipes are descriptive.** Each recipe is a one-line wrapper around a
   custom resource. The resource does the actual work.
4. **Hourly timer.** cinc-client runs via the systemd timer installed by
   `cinc_client::default`. Fleet-wide changes in fleet roles propagate
   within the timer interval; risky changes go in a per-node file first
   and roll out gradually.

---

## Patterns to know

| Pattern | Where | Why |
|---|---|---|
| `node[cookbook][...]` namespace | `attributes/default.rb` | Cookbook can be renamed in one place (metadata.rb). The `cookbook` symbol comes from the `munchbox_lib` helper. |
| `default.rb` recipe stays empty | every cookbook | Consumers cherry-pick sub-recipes; nothing forced. |
| Recipes are 1-liners | `recipes/*.rb` | Logic, control flow, multi-resource orchestration live in `resources/` only. |
| `lazy { vault_fetch(...) }` | inside recipes/resources | Vault agent token may not be present at compile time on greenfield nodes; lazy defers fetch to converge time. |
| Override attributes | role `override_attributes` / node `self.override_attrs =` | Cookbook attribute defaults written as Hash literals can't deep-merge from `default_attributes`. |
| Per-node config in node objects | `nodes/<host>.rb` | run_list + tags + per-node attrs live on the node object, not in a role wrapper. Edit + `knife node from file nodes/<host>.rb` to apply. |
| Per-node roles for risky changes | add the recipe to one `nodes/<host>.rb` first | Validate on one box; promote to the shared fleet role only after. |

---

## Common ops

From any cookbook dir:

```
make lint        # cookstyle
make test        # chefspec + rspec
make kitchen     # full test-kitchen lifecycle
make verify      # kitchen verify only (VM already up)
make destroy     # tear down the kitchen VM
```

After editing a cookbook:

```
knife cookbook upload <name>
```

After editing a role:

```
knife role from file roles/<name>.rb
```

After editing a node:

```
knife node from file nodes/<name>.rb
```

To force a converge on one node without waiting for the timer:

```
ssh root@<node> 'cinc-client'
```

---

## Scripts

Operator helpers live at `infrastructure/scripts/` (alongside fleet ops
like `cinc-client-all.sh`, `fix-vault.sh`, `fix-consul-cluster.sh`).
One-shot bootstrap + ops; not part of any cookbook.

| Script | Purpose |
|---|---|
| `bootstrap-cinc-node.sh` | Bootstrap a brand-new node onto the chef-server (validator key, first cinc-client run). |
| `prepare-chef-bootstrap.sh` | Stage the artifacts a node needs before `bootstrap-cinc-node.sh` can run. |
| `adopt-existing-node.sh` | Take over a node that was previously managed by something else. |
| `install-data-bag-secret.sh` | Drop the shared data-bag secret onto a node so encrypted bags can be read. |
| `upload-vault-agent-data-bag.sh` | Push the vault-agent config bag to the chef-server. |
| `store-validator-key-in-vault.sh` | Stash the per-org validator key in Vault for reuse. |
| `kitchen-debian.sh` | Helper used by per-cookbook `make tools` / kitchen runs. |

---

## Related

- [STYLE_GUIDE.md](./STYLE_GUIDE.md) -- chef coding conventions, comment
  rules, testing standards.
- [Top-level CLAUDE.md](../../CLAUDE.md) -- repo-wide conventions
  (commit style, secrets handling, deploy gotchas).
- [Munchbox kanban](https://github.com/users/afreidah/projects/4) -- open
  cookbook work tracked in Project #4.
