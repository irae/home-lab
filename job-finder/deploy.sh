#!/usr/bin/env bash
set -euo pipefail
# The deploy service runs with UMask=0077; checkout files must stay readable
# by the image's non-root user after Docker COPY preserves their modes.
umask 022

sha=${FORGEJO_DEPLOY_SHA:-}
[[ $sha =~ ^[0-9a-f]{40}$ ]] || { echo "invalid FORGEJO_DEPLOY_SHA" >&2; exit 2; }

exec 9>/data/volumes/forgejo-deploy/job-finder.lock
flock -n 9 || { echo "job-finder deployment already running" >&2; exit 1; }

stack=/data/stacks/job-finder
app=$stack/app
data=/data/volumes/job-finder
backups=/data/volumes/job-finder-backups
state=/data/volumes/forgejo-deploy/state/job-finder.sha
new_image=job-finder:$sha
previous_image=
backup=
backup_tmp=
stopped=0
finished=0

recover() {
  [ "$stopped" -eq 1 ] || return 0
  echo "deployment failed; restoring previous Job Finder"
  docker compose -f "$stack/compose.yaml" stop job-finder >/dev/null 2>&1 || true
  if [ -n "$backup" ] && [ -f "$backup" ]; then
    find "$data" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    tar --zstd -xf "$backup" -C "$data"
  fi
  if [ -n "$previous_image" ]; then docker tag "$previous_image" job-finder:prod; fi
  docker compose -f "$stack/compose.yaml" up -d --no-build --wait job-finder
}

on_exit() {
  code=$?
  if [ "$code" -ne 0 ] && [ "$finished" -eq 0 ]; then recover || true; fi
  exit "$code"
}
trap on_exit EXIT

[ -z "$(git -C "$app" status --porcelain)" ] || { echo "Job Finder checkout is dirty" >&2; exit 1; }
git -C "$app" fetch --prune origin main
remote=$(git -C "$app" rev-parse origin/main)
if [ "$remote" != "$sha" ]; then
  echo "deployment $sha was superseded by $remote"
  finished=1
  exit 0
fi

git -C "$app" checkout main
git -C "$app" merge --ff-only "$sha"

docker build --pull -t "$new_image" "$app"
previous_image=$(docker image inspect job-finder:prod --format '{{.Id}}' 2>/dev/null || true)
[ -z "$previous_image" ] || docker tag "$previous_image" job-finder:rollback

install -d -m 0700 "$backups"
docker compose -f "$stack/compose.yaml" stop job-finder
stopped=1
backup=$backups/$(date -u +%Y%m%dT%H%M%SZ)-$sha.tar.zst
backup_tmp=$backup.tmp
tar --zstd -cf "$backup_tmp" -C "$data" .
mv "$backup_tmp" "$backup"

docker tag "$new_image" job-finder:prod
docker compose -f "$stack/compose.yaml" up -d --no-build --wait job-finder
curl --fail --silent --show-error http://127.0.0.1:5007/api/status >/dev/null

printf '%s\n' "$sha" > "$state"
chmod 0600 "$state"
ls -1t "$backups"/*.tar.zst 2>/dev/null | tail -n +4 | xargs -r rm --
finished=1
trap - EXIT
echo "deployed job-finder $sha"
