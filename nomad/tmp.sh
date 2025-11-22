#!/usr/bin/env bash

jobs=( "promtail" "loki" "prometheus" "alertmanager" "grafana" )

for job in "${jobs[@]}"; do
    echo "stopping $job..."
    nomad job stop -purge $job

    echo "re-deploying $job..."
    make run JOB=$job
done
