# sabnzbd

Usenet downloader. On this host the published port is `5003`. Config and downloads are under `/data/volumes/sabnzbd`.

The image is `linuxserver/sabnzbd` with no tag, so a pull follows the current image.

## Update

As `irae`. This stack has no git checkout.

```bash
cd /data/stacks/sabnzbd
docker compose pull
docker compose up -d
```

A Restart does not pull a new image. The config and download directories stay.
