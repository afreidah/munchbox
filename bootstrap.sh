#!/bin/bash

ssh afreidah@$1 "sudo rm -rf /tmp/chef/"
rsync -av chef/ afreidah@$1:/tmp/chef/

ssh afreidah@$1 sudo chef-solo -c /tmp/chef/solo.rb -j /tmp/chef/node-pi-$2.json

