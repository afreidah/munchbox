# -----------------------------------------------------------------------------
# PROXMOX CLUSTER ENV HELPER
# -----------------------------------------------------------------------------
#
# Manages a group of on-prem Proxmox VMs. The calling terragrunt directory's
# name (e.g. `cluster`, `cinc-server`) selects which group from
# `proxmox_vm_groups` (below) gets provisioned, so a new VM group is added by
# dropping a new directory under terragrunt/proxmox/ and adding the matching
# key here.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/infrastructure/terragrunt/modules/proxmox-cluster"
}

locals {
  root       = read_terragrunt_config(find_in_parent_folders("root.hcl"))
  group_name = basename(get_terragrunt_dir())
  group      = local.proxmox_vm_groups[local.group_name]

  # --- keyed by terragrunt subdir name under terragrunt/proxmox/. Each leaf
  #     reads its own group; a new VM group is one new dir + one new key. ---
  proxmox_vm_groups = {
    "nomad-server-03" = {
      "nomad-server-03" = {
        target_node = "fontana"
        vmid        = 172
        memory      = 2048
        cores       = 2
        disk_size   = "40G"
        existing    = true
      }
    }

    "nomad-client-01" = {
      "nomad-client-01" = {
        target_node = "fontana"
        vmid        = 180
        memory      = 13312
        balloon     = 10240
        cores       = 4
        disk_size   = "60G"
        existing    = true
      }
    }

    "nomad-client-02" = {
      "nomad-client-02" = {
        target_node = "mccoy"
        vmid        = 181
        memory      = 15360
        balloon     = 12288
        cores       = 4
        disk_size   = "40G"
        existing    = true
      }
    }

    "nomad-client-03" = {
      "nomad-client-03" = {
        target_node = "cabot"
        vmid        = 182
        memory      = 7168
        balloon     = 5120
        cores       = 4
        disk_size   = "40G"
        existing    = true
      }
    }

    "nomad-client-04" = {
      "nomad-client-04" = {
        target_node     = "rubirosa"
        vmid            = 183
        memory          = 28672
        balloon         = 24576
        cores           = 10
        disk_size       = "140G"
        gpu_passthrough = { pci_address = "0000:02:00.0" }
        cloud_init = {
          ip         = "192.168.68.73/24"
          gateway    = "192.168.68.1"
          nameserver = "192.168.68.62"
        }
      }
    }

    "nomad-client-05" = {
      "nomad-client-05" = {
        target_node = "rubirosa"
        vmid        = 184
        memory      = 28672
        balloon     = 18432
        cores       = 10
        disk_size   = "40G"
        cloud_init = {
          ip         = "192.168.68.74/24"
          gateway    = "192.168.68.1"
          nameserver = "192.168.68.62"
        }
      }
    }

    # --- Cinc server host. Provisioned as its own group so it can be applied independently of the cluster ---
    cinc-server = {
      "cinc-server" = {
        target_node = "rubirosa"
        vmid        = 185
        memory      = 4096
        cores       = 2
        disk_size   = "60G"
        cloud_init = {
          ip         = "192.168.68.99/24"
          gateway    = "192.168.68.1"
          nameserver = "192.168.68.62"
          sshkeys    = local.root.locals.ssh_public_key
          # Attach a cloud-init CD-ROM so the OS can actually read the
          # ipconfig0 / ciuser settings above.
          storage = "local-lvm"
        }
      }
    }
  }
}

inputs = {
  vms            = local.group
  disk_storage   = local.root.locals.proxmox_defaults.disk_storage
  network_bridge = local.root.locals.proxmox_defaults.network_bridge
  template_name  = try(local.root.locals.proxmox_defaults.template_name, "debian-base")
}
