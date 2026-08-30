# Cutline Stats Collector

This directory contains the stats collection system for Cutline DNS resolvers.

## Architecture

- **`collect-stats.sh`**: Main collector script that gathers metrics and publishes JSON
- **`query-logger.sh`**: Feeds source IPs from DNS logs to the collector
- **`nginx-stats.conf`**: Nginx configuration for serving stats with CORS

## Privacy Compliance

- **Source IPs**: Stored for 7 days only, then automatically deleted
- **Query names**: NEVER stored anywhere
- **History files**: Contain only dates and aggregate integers (no IPs)
- **IP log location**: `/var/cutline/stats/ip_log.txt` (never committed to git)

## Deployment

### Prerequisites

Both resolver VMs (EWR and LAX) must have:
- Blocky running with Prometheus metrics enabled (port 4000)
- Nginx serving on `dns.thecutline.org`
- Write access to `/var/cutline/stats/`

### Installation Steps

**On each resolver VM (EWR at 64.176.200.99 and LAX at 149.28.79.49):**

1. **Copy collector scripts:**
   ```bash
   sudo mkdir -p /opt/cutline/collector
   sudo cp collect-stats.sh query-logger.sh /opt/cutline/collector/
   sudo chmod +x /opt/cutline/collector/*.sh
   ```

2. **Set site identifier:**
   ```bash
   # On EWR VM:
   echo 'export CUTLINE_SITE=ewr' | sudo tee -a /etc/environment
   
   # On LAX VM:
   echo 'export CUTLINE_SITE=lax' | sudo tee -a /etc/environment
   ```

3. **Create data directory:**
   ```bash
   sudo mkdir -p /var/cutline/stats
   sudo chown www-data:www-data /var/cutline/stats
   ```

4. **Set up cron job for collection (runs every 5 minutes):**
   ```bash
   echo '*/5 * * * * CUTLINE_SITE=ewr /opt/cutline/collector/collect-stats.sh collect' | sudo crontab -u www-data -
   ```
   
   (Replace `ewr` with `lax` on the LAX VM)

5. **Update Blocky config:**
   Ensure `resolver/config.yml` has Prometheus enabled:
   ```yaml
   ports:
     dns: 53
     http: 4000
   
   prometheus:
     enable: true
     path: /metrics
   ```
   
   Restart Blocky:
   ```bash
   docker restart blocky
   ```

6. **Configure Nginx:**
   ```bash
   sudo cp nginx-stats.conf /etc/nginx/snippets/cutline-stats.conf
   ```
   
   Add to your nginx server block for `dns.thecutline.org`:
   ```nginx
   server {
       listen 443 ssl;
       server_name dns.thecutline.org;
       
       # ... existing SSL config ...
       
       include snippets/cutline-stats.conf;
   }
   ```
   
   Test and reload:
   ```bash
   sudo nginx -t
   sudo systemctl reload nginx
   ```

7. **Verify deployment:**
   ```bash
   # Test stats collection
   sudo -u www-data CUTLINE_SITE=ewr /opt/cutline/collector/collect-stats.sh collect
   
   # Check stats JSON was created
   cat /var/cutline/stats/stats.json
   
   # Test from web
   curl https://dns.thecutline.org/stats.json
   ```

## IP Tracking

The collector maintains a simple IP log at `/var/cutline/stats/ip_log.txt` with format:
```
unix_timestamp|ip_address
```

**Automatic 7-day pruning**: The `collect-stats.sh` script prunes entries older than 7 days on every run.

**Recording IPs**: Currently manual/placeholder. In production, you would:
1. Configure your DNS server to log source IPs (query names excluded)
2. Pipe logs to `query-logger.sh`:
   ```bash
   tail -f /var/log/dns.log | grep -oP '\d+\.\d+\.\d+\.\d+' | /opt/cutline/collector/query-logger.sh
   ```

## Metrics

### Live Stats (`/stats.json`)

Current snapshot:
```json
{
  "site": "ewr",
  "timestamp": "2026-08-30T21:00:00Z",
  "health": "healthy",
  "distinct_ips_7d": 1234,
  "latency": {
    "p50_ms": 3.2,
    "p95_ms": 8.5
  },
  "version": "1.0"
}
```

### Daily History (`/history.jsonl`)

Append-only JSONL:
```json
{"date":"2026-08-30","site":"ewr","distinct_ips_7d":1234,"latency":{"p50_ms":3.2,"p95_ms":8.5}}
{"date":"2026-08-31","site":"ewr","distinct_ips_7d":1256,"latency":{"p50_ms":3.1,"p95_ms":8.3}}
```

## Latency Definition

- **Metric**: Resolver processing time (query received → answer sent)
- **NOT included**: Last-mile network latency, client OS delays, browser Secure DNS overhead
- **Window**: Last 24 hours
- **Percentiles**: p50 (median) and p95
- **Source**: Blocky Prometheus metrics (`blocky_request_duration_ms`)

See `/spec` page for the published latency specification.

## Troubleshooting

**No metrics available:**
- Check Blocky is running: `docker ps | grep blocky`
- Verify Prometheus endpoint: `curl http://localhost:4000/metrics`
- Check Blocky logs: `docker logs blocky`

**IP count is 0:**
- Verify IP logging is configured
- Check IP log file: `cat /var/cutline/stats/ip_log.txt`
- Manually test: `/opt/cutline/collector/collect-stats.sh record 1.2.3.4`

**Stats not accessible via web:**
- Check nginx config: `sudo nginx -t`
- Verify file permissions: `ls -la /var/cutline/stats/`
- Check nginx logs: `sudo tail /var/log/nginx/error.log`

## Security Notes

- IP log file should NEVER be world-readable
- Never commit IP log to git (it's in `.gitignore`)
- History files contain only aggregates and are safe to publish
- CORS is restricted to `https://thecutline.org` only
