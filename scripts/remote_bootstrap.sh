#!/usr/bin/env bash
NODE="$1"    # e.g. pi-01
json="chef/node-${NODE}.json"

rsync -az chef/ pi@"$NODE":/tmp/chef/

ssh pi@"$NODE" <<-SSH
  sudo chef-solo -c /tmp/chef/solo.rb -j /tmp/chef/${json##*/}
SSH

