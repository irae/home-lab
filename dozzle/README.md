# dozzle

Read-only log and container viewer. Host port `5001`; container port `8080`. Login is required (simple auth).

Dozzle reaches Docker only through `socket-proxy`, on an internal network. The proxy allows GET requests for containers, logs, info, events, ping, and version. It blocks POST, exec, archive, export, and all other API calls. You cannot start, stop, or edit stacks here. Use SSH.

`/data/volumes/dozzle` holds `users.yml` (bcrypt hash) and Dozzle user settings. It is not in git.

## Deploy

As `irae`, after `git pull` in `/data/stacks`:

1. Create the users file. Use a long random password; the login has no rate limit.
   ```bash
   mkdir -p /data/volumes/dozzle
   docker run -it --rm amir20/dozzle:latest generate <user> --user-roles none > /data/volumes/dozzle/users.yml
   ```
2. Stop and remove the old Dockge stack, which holds port 5001:
   `docker compose -p dockge down`
3. Start the stack:
   `cd /data/stacks/dozzle && docker compose up -d`

`/data/volumes/dockge` is no longer used. Remove it when you no longer need it.

## Update

The image timer pulls both images. By hand:

```bash
cd /data/stacks/dozzle
docker compose pull
docker compose up -d
```
