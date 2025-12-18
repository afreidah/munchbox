#cloud-config
# -----------------------------------------------------------------------------
# Munchbox Node Bootstrap - Cloud-Init Template
#
# Bootstraps a cloud node to join the Munchbox homelab cluster:
# - Configures WireGuard VPN back to homelab
# - Installs and configures Nomad client
# - Installs and configures Consul client
# - Installs Docker for container workloads
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

package_update: true
package_upgrade: true

packages:
  - wireguard
  - curl
  - gnupg
  - ca-certificates
  - jq
  - unzip

# Write configuration files
write_files:
  # WireGuard configuration
  - path: /etc/wireguard/wg0.conf
    permissions: '0600'
    content: |
      [Interface]
      PrivateKey = ${wireguard_private_key}
      Address = ${wireguard_address}/24

      [Peer]
      PublicKey = ${wireguard_server_public_key}
      Endpoint = ${wireguard_endpoint}
      AllowedIPs = ${wireguard_allowed_ips}
      PersistentKeepalive = 25

  # Consul configuration
  - path: /etc/consul.d/consul.hcl
    permissions: '0644'
    content: |
      datacenter = "${datacenter}"
      data_dir = "/opt/consul"
      log_level = "INFO"

      bind_addr = "{{ GetInterfaceIP \"wg0\" }}"
      advertise_addr = "{{ GetInterfaceIP \"wg0\" }}"

      retry_join = [${consul_retry_join}]

      # Client mode
      server = false

      # Enable service mesh
      connect {
        enabled = true
      }

      ports {
        grpc = 8502
      }

  # Nomad configuration
  - path: /etc/nomad.d/nomad.hcl
    permissions: '0644'
    content: |
      datacenter = "${datacenter}"
      data_dir = "/opt/nomad"
      log_level = "INFO"

      bind_addr = "{{ GetInterfaceIP \"wg0\" }}"
      advertise {
        http = "{{ GetInterfaceIP \"wg0\" }}"
        rpc  = "{{ GetInterfaceIP \"wg0\" }}"
        serf = "{{ GetInterfaceIP \"wg0\" }}"
      }

      # Client mode
      client {
        enabled = true

        servers = [${nomad_servers}]

        node_class = "${node_class}"

        %{ if node_pool != "" ~}
        node_pool = "${node_pool}"
        %{ endif ~}

        meta {
          provider = "${provider_type}"
          %{ for key, value in node_meta ~}
          ${key} = "${value}"
          %{ endfor ~}
        }

        host_volume "docker-sock" {
          path      = "/var/run/docker.sock"
          read_only = true
        }
      }

      plugin "docker" {
        config {
          allow_privileged = ${allow_privileged_docker}
          volumes {
            enabled = true
          }
        }
      }

      %{ if consul_integration ~}
      consul {
        address = "127.0.0.1:8500"
      }
      %{ endif ~}

  # Docker daemon configuration
  - path: /etc/docker/daemon.json
    permissions: '0644'
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        },
        "storage-driver": "overlay2"
      }

runcmd:
  # Enable IP forwarding for WireGuard
  - echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
  - sysctl -p

  # Start WireGuard
  - systemctl enable wg-quick@wg0
  - systemctl start wg-quick@wg0

  # Wait for WireGuard to establish
  - sleep 5

  # Configure iptables to allow traffic from WireGuard and homelab networks
  # Insert rules BEFORE the default REJECT rule
  # Allow all traffic from WireGuard interface
  - iptables -I INPUT 5 -i wg0 -j ACCEPT
  # Allow high ports for Nomad dynamic port allocation (20000-32000)
  - iptables -I INPUT 5 -p tcp --dport 20000:32000 -j ACCEPT
  - iptables -I INPUT 5 -p udp --dport 20000:32000 -j ACCEPT
  # Allow common service ports (8000-9999)
  - iptables -I INPUT 5 -p tcp --dport 8000:9999 -j ACCEPT
  # Allow Nomad/Consul ports
  - iptables -I INPUT 5 -p tcp --dport 4646:4648 -j ACCEPT
  - iptables -I INPUT 5 -p tcp --dport 8300:8600 -j ACCEPT
  - iptables -I INPUT 5 -p udp --dport 8301:8302 -j ACCEPT
  - iptables -I INPUT 5 -p udp --dport 8600 -j ACCEPT
  # Save iptables rules to persist across reboots
  - apt-get install -y iptables-persistent
  - netfilter-persistent save

  # Install Docker
  - curl -fsSL https://get.docker.com | sh
  - systemctl enable docker
  - systemctl start docker
  %{ if docker_user != "" ~}
  - usermod -aG docker ${docker_user}
  %{ endif ~}

  # Install HashiCorp repository
  - curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  - echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  - apt-get update

  # Install Consul
  - apt-get install -y consul=${consul_version}-1
  - mkdir -p /opt/consul
  - chown consul:consul /opt/consul
  - systemctl enable consul
  - systemctl start consul

  # Install Nomad
  - apt-get install -y nomad=${nomad_version}-1
  - mkdir -p /opt/nomad
  - chown nomad:nomad /opt/nomad
  - systemctl enable nomad
  - systemctl start nomad

  # Signal completion
  - echo "Bootstrap complete" > /var/log/bootstrap-complete

final_message: "Munchbox node bootstrap completed after $UPTIME seconds"
