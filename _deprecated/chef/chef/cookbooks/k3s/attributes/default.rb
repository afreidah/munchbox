# frozen_string_literal: true

# -------------------------------------------------------------------------------
# K3s Cookbook - Default Attributes
#
# Project: Munchbox / Author: Alex Freidah
#
# Default attributes for k3s installation. Defines inbound firewall rules for
# k3s control-plane and cluster CIDRs for pod/service networking.
# -------------------------------------------------------------------------------

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

# --- Cluster CIDR allowances (UFW "allow from <cidr> to any") ---
default['k3s']['allow_cidrs'] = [
  { name: 'k3s-pod-cidr',     cidr: '10.42.0.0/16' },  # pods
  { name: 'k3s-service-cidr', cidr: '10.43.0.0/16' },  # services
]

# Owner of kubeconfig
default['k3s']['user'] = 'root'  # e.g., 'root' or 'debian'

# Paths derived from user
default['k3s']['home']        = node['k3s']['user'] == 'root' ? '/root' : "/home/#{node['k3s']['user']}"
default['k3s']['kube_dir']    = ::File.join(node['k3s']['home'], '.kube')
default['k3s']['kube_config'] = ::File.join(node['k3s']['kube_dir'], 'config')
default['k3s']['server_kube'] = '/etc/rancher/k3s/k3s.yaml'

# Installer options (nil -> upstream defaults)
default['k3s']['install_exec'] = 'server'   # passed to INSTALL_K3S_EXEC
default['k3s']['version']      = nil        # e.g., 'v1.30.4+k3s1'
default['k3s']['channel']      = nil        # e.g., 'stable' or 'latest'

# Minimal prerequisites for the install script
default['k3s']['install_packages'] = %w[curl ca-certificates]
