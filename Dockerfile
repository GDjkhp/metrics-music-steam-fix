# Base image
FROM node:20-bookworm-slim

# Chrome is installed from apt below, so puppeteer must never download its own Chromium
# (these must be set BEFORE `npm ci`, otherwise the postinstall script downloads ~150MB for nothing)
ENV PUPPETEER_SKIP_DOWNLOAD true
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
ENV PUPPETEER_BROWSER_PATH "google-chrome-stable"

WORKDIR /metrics

# System dependencies (does not depend on repository content, so this layer is cached)
RUN \
  # Install latest chrome dev package, fonts to support major charsets
  # Based on https://github.com/GoogleChrome/puppeteer/blob/master/docs/troubleshooting.md#running-puppeteer-in-docker
  apt-get update \
  && apt-get install -y wget gnupg ca-certificates libgconf-2-4 \
  && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
  && apt-get update \
  && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 libx11-xcb1 libxtst6 lsb-release --no-install-recommends \
  # Install deno for miscellaneous scripts
  && apt-get install -y curl unzip \
  && curl -fsSL https://deno.land/x/install/install.sh | DENO_INSTALL=/usr/local sh \
  # Install ruby to support github licensed gem
  # xz-utils (xzcat), zlib1g-dev and liblzma-dev are needed when nokogiri (a licensed dependency) compiles its bundled libxml2 from source
  && apt-get install -y ruby-full git g++ cmake make patch pkg-config libssl-dev xz-utils zlib1g-dev liblzma-dev \
  && gem install licensed --no-document \
  # Install python for node-gyp
  && apt-get install -y python3 \
  # Clean apt/lists
  && rm -rf /var/lib/apt/lists/*

# Node modules (only rebuilt when package.json or package-lock.json change, which is the slow part)
COPY package.json package-lock.json ./
RUN npm ci

# Copy repository and rebuild indexes
COPY . /metrics
RUN chmod +x /metrics/source/app/action/index.mjs \
  && npm run build

# Execute GitHub action
ENTRYPOINT node /metrics/source/app/action/index.mjs