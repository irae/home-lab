# SABnzbd: a home-server utility

A Usenet downloader for everyday use, separate from the agent experiments. The
stack keeps configuration and downloads in persistent host storage so replacing
the container doesn't discard them. Completed media can be exposed through the
[narrower Samba share](../host/samba/README.md), not by sharing the application's
whole configuration directory.

## Configuration and access boundary

[Compose](compose.yaml) maps host port `5003` to container port `8080` without a
host-address restriction. It does not make the UI Tailscale-only or configure
application authentication. Review the saved application's authentication and
network exposure before using it; don't assume LAN access implies access control.
This stack does not declare the sandbox's read-only filesystem, capability drops,
or destination firewall policy.

`PUID`/`PGID` are set to 1000 for the LinuxServer image's application file
ownership. Configuration is at `/data/volumes/sabnzbd/config`; the host downloads
directory is mounted at both `/downloads` and `/incomplete-downloads`. The
application's configured categories/paths decide where completed files actually
go. The Samba installer expects `config/Downloads/complete`; verify that matches
the saved configuration instead of assuming the mount names establish it.
Configuration can contain server passwords and API keys: keep it out of Git,
shared logs, and the guest media share.

The image is `linuxserver/sabnzbd` with no tag, so a pull follows the current
image. That is an update policy, not a compatibility guarantee.

## Update

As `irae`. This stack has no git checkout.

```bash
cd /data/stacks/sabnzbd
docker compose pull
docker compose up -d
```

A restart does not pull a new image. The config and download directories stay.
The [host timer](../host/README.md) also discovers this stack for image updates.
Back up private configuration and inspect active downloads before disruptive
maintenance; recreating a container preserves mounts, not in-flight process state.

After an update, check UI authentication, a small download, configured completion
paths, file ownership, and media-share playback if used. These are operational
checks to perform; the Compose file has no healthcheck and this README does not
claim a tested restore or download result.
