#!/bin/bash
# Read-only diagnostic. Copies output to the dir nginx serves stats.json from (random name), prints the URL.
N="d-$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n').txt"
OUT=/tmp/$N
{
echo "### HOST $(hostname) $(date -u +%FT%TZ)"
echo "### UPTIME"; uptime; echo "### MEM"; free -m; echo "### DISK"; df -h -x tmpfs -x devtmpfs -x squashfs; df -i / | tail -1
echo "### SERVICES"; for s in blocky nginx cron ssh vnstat ufw; do printf '%s=%s ' $s "$(systemctl is-active $s 2>&1)"; done; echo
systemctl --failed --no-pager --no-legend
echo "### BLOCKY STATUS"; systemctl status blocky --no-pager 2>&1 | head -12; docker ps 2>/dev/null | head
echo "### LISTEN"; ss -lntup 2>/dev/null | rg -n ':(53|853|443|80|4000|8053)\b' 2>/dev/null || ss -lntup | grep -E ':(53|853|443|80|4000|8053) '
echo "### UFW"; ufw status verbose 2>&1 | head -40
echo "### NFT/IPT DNS"; iptables -S 2>/dev/null | grep -E 'dport (53|853)' | head; nft list ruleset 2>/dev/null | grep -nE 'dport (53|853)|limit' | head
echo "### DNS SELFTEST"; PUB=$(curl -s -4 --max-time 5 https://api.ipify.org || hostname -I | awk '{print $1}'); echo pub=$PUB
for t in 127.0.0.1 $PUB 64.176.200.99 149.28.79.49; do for proto in "" "+tcp"; do printf '%s %s on=' $t "${proto:-udp}"; dig +short +time=3 +tries=1 $proto @$t on.thecutline.org A 2>&1 | tr '\n' ' '; printf ' ex='; dig +short +time=3 +tries=1 $proto @$t example.com A 2>&1 | head -1; done; done
echo "### CRON"; echo "-- root:"; crontab -l 2>&1; echo "-- www-data:"; crontab -u www-data -l 2>&1; ls -la /etc/cron.d; systemctl list-timers --all --no-pager 2>&1 | head -25
echo "### STATS DIR"; ls -la --time-style=full-iso /var/cutline/stats /opt/cutline/collector 2>&1
echo "### stats.json"; cat /var/cutline/stats/stats.json 2>&1; echo; echo "### public.json"; cat /var/cutline/stats/public.json 2>&1; echo
echo "### MERGE LOG tail"; ls -la /var/log/cutline-merge.log*; tail -40 /var/log/cutline-merge.log 2>&1
echo "### CRON JOURNAL around Sep 12"; journalctl -u cron --since 2026-09-11 --until 2026-09-13 --no-pager 2>/dev/null | grep -iE 'collect|merge|error|fail' | tail -15
echo "### CRON JOURNAL recent"; journalctl -u cron --since '-30 min' --no-pager 2>/dev/null | tail -15
echo "### CRON JOURNAL first/last entries"; journalctl -u cron --no-pager -o short-iso 2>/dev/null | head -2; journalctl -u cron --no-pager -o short-iso 2>/dev/null | tail -3
echo "### JOURNAL disk"; journalctl --disk-usage 2>&1
echo "### METRICS"; curl -s --max-time 5 http://127.0.0.1:4000/metrics | grep -E '^blocky_(query_total|build_info|blocking_enabled)' | head -10
echo "### COLLECT DRYRUN check (syntax only)"; bash -n /opt/cutline/collector/collect-stats.sh && echo syntax_ok; sudo -u www-data test -w /var/cutline/stats && echo www_writable || echo www_NOT_writable
echo "### www-data shell/account"; getent passwd www-data; chage -l www-data 2>/dev/null | head -4; ls -la /var/spool/cron/crontabs/ 2>&1
echo "### pam/cron errors"; journalctl --since 2026-09-11 --until 2026-09-14 --no-pager 2>/dev/null | grep -iE 'cron|www-data' | grep -viE 'session (opened|closed)' | head -20
echo "### dpkg/unattended around Sep 12"; grep -hE '2026-09-1[1-3]' /var/log/dpkg.log 2>/dev/null | grep -E ' (upgrade|install|remove) ' | head -30
echo "### last reboots"; last -x reboot shutdown 2>/dev/null | head -6
echo "### blocky journal tail"; journalctl -u blocky -n 15 --no-pager 2>&1 | tail -15
echo "### nginx vhosts"; ls -la /etc/nginx/sites-enabled; grep -rn 'stats.json' -A12 /etc/nginx/sites-enabled/ 2>/dev/null | grep -E 'server_name|alias|root' | head
echo "### DU /var"; du -xsh /var/* 2>/dev/null | sort -h | tail -12; du -xsh /var/log/* 2>/dev/null | sort -h | tail -10
echo "### BIG FILES"; find / -xdev -type f -size +200M -printf '%s %p\n' 2>/dev/null | sort -n | tail -15
echo "### BLOCKY unit"; systemctl cat blocky --no-pager 2>&1
echo "### BLOCKY version"; for b in $(which blocky) /usr/local/bin/blocky /opt/blocky/blocky; do [ -x $b ] && $b version 2>&1 | head -5; done
echo "### BLOCKY config files"; ls -la /etc/blocky /opt/blocky 2>&1
for f in /etc/blocky/config.yml /etc/blocky/config.yaml /opt/blocky/config.yml; do [ -f $f ] && { echo "=== $f"; cat $f; }; done
echo "### lists"; ls -la /etc/blocky/*/ /var/lib/blocky 2>/dev/null
echo "### grep narge/cutline"; grep -rIl -E 'narge|stevenblack|thecutline' /etc /opt 2>/dev/null | grep -v '\.bak' | head -30
echo "### collector"; ls -la /opt/cutline /opt/cutline/* 2>&1; for f in /opt/cutline/collector/*; do echo "=== $f"; cat "$f"; done
echo "### nginx stats"; cat /etc/nginx/sites-enabled/* 2>/dev/null | head -200
echo "### logrotate"; ls /etc/logrotate.d; cat /etc/systemd/journald.conf | grep -v '^#' | grep .
echo "### DONE"
} > $OUT 2>&1 < /dev/null
chmod 644 $OUT
echo "lines=$(wc -l < $OUT)"
DIRS=$(nginx -T 2>/dev/null | grep -E '^\s*(root|alias)\s' | awk '{print $2}' | tr -d ';' | sort -u)
for d in $DIRS; do [ -d "$d" ] && { [ -f "$d/stats.json" ] || [ -f "$d/index.html" ]; } && cp $OUT "$d/$N" && echo "copied $d"; done
for h in dns ewr.dns lax.dns; do for p in "" stats/; do c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://$h.thecutline.org/$p$N"); [ "$c" = 200 ] && echo "OK https://$h.thecutline.org/$p$N"; done; done
echo "FILE $N"
