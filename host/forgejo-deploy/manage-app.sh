#!/usr/bin/env bash
set -euo pipefail

root=/data/volumes/forgejo-deploy
config=$root/config.json
keys=$root/keys

usage() {
  echo "usage: $0 set <app> <absolute-command> | remove <app> | list" >&2
  echo "set reads the application API key from standard input" >&2
  exit 2
}

wait_for_service() {
  for _ in $(seq 1 20); do
    curl --silent --fail http://127.0.0.1:5008/healthz >/dev/null && return 0
    sleep 0.25
  done
  systemctl --user status forgejo-deploy.service --no-pager
  return 1
}

[ -f "$config" ] || { echo "forgejo-deploy is not installed; run install-user.sh first" >&2; exit 1; }

case ${1:-} in
  set)
    [ "$#" -eq 3 ] || usage
    app=$2
    command=$3
    [[ $app =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "invalid app name: $app" >&2; exit 1; }
    [[ $command = /* ]] && [ -x "$command" ] || { echo "command must be an executable absolute path: $command" >&2; exit 1; }
    IFS= read -r token
    [ -n "$token" ] || { echo "empty API key" >&2; exit 1; }
    install -d -m 0700 "$keys"
    printf '%s' "$token" > "$keys/$app"
    chmod 0600 "$keys/$app"
    tmp=$(mktemp "$root/config.XXXXXX")
    jq --arg app "$app" --arg key "$keys/$app" --arg command "$command" \
      '.apps[$app] = {keyFile:$key, command:[$command], timeoutMs:1800000}' "$config" > "$tmp"
    chmod 0600 "$tmp"
    mv "$tmp" "$config"
    systemctl --user restart forgejo-deploy.service
    wait_for_service
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
    wait_for_service
    ;;
  list)
    [ "$#" -eq 1 ] || usage
    jq -r '.apps | to_entries[] | [.key, .value.command[0]] | @tsv' "$config"
    ;;
  *) usage ;;
esac
