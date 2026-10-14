# JBrowse 5 plus the VEuPathDB plugins, served as static files by nginx.
#
# Two stages: the builder fetches a JBrowse release and builds each plugin from
# source; the runtime carries neither node nor a package manager, only nginx and
# the files it serves.

FROM node:22-bookworm AS builder

# JBrowse 5 has no GitHub release yet -- the CLI skips prereleases when it
# resolves "latest", and `--tag v5.0.0-beta.x` 404s because no such release
# exists. `--nightly` builds from main. REPLACE THIS WITH A PINNED --tag THE DAY
# v5 SHIPS: a nightly is not a thing to run in production, and the only reason
# it is here is that GMOD has not yet given us an alternative.
ARG JBROWSE_RELEASE_FLAG="--nightly"

RUN npm install -g @jbrowse/cli@next \
    && jbrowse create /jbrowse ${JBROWSE_RELEASE_FLAG} \
    && rm -rf /jbrowse/test_data

# Each plugin is built from a pinned ref rather than a branch name, so an image
# rebuild cannot quietly pick up a different plugin than the one that was
# tested. Bump these deliberately.
ARG SUBTRACK_PLUGIN_REPO="https://github.com/VEuPathDB/jbrowse-plugin-subtrack-renderer.git"
ARG SUBTRACK_PLUGIN_REF="main"

RUN corepack enable \
    && git clone "${SUBTRACK_PLUGIN_REPO}" /src/subtrack \
    && git -C /src/subtrack checkout "${SUBTRACK_PLUGIN_REF}" \
    && cd /src/subtrack \
    && pnpm install --frozen-lockfile \
    && pnpm build \
    && mkdir -p /jbrowse/plugins \
    && cp dist/*.umd.production.min.js /jbrowse/plugins/

# What this image actually contains, readable from the running container and
# from the served site. A deployment that cannot say which JBrowse and which
# plugin commit it is running is one nobody can debug from the outside.
RUN printf '%s\n' \
      "jbrowse_release_flag=${JBROWSE_RELEASE_FLAG}" \
      "jbrowse_version=$(cat /jbrowse/version.txt 2>/dev/null || echo unknown)" \
      "subtrack_plugin_ref=$(git -C /src/subtrack rev-parse HEAD)" \
      "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > /jbrowse/build-info.txt

# The plugin list this image can serve. The container merges it into whatever
# config.json the data mount supplies, so the workflow that writes config.json
# does not need to know which plugins are baked in or where they live.
COPY plugins.json /jbrowse/plugins.json


FROM nginx:1.27

RUN apt-get -qq update \
    && apt-get --no-install-recommends -y install jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /jbrowse /usr/share/nginx/html
COPY conf/jbrowse.conf.template /etc/nginx/templates/default.conf.template
COPY startup.sh /startup.sh

ENV JBROWSE2_SERVER_PORT=8080 \
    SERVICE_FILES_MOUNT=/data \
    CONFIG_JSON_CHECK_INTERVAL_SECS=30

CMD ["/startup.sh"]
