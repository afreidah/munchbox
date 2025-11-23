#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Munchbox Debian Base Image Generator
#
# Project: Munchbox / Author: Alex Freidah
#
# Generates a Debian base VM on a Proxmox node for use as a reusable template.
# Configures disk, network, and guest agent integration so that Terraform and
# Ansible can clone and configure cluster nodes in a consistent, repeatable way.
# -------------------------------------------------------------------------------

set -euo pipefail

# -------------------------------------------------------------------------------
# CONFIGURATION
# -------------------------------------------------------------------------------

# Debian netinst ISO URL
DEBIAN_ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.7.0-amd64-netinst.iso"

# Proxmox ISO storage configuration
ISO_STORAGE_PATH="/var/lib/vz/template/iso"
ISO_STORAGE_ID="local"

# VM identity and resources
VMID="9000"
VM_NAME="debian-base"
VM_MEMORY_MB="2048"
VM_CORES="2"

# VM disk configuration
DISK_STORAGE_ID="local-lvm"  # Storage ID for VM disk placement
DISK_SIZE_GB="16"            # Root disk size in gigabytes

# VM network configuration
BRIDGE="vmbr0"               # Proxmox bridge for VM connectivity

# -------------------------------------------------------------------------------
# DERIVED VARIABLES
# -------------------------------------------------------------------------------

# --- ISO filename and full path on host ---
iso_filename="$(basename "${DEBIAN_ISO_URL}")"
iso_full_path="${ISO_STORAGE_PATH}/${iso_filename}"

# -------------------------------------------------------------------------------
# HELPER FUNCTIONS
# -------------------------------------------------------------------------------

die() {
  # Prints an error message and terminates with a non-zero status.
  echo "ERROR: $*" >&2
  exit 1
}

check_root() {
  # Verifies execution as root to avoid partial configuration and permission issues.
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "This script must be run as root on a Proxmox node."
  fi
}

check_proxmox_tools() {
  # Ensures Proxmox CLI tooling is available for VM lifecycle operations.
  command -v qm >/dev/null 2>&1 || die "qm command not found. This host does not appear to be a Proxmox node."
}

download_iso() {
  # Ensures the Debian ISO is present in the Proxmox ISO storage directory.
  echo "Creating ISO directory: ${ISO_STORAGE_PATH}"
  mkdir -p "${ISO_STORAGE_PATH}"

  if [[ -f "${iso_full_path}" ]]; then
    echo "ISO already present: ${iso_full_path}"
    return
  fi

  echo "Downloading Debian ISO:"
  echo "  ${DEBIAN_ISO_URL}"
  curl -L "${DEBIAN_ISO_URL}" -o "${iso_full_path}"
  echo "Downloaded ISO to: ${iso_full_path}"
}

create_vm() {
  # Creates a base VM configured for use as a Debian template.
  echo "Creating VM ${VMID} (${VM_NAME})"

  qm create "${VMID}" \
    --name "${VM_NAME}" \
    --memory "${VM_MEMORY_MB}" \
    --cores "${VM_CORES}" \
    --net0 "virtio,bridge=${BRIDGE}" \
    --ostype l26

  qm set "${VMID}" \
    --scsihw virtio-scsi-pci \
    --scsi0 "${DISK_STORAGE_ID}:${DISK_SIZE_GB}"

  qm set "${VMID}" \
    --ide2 "${ISO_STORAGE_ID}:iso/${iso_filename},media=cdrom"

  qm set "${VMID}" \
    --boot order='ide2;scsi0'

  qm set "${VMID}" \
    --agent enabled=1

  echo "VM ${VMID} created and configured."
}

print_next_steps() {
  # Prints inside-guest configuration steps and template conversion instructions.
  cat <<EOF

# -------------------------------------------------------------------------------
# NEXT STEPS (HOST AND GUEST)
#
# Project: Munchbox / Author: Alex Freidah
#
# These steps complete the Debian installation inside the VM and prepare it as a
# reusable template. The template becomes the base image Terraform and Ansible
# use for provisioning Nomad, Consul, Vault, and related infrastructure nodes.
# -------------------------------------------------------------------------------

Host-side actions:
- Start VM ${VMID} ("${VM_NAME}") from the Proxmox web interface.
- Open the console for VM ${VMID}.
- Install Debian using the netinst ISO attached to the VM.

Debian installer guidance:
- Partitioning:
  Use guided partitioning with the entire disk and a single partition.
- Users:
  Enable the root account and set a root password.
  Any additional user accounts are optional and unused by Terraform and Ansible.
- Software selection:
  Include "SSH server" and "standard system utilities".

After the installation completes and Debian boots, log in as root in the VM console
and run the following commands inside the guest:

-------------------------------------------------------------------------------
# Inside the Debian guest as root:

apt update
apt install -y \\
  python3 python3-apt \\
  qemu-guest-agent \\
  sudo \\
  ca-certificates curl rsync

systemctl enable qemu-guest-agent

# Configure SSH key-based access for root.
# Replace the placeholder key block with the actual public key that Terraform
# and Ansible use for automation.

mkdir -p /root/.ssh
chmod 700 /root/.ssh

cat >> /root/.ssh/authorized_keys << 'EOF_KEY'
ssh-ed25519 AAAA...replace-this-with-your-public-key
EOF_KEY

chmod 600 /root/.ssh/authorized_keys

# Restrict SSH to key-based root access only to avoid password-based logins.

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

systemctl restart ssh

# Optional: configure basic time synchronization for stable cluster behavior.

apt install -y systemd-timesyncd
timedatectl set-ntp true
timedatectl

-------------------------------------------------------------------------------

Guest shutdown and template creation:
- Shutdown the VM cleanly from inside the guest:

  shutdown -h now

- On the Proxmox host, convert the VM into a reusable template:

  qm template ${VMID}

Resulting state:
- The "debian-base" template logs in as root using SSH keys only.
- Python dependencies for Ansible are present in the base image.
- QEMU guest agent integration is enabled for clean lifecycle management.
- Terraform can clone this template to produce Nomad, Consul, Vault, and other
  infrastructure VMs with a consistent, documented starting point.

EOF
}

# -------------------------------------------------------------------------------
# MAIN EXECUTION
# -------------------------------------------------------------------------------

check_root
check_proxmox_tools
download_iso
create_vm
print_next_steps

