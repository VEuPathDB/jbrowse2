# Based on the GMOD project sample Dockerfile here:
#   https://github.com/GMOD/jbrowse_docker/blob/main/Dockerfile.jb2_env

FROM nginx:latest

# basic system dependencies
RUN apt-get -qq update --fix-missing \
    && apt-get --no-install-recommends -y install zip unzip wget curl software-properties-common git build-essential zlib1g-dev libpng-dev perl-doc ca-certificates libjson-perl samtools tabix

# install nvm/node/npm
ENV NVM_DIR /root/.nvm
ENV NODE_VERSION 20.7.0

# Install nvm with node and npm
RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

ENV NODE_PATH $NVM_DIR/versions/node/v$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# install JBrowse2
RUN npm install -g @jbrowse/cli serve
RUN jbrowse create --tag v2.6.3 jbrowse2

# copy and run startup script
COPY startup.sh .
CMD ./startup.sh
