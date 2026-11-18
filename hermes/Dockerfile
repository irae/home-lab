FROM nousresearch/hermes-agent:latest

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server \
 && rm -rf /var/lib/apt/lists/*

COPY --from=sshkeys /authorized_keys /etc/ssh/authorized_keys
COPY --from=sshd /sshd-run.sh /usr/local/bin/sshd-run.sh
COPY --chmod=755 ssh-shell.sh /usr/local/bin/ssh-shell
COPY --chmod=644 root-shell-warning.sh /usr/local/share/root-shell-warning.sh

RUN chmod 644 /etc/ssh/authorized_keys \
 && chmod 755 /usr/local/bin/sshd-run.sh \
 && mkdir -p /etc/s6-overlay/s6-rc.d/sshd \
 && printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/sshd/type \
 && printf '#!/bin/sh\nexport SSHD_ALLOW_USERS=hermes SSHD_PERMIT_ROOT_LOGIN=no\nexec /usr/local/bin/sshd-run.sh\n' > /etc/s6-overlay/s6-rc.d/sshd/run \
 && chmod 755 /etc/s6-overlay/s6-rc.d/sshd/run \
 && touch /etc/s6-overlay/s6-rc.d/user/contents.d/sshd \
 && test -x /command/s6-envdir \
 && printf 'export PATH="%s"\n' "$PATH" > /etc/profile.d/hermes-path.sh \
 && usermod --password x --shell /usr/local/bin/ssh-shell hermes \
 && printf '\n. /usr/local/share/root-shell-warning.sh\n' >> /etc/bash.bashrc

RUN mkdir -p /etc/s6-overlay/s6-rc.d/t3/dependencies.d \
 && printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/t3/type \
 && touch /etc/s6-overlay/s6-rc.d/t3/dependencies.d/base \
          /etc/s6-overlay/s6-rc.d/user/contents.d/t3
COPY --chmod=755 t3-run.sh /etc/s6-overlay/s6-rc.d/t3/run

ADD https://github.com/pingdotgg/t3code/releases/latest/download/SHA256SUMS /tmp/t3-SHA256SUMS
RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
      amd64) arch=x64 ;; \
      arm64) arch=arm64 ;; \
      *) echo 'No T3 release archive for this architecture' >&2; exit 1 ;; \
    esac; \
    archive="$(grep -Eo "t3-[0-9]+\.[0-9]+\.[0-9]+-linux-${arch}\.tar\.gz$" /tmp/t3-SHA256SUMS)"; \
    version="${archive#t3-}"; \
    cd /tmp; \
    curl -fsSL --retry 3 "https://github.com/pingdotgg/t3code/releases/download/v${version%-linux-*}/${archive}" -o "$archive"; \
    sha256sum --check --ignore-missing t3-SHA256SUMS; \
    mkdir -p /opt/t3; \
    tar -xzf "$archive" -C /opt/t3 --strip-components=1; \
    ln -s /opt/t3/t3 /usr/local/bin/t3; \
    rm "$archive" t3-SHA256SUMS; \
    /usr/local/bin/t3 --version
