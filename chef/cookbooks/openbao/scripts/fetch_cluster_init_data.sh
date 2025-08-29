#!/usr/bin/env bash

# --- Fetch the cluster init data from the server ---
aws s3 cp \
  s3://openbao-cluster-kitchen/openbao/bao_cluster/init.json \
  - \
  --region us-west-2
