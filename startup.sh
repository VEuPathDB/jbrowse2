#/bin/bash

cd jbrowse2
rm -r test_data
ln -s $SERVICE_FILES_MOUNT data
npx serve -S -p $JBROWSE2_SERVER_PORT
