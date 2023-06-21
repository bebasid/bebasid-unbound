#!/bin/sh

. /etc/profile

UNBOUND_BLOCKED_HOSTS_FILE=/etc/unbound/unbound.blocked.hosts

check_error() {
  if [ "$1" != "0" ]; then
    echo "| ERR: $2"
    exit $1
  fi
}

touch /tmp/hosts
truncate -s 0 /tmp/hosts

echo "| INFO: Downloading bebasdns custom filter..."
curl https://raw.githubusercontent.com/bebasid/bebasdns/main/dev/resources/hosts/custom-filtering-rules-blocklist --progress-bar --insecure | tee -a /tmp/hosts >/dev/null 2>&1
check_error $? "Download failed!"

echo "| INFO: Downloading Windows Spy Blocker..."
curl https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt --progress-bar --insecure | tee -a /tmp/hosts >/dev/null 2>&1
check_error $? "Download failed!"

echo "| INFO: Downloading URLHaus's Maliclious..."
curl https://raw.githubusercontent.com/BlackJack8/iOSAdblockList/master/Hosts.txt --progress-bar --insecure | tee -a /tmp/hosts >/dev/null 2>&1
check_error $? "Download failed!"

if [ "${BEBASID_FAMILY_UNBOUND}" = "true" ]; then
    echo "| INFO: Downloading StevenBlack Unified Hosts + Porn..."
    curl https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts --progress-bar --insecure | tee -a /tmp/hosts >/dev/null 2>&1
    check_error $? "Download failed!"

    echo "| INFO: Downloading StevenBlack Unified hosts + Gambling... "
    curl https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling/hosts --progress-bar --insecure | tee -a /tmp/hosts >/dev/null 2>&1
    check_error $? "Download failed!"
    
    echo "| INFO: Downloading StevenBlack Unified hosts + Fakenews... "
    curl https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts --progress-bar --insecure | tee -a /tmp/hosts >/dev/null 2>&1
    check_error $? "Download failed!"
fi

echo "| INFO: Updating unbound host zones..."
cat /tmp/hosts | grep '^0\.0\.0\.0' | awk '{print "local-zone: \""$2"\" redirect\nlocal-data: \""$2" A 0.0.0.0\""}' | sort -u > ${UNBOUND_BLOCKED_HOSTS_FILE}

chown -Rf unbound:unbound ${UNBOUND_BLOCKED_HOSTS_FILE}

unbound-control reload >/dev/null 2>&1
if [ "$?" != "0" ]; then
    echo "| WARN: unbound reload failed, trying to restart service..."
    supervisorctl restart unbound
    check_error $? "Unbound service restart failed!"
fi