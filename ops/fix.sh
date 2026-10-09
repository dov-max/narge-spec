#!/bin/bash
# Narge resolver fix 2026-10-09 (owner-approved): query logging off, docker log cap,
# subdomain blocking via wildcard list, drop public suffixes (incl. blogspot.com).
# Backs up, tests, and rolls back automatically if checks fail.
N="f-$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n').txt"; R=/tmp/$N
exec > >(tee $R) 2>&1
set -u
D=/opt/narge; B=bak-20261009
echo "### $(hostname) $(date -u +%FT%TZ)"
python3 -c 'import yaml' || { echo "ABORT no python3-yaml"; exit 1; }
COMPOSE="docker compose"; $COMPOSE version >/dev/null 2>&1 || COMPOSE="docker-compose"
[ -f $D/config.yml.$B ] || cp -a $D/config.yml $D/config.yml.$B
[ -f $D/docker-compose.yml.$B ] || cp -a $D/docker-compose.yml $D/docker-compose.yml.$B
mkdir -p $D/lists
curl -fsSL https://raw.githubusercontent.com/dov-max/narge-spec/2b6a603bb095/ops/narge-sync.sh -o /usr/local/bin/narge-sync.sh && chmod 755 /usr/local/bin/narge-sync.sh
/usr/local/bin/narge-sync.sh || { echo "ABORT sync failed"; exit 1; }
echo "wild lines: $(grep -vc '^#' $D/lists/narge-wild.txt)"; grep -c '^\*\.' $D/lists/narge-wild.txt
python3 - <<'PY'
import yaml
D='/opt/narge'
c=yaml.safe_load(open(D+'/config.yml'))
c['queryLog']={'type':'none'}
c['blocking']['denylists']['narge']=['/app/lists/narge-wild.txt','/app/local-deny.txt']
c['blocking'].setdefault('loading',{})['refreshPeriod']='1h'
open(D+'/config.yml','w').write('# Narge Blocky config. Edited 2026-10-09: queryLog none, wildcard list (narge-sync.sh hourly).\n'+yaml.safe_dump(c,sort_keys=False))
k=yaml.safe_load(open(D+'/docker-compose.yml'))
svc=[s for s in k['services'].values() if 'blocky' in str(s.get('image',''))][0]
v=svc.setdefault('volumes',[])
if not any('/app/lists' in str(x) for x in v): v.append('/opt/narge/lists:/app/lists:ro')
svc['logging']={'driver':'json-file','options':{'max-size':'10m','max-file':'3'}}
open(D+'/docker-compose.yml','w').write(yaml.safe_dump(k,sort_keys=False))
PY
echo "17 * * * * root /usr/local/bin/narge-sync.sh >>/var/log/narge-sync.log 2>&1" > /etc/cron.d/narge-sync
cat > /etc/logrotate.d/narge-sync <<'L'
/var/log/narge-sync.log /var/log/cutline-merge.log { weekly rotate 2 compress missingok notifempty copytruncate }
L
cd $D && $COMPOSE up -d --force-recreate </dev/null 2>&1 | tail -3
sleep 8
q(){ dig +short +time=2 +tries=2 @127.0.0.1 "$1" A | head -1; r=$(dig +time=2 +tries=2 @127.0.0.1 "$1" A | grep -o 'status: [A-Z]*'); echo "$1 $r"; }
FAIL=0
for n in onlyfans.com www.onlyfans.com www.chaturbate.com pornhub.com www.pornhub.com off.thecutline.org wordpress.com; do o=$(q $n); echo "BLOCK? $o"; echo "$o" | grep -q NXDOMAIN || FAIL=1; done
for n in on.thecutline.org example.com google.com bbc.co.uk googleblog.blogspot.com blogspot.com en.wordpress.com; do o=$(q $n); echo "ALLOW? $o"; echo "$o" | grep -q NOERROR || FAIL=1; done
sleep 5; echo "docker log lines with queryLog: $(docker logs --since 20s $(docker ps -q --filter name=blocky) 2>&1 | grep -c queryLog)"
docker inspect $(docker ps -q --filter name=blocky) --format '{{.HostConfig.LogConfig}} {{.State.Health.Status}}'
if [ $FAIL = 1 ]; then
  echo "CHECKS FAILED -> ROLLBACK"; cp -a $D/config.yml.$B $D/config.yml; cp -a $D/docker-compose.yml.$B $D/docker-compose.yml; rm -f /etc/cron.d/narge-sync
  cd $D && $COMPOSE up -d --force-recreate </dev/null 2>&1 | tail -2; sleep 5; q on.thecutline.org; q pornhub.com
else echo "ALL CHECKS PASSED"; fi
rm -f /var/www/narge-canary/d-*.txt /var/cutline/stats/d-*.txt /tmp/d-*.txt
df -h / | tail -1
cp $R /var/www/narge-canary/$N 2>/dev/null; chmod 644 /var/www/narge-canary/$N
echo "RESULT $N"
