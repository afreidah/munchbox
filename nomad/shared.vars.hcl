# -------------------------------------------------------------------------------
# Shared Nomad Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# Common variables used across multiple Nomad jobs. Automatically included
# via Makefile when running jobs.
# -------------------------------------------------------------------------------

# --- DNS Servers ---
# Pi-hole DNS servers for fallback resolution
pihole_1 = "192.168.68.62"  # pihole-01 (green)
pihole_2 = "192.168.68.64"  # pihole-02 (logan)
