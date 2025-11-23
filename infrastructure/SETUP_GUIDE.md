# Munchbox Infrastructure Setup - Proxmox ISO Method

## Overview

This guide walks you through setting up your Munchbox infrastructure assuming:
- **Proxmox VE installed from ISO** on cabot, mccoy, fontana
- **Debian 12 (Bookworm) VMs** for Nomad cluster
- **Terraform** for VM provisioning
- **Ansible** for configuration management

**Total Time:** ~30-40 minutes from installed Proxmox to running Nomad cluster

## Prerequisites

✅ Proxmox VE installed from ISO on all three nodes  
✅ Proxmox nodes: cabot (192.168.68.59), mccoy (192.168.68.63), fontana (192.168.68.65)  
✅ DNS servers: green (192.168.68.62), logan (192.168.68.64)  
✅ Terraform and Ansible installed on your workstation  
✅ SSH key at `~/.ssh/id_ed25519`

## Phase 1: Proxmox Cluster Formation (10 min)

### 1.1 Form Proxmox Cluster

SSH to fontana (master):
```bash
ssh root@192.168.68.65

# Create cluster
pvecm create munchbox

# Verify
pvecm status
```

### 1.2 Join Other Nodes

SSH to cabot:
```bash
ssh root@192.168.68.59
pvecm add 192.168.68.65
```

SSH to mccoy:
```bash
ssh root@192.168.68.63
pvecm add 192.168.68.65
```

Verify from any node:
```bash
pvecm nodes
# Should show all 3 nodes
```

### 1.3 Initialize Ceph (from fontana)

```bash
ssh root@192.168.68.65

# Install Ceph packages
pveceph install

# Initialize Ceph
pveceph init --network 192.168.68.0/24

# Create monitors on each node
pveceph mon create

# On cabot and mccoy, also create monitors
ssh root@192.168.68.59 pveceph mon create
ssh root@192.168.68.63 pveceph mon create

# Create OSDs (replace with your actual disk IDs)
# List available disks:
lsblk

# Create OSDs on unused disks (example - adjust for your hardware):
pveceph osd create /dev/sdb
ssh root@192.168.68.59 pveceph osd create /dev/sdb
ssh root@192.168.68.63 pveceph osd create /dev/sdb

# Create RBD pool
pveceph pool create ceph-rbd --size 2 --min_size 1 --application rbd

# Add to Proxmox storage
pvesm add rbd ceph-rbd --pool ceph-rbd --content rootdir,images

# Verify Ceph health
ceph -s
# Should show HEALTH_OK
```

## Phase 2: Create Debian Cloud-Init Template (15 min)

### 2.1 Download Debian Cloud Image

```bash
ssh root@192.168.68.65

cd /var/lib/vz/template/iso/
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
```

### 2.2 Create VM Template

```bash
# Create VM
qm create 9000 --name debian-12-cloudinit --memory 2048 --net0 virtio,bridge=vmbr0 --cores 2

# Import disk to Ceph
qm importdisk 9000 /var/lib/vz/template/iso/debian-12-generic-amd64.qcow2 ceph-rbd

# Attach disk
qm set 9000 --scsihw virtio-scsi-pci --scsi0 ceph-rbd:vm-9000-disk-0

# Add cloud-init drive
qm set 9000 --ide2 ceph-rbd:cloudinit

# Set boot order
qm set 9000 --boot c --bootdisk scsi0

# Add serial console
qm set 9000 --serial0 socket --vga serial0

# Enable QEMU guest agent
qm set 9000 --agent enabled=1

# Convert to template
qm template 9000
```

### 2.3 Create Cloud-Init Snippets Directory

```bash
mkdir -p /var/lib/vz/snippets
```

### 2.4 Create Server Cloud-Init Snippet

```bash
cat > /var/lib/vz/snippets/cloud-init-nomad-server.yml << 'EOF'
#cloud-config
users:
  - name: ansible
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    lock_passwd: false
    ssh_authorized_keys:
      - YOUR_SSH_PUBLIC_KEY_HERE

packages:
  - qemu-guest-agent
  - python3
  - curl
  - wget
  - vim
  - git

package_update: true

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - timedatectl set-timezone America/Los_Angeles
EOF

# Replace YOUR_SSH_PUBLIC_KEY_HERE with your actual key
vim /var/lib/vz/snippets/cloud-init-nomad-server.yml
```

