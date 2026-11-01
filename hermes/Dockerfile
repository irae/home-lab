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
