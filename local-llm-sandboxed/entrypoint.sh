#!/bin/sh
set -eu
umask 077
if [ ! -e /home/haku/.dotfiles ]; then
  cp -R /opt/dotfiles-seed /home/haku/.dotfiles
  mkdir -p /home/haku/.pi/agent
  if [ ! -e /home/haku/.pi/agent/models.json ]; then
    cp /opt/models.json /home/haku/.pi/agent/models.json
  fi
  cd /home/haku/.dotfiles
  stow bash
  stow git
  stow bin
  stow agents
fi
exec "$@"
