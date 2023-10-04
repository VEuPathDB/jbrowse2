#!/usr/bin/env sh

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
runConfigRefresherThread &

echo "Starting up node server on port $JBROWSE2_SERVER_PORT"
npx serve -S -p $JBROWSE2_SERVER_PORT .
