#!/bin/sh
set -eu
mkdir -p /run/sshd /var/lib/ssh-hostkeys
chmod 755 /run/sshd
for type in ed25519 rsa; do
    if [ ! -f "/var/lib/ssh-hostkeys/ssh_host_${type}_key" ]; then
        ssh-keygen -q -t "$type" -N '' -f "/var/lib/ssh-hostkeys/ssh_host_${type}_key"
    fi
done
chown root:root /var/lib/ssh-hostkeys /var/lib/ssh-hostkeys/ssh_host_*
chmod 700 /var/lib/ssh-hostkeys
chmod 600 /var/lib/ssh-hostkeys/ssh_host_*_key
chmod 644 /var/lib/ssh-hostkeys/ssh_host_*.pub
exec /usr/sbin/sshd -D -e -o PidFile=/tmp/sshd.pid \
    -o HostKey=/var/lib/ssh-hostkeys/ssh_host_ed25519_key \
    -o HostKey=/var/lib/ssh-hostkeys/ssh_host_rsa_key \
    -o AuthorizedKeysFile=/etc/ssh/authorized_keys \
    -o PasswordAuthentication=no \
    -o KbdInteractiveAuthentication=no \
    -o PermitRootLogin=prohibit-password \
    -o AllowUsers=root \
    -o UsePAM=no
