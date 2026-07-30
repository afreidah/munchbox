# frozen_string_literal: true

# -------------------------------------------------------------------------------
# Cookbook:: consul
# Attributes:: default
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Binary install
#
# Pinned to the version currently running in the munchbox cluster. Bumping
# = re-upload the cookbook + every node re-converges to fetch + restart.
# -------------------------------------------------------------------------------

default[cookbook]['install'] = {
  version: '2.0.2',
  bin_path: '/usr/local/bin/consul',
  user: 'consul',
  group: 'consul',
  config_dir: '/etc/consul.d',
  data_dir: '/opt/consul/data',
  tls_dir: '/etc/consul.d/tls',
  log_dir: '/var/log/consul',
}

# -------------------------------------------------------------------------------
# Agent configuration
#
# Per-node knobs to override in the role:
#   bind_addr        -- IP this agent binds to (WG IP for oracle nodes,
#                       LAN IP for bare metal). REQUIRED.
#   server           -- true for cluster servers (goren/stabler/etc.),
#                       false for clients (default).
#   bootstrap_expect -- only meaningful when server=true.
#   retry_join       -- list of IPs to attempt joining. REQUIRED.
#   node_meta        -- optional Hash, becomes `node_meta {}` block.
#
# Everything else (datacenter, ports, TLS, ACL, telemetry) is cookbook-wide
# and matches the current cluster config on goren.
#
# TLS cert paths point at the layout vault-cert-manager already writes
# (/etc/consul.d/tls/{consul.crt, consul.key, ca-chain.crt}); this
# cookbook never touches the cert files themselves.
# -------------------------------------------------------------------------------

default[cookbook]['config'] = {
  datacenter: 'munchbox',
  primary_datacenter: nil, # set on every node once federated; nil = single-DC
  domain: 'consul',
  client_addr: '0.0.0.0',
  ui_enabled: true,
  connect_enabled: true,
  raft_multiplier: 1,

  bind_addr: nil, # required, set per-node
  advertise_addr: nil, # LAN advertise; set when bind_addr is 0.0.0.0 (multi-homed)
  server: false,
  bootstrap_expect: nil,
  retry_join: [],
  retry_join_wan: [], # server-only; secondary/primary WAN serf peers
  advertise_addr_wan: nil, # server-only; addr advertised to the WAN pool
  node_meta: {},

  ports: {
    dns: 8600,
    http: 8500,
    https: 8501,
    grpc: 8502,
    grpc_tls: 8503,
    serf_lan: 8301,
    serf_wan: 8302,
    server: 8300,
  },

  tls_enabled: true,
  tls_ca_file: '/etc/consul.d/tls/ca-chain.crt',
  tls_cert_file: '/etc/consul.d/tls/consul.crt',
  tls_key_file: '/etc/consul.d/tls/consul.key',
  tls_verify_incoming: true,
  tls_verify_outgoing: true,
  tls_verify_server_hostname: true,

  acl_enabled: true,
  acl_default_policy: 'deny',
  acl_down_policy: 'extend-cache',
  enable_token_replication: false, # secondary-DC servers opt in to pull global tokens

  telemetry_prometheus_retention_time: '30s',
  telemetry_disable_hostname: false,

  # --- gossip_lan tuning (loosened probe_timeout per GH #130 for WG-to-oracle stability). Strings: consul wants duration literals. ---
  gossip_lan_interval: '1s',
  gossip_lan_probe_timeout: '5s',
  # --- suspicion_mult raised off the upstream 4 so a transient WAN blip on an oracle node's wg path takes more missed probe rounds to be declared failed (Integer multiplier, not a duration). ---
  gossip_lan_suspicion_mult: 6,
}

# -------------------------------------------------------------------------------
# Local DNS / dnsmasq (consul::dns)
#
# Opt-in recipe. Defaults reproduce the ansible play this replaces:
# dnsmasq listens on 127.0.0.53 + the host IP, forwards .consul to the
# local consul agent, and forwards everything else to local CoreDNS
# (with Pi-hole fallback). Override per-role/per-node as needed.
#
# `host_ip` defaults to nil here -- the recipe falls back to
# node['ipaddress'] (chef's auto-detected primary IP). Set explicitly in
# a role when the primary interface isn't the right one (e.g. oracle
# nodes binding on wg1).
# -------------------------------------------------------------------------------

default[cookbook]['dns'] = {
  host_ip: nil,
  listen_address: '127.0.0.53',
  consul_dns_port: 8600,
  coredns_port: 5354,
  pihole_servers: %w(192.168.68.62 192.168.68.64),
  cache_size: 1000,
  dns_forward_max: 150,
  dnsmasq_config_path: '/etc/dnsmasq.d/consul.conf',
  resolv_conf_search: 'munchbox.cc',
  disable_systemd_resolved: true,
  disable_avahi: true,
  manage_resolv_conf: false,
  filter_aaaa: true,
}
