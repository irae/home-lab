# Dozzle: observation without stack control

A log and container viewer for checking the lab without turning the web UI into
a deployment console. Simple authentication is enabled. Stack/Docker changes remain a deliberate operation over SSH.

## Design and limits

Most of those traits are designs from Dozzle itself, and my installation was hardened with IA help, to fulfill the requirements of this repo being public while making it as secure as possible. My services are only exposed to LAN and Wireguard Tailnet, thus this is a second tier protection, besides host firewall.

[Compose](compose.yaml) gives Dozzle access to Docker through `socket-proxy`, not
a direct socket mount. The proxy is on an internal Docker network and has no
published port. Its configured API policy enables container/log inspection,
info, events, ping, and version, and disables POST, exec, archive, export, and
other API categories. Dozzle's action, shell, MCP, and setup-wizard features are
also disabled in the environment so UI configuration cannot enable them.

Dozzle runs as UID/GID 1000 with a read-only root filesystem, all capabilities
dropped, and `no-new-privileges`. Its data directory is still writable. The proxy
itself holds the Docker socket: the `:ro` socket mount is not an API authorization
boundary, so the proxy's request filtering and isolation remain important. Logs
and container metadata can contain sensitive information even without write
access to Docker.

## Deploy

Port 5001 has no host-address restriction in Compose; it is not a Tailscale-only
listener. Authentication has no rate limit in this setup. Check network exposure
and use a long random password; this is not intended as a public log endpoint.

`/data/volumes/dozzle` holds `users.yml` (bcrypt hash) and Dozzle user settings.
Keep it outside Git and preserve ownership/access when restoring it.

If migrating an older deployment that still has Dockge, stop it using its
original Compose project before removing that checkout. Do not assume deleting a
stack directory stops its containers. The current repo has no Dockge stack.

For a new installation, as `irae`, follow the steps below. On an existing
installation, preserve `users.yml` rather than overwriting it during updates.

1. Create the users file. Use a long random password; the login has no rate limit.
   Do not add `-t`. With `-t`, the password prompt is written into `users.yml`.
   ```bash
   mkdir -p /data/volumes/dozzle
   read -rs password
   printf '%s\n' "$password" | docker run -i --rm amir20/dozzle:latest generate <user> --user-roles none > /data/volumes/dozzle/users.yml
   unset password
   ```
   The file must start with `users:` and the password field must be a bcrypt hash. Do not print the file.
   ```bash
   awk '
   { sub(/\r$/, "") }
   NR == 1 { ok = ($0 == "users:") }
   $1 == "password:" && $2 ~ /^\$2[aby]\$/ { hash = 1 }
   $0 == "Password:" { bad = 1 }
   END { exit !(ok && hash && !bad) }
   ' /data/volumes/dozzle/users.yml
   ```
2. Start the stack:
   `cd /data/stacks/dozzle && docker compose up -d`

If migrating from Dockge, retain its data until you have checked for work you
need; remove the old volume only deliberately.

## Update

The image timer pulls both images. By hand:

```bash
cd /data/stacks/dozzle
docker compose pull
docker compose up -d
```

After deployment or an image update, check that login is required, expected logs
are visible, and action/shell controls remain unavailable. Inspect the effective
proxy policy if its image changes; a successful container start does not verify
API filtering. Preserve the users file and keep credentials/log contents out of
shared diagnostic output.
