#!/bin/bash
# Query Logger for IP Tracking
# Reads DNS query logs (source IP only) and feeds them to the collector
# This script should tail the DNS server logs and extract source IPs
#
# PRIVACY: Query names are NEVER extracted or stored

set -euo pipefail

COLLECTOR="/opt/cutline/collector/collect-stats.sh"

# Read from stdin (expected format: one IP per line)
# In production, pipe filtered logs here:
#   tail -f /var/log/dns.log | extract-ip.sh | query-logger.sh

while read -r ip; do
    # Validate IP format (basic check)
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        "$COLLECTOR" record "$ip"
    fi
done
