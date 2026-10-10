# set-brainz

Tracklist tool. On this host the published port is `5004`. Data is `/data/volumes/set-brainz`, owned by `irae`.

The checkout is `/data/stacks/set-brainz/app`, owned by `irae`, and it is a separate git repo (`git@github.com:irae/set-brainz.git`). This directory ignores that checkout. Compose lives here.

## Update

As `irae`:

```bash
git -C /data/stacks/set-brainz/app pull
cd /data/stacks/set-brainz
docker compose up -d --build
```

`docker compose build` and a Dockge Restart, Deploy, or Update leave the existing container on its old image. `up -d --build` replaces the container. The data directory stays.
