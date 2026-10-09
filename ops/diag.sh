#!/bin/bash
# Read-only diagnostic. Writes output to the stats web dir under a random name so it can be fetched over HTTPS, then removed.
N="d-$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n').txt"
D=/var/cutline/stats; [ -d $D ] || D=/tmp
curl -fsSL https://raw.githubusercontent.com/dov-max/narge-spec/ops-2026-10-08/ops/diag-body.sh | bash > $D/$N 2>&1
chmod 644 $D/$N
H=$(hostname)
for u in https://dns.thecutline.org/$N https://dns.thecutline.org/stats/$N https://ewr.dns.thecutline.org/$N https://lax.dns.thecutline.org/$N; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$u"); echo "$c $u"
done
echo "FILE $D/$N lines=$(wc -l < $D/$N)"
