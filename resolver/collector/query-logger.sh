#!/bin/bash
# Query Logger for IP Tracking
# Reads source IPs from stdin and feeds them to the collector
# Sources: nginx DoH logs ($remote_addr) or nftables packet headers (SRC= field)
#
# PRIVACY: Query names are NEVER extracted or stored
# Only source IPs from packet headers or HTTP access logs

set -euo pipefail

COLLECTOR="/opt/cutline/collector/collect-stats.sh"

# Read from stdin (expected format: one IP per line)
while read -r ip; do
    # Validate IPv4 format
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        "$COLLECTOR" record "$ip"
    # Validate IPv6 format (simplified check)
    elif [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]] && [[ "$ip" == *:* ]]; then
        "$COLLECTOR" record "$ip"
    fi
done
