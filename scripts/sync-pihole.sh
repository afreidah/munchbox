#!/usr/bin/env bash

docker run --rm --name nebula-sync -e PRIMARY="http://green|$PIHOLE_PASSWORD" -e REPLICAS="http://logan|$PIHOLE_PASSWORD" -e FULL_SYNC=true -e RUN_GRAVITY=true ghcr.io/lovelaze/nebula-sync:latest
