# dockge

Stack manager. On this host the published port is `5001`. The image pin is `louislam/dockge:1`.

Runtime data is `/data/volumes/dockge`. Stack files stay in `/data/stacks`.

## Update

As `irae`, from a shell. This is the Dockge container, so do not use Dockge to update itself.

```bash
cd /data/stacks/dockge
docker compose pull
docker compose up -d
```

A Restart does not pull a new image. The stack files and the Dockge data directory stay.
