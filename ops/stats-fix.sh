#!/bin/bash
# Stats fix 2026-10-09 (owner-approved): reload nginx (running config was stale), restart services
# that died when the disk filled, LAX pulls combined stats from EWR over HTTPS (SSH push is blocked).
echo "### $(hostname) $(date -u +%FT%TZ)"
ps -o lstart= -p $(cat /run/nginx.pid) 2>/dev/null | sed 's/^/nginx master started: /'
nginx -t 2>&1 | tail -1 && systemctl reload nginx && echo "nginx reloaded"
for s in vnstat logrotate; do systemctl reset-failed $s 2>/dev/null; systemctl restart $s 2>/dev/null; printf '%s=%s\n' $s "$(systemctl is-active $s)"; done
if hostname | grep -q lax; then
cat > /usr/local/bin/cutline-pull-public.sh <<'P'
#!/bin/bash
# Pull combined public stats from EWR (publisher) over HTTPS; validate; atomic replace.
set -e; S=/var/cutline/stats; T=$(mktemp -d)
curl -fsS --max-time 15 --resolve dns.thecutline.org:443:64.176.200.99 https://dns.thecutline.org/stats.json -o $T/p.json
curl -fsS --max-time 15 --resolve dns.thecutline.org:443:64.176.200.99 https://dns.thecutline.org/history.jsonl -o $T/h.jsonl
python3 -c "import json,sys; d=json.load(open('$T/p.json')); assert 'as_of' in d; [json.loads(l) for l in open('$T/h.jsonl') if l.strip()]"
install -o www-data -g www-data -m 644 $T/p.json $S/public.json.new && mv $S/public.json.new $S/public.json
install -o www-data -g www-data -m 644 $T/h.jsonl $S/public-history.jsonl.new && mv $S/public-history.jsonl.new $S/public-history.jsonl
rm -rf $T
P
chmod 755 /usr/local/bin/cutline-pull-public.sh
echo "2-59/5 * * * * root /usr/local/bin/cutline-pull-public.sh >>/var/log/cutline-pull.log 2>&1" > /etc/cron.d/cutline-pull-public
fi
if hostname | grep -q ewr; then
  crontab -l | sed 's/CUTLINE_PUBLISH_PEER=1/CUTLINE_PUBLISH_PEER=0/' | crontab - && echo "ewr: peer push off (LAX pulls over HTTPS)"
fi
sleep 2
for ip in 64.176.200.99 149.28.79.49; do echo "served via $ip: $(curl -s --resolve dns.thecutline.org:443:$ip https://dns.thecutline.org/stats.json | tr -d '\n ' )"; done
rm -f /var/www/narge-canary/f-*.txt /var/www/narge-canary/d-*.txt
echo DONE
