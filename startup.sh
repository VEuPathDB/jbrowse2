#!/usr/bin/env sh

cd jbrowse2
rm -rf test_data
ln -s $SERVICE_FILES_MOUNT data
echo "Starting up node server on port $JBROWSE2_SERVER_PORT"
npx serve -S -p $JBROWSE2_SERVER_PORT
