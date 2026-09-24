FROM debian:trixie

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    git-delta \
    git-extras \
    jq \
    openssh-client \
    python3 \
    python3-venv \
    ripgrep \
    stow \
 && rm -rf /var/lib/apt/lists/*

ENV NVM_DIR=/usr/local/nvm
RUN mkdir -p "$NVM_DIR" \
 && curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | NVM_DIR=/usr/local/nvm bash \
 && . "$NVM_DIR/nvm.sh" \
 && nvm install 24 \
 && nvm alias default 24 \
 && npm install -g npm@latest \
 && npm install -g --ignore-scripts @earendil-works/pi-coding-agent \
 && node_bin="$(dirname "$(nvm which current)")" \
 && ln -sf "$node_bin/node" /usr/local/bin/node \
 && ln -sf "$node_bin/npm" /usr/local/bin/npm \
 && ln -sf "$node_bin/npx" /usr/local/bin/npx \
 && ln -sf "$node_bin/pi" /usr/local/bin/pi

RUN mkdir -p /usr/share/omarchy/default/bash \
 && touch /usr/share/omarchy/default/bash/rc \
 && printf 'umask 077\n' > /etc/profile.d/umask.sh \
 && printf '\numask 077\n' >> /etc/bash.bashrc \
 && groupadd --gid 1000 haku \
 && useradd --uid 1000 --gid 1000 --home-dir /home/haku --create-home --shell /bin/bash haku

COPY --from=dotfiles . /opt/dotfiles
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh \
 && chmod -R a+rX /opt/dotfiles \
 && chown -R haku:haku /home/haku /opt/dotfiles

USER 1000:1000
WORKDIR /home/haku
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
