# sheeta / home-lab

Local checkout: `/data/stacks` (Dockge stacks dir).
GitHub: private repo `home-lab` (Free plan allows unlimited private repos).

## Host

- Debian 13 (trixie)
- user `irae` uid/gid 1000
- NVMe `/` — OS + Docker `data-root` (`/var/lib/docker`; leave default)
- 2TB SATA `/data` — stacks, volumes, agent
- Home stays on the NVMe (bind-mount skipped)

## fstab

```
UUID=<data-disk-uuid> /data ext4 defaults,noatime 0 2
```

## Directories

- `/data/stacks` — compose projects + this repo (`irae:irae`)
- `/data/volumes` — bind mounts for container data
- `/data/agent` — sandbox workspace

## Packages (stub)

- git neovim fd-find fzf bat lazygit
- docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin (Docker Inc Debian repo)
- gh needrestart (Debian)
- herdr (user install under `~/.local`)
- lazydocker: not in Debian — skipped

## Docker

- Docker Inc apt repo (`download.docker.com`), not Debian `docker.io` (newer, faster patches)
- Origin added in `/etc/apt/apt.conf.d/51unattended-upgrades-docker` so it actually auto-updates
- Majors pinned in `/etc/apt/preferences.d/docker-majors` (patches still apply)
- `irae` in group `docker` (re-login after `usermod`)
- needrestart: `/etc/needrestart/conf.d/no-docker-restart.conf` skips `docker.service` and `containerd.service`

## Stacks

- One dir per project: `/data/stacks/<name>/compose.yaml`
- Image pins: floating major (`louislam/dockge:1`), not `latest`, not digests
- `restart: unless-stopped` + healthcheck
- Binds under `/data/volumes/<name>`

## Herdr

Host tool, not a container. Lingering user service + native resume: TODO.

## Image timer

systemd timer after the reboot window (e.g. 04:30):

`compose build --pull && compose pull && compose up -d`

TODO: units not written. No reboot-window timer found on disk.

## Next box

Same uid 1000, mount UUID, packages, Docker Engine, `compose up`, Herdr.
