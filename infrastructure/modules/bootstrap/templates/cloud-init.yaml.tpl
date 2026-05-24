#cloud-config
# -----------------------------------------------------------------------------
# Munchbox Chef-Bootstrap Cloud-Init
#
# First-boot bootstrap for a chef-managed Munchbox node. Works for both
# oracle cloud nodes (need WireGuard to reach cinc-server over wg0) and
# proxmox/bare-metal nodes (already on the 192.168.68.x LAN, no WG).
# After this template runs, the node is registered with
# cinc-server.munchbox.cc and has performed its first cinc-client
# converge against its role. All subsequent config (consul, nomad,
# docker, vault-agent, etc.) lives in chef cookbooks; this template
# stops touching the node once chef takes over.
#
# WHAT THIS TEMPLATE DOES:
#   1. Optional static IP via netplan (when static_ip is set; common on
#      proxmox VMs, usually skipped on oracle where DHCP suffices).
#   2. Drop the munchbox PKI CAs so the node trusts cinc-server's TLS.
#   3. Pin /etc/hosts entries (cinc-server, anything in hosts_overrides)
#      so bootstrap doesn't depend on DNS being up.
#   4. Optionally bring up WireGuard wg0 (when bootstrap_wireguard=true;
#      needed for oracle nodes to reach 192.168.68.x, skipped for
#      proxmox/bare-metal nodes already on the LAN).
#   5. Install cinc-client via direct .deb from downloads.cinc.sh.
#   6. Drop /etc/cinc/{client.rb, validation.pem, encrypted_data_bag_secret}.
#   7. Drop /etc/cinc/first_run.json with the node's role.
#   8. Run cinc-client -j /etc/cinc/first_run.json (the rest is chef's job).
#
# PRE-PROVISION REQUIREMENTS (do these BEFORE `terragrunt apply`):
#   - Mint an AppRole secret_id for this node from
#     auth/chef-approle/role/chef-managed-node and store at
#     secret/chef-approle/secret-ids/<node>.
#   - Upload the encrypted vault_agent data-bag item:
#       infrastructure/cinc/scripts/upload-vault-agent-data-bag.sh <node>
#   - Ensure the per-node role file exists at
#     infrastructure/cinc/roles/nodes/<node>.rb AND has been uploaded
#     to cinc-server (knife role from file ...).
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

package_update: true
package_upgrade: false

packages:
  - curl
  - ca-certificates
  - gnupg
%{ if bootstrap_wireguard ~}
  - wireguard
%{ endif ~}

write_files:
  # --- munchbox root CA so apt/curl + cinc-client trust apt.munchbox.cc / cinc-server.munchbox.cc ---
  - path: /usr/local/share/ca-certificates/munchbox-root-ca.crt
    permissions: '0644'
    content: |
      ${indent(6, munchbox_root_ca)}

  - path: /usr/local/share/ca-certificates/munchbox-intermediate-ca.crt
    permissions: '0644'
    content: |
      ${indent(6, munchbox_intermediate_ca)}

  # --- /etc/hosts pin (cinc-server reachability before DNS works on a fresh node). Harmless on LAN nodes too. ---
  - path: /etc/hosts
    append: true
    content: |
      # Munchbox bootstrap host pins (cloud-init)
      %{ for hostname, ip in hosts_overrides ~}
      ${ip} ${hostname}
      %{ endfor ~}

%{ if bootstrap_wireguard ~}
  # --- WireGuard wg0 (oracle nodes only; bootstrap-time path to 192.168.68.x). chef wireguard cookbook owns wg1 later. ---
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
%{ endif ~}

  # --- cinc validator key (shared per chef-server organization; pulled from Vault by terragrunt) ---
  - path: /etc/cinc/validation.pem
    permissions: '0600'
    owner: 'root:root'
    content: |
      ${indent(6, chef_validator_key)}

  # --- shared encrypted_data_bag_secret (same on every node; pulled from Vault by terragrunt) ---
  - path: /etc/cinc/encrypted_data_bag_secret
    permissions: '0640'
    owner: 'root:root'
    content: |
      ${chef_encrypted_data_bag_secret}

  # --- cinc client.rb (matches the shape cinc_client::configure renders post-bootstrap) ---
  - path: /etc/cinc/client.rb
    permissions: '0644'
    content: |
      # Bootstrap client.rb -- cinc_client::configure replaces this on first chef run.
      chef_server_url        '${chef_server_url}'
      node_name              '${chef_node_name}'
      validation_client_name '${chef_validator_client_name}'
      validation_key         '/etc/cinc/validation.pem'
      client_key             '/etc/cinc/client.pem'
      trusted_certs_dir      '/etc/cinc/trusted_certs'
      log_level              :info
      log_location           STDOUT

  # --- First-run json picks up the per-node role; matches what knife bootstrap would inject ---
  - path: /etc/cinc/first_run.json
    permissions: '0644'
    content: |
      {
        "run_list": ["${chef_run_list}"]
      }

%{ if static_ip != "" ~}
  # --- Static IP via netplan (replaces DHCP for the primary interface) ---
  - path: /etc/netplan/00-munchbox-static.yaml
    permissions: '0600'
    content: |
      network:
        version: 2
        ethernets:
          ${network_interface}:
            dhcp4: false
            addresses:
              - ${static_ip}/${static_netmask_bits}
            routes:
              - to: default
                via: ${gateway}
            nameservers:
              addresses: [${join(", ", dns_servers)}]
%{ endif ~}

runcmd:
  # --- Update the CA trust bundle so cinc-server.munchbox.cc verifies ---
  - update-ca-certificates

%{ if static_ip != "" ~}
  # --- Apply netplan so the static IP is live before anything else tries to bind ---
  - netplan apply
  - sleep 3
%{ endif ~}

%{ if bootstrap_wireguard ~}
  # --- IP forwarding + bring WG up (oracle nodes only); required so the cinc-client pull below reaches 192.168.68.99 over wg0 ---
  - echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
  - sysctl -p
  - systemctl enable wg-quick@wg0
  - systemctl start wg-quick@wg0
  - sleep 5
%{ endif ~}

  # --- Install cinc-client from downloads.cinc.sh (mirrors cinc_client::install, no packagecloud) ---
  - 'DEB_ARCH=$(dpkg --print-architecture)'
  - 'curl -fsSL -o /var/cache/cinc.deb "https://downloads.cinc.sh/files/stable/cinc/${cinc_version}/$(. /etc/os-release; echo $ID)/$(. /etc/os-release; echo $VERSION_ID)/cinc_${cinc_version}-1_$${DEB_ARCH}.deb"'
  - dpkg -i /var/cache/cinc.deb
  - mkdir -p /etc/cinc/trusted_certs

  # --- First chef converge: registers the node, downloads its run_list, and configures everything ---
  - cinc-client -j /etc/cinc/first_run.json --no-fork

  # --- Done marker ---
  - echo "chef-bootstrap complete at $(date -u +%FT%TZ)" > /var/log/munchbox-bootstrap-complete

final_message: "Munchbox chef-bootstrap finished after $UPTIME seconds"
