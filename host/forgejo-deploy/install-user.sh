#!/usr/bin/env bash
set -euo pipefail

root=/data/volumes/forgejo-deploy
unit_source=/data/stacks/host/forgejo-deploy/forgejo-deploy.service
unit_dir=$HOME/.config/systemd/user
unit=$unit_dir/forgejo-deploy.service

major=$(node -p 'Number(process.versions.node.split(".")[0])')
[ "$major" -ge 26 ] || { echo "forgejo-deploy requires Node 26 or newer" >&2; exit 1; }

install -d -m 0700 "$root" "$root/keys" "$root/state" "$unit_dir"
if [ ! -f "$root/config.json" ]; then
  printf '%s\n' '{"apps":{}}' > "$root/config.json"
  chmod 0600 "$root/config.json"
fi

install -m 0644 "$unit_source" "$unit"
systemd-analyze --user verify "$unit"
systemctl --user daemon-reload
systemctl --user enable forgejo-deploy.service
systemctl --user restart forgejo-deploy.service

for _ in $(seq 1 20); do
  if curl --silent --fail http://127.0.0.1:5008/healthz >/dev/null; then
    systemctl --user is-enabled forgejo-deploy.service
    systemctl --user is-active forgejo-deploy.service
    exit 0
  fi
  sleep 0.25
done

systemctl --user status forgejo-deploy.service --no-pager
exit 1