### 2.5 Create Client Cloud-Init Snippet

```bash
cat > /var/lib/vz/snippets/cloud-init-nomad-client.yml << 'EOF'
#cloud-config
users:
  - name: ansible
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    lock_passwd: false
    ssh_authorized_keys:
      - YOUR_SSH_PUBLIC_KEY_HERE

packages:
  - qemu-guest-agent
  - python3
  - curl
  - wget
  - vim
  - git
  - apt-transport-https
  - ca-certificates
  - gnupg

package_update: true

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - timedatectl set-timezone America/Los_Angeles
  - curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ansible
EOF

# Replace YOUR_SSH_PUBLIC_KEY_HERE with your actual key
vim /var/lib/vz/snippets/cloud-init-nomad-client.yml
```

## Phase 3: Terraform VM Provisioning (5 min)

### 3.1 Create Proxmox API Token

```bash
ssh root@192.168.68.65

# Create user
pveum user add terraform@pam

# Create token
pveum user token add terraform@pam terraform --privsep 0

# Grant permissions
pveum aclmod / -user terraform@pam -role Administrator
```

Save the token ID and secret!

### 3.2 Download Infrastructure Files

Extract the terraform files from the archive (download separately).

### 3.3 Configure Terraform

```bash
cd terraform/proxmox
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

Update with:
- Your Proxmox API token
- Your SSH public key
- Template name: `debian-12-cloudinit`

### 3.4 Provision VMs

```bash
terraform init
terraform plan
terraform apply

# Wait ~2 minutes for cloud-init to complete
sleep 120

# Generate Ansible inventory
terraform output -raw ansible_inventory > ../../ansible/inventory/nomad-cluster.ini
```

## Phase 4: Ansible Configuration (10 min)

### 4.1 Verify Connectivity

```bash
cd ../../ansible
ansible all -i inventory/nomad-cluster.ini -m ping
```

### 4.2 Deploy Nomad Cluster

```bash
ansible-playbook -i inventory/nomad-cluster.ini playbooks/nomad-cluster.yml
```

This will:
- Install Consul on all nodes
- Install Nomad on all nodes
- Configure Consul Connect service mesh
- Start all services

### 4.3 Verify Cluster

SSH to a server:
```bash
ssh ansible@192.168.68.70

# Check Consul
consul members

# Check Nomad servers
nomad server members

# Check Nomad clients
nomad node status
```

## Phase 5: Access Services

Open in browser:
- **Nomad UI**: http://192.168.68.70:4646
- **Consul UI**: http://192.168.68.70:8500
- **Proxmox UI**: https://192.168.68.65:8006

## Deploy Your First Job

```bash
ssh ansible@192.168.68.70

cat > nginx.nomad <<'EOF'
job "nginx" {
  datacenters = ["munchbox"]
  type = "service"
  
  group "web" {
    count = 2
    
    network {
      mode = "bridge"
      port "http" { to = 80 }
    }
    
    service {
      name = "nginx"
      port = "http"
      
      connect {
        sidecar_service {}
      }
    }
    
    task "server" {
      driver = "docker"
      
      config {
        image = "nginx:alpine"
      }
      
      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
EOF

nomad job run nginx.nomad
nomad job status nginx
```

## Troubleshooting

### VMs Don't Boot
```bash
# Check cloud-init logs
ssh ansible@192.168.68.70 cat /var/log/cloud-init-output.log
```

### Consul Won't Form Cluster
```bash
# Check logs
journalctl -u consul -f

# Verify connectivity
consul members -detailed
```

### Ceph Health Issues
```bash
ssh root@192.168.68.65
ceph health detail
ceph osd tree
```

## Next Steps

1. **Set up Traefik** for HTTP ingress
2. **Deploy monitoring** (Prometheus/Grafana)
3. **Enable ACLs** for Consul and Nomad
4. **Configure backups** for VMs and Consul data
5. **Migrate workloads** from existing infrastructure

---

**Estimated Total Time:** 40 minutes  
**Result:** Fully operational Nomad + Consul cluster with service mesh
