#!/bin/sh

set -e

if [ -f /run/secrets/DEBUG ]; then
    export DEBUG=$(cat $i)
fi

if [ $DEBUG = "1"]; then
    set -x
    BASH_CMD_FLAGS='-x'
fi

OSF=$(cat /etc/os-release|grep -e '^ID=.*'|cut -d '=' -f 2)

UNBOUND_CONFIG_DIR=/etc/unbound
export UNBOUND_CONFIG_FILE=${UNBOUND_CONFIG_DIR}/unbound.conf
export UNBOUND_ANCHOR_FILE=${UNBOUND_CONFIG_DIR}/keys/root.key
export UNBOUND_BLOCKED_HOSTS_FILE=${UNBOUND_CONFIG_DIR}/unbound.blocked.hosts
export ICANN_BUNDLE_FILE=${UNBOUND_CONFIG_DIR}/keys/icannbundle.pem

echo "|---------------------------------------------------------------------------------------------\n";
echo "| Starting Unbound DNS Cache Server\n"

printf "| ENTRYPOINT: \033[0;31mLoading docker secrets if found...\033[0m\n"
for i in $(env|grep '/run/secrets')
do
    varName=$(echo $i|awk -F '[=]' '{print $1}'|sed 's/_FILE//')
    varFile=$(echo $i|awk -F '[=]' '{print $2}')
    exportCmd="export $varName=$(cat $varFile)"
    echo "${exportCmd}" >> /etc/profile
    eval "${exportCmd}"
    printf "| ENTRYPOINT: Exporting var: $varName\n"
done

TMP_FILE=/tmp/unbound.conf
cp ${UNBOUND_CONFIG_FILE} ${TMP_FILE}
DOLLAR='$' envsubst < ${TMP_FILE} > ${UNBOUND_CONFIG_FILE}
rm ${TMP_FILE}

if [ ! -d ${UNBOUND_CONFIG_DIR}/keys ]; then
  mkdir -p ${UNBOUND_CONFIG_DIR}/keys
fi

if [ ! -f ${ICANN_BUNDLE_FILE} ]; then
  curl https://data.iana.org/root-anchors/icannbundle.pem --output ${ICANN_BUNDLE_FILE} >/dev/null 2>&1
  ln -s ${ICANN_BUNDLE_FILE} ${UNBOUND_CONFIG_DIR}/icannbundle.pem
  ln -s ${ICANN_BUNDLE_FILE} /icannbundle.pem
fi

if [ ! -f ${UNBOUND_CONFIG_DIR}/unbound_control.pem ] || [ ! -f ${UNBOUND_CONFIG_DIR}/unbound_server.pem ]; then
  printf "| ENTRYPOINT: Setting up unbound certificates...\n"
  unbound-control-setup 2>&1 | sed 's/^/| ENTRYPOINT: Unbound: /g'
fi

unbound-anchor -a ${UNBOUND_ANCHOR_FILE} || echo

chown -Rf unbound:unbound ${UNBOUND_CONFIG_DIR} ${UNBOUND_CONFIG_DIR}/keys
chmod 644 ${UNBOUND_CONFIG_DIR}/*.conf

if [ ! -f ${UNBOUND_BLOCKED_HOSTS_FILE} ]; then
  /bin/sh $BASH_CMD_FLAGS /scripts/auto-update.sh "${UNBOUND_BLOCKED_HOSTS_FILE}" no-reload
fi

printf "| ENTRYPOINT: \033[0;31mStarting supervisord (which starts and monitors cron and unbound) \033[0m\n"
printf "|---------------------------------------------------------------------------------------------\n";

if [ "$OSF" = "ubuntu" ]; then
  rm -rf /etc/cron.daily/*
  CRON_FILE=/etc/cron.daily/updatehosts
elif [ "$OSF" = "alpine" ]; then
  CRON_FILE=/etc/periodic/daily/updatehosts
else
  echo "Error: We support only alpine and ubuntu flavors right now"
  sleep 1000000000
  #exit 1
fi

printf "#!/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin\n" > ${CRON_FILE}
printf ". /scripts/auto-update.sh ${UNBOUND_BLOCKED_HOSTS_FILE}\n" >> ${CRON_FILE}
chmod +x ${CRON_FILE}

if [ -f /app-config ]; then
    echo "| ENTRYPOINT: Executing app-config..."
    . /app-config "$@"
else
    echo "| ENTRYPOINT: app-config was not available, running given parameters or default CMD..."
    exec $@
fi