FROM nousresearch/hermes-agent:latest

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server \
 && usermod --password x root \
 && rm -rf /var/lib/apt/lists/*

COPY --from=sshkeys /authorized_keys /etc/ssh/authorized_keys
COPY --from=sshd /sshd-run.sh /usr/local/bin/sshd-run.sh

RUN chmod 644 /etc/ssh/authorized_keys \
 && chmod 755 /usr/local/bin/sshd-run.sh \
 && mkdir -p /etc/s6-overlay/s6-rc.d/sshd \
 && printf 'longrun\n' > /etc/s6-overlay/s6-rc.d/sshd/type \
 && ln -s /usr/local/bin/sshd-run.sh /etc/s6-overlay/s6-rc.d/sshd/run \
 && touch /etc/s6-overlay/s6-rc.d/user/contents.d/sshd
