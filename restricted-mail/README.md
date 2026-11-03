# restricted-mail

HTTP server that gives other containers read-only access to an allowlist of Fastmail mail. On this host the published port is `5002`. Other containers use `http://restricted-mail:8080`.

The checkout is `/data/stacks/restricted-mail/app`, owned by root, and it is a separate git repo (`git@github.com:irae/restricted-mail.git`). This directory ignores that checkout. Compose and `.env` live here. The API is documented in the app repo.

## Update

This is the stack that must be updated as root. This host has no `sudo`. Open a root shell.

Root pulls with the key at `/home/irae/.ssh/id_ed25519`. The client config is `/root/.ssh/config`, mode `600`. `/root/.ssh` is mode `700`.

```
Host github.com
    User git
    IdentityFile /home/irae/.ssh/id_ed25519
    IdentitiesOnly yes
```

As root:

```bash
git -C /data/stacks/restricted-mail/app pull
cd /data/stacks/restricted-mail
docker compose up -d --build
```

Run Compose in this directory. The app checkout has no `compose.yaml` and no `.env`.

`docker compose build` and `docker compose restart` leave the existing container on its old image. `up -d --build` replaces the container.

```bash
docker inspect restricted-mail-restricted-mail-1 --format '{{.Image}}'
docker image inspect restricted-mail:prod --format '{{.Id}}'
```

The two ids match when the new image is the one that is running.
