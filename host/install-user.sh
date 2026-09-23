#!/bin/bash
# There is no user-level image-update timer.
#
# This job walks every compose project on the box and talks to the Docker
# engine. It must fire at 04:30 even if irae is not logged in. That is a
# system timer, installed by install-root.sh as root.
#
# Linger is already yes for Herdr. We still do not put this in
# ~/.config/systemd/user/, because it is host-wide, not a personal session
# service.
#
# Run this script only to confirm you opened the right file. It installs
# nothing.

echo "install-user: this timer is a system unit, not a user unit"
echo "install-user: review /data/stacks/host/README.md"
echo "install-user: install with root: bash /data/stacks/host/install-root.sh"
echo "install-user: nothing was changed"
exit 0
