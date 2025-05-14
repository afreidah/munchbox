#!/bin/bash

# shitty hack because I don't feel like focusning on 
# proper deployment right now
ssh afreidah@$1 "sudo rm -rf /tmp/chef/"
rsync -av chef/ afreidah@$1:/tmp/chef/
ssh afreidah@$1 sudo chef-solo -c /tmp/chef/knife.rb -j /tmp/chef/nodes/node-pi-$2.json

# just dumping the knife-zero command here so I don't forget it
# bundle exec knife zero bootstrap 192.168.1.225 --ssh-user afreidah --node-name pi-225 -c solo.rb --json-attribute-file nodes/node-pi-225.json --sudo
