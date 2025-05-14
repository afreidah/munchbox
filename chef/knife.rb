# local_mode true
#chef_repo_path   File.expand_path('../' , __FILE__)
cookbook_path ['/tmp/chef/cookbooks', '/tmp/chef/community-cookbooks' ]
log_level        :info
formatter        :doc


knife[:ssh_attribute] = "knife_zero.host"
knife[:use_sudo] = true
knife[:identity_file] = "~/.ssh/ed25519"
# knife[:ssh_identity_file] = '"~/.ssh/ed25519"'  # Newer than Chef 14

knife[:automatic_attribute_whitelist] = %w[
  fqdn
  os
  os_version
  hostname
  ipaddress
  roles
  recipes
  ipaddress
  platform
  platform_version
  cloud
  cloud_v2
  chef_packages
]

### Optional.
## If you use attributes from cookbooks for set credentials or dynamic values.
## This option is useful to managing node-objects which are managed under version controle systems(e.g git).
# knife[:default_attribute_whitelist] = []
# knife[:normal_attribute_whitelist] = []
# knife[:override_attribute_whitelist] = []

## Use `allowd_*` for Chef Infra Client 16.3 or later
# knife[:allowed_default_attributes] = []
# knife[:allowed_normal_attributes] = []
# knife[:allowed_override_attributes] = []
