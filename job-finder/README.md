# Job Finder

[Compose](compose.yaml) builds the app from the ignored checkout at
`/data/stacks/job-finder/app`. Check out a Job Finder revision that includes
the Dockerfile before the first build. The container runs as UID/GID 1000
and keeps its SQLite database, Job Pages, and Profile files in
`/data/volumes/job-finder`.

## First start

Create the data directory once as root if it does not exist:

```bash
install -d -m 0700 -o 1000 -g 1000 /data/volumes/job-finder
```

For Judgments, set `TYPESAFE_API_KEY` in the stack's ignored `.env` (mode
0600). The app starts without it. If bringing an existing database, stop
its writer and copy the whole data directory before starting this stack.
Make sure UID/GID 1000 can read the imported files and write to the
database and data directory. Startup applies pending migrations.

As `irae`:

```bash
cd /data/stacks/job-finder
docker compose up -d --build --wait
curl --fail http://127.0.0.1:5007/api/status
```

The UI and Intake API listen on host loopback at `http://127.0.0.1:5007/`.
The app has no login. Tailscale Serve publishes it on the tailnet at
`https://<sheeta-tailnet-name>:5007/`. Set up the forward once, as the
Tailscale operator or root:

```bash
tailscale serve --bg --https=5007 http://127.0.0.1:5007
```

## Update

The [host image timer](../host/README.md#image-update-workflow) skips this
stack. Rebuild by hand as `irae`:

```bash
cd /data/stacks/job-finder
git -C app pull --ff-only
docker compose up -d --build --wait
```

The data directory stays in place.
