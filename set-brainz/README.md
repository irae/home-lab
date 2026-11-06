# Set-brainz: tracklist automation

A personal music workflow: identify tracks in recorded DJ sets, combine results,
and curate a tracklist. This stack is one way I try automating a useful part of
an existing hobby rather than running an agent for its own sake. The application
and its research live in a separate
[set-brainz repository](https://github.com/irae/set-brainz); this directory owns the
Compose deployment, not the application source or test suite.

## Layout and boundaries

The ignored application checkout is `/data/stacks/set-brainz/app`, owned by
`irae`. [Compose](compose.yaml) builds it locally, runs UID/GID 1000, and mounts
`/data/volumes/set-brainz` at `/data`. Temporary work under `/data/tmp` is a separate
bind to `/var/tmp/set-brainz`, not tmpfs. Check both host paths when reviewing
space use and what must survive a recreation.

Host port `5004` maps to container port `8765` with no host-address restriction.
The upstream app documents no login; Compose adds no authentication or network
allowlist. Reachability is therefore part of the trust boundary, not merely a
convenient URL. This stack does not declare a read-only root filesystem,
capability drops, or the local-LLM sandbox's firewall rules. Running as a non-root
user limits Unix privileges, not access to its mounted data or network.

Treat the data directory as private: the app may store source URLs, results, and
browser cookies used by its posting workflow. The upstream docs say the Docker
image has no browser and does not support posting to 1001Tracklists from the
container; don't infer support from the web UI or copy credentials in to try to
make it work without reviewing that limitation.

## Update

As `irae`:

```bash
git -C /data/stacks/set-brainz/app pull
cd /data/stacks/set-brainz
docker compose up -d --build
```

`docker compose build` and `docker compose restart` leave the existing container
on its old image. `up -d --build` replaces the container. The mounted data stays.
The [host updater](../host/README.md) can rebuild the local image, but does not
pull the ignored application Git checkout. Source updates remain explicit.

Before maintenance, check for active processing jobs and back up data you need
with writers stopped. After a rebuild, verify the UI, a small processing job,
and saved decisions; a running container is not proof that external recognition
services still work. There is no Compose healthcheck. Application tests and
known tool limitations belong to the upstream repo, and no live processing or
restore test result is claimed here.
