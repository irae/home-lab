FROM debian:trixie

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    fd-find \
    ghostscript \
    git \
    git-delta \
    git-extras \
    jq \
    mupdf-tools \
    openssh-client \
    openssh-server \
    poppler-utils \
    python3 \
    python3-pdfminer \
    python3-pikepdf \
    python3-pymupdf \
    python3-pypdf \
    python3-venv \
    qpdf \
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
 && ln -sf "$node_bin/pi" /usr/local/bin/pi \
 && ln -sf /usr/bin/fdfind /usr/local/bin/fd

RUN mkdir -p /usr/share/omarchy/default/bash \
 && touch /usr/share/omarchy/default/bash/rc \
 && printf 'umask 077\n' > /etc/profile.d/umask.sh \
 && printf '\numask 077\n' >> /etc/bash.bashrc \
 && groupadd --gid 1000 haku \
 && useradd --uid 1000 --gid 1000 --home-dir /home/haku --create-home --shell /bin/bash haku \
 && usermod --password x haku

COPY --from=dotfiles . /opt/dotfiles
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY sshd-run.sh /usr/local/bin/sshd-run.sh
COPY --from=sshkeys /authorized_keys /etc/ssh/authorized_keys
COPY --chmod=644 root-shell-warning.sh /usr/local/share/root-shell-warning.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh /usr/local/bin/sshd-run.sh \
 && chown root:root /etc/ssh/authorized_keys \
 && chmod 644 /etc/ssh/authorized_keys \
 && printf '\n. /usr/local/share/root-shell-warning.sh\n' >> /etc/bash.bashrc \
 && chmod -R a+rX /opt/dotfiles \
 && chown -R haku:haku /home/haku /opt/dotfiles

USER 1000:1000
WORKDIR /home/haku
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
