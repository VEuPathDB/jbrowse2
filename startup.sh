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

# need to copy the config.json file and fix paths
sed 's|uri": "|uri": "data/|' data/config.json > config.json

echo "Starting up node server on port $JBROWSE2_SERVER_PORT"
npx serve -S -p $JBROWSE2_SERVER_PORT .
