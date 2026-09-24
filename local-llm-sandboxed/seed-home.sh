#!/bin/sh
set -eu
umask 077
rm -rf /mnt/home/.dotfiles
cp -R /home/haku/.dotfiles /mnt/home/.dotfiles
if [ ! -e /mnt/home/.pi/agent/models.json ]; then
  mkdir -p /mnt/home/.pi/agent
  cp /home/haku/.pi/agent/models.json /mnt/home/.pi/agent/models.json
fi
cd /mnt/home/.dotfiles
stow bash
stow git
stow bin
stow agents
