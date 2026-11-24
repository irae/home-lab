FROM node:26-trixie

ENV DEBIAN_FRONTEND=noninteractive \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      docker-buildx \
      docker-cli \
      docker-compose \
      fd-find \
      git \
      git-lfs \
      jq \
      less \
      openssh-client \
      openssl \
      pkg-config \
      procps \
      python-is-python3 \
      python3 \
      python3-pip \
      python3-venv \
      ripgrep \
      rsync \
      shellcheck \
      sqlite3 \
      tar \
      unzip \
      wget \
      zip \
      zstd \
    && npm install --global @playwright/cli@0.1.25 \
    && node /usr/local/lib/node_modules/@playwright/cli/node_modules/playwright/cli.js install --with-deps chromium \
    && rm -rf /var/lib/apt/lists/*
