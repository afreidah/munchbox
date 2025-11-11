# -------------------------------------------------------------------------------
# Promtail — System Log Collection Agent — Nomad Pack Example
#
# Project: Munchbox
# Author: Alex Freidah
#
# System job that runs on all nodes collecting container logs from journald
# and Nomad alloc directories. Sends structured logs to Loki via push API
# for centralized log aggregation and querying.
# -------------------------------------------------------------------------------

job_name            = "promtail"
region              = "global"
datacenters         = ["pi-dc"]
node_pool           = "all"
promtail_version    = "3.3.1"
loki_address        = "http://loki.service.consul:3100"
http_port           = 9080
dns_servers         = ["192.168.68.62", "192.168.68.64"]
cpu                 = 150
memory              = 128
