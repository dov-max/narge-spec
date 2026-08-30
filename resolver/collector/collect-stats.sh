#!/bin/bash
# Cutline DNS Resolver Stats Collector
# Runs on each resolver VM (EWR and LAX) to collect metrics and publish stats.json
#
# PRIVACY:
# - Source IPs stored for 7 days only (rate limits + public stats)
# - Query names are NEVER stored
# - IP store is never committed to git
# - History files contain only dates and aggregate integers

set -euo pipefail

# Configuration
SITE="${CUTLINE_SITE:-unknown}"  # Set to "ewr" or "lax" via environment
DATA_DIR="/var/cutline/stats"
IP_LOG="$DATA_DIR/ip_log.txt"
LIVE_JSON="$DATA_DIR/stats.json"
HISTORY_JSON="$DATA_DIR/history.jsonl"
BLOCKY_METRICS="http://localhost:4000/metrics"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Function: Prune IPs older than 7 days
prune_ips() {
    if [[ ! -f "$IP_LOG" ]]; then
        return
    fi
    
    local cutoff_date=$(date -d '7 days ago' +%s)
    local temp_file=$(mktemp)
    
    while IFS='|' read -r timestamp ip; do
        if [[ "$timestamp" -ge "$cutoff_date" ]]; then
            echo "$timestamp|$ip" >> "$temp_file"
        fi
    done < "$IP_LOG"
    
    mv "$temp_file" "$IP_LOG"
}

# Function: Record an IP (called by DNS logger or external source)
# Usage: record_ip <ip_address>
record_ip() {
    local ip="$1"
    local now=$(date +%s)
    
    # Check if IP already exists in last 7 days
    if [[ -f "$IP_LOG" ]] && grep -q "|$ip$" "$IP_LOG"; then
        # Update timestamp for existing IP
        local temp_file=$(mktemp)
        while IFS='|' read -r timestamp existing_ip; do
            if [[ "$existing_ip" == "$ip" ]]; then
                echo "$now|$ip" >> "$temp_file"
            else
                echo "$timestamp|$existing_ip" >> "$temp_file"
            fi
        done < "$IP_LOG"
        mv "$temp_file" "$IP_LOG"
    else
        # Add new IP
        echo "$now|$ip" >> "$IP_LOG"
    fi
}

# Function: Count distinct IPs in last 7 days
count_ips() {
    if [[ ! -f "$IP_LOG" ]]; then
        echo "0"
        return
    fi
    
    wc -l < "$IP_LOG"
}

# Function: Query Prometheus metrics for latency
get_latency_metrics() {
    local metrics_output
    if ! metrics_output=$(curl -s --max-time 5 "$BLOCKY_METRICS" 2>/dev/null); then
        echo "null"
        return
    fi
    
    # Parse blocky_request_duration_ms_bucket for percentiles
    # Blocky exposes histogram buckets, we need to calculate percentiles
    # For simplicity, extract the summary quantiles if available
    # Otherwise calculate from histogram buckets
    
    # Try to get quantile data (if Blocky exposes it)
    local p50=$(echo "$metrics_output" | grep 'blocky_request_duration_ms{quantile="0.5"' | awk '{print $2}' | head -1)
    local p95=$(echo "$metrics_output" | grep 'blocky_request_duration_ms{quantile="0.95"' | awk '{print $2}' | head -1)
    
    # If quantiles not available, calculate from histogram (simplified)
    if [[ -z "$p50" ]]; then
        # This is a placeholder - real implementation would calculate from histogram buckets
        # For now, return null to indicate unavailable
        echo "null"
        return
    fi
    
    echo "{\"p50_ms\":$p50,\"p95_ms\":$p95}"
}

# Function: Check resolver health
check_health() {
    # Simple health check: can we query Blocky metrics?
    if curl -s --max-time 2 "$BLOCKY_METRICS" > /dev/null 2>&1; then
        echo '"healthy"'
    else
        echo '"unhealthy"'
    fi
}

# Main collection logic
collect_stats() {
    # Prune old IPs first
    prune_ips
    
    # Gather metrics
    local distinct_ips=$(count_ips)
    local latency=$(get_latency_metrics)
    local health=$(check_health)
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Generate live stats JSON
    cat > "$LIVE_JSON" << EOF
{
  "site": "$SITE",
  "timestamp": "$timestamp",
  "health": $health,
  "distinct_ips_7d": $distinct_ips,
  "latency": $latency,
  "version": "1.0"
}
EOF
    
    # Update today's row in daily history (or append if not exists)
    local today=$(date -u +%Y-%m-%d)
    local temp_history=$(mktemp)
    local updated=false
    
    if [[ -f "$HISTORY_JSON" ]]; then
        while IFS= read -r line; do
            if echo "$line" | grep -q "\"date\":\"$today\""; then
                # Update today's row
                echo "{\"date\":\"$today\",\"site\":\"$SITE\",\"distinct_ips_7d\":$distinct_ips,\"latency\":$latency}" >> "$temp_history"
                updated=true
            else
                echo "$line" >> "$temp_history"
            fi
        done < "$HISTORY_JSON"
        mv "$temp_history" "$HISTORY_JSON"
    fi
    
    # Append if today's row didn't exist
    if [[ "$updated" == "false" ]]; then
        echo "{\"date\":\"$today\",\"site\":\"$SITE\",\"distinct_ips_7d\":$distinct_ips,\"latency\":$latency}" >> "$HISTORY_JSON"
    fi
}

# Parse command
case "${1:-collect}" in
    collect)
        collect_stats
        ;;
    prune)
        prune_ips
        ;;
    record)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 record <ip_address>" >&2
            exit 1
        fi
        record_ip "$2"
        ;;
    count)
        count_ips
        ;;
    *)
        echo "Usage: $0 {collect|prune|record <ip>|count}" >&2
        exit 1
        ;;
esac
