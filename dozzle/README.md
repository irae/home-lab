# dozzle

Read-only log and container viewer. Host port `5001`; container port `8080`. Login is required (simple auth).

Dozzle reaches Docker only through `socket-proxy`, on an internal network. The proxy allows GET requests for containers, logs, info, events, ping, and version. It blocks POST, exec, archive, export, and all other API calls. You cannot start, stop, or edit stacks here. Use SSH.

`/data/volumes/dozzle` holds `users.yml` (bcrypt hash) and Dozzle user settings. It is not in git.

## Deploy

For the first deploy, stop Dockge before you update `/data/stacks`. The update removes `dockge/`. As `irae`, run:

```bash
cd /data/stacks/dockge && docker compose down
```

Stop if this fails. After the checkout update, as `irae`:

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

`/data/volumes/dockge` is no longer used. Remove it when you no longer need it.

## Update

The image timer pulls both images. By hand:

```bash
cd /data/stacks/dozzle
docker compose pull
docker compose up -d
```
