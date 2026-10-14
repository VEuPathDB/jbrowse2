#!/usr/bin/env bash
# Publishes the mounted config.json into the served directory, with this
# image's plugins merged in, and keeps doing so while the file changes.
#
# The merge is why the workflow that writes config.json does not have to know
# which plugins this image carries, or what path they sit at. It names tracks;
# the container names its own plugins.

set -euo pipefail

SERVED=/usr/share/nginx/html
MOUNTED="$SERVICE_FILES_MOUNT/config.json"

if [ ! -d "$SERVICE_FILES_MOUNT" ]; then
    echo "$SERVICE_FILES_MOUNT does not exist. Is the volume configured?" >&2
    exit 1
fi

publishConfig() {
    if [ ! -r "$MOUNTED" ]; then
        echo "no readable config.json at $MOUNTED" >&2
        return 1
    fi
    # Written beside the target and moved, so nginx never serves a half-written
    # config to a browser that happens to ask mid-update.
    # Image plugins first: unique_by keeps the first of each name, so a stale
    # entry in a mounted config loses to the bundle this image actually ships.
    jq --slurpfile plugins "$SERVED/plugins.json" \
       '.plugins = ($plugins[0] + (.plugins // []) | unique_by(.name))' \
       "$MOUNTED" > "$SERVED/.config.json.new"
    mv "$SERVED/.config.json.new" "$SERVED/config.json"
}

watchConfig() {
    local modDate=""
    while true; do
        newModDate=$(stat -c %y "$MOUNTED" 2>/dev/null || echo missing)
        if [ "$newModDate" != "$modDate" ]; then
            if publishConfig; then
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) config.json published"
                modDate=$newModDate
            fi
        fi
        sleep "$CONFIG_JSON_CHECK_INTERVAL_SECS"
    done
}

publishConfig || echo "starting without a config; will pick one up when it appears" >&2
watchConfig &

cat "$SERVED/build-info.txt" 2>/dev/null || true

# envsubst over the template, then nginx in the foreground as PID 1's child --
# the stock nginx entrypoint does the first part for files in /etc/nginx/templates.
exec /docker-entrypoint.sh nginx -g 'daemon off;'
