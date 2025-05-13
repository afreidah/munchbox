#!/bin/bash

# rsync -av chef/ afreidah@$1:/tmp/chef/
scp -r chef/ afreidah@$1:/tmp/

ssh afreidah@$1 sudo chef-solo -c /tmp/chef/solo.rb -j /tmp/chef/node-pi-$2.json

