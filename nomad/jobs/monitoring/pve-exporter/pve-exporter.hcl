# -------------------------------------------------------------------------------
# PVE Exporter — Proxmox VE Metrics Collection
#
# Project: Munchbox / Author: Alex Freidah
#
# Exports Proxmox VE hypervisor metrics including CPU, memory, storage, disk
# I/O, and network for Prometheus scraping. Queries all Proxmox hosts via API.
# -------------------------------------------------------------------------------

# --- Core job configuration ---
name        = "pve-exporter"
image       = "prompve/prometheus-pve-exporter:3.9.0"
port        = 9221
static_port = 9221
size        = "tiny"
# --- cpu override: Python exporter enumerates 4 PVE hosts per scrape; tiny preset is too small ---
cpu         = 300
vault       = true

# --- Placement ---
node = "any"

# --- Traefik routing ---
traefik = false

# --- Health check ---
health_path = "/metrics"

# --- Environment (static) ---
env = {
  TZ = "America/Los_Angeles"
}

# --- Configuration templates (Vault credentials) ---
templates = [
  { src = "pve.yml.tpl", dest = "/etc/pve-exporter/pve.yml", vault = true }
]

# --- Container arguments ---
args = [
  "--config.file=/etc/pve-exporter/pve.yml"
]

# --- Service tags ---
tags = ["monitoring", "pve-exporter", "metrics", "proxmox", "hypervisor"]
