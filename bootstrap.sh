#!/bin/bash

# shitty hack because I don't feel like focusning on  proper deployment right now
if [ "$2" != "skip" ]; then
ssh afreidah@$1 "curl -L https://omnitruck.chef.io/install.sh | sudo bash"
ssh afreidah@$1 "sudo rm -rf /tmp/chef/"
fi
rsync -av chef/ afreidah@$1:/tmp/chef/
ssh afreidah@$1 "sudo chef-solo --chef-license accept -c /tmp/chef/knife.rb -j /tmp/chef/nodes/$1.json"
