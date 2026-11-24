#!/usr/bin/env bash
set -euo pipefail

root=/data/volumes/forgejo-deploy
config=$root/config.json
keys=$root/keys

usage() {
  echo "usage: $0 add <app> <absolute-command> | remove <app> | list" >&2
  exit 2
}

[ -f "$config" ] || { echo "forgejo-deploy is not installed; run install-user.sh first" >&2; exit 1; }

case ${1:-} in
  add)
    [ "$#" -eq 3 ] || usage
    app=$2
    command=$3
    [[ $app =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "invalid app name: $app" >&2; exit 1; }
    [[ $command = /* ]] && [ -x "$command" ] || { echo "command must be an executable absolute path: $command" >&2; exit 1; }
    install -d -m 0700 "$keys"
    token=$(openssl rand -hex 32)
    printf '%s\n' "$token" > "$keys/$app"
    chmod 0600 "$keys/$app"
    tmp=$(mktemp "$root/config.XXXXXX")
    jq --arg app "$app" --arg key "$keys/$app" --arg command "$command" \
      '.apps[$app] = {keyFile:$key, command:[$command], timeoutMs:1800000}' "$config" > "$tmp"
    chmod 0600 "$tmp"
    mv "$tmp" "$config"
    systemctl --user restart forgejo-deploy.service
    for _ in $(seq 1 20); do
      if curl --silent --fail --unix-socket "$root/run/server.sock" http://localhost/healthz >/dev/null; then
        printf '%s\n' "$token"
        exit 0
      fi
      sleep 0.25
    done
    systemctl --user status forgejo-deploy.service --no-pager
    exit 1
    ;;
  remove)
    [ "$#" -eq 2 ] || usage
    app=$2
    tmp=$(mktemp "$root/config.XXXXXX")
    jq --arg app "$app" 'del(.apps[$app])' "$config" > "$tmp"
    chmod 0600 "$tmp"
    mv "$tmp" "$config"
    rm -f "$keys/$app"
    systemctl --user restart forgejo-deploy.service
    for _ in $(seq 1 20); do
      curl --silent --fail --unix-socket "$root/run/server.sock" http://localhost/healthz >/dev/null && exit 0
      sleep 0.25
    done
    systemctl --user status forgejo-deploy.service --no-pager
    exit 1
    ;;
  list)
    [ "$#" -eq 1 ] || usage
    jq -r '.apps | to_entries[] | [.key, .value.command[0]] | @tsv' "$config"
    ;;
  *) usage ;;
esac
