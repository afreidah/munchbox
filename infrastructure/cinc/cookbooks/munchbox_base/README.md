# munchbox_base

Base cookbook. Ships the OS-level prerequisites every Munchbox node depends
on, exposed as small targeted resources + per-concern recipes so consumers
cherry-pick exactly what they need.

`default.rb` is intentionally empty. Add the specific recipes to a node's run
list (or include them from a role) rather than pulling the whole cookbook.

## Resources

| Resource | Purpose |
|---|---|
| `munchbox_base_apt_repo` | Add an apt repository + signing key (idempotent) |
| `munchbox_base_packages` | Install (or remove) a set of apt packages |
| `munchbox_base_timesync` | Configure systemd-timesyncd via conf.d drop-in |
| `munchbox_base_journald` | Apply journald disk/retention limits via conf.d drop-in |
| `munchbox_base_sshd` | Apply sshd hardening via sshd_config.d drop-in |

Each resource exposes a `:configure` (default) and `:remove` action.

## Recipes

| Recipe | What it converges |
|---|---|
| `munchbox_base::default` | empty — intentional |
| `munchbox_base::apt_repo` | register the munchbox aptly repo |
| `munchbox_base::packages` | install the baseline package set |
| `munchbox_base::timesync` | configure NTP via systemd-timesyncd |
| `munchbox_base::journald` | apply journald size + retention limits |
| `munchbox_base::sshd` | apply sshd hardening drop-in |

Typical node run_list:

```
recipe[munchbox_base::apt_repo]
recipe[munchbox_base::packages]
recipe[munchbox_base::timesync]
recipe[munchbox_base::journald]
recipe[munchbox_base::sshd]
```

## Usage

```ruby
# metadata.rb of a node-level role cookbook (or via run_list)
depends 'munchbox_base'
```

Override attributes as needed:

```ruby
# in a role
default_attributes(
  'munchbox_base' => {
    'packages' => %w(vim git my-extra-tool),
    'timesync' => { 'ntp_servers' => %w(internal-ntp.munchbox.cc) },
  }
)
```

Iptables is intentionally *not* managed here — that comes later as a
per-cookbook rule contribution pattern. Otherwise a converge of any
`munchbox_base` recipe would risk clobbering service-specific rules from
other cookbooks.

## Development

All tooling comes from **cinc-workstation** (bundles chef + kitchen + inspec
+ cookstyle + chefspec). One-time host setup:

```
make tools
```

That installs cinc-workstation, libvirt/KVM/vagrant-libvirt, and the
`/usr/local/bin` wrappers that `env -i` cinc tools so RVM/rbenv/bundler env
can't pollute them.

After that:

```
make lint     # cookstyle
make test     # rspec + chefspec (unit)
make kitchen  # full test-kitchen (libvirt VM converge + inspec verify)
make verify   # rerun inspec against an already-up VM
make destroy  # tear the VM back down
```

Targets `bento/debian-12` via vagrant-libvirt to match the cookbook's
`supports`.
