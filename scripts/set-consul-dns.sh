#!/bin/bash
# -------------------------------------------------------------------------------
# Configure Pi-hole to forward .consul domain queries to Consul servers
# 
# This script configures Pi-hole's dnsmasq to forward queries for the .consul
# domain to Consul servers, enabling service discovery via DNS.
#
# Usage: sudo ./setup-pihole-consul-dns.sh
# -------------------------------------------------------------------------------

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Consul server IPs (modify these for your environment)
CONSUL_SERVERS=(
    "192.168.68.63#8600"  # mccoy
    "192.168.68.61#8600"  # stabler
    "192.168.68.59#8600"  # cabot
    "192.168.68.60#8600"  # goren
)

PIHOLE_CONFIG="/etc/pihole/pihole.toml"
BACKUP_CONFIG="${PIHOLE_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

echo -e "${YELLOW}=== Pi-hole Consul DNS Setup ===${NC}"
echo ""

# Verify Pi-hole is installed
if [ ! -f "$PIHOLE_CONFIG" ]; then
    echo -e "${RED}Error: Pi-hole config not found at $PIHOLE_CONFIG${NC}"
    exit 1
fi

# Backup existing config
echo -e "${GREEN}1. Creating backup of pihole.toml...${NC}"
cp "$PIHOLE_CONFIG" "$BACKUP_CONFIG"
echo "   Backup saved to: $BACKUP_CONFIG"
echo ""

# Check if dnsmasq_lines already has consul entries
if grep -q "server=/consul/" "$PIHOLE_CONFIG"; then
    echo -e "${YELLOW}2. Consul DNS forwarding already configured!${NC}"
    echo "   Skipping configuration..."
else
    echo -e "${GREEN}2. Adding Consul DNS forwarding to dnsmasq_lines...${NC}"
    
    # Build the dnsmasq_lines array
    DNSMASQ_LINES="  dnsmasq_lines = [\n"
    for server in "${CONSUL_SERVERS[@]}"; do
        DNSMASQ_LINES+="    \"server=/consul/${server}\",\n"
    done
    # Remove trailing comma from last entry
    DNSMASQ_LINES="${DNSMASQ_LINES%,\\n}\"\n  ]\n"
    
    # Replace empty dnsmasq_lines with consul config
    if grep -q "dnsmasq_lines = \[\]" "$PIHOLE_CONFIG"; then
        # Use perl for proper multiline replacement
        perl -i -pe "s/dnsmasq_lines = \[\]/dnsmasq_lines = [\n    \"server\/consul\/${CONSUL_SERVERS[0]}\",\n    \"server\/consul\/${CONSUL_SERVERS[1]}\",\n    \"server\/consul\/${CONSUL_SERVERS[2]}\",\n    \"server\/consul\/${CONSUL_SERVERS[3]}\"\n  ]/g" "$PIHOLE_CONFIG"
    else
        echo -e "${YELLOW}   Warning: dnsmasq_lines is not empty. Please add manually:${NC}"
        echo ""
        for server in "${CONSUL_SERVERS[@]}"; do
            echo "    \"server=/consul/${server}\","
        done
        echo ""
    fi
fi

# Verify configuration syntax
echo -e "${GREEN}3. Verifying dnsmasq configuration...${NC}"
if pihole-FTL dnsmasq-test 2>&1 | grep -q "syntax check OK"; then
    echo "   ✓ Configuration syntax is valid"
else
    echo -e "${RED}   ✗ Configuration has errors!${NC}"
    echo "   Restoring backup..."
    cp "$BACKUP_CONFIG" "$PIHOLE_CONFIG"
    exit 1
fi
echo ""

# Restart Pi-hole FTL
echo -e "${GREEN}4. Restarting Pi-hole FTL...${NC}"
systemctl restart pihole-FTL
sleep 3

# Verify FTL started successfully
if systemctl is-active --quiet pihole-FTL; then
    echo "   ✓ Pi-hole FTL restarted successfully"
else
    echo -e "${RED}   ✗ Pi-hole FTL failed to start!${NC}"
    echo "   Restoring backup..."
    cp "$BACKUP_CONFIG" "$PIHOLE_CONFIG"
    systemctl restart pihole-FTL
    exit 1
fi
echo ""

# Test Consul DNS resolution
echo -e "${GREEN}5. Testing Consul DNS resolution...${NC}"
if dig @127.0.0.1 loki.service.consul +short | grep -q '^[0-9]'; then
    echo "   ✓ Consul DNS resolution is working!"
    RESOLVED_IP=$(dig @127.0.0.1 loki.service.consul +short | head -1)
    echo "   loki.service.consul resolved to: $RESOLVED_IP"
else
    echo -e "${YELLOW}   ⚠ Could not resolve loki.service.consul${NC}"
    echo "   This might be normal if the service doesn't exist yet."
    echo "   You can test with other Consul services once they're registered."
fi
echo ""

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Your Pi-hole can now resolve .consul domains!"
echo "All queries for *.consul will be forwarded to your Consul servers."
echo ""
echo "Backup saved at: $BACKUP_CONFIG"
echo ""
echo "To test: dig loki.service.consul"
echo ""
