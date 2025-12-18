#!/bin/bash
# -------------------------------------------------------------------------------
# Bootstrap Chef - Legacy Chef Solo Deployment
#
# Project: Munchbox / Author: Alex Freidah
#
# Deploys Chef Solo configuration to a remote node. Installs Chef omnibus and
# runs chef-solo with node-specific configuration. Deprecated in favor of Ansible.
# -------------------------------------------------------------------------------

# Legacy deployment script - use Ansible playbooks instead
if [ "$2" != "skip" ]; then
ssh afreidah@$1 "curl -L https://omnitruck.chef.io/install.sh | sudo bash"
ssh afreidah@$1 "sudo rm -rf /tmp/chef/"
fi
rsync -av chef/ afreidah@$1:/tmp/chef/
ssh afreidah@$1 "sudo chef-solo --chef-license accept -c /tmp/chef/knife.rb -j /tmp/chef/nodes/$1.json"
