#!/bin/bash
# ------------------------------------------------------------------------------
# Nextcloud 2FA Enforcement Toggle
#
# Usage: ./2fa.sh [on|off|status]
# ------------------------------------------------------------------------------

set -e

CONTAINER=$(ssh root@goren "docker ps --filter ancestor=nextcloud:apache --format '{{.Names}}' | grep -v cron | head -1")

if [ -z "$CONTAINER" ]; then
    echo "Error: Nextcloud container not found"
    exit 1
fi

case "${1:-status}" in
    on)
        echo "Enabling 2FA enforcement..."
        ssh root@goren "docker exec -u www-data $CONTAINER /var/www/html/occ twofactorauth:enforce --on"
        ;;
    off)
        echo "Disabling 2FA enforcement..."
        ssh root@goren "docker exec -u www-data $CONTAINER /var/www/html/occ twofactorauth:enforce --off"
        ;;
    status)
        echo "Checking 2FA status..."
        ssh root@goren "docker exec -u www-data $CONTAINER /var/www/html/occ twofactorauth:state"
        ;;
    *)
        echo "Usage: $0 [on|off|status]"
        exit 1
        ;;
esac
