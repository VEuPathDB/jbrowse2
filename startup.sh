#!/usr/bin/env sh

trap gracefulShutdown EXIT 1 2 3 6 9 15 SIGTERM

# clean up jbrowse2 raw installation
cd jbrowse2
rm -rf test_data

# check to make sure data directory exists; easier to bail now if not
if [ ! -e "$SERVICE_FILES_MOUNT" ]; then
    echo "$SERVICE_FILES_MOUNT does not exist. Is the volume configured?"
    exit 1
fi

# link to mounted track data
rm -f data
ln -s $SERVICE_FILES_MOUNT data

# need to copy the config.json file and fix paths; monitor this file and refresh if it is modified
runConfigRefresherThread() {
  while true; do
    timestamp=`date`
    echo -n "$timestamp Checking config.json... "
    newModDate=`stat -c %y data/config.json`
    if [ "$newModDate" != "$modDate" ]; then
      sed 's|uri": "|uri": "data/|' data/config.json > config.json.new
      mv config.json.new config.json # more atomic than sed
      modDate=$newModDate
      echo "modified.  Updated."
    else
      echo "unmodified."
    fi
    sleep $CONFIG_JSON_CHECK_INTERVAL_SECS
  done
}

gracefulShutdown() {
    log=/opt/logs/exit-catch.log
    echo ""
    echo "Found nginx PID to be: $(cat /var/run/nginx.pid)" > $log
    echo "Shutting down nginx..." >> $log
    /etc/init.d/nginx -s stop >> $log
    for attempts in $(seq 1 20); do
	nginxPid=$(cat /var/run/nginx.pid 2>/dev/null)
	echo "nginx PID = ${nginxPid}" >> $log
	if [ -z "$nginxPid" ]; then
	    echo "nginx gracefully shut down." >> $log
	    exit 0
	fi
	sleep 2
    done
    echo "nginx shutdown will be forced." >> $log exit 1
}

runConfigRefresherThread &

echo "hello" > /opt/logs/silly

echo "Starting up nginx"
#npx serve -S -p $JBROWSE2_SERVER_PORT .
/etc/init.d/nginx start \
&& echo "nginx running..." \
&& tail -f /dev/null & wait ${!}

