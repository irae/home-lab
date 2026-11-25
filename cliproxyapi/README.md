# CLIProxyAPI

Centralized OAuth and API-key gateway on `sheeta`, using the upstream-published
`eceasy/cli-proxy-api:latest` image. Upstream does not define an application user
in the image. The local Compose override runs it as UID/GID `1000:1000`
with dropped capabilities so it can write to the private data directory without
running as root. The directory `/data/volumes/cliproxyapi` stores `config.yaml`,
OAuth credentials, `kv.db`, logs, and the management panel.

## Deploy and access

Create the data directory once as root (or as `irae` if `/data/volumes` allows):

```bash
install -d -m 0700 -o 1000 -g 1000 /data/volumes/cliproxyapi /data/volumes/cliproxyapi/auth /data/volumes/cliproxyapi/static
```

Place `config.yaml` (mode `0600`, owned `1000:1000`) at
`/data/volumes/cliproxyapi/config.yaml`. Keep `server.host: ""` inside the
container so Docker's loopback publish (`127.0.0.1:8317:8317`) can reach it,
and set `oauth.auth-dir: "/data/auth"`. To use the management UI through
Tailscale Serve, set `management.allow-remote: true` and configure a strong
`management.secret-key`. Docker's host loopback bind does not make forwarded
requests local to the application inside the container.

Start the stack as `irae`:

```bash
cd /data/stacks/cliproxyapi
docker compose up -d --wait
curl --fail http://127.0.0.1:8317/healthz
```

Publish HTTPS on the tailnet once, as the Tailscale operator or root:

```bash
tailscale serve --bg --https=8317 http://127.0.0.1:8317
tailscale serve status
```

Docker publishes port `8317` on loopback only so it can restart before
Tailscale is ready. Tailscale Serve terminates HTTPS on port `8317` and
forwards to `127.0.0.1:8317`.

- Proxy base URL: `https://<sheeta-tailnet-name>:8317`
- Management UI: `https://<sheeta-tailnet-name>:8317/management.html`

Provider OAuth logins can be completed from the Management UI or via CLI inside
the container:

```bash
docker compose exec cliproxyapi /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser -claude-login
docker compose exec cliproxyapi /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser -codex-login
docker compose exec cliproxyapi /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser -xai-login
docker compose exec cliproxyapi /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser -antigravity-login
```

## Updates and backups

The [host image timer](../host/README.md#image-update-workflow) pulls the
upstream `:latest` tag daily and recreates the container when the image changes.
This can include major-version upgrades. To update immediately as `irae`:

```bash
cd /data/stacks/cliproxyapi
docker compose pull
docker compose up -d --wait
```

For a backup, stop the container with `docker compose stop`, back up
`/data/volumes/cliproxyapi` privately (it contains OAuth tokens, client API
keys, and the hashed management key), and start it again with
`docker compose up -d --wait`.
