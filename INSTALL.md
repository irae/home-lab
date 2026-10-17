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

Host tool, not a container. User install at `~/.local/bin/herdr` (self-updates with `herdr update`; do not put it in `/usr/local`).

- User unit: `~/.config/systemd/user/herdr.service` (`herdr server`)
- Linger: `loginctl enable-linger irae` (root; already `yes` on this box)
- Native resume: `[session] resume_agents_on_restore = true` in `~/.config/herdr/config.toml`
- Grok hook: `herdr integration install grok`
- Attach from Omarchy: `herdr --remote sheeta` (do not nest)

## Update a stack

Each stack README has the commands. `irae` runs them, except `restricted-mail`, which is root. This host has no `sudo`.

`docker compose up -d --build` replaces a locally built container. `docker compose build` alone, and a Dockge Restart, Deploy, or Update, leave the old container running.

## Image timer

Versioned in this repo: `/data/stacks/host/`.

- Worker: `host/stacks-image-update.sh` (one compose project at a time: build --pull, pull, up -d)
- Units: `host/stacks-image-update.service` + `.timer` (04:30 local, Persistent=)
- Install (root, after review): `bash /data/stacks/host/install-root.sh`
- There is no user unit. `host/install-user.sh` only explains that.

Leave the existing reboot-if-`/run/reboot-required` cron alone. Do not enable
`Automatic-Reboot` in unattended-upgrades. Confirm that cron is before 04:30
before enabling the timer.

Units are **not** copied into `/etc/systemd/system/` until `install-root.sh` runs.

## LAN file share

Versioned in `/data/stacks/host/samba/`. SMB guest share for VLC on Apple TV. NetBIOS name `sheeta` on `enp1s0` and `enp2s0`. Allow `192.168.1.0/24` only. One share enabled: SABnzbd complete downloads.

Install (root, after review): `bash /data/stacks/host/samba/install-root.sh`

Samba is not installed until that script runs. Decision and steps: `host/samba/README.md`.

## Next box

Same uid 1000, mount UUID, packages, Docker Engine, `compose up`, Herdr.
