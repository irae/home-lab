#!/bin/sh
set -eu
mkdir -p /run/sshd /tmp/ssh-hostkeys
chmod 755 /run/sshd
for type in ed25519 rsa; do
    if [ ! -f "/tmp/ssh-hostkeys/ssh_host_${type}_key" ]; then
        ssh-keygen -q -t "$type" -N '' -f "/tmp/ssh-hostkeys/ssh_host_${type}_key"
    fi
done
exec /usr/sbin/sshd -D -e -o PidFile=/tmp/sshd.pid \
    -o HostKey=/tmp/ssh-hostkeys/ssh_host_ed25519_key \
    -o HostKey=/tmp/ssh-hostkeys/ssh_host_rsa_key \
    -o AuthorizedKeysFile=/etc/ssh/authorized_keys \
    -o PasswordAuthentication=no \
    -o KbdInteractiveAuthentication=no \
    -o PermitRootLogin=prohibit-password \
    -o AllowUsers=root \
    -o UsePAM=no
