# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  firewall.rb — k3s Firewall (simple/internal)
#
#  This recipe:
#    1) Includes the firewall provider
#    2) Applies k3s port rules from node attributes
#    3) (Optional) Allows cluster CIDRs to the host
#
#  Assumptions:
#    • You control the attribute values and formats.
#    • :port accepts an Integer or a String range like "30000-32767".
# ------------------------------------------------------------------------------

include_recipe 'firewall'

# ------------------------------------------------------------------------------
# Port Rules (e.g., 6443/tcp, 10250/tcp, 8472/udp)
#   Example attributes:
#     default['k3s']['firewall_rules'] = [
#       { 'name' => 'k3s-apiserver',     'port' => 6443,          'protocol' => :tcp },
#       { 'name' => 'k3s-kubelet',       'port' => 10250,         'protocol' => :tcp },
#       { 'name' => 'k3s-flannel-vxlan', 'port' => 8472,          'protocol' => :udp },
#       # { 'name' => 'k3s-nodeport',    'port' => '30000-32767', 'protocol' => :tcp }, # if needed
#     ]
# ------------------------------------------------------------------------------
Array(node['k3s']['firewall_rules']).each do |r|
  firewall_rule r['name'] do
    command  :allow
    port     r['port']                     # Integer or "start-end"
    protocol r['protocol']                 # :tcp or :udp (string also fine)
    source   r['source'] if r['source']    # optional; omit => anywhere
  end
end

# ------------------------------------------------------------------------------
# Cluster CIDRs (optional; e.g., allow Pods/Services to reach host)
#   Example attributes:
#     default['k3s']['allow_cidrs'] = [
#       { 'name' => 'k3s-pod-cidr',     'cidr' => '10.42.0.0/16' },
#       { 'name' => 'k3s-service-cidr', 'cidr' => '10.43.0.0/16' },
#     ]
# ------------------------------------------------------------------------------
Array(node['k3s']['allow_cidrs']).each do |c|
  firewall_rule c['name'] do
    command :allow
    source  c['cidr']
  end
end
