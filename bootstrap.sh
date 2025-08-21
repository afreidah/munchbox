#!/bin/bash

# shitty hack because I don't feel like focusning on 
# proper deployment right now
if [ "$2" != "skip" ]; then
ssh afreidah@$1 "curl -L https://omnitruck.chef.io/install.sh | sudo bash"
ssh afreidah@$1 "sudo rm -rf /tmp/chef/"
fi
rsync -av chef/ afreidah@$1:/tmp/chef/
ssh afreidah@$1 "sudo chef-solo --chef-license accept -c /tmp/chef/knife.rb -j /tmp/chef/nodes/$1.json"

# just dumping the knife-zero command here so I don't forget it
# bundle exec knife zero bootstrap 192.168.1.225 --ssh-user afreidah --node-name pi-225 -c solo.rb --json-attribute-file nodes/node-pi-225.json --sudo
