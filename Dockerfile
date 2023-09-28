FROM nginx:latest

ENV DEBIAN_FRONTEND noninteractive
#RUN mkdir -p /usr/share/man/man1 /usr/share/man/man7

# basic system dependencies
RUN apt-get -qq update --fix-missing \
    && apt-get --no-install-recommends -y install zip unzip wget curl software-properties-common git build-essential zlib1g-dev libpng-dev perl-doc ca-certificates libjson-perl samtools tabix

#    && curl -fsSL https://deb.nodesource.com/setup_14.x | bash -

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

# install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install

# install JBrowse2
RUN npm install -g @jbrowse/cli serve
RUN jbrowse create --tag v2.6.3 jbrowse2

# copy and run startup script
COPY startup.sh .
CMD ./startup.sh
