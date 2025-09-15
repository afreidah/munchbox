# frozen_string_literal: true

# ------------------------------------------------------------------------------
#  attributes/default.rb — k3s Firewall Defaults
#
#  Purpose:
#    Define the inbound firewall rules commonly required for a k3s control-plane
#    (single-node or seed server) on Debian/Ubuntu hosts.
#
#  Notes:
#    • kubelet (10250/tcp) is included as many operators allow control-plane access.
#    • etcd ports are commented out; enable only if running HA with embedded etcd.
#    • If you expose NodePort services, you may also need 30000–32767 (tcp/udp).
# ------------------------------------------------------------------------------

default['k3s']['firewall_rules'] = [
  # --- Core Kubernetes API (control-plane) ---
  { name: 'k3s-apiserver', port: 6443, protocol: :tcp },      # kube-apiserver

  # --- Node agent (often allowed from control-plane) ---
  { name: 'k3s-kubelet',   port: 10250, protocol: :tcp },     # kubelet

  # --- CNI overlay (flannel VXLAN default) ---
  { name: 'k3s-flannel-vxlan', port: 8472, protocol: :udp },  # flannel VXLAN

  # --- Etcd (ONLY if using HA with embedded etcd) ---
  # { name: 'k3s-etcd-client', port: 2379, protocol: :tcp },  # etcd client
  # { name: 'k3s-etcd-peer',   port: 2380, protocol: :tcp },  # etcd peer
]

# ------------------------------------------------------------------------------
#  Optional: Cluster CIDR allowances (UFW "allow from <cidr> to any")
#  - These are not "ports", but many deployments allow pod/service CIDRs explicitly.
#  - Use in your firewall recipe to create UFW rules that allow these ranges.
# ------------------------------------------------------------------------------
default['k3s']['allow_cidrs'] = [
  { name: 'k3s-pod-cidr',     cidr: '10.42.0.0/16' },  # pods
  { name: 'k3s-service-cidr', cidr: '10.43.0.0/16' },  # services
]
