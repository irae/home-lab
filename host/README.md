# Host units (review, then install)

This directory is **not** a Dockge stack. There is no `compose.yaml` here on
purpose, so Dockge will not list `host` as a project.

Nothing in this folder is live on the box until you run `install-root.sh` as
root. The scripts never copy themselves into systemd. You review, then you
install.

## What this is

A systemd **timer** that, once a day, walks every Dockge stack under
`/data/stacks/*/compose.yaml` and runs three separate compose commands:

1. `docker compose build --pull`
2. `docker compose pull`
3. `docker compose up -d`

It is a host job, not a container.

For a locally built image (`set-brainz:prod`, `restricted-mail:prod`,
`local-llm-sandboxed:1`, `hermes-ssh:latest`), `docker compose pull` fails. The
worker then skips `up -d`, so the new image is built and not started. Update
those stacks with the commands in each stack README. `dockge` and `sabnzbd` are
registry images and follow the three commands above. The timer is not installed
until `install-root.sh` runs.

## Files

| File | Role |
| --- | --- |
| `stacks-image-update.sh` | The worker. Verbose bash. This path is what the unit will exec. |
| `stacks-image-update.service` | systemd oneshot that calls the script |
| `stacks-image-update.timer` | Fires the service at 04:30 local time |
| `install-root.sh` | Copies the two unit files into `/etc/systemd/system/` and enables the timer; installs and applies the sysctl file |
| `90-lan-ipv6-off.conf` | Turns off IPv6 on `enp1s0` and `enp2s0`. Docker publishes ports on `[::]`, so a router that gives out IPv6 would expose them. `tailscale0` keeps IPv6. |
| `install-user.sh` | Explains why there is no user unit. Does not install anything. |
| `drafts/hermes-compose.yaml` | **Not installed.** Older Hermes draft; superseded by the review plan in [`../hermes/README.md`](../hermes/README.md). |

The worker script stays in this git tree. The unit's `ExecStart=` points here
(`/data/stacks/host/stacks-image-update.sh`). If you want a frozen copy under
`/usr/local` later, change `ExecStart` in the service file before running the
installer.

## Reboot cron: leave it

The daily "reboot if `/run/reboot-required` else skip" job is the reboot
window from the original design. Do not turn on `Automatic-Reboot` in
unattended-upgrades. Do not add a second systemd reboot unit.

`04:30` is the plan example for the image timer (after that window, not tied
to it). Before enabling, look at root's crontab and confirm the reboot job is
**before** 04:30. If the cron is later than 04:30, change `OnCalendar=` in
the timer file, then install.

## Install (after you review)

Run as root, not sudo (sudo is not installed):

```
bash /data/stacks/host/install-root.sh
```

That script:

- copies the `.service` and `.timer` into `/etc/systemd/system/`
- runs `daemon-reload`
- enables the timer
- copies `90-lan-ipv6-off.conf` into `/etc/sysctl.d/` and applies it
- does **not** start a compose update right now
- does **not** touch the reboot cron

Check without running an update:

```
systemctl status stacks-image-update.timer
systemctl list-timers stacks-image-update.timer
```

A one-shot test run, when you want one:

```
systemctl start stacks-image-update.service
journalctl -u stacks-image-update.service -n 100
```

## Uninstall

```
systemctl disable --now stacks-image-update.timer
rm /etc/systemd/system/stacks-image-update.service
rm /etc/systemd/system/stacks-image-update.timer
systemctl daemon-reload
```

The copies in this git directory stay. That is the versioned source.

## LAN file share

Samba for VLC on Apple TV lives in `samba/`. The NetBIOS name is `sheeta`. One share is enabled. The first share is the SABnzbd complete directory.

Review `samba/README.md`. Install later, as root:

```
bash /data/stacks/host/samba/install-root.sh
```

That script is not the image-timer installer. The image timer stays on `bash /data/stacks/host/install-root.sh`.
