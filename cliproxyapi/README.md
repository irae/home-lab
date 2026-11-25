# CLIProxyAPI

OAuth and API-key gateway using the upstream `eceasy/cli-proxy-api:latest`
image. All state (`config.yaml`, OAuth credentials, `kv.db`, logs, and the
management UI) lives in `/data/volumes/cliproxyapi`.

## Setup

1. Create the private data directories:

```bash
install -d -m 0700 -o 1000 -g 1000 \
  /data/volumes/cliproxyapi \
  /data/volumes/cliproxyapi/auth \
  /data/volumes/cliproxyapi/static
```

2. Copy [`config.yaml.sample`](config.yaml.sample) and replace the two key
placeholders with freshly generated secrets:

```bash
install -m 0600 -o 1000 -g 1000 \
  /data/stacks/cliproxyapi/config.yaml.sample \
  /data/volumes/cliproxyapi/config.yaml

openssl rand -hex 16              # management.secret-key (save it; hashed on first start)
echo "sk-cliproxy-$(openssl rand -hex 16)"   # access.api-keys entry
```

Edit `/data/volumes/cliproxyapi/config.yaml` with the two generated keys (and
any optional routing/model settings).

3. Start the container and verify health:

```bash
cd /data/stacks/cliproxyapi
docker compose up -d --wait
curl --fail http://127.0.0.1:5009/healthz
```

4. Publish HTTPS on the tailnet once (as Tailscale operator or root):

```bash
tailscale serve --bg --https=5009 http://127.0.0.1:5009
tailscale serve status
```

- Proxy base URL: `https://<tailnet-host>:5009`
- Management UI: `https://<tailnet-host>:5009/management.html`

5. Sign in to the Management UI with your `management.secret-key` to add
providers, or run headless OAuth logins inside the container:

```bash
docker compose exec cliproxyapi /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser -claude-login
docker compose exec cliproxyapi /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser -codex-login
docker compose exec cliproxyapi /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser -xai-login
docker compose exec cliproxyapi /CLIProxyAPI/CLIProxyAPI -config /data/config.yaml -no-browser -antigravity-login
```

## Updates and backups

The [host image timer](../host/README.md#image-update-workflow) updates
`:latest` daily (including major versions). To update manually:

```bash
cd /data/stacks/cliproxyapi
docker compose pull
docker compose up -d --wait
```

To back up, stop the container (`docker compose stop`), copy
`/data/volumes/cliproxyapi` privately, and start it again
(`docker compose up -d --wait`).
