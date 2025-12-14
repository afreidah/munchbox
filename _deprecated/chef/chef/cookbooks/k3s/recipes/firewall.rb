# frozen_string_literal: true

# -------------------------------------------------------------------------------
# K3s Cookbook - Firewall Recipe
#
# Project: Munchbox / Author: Alex Freidah
#
# Configures k3s firewall rules. Includes the firewall provider, applies k3s
# port rules from node attributes, and optionally allows cluster CIDRs.
# -------------------------------------------------------------------------------

include_recipe 'firewall'

# --- Port Rules (e.g., 6443/tcp, 10250/tcp, 8472/udp) ---
Array(node['k3s']['firewall_rules']).each do |r|
  firewall_rule r['name'] do
    command  :allow
    port     r['port']                     # Integer or "start-end"
    protocol r['protocol']                 # :tcp or :udp (string also fine)
    source   r['source'] if r['source']    # optional; omit => anywhere
  end
end

# --- Cluster CIDRs (optional; allow Pods/Services to reach host) ---
Array(node['k3s']['allow_cidrs']).each do |c|
  firewall_rule c['name'] do
    command :allow
    source  c['cidr']
  end
end
