# Forgejo

Private Git hosting on `sheeta`, using the official rootless Forgejo 15 LTS
image and SQLite. Git works over HTTP and Forgejo's built-in SSH. Actions,
self-registration, and anonymous repository access are disabled. New
repositories default to private.

## Deploy and access

On the host, as `irae`:

```bash
cd /data/stacks/forgejo
install -d -m 0700 /data/volumes/forgejo
(set -eu -o noclobber; umask 077
  host=$(tailscale status --json | jq -er '.Self.DNSName | rtrimstr(".")')
  ip=$(tailscale ip -4)
  printf 'FORGEJO_BIND_IP=%s\nFORGEJO_ROOT_URL=https://%s:5005/\n' \
    "$ip" "$host" > .env)
docker compose up -d --wait
```

Then publish HTTPS on the tailnet (run as root on the host once):

```bash
tailscale serve --bg --https=5005 http://127.0.0.1:4005
```

Create `.env` only on first setup. Its `FORGEJO_ROOT_URL` is the HTTPS web URL.
HTTP binds only to host loopback (`127.0.0.1:4005` → container `3000`) and is
terminated with TLS by `tailscale serve` on port `5005`. SSH binds to the
host's Tailscale IPv4 address (`FORGEJO_BIND_IP:2203` → container `22`), not
the LAN address. Without `.env`, Compose defaults SSH to loopback. If the
Tailscale IP changes or the bind fails at boot, check `.env` and rerun
`docker compose up -d --wait` after Tailscale is up.

Forgejo advertises SSH clone URLs as `git@forgejo:<owner>/<repo>.git`. Set
`Host forgejo` in the client's SSH config to reach `sheeta` as `git` on port
`2203`, then test with `ssh -T git@forgejo`. Docker still maps host port `2203`
to container port `22`. This endpoint is for Git, not shell access.

For a fresh database, create the first admin once from a private terminal:

```bash
docker compose exec forgejo forgejo admin user create --username irae \
  --email irae@sheeta.invalid --admin --random-password \
  --random-password-length 32 --must-change-password
```

Change the temporary password on first login and replace the placeholder email.

## Sync SSH keys

Forgejo stores SSH keys on the `irae` Forgejo account, not in the image. On
first setup and after changing `/home/irae/.ssh/authorized_keys`, create a
temporary **All (public, private, and limited)** access token scoped to
`write:user` under **Settings → Applications**. Run this on `sheeta` from the
stack directory and enter the token at the prompt:

```bash
python3 sync-ssh-keys.py --prune "http://$(docker compose port forgejo 3000)/"
```

Revoke the token afterward. The script adds missing keys and removes only stale
keys previously added by the script; it preserves separately enrolled keys.
If a revoked key was also enrolled separately, remove it in **Settings → SSH /
GPG Keys**. The sync accepts plain public keys and rejects OpenSSH lines with
per-key options, since Forgejo cannot enforce those restrictions.

## Updates and backups

The host image timer picks up updates within the Forgejo 15 LTS series. To apply
one manually, run `docker compose pull && docker compose up -d --wait` from this
directory. Review the [release notes](https://forgejo.org/releases/) before
changing the LTS series.

For a consistent filesystem backup, stop Forgejo with `docker compose stop`,
back up all of `/data/volumes/forgejo` (including SQLite, repositories, and
`custom/conf/app.ini` with its secrets), and start it again with
`docker compose up -d --wait`. Keep the backup private.
