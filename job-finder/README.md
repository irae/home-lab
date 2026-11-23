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
Startup applies pending migrations.

As `irae`:

```bash
cd /data/stacks/job-finder
docker compose up -d --build --wait
curl --fail http://127.0.0.1:5007/api/status
```

The UI and Intake API listen on host loopback at `http://127.0.0.1:5007/`.
The app has no login. For tailnet access, forward this loopback port through
Tailscale Serve rather than publishing it on all interfaces.

## Update

The [host image timer](../host/README.md#image-update-workflow) skips this
stack. Update the app checkout by hand and run the same `up` command to
rebuild and replace the container. The data directory stays in place.
