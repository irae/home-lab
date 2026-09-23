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

That is the image-update path from `sheeta-homelab.md`. It is a host job, not
a container.

## Files

| File | Role |
| --- | --- |
| `stacks-image-update.sh` | The worker. Verbose bash. This path is what the unit will exec. |
| `stacks-image-update.service` | systemd oneshot that calls the script |
| `stacks-image-update.timer` | Fires the service at 04:30 local time |
| `install-root.sh` | Copies the two unit files into `/etc/systemd/system/` and enables the timer |
| `install-user.sh` | Explains why there is no user unit. Does not install anything. |
| `drafts/hermes-compose.yaml` | **Not installed.** Review draft for the Hermes sandbox stack. |

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

Root SSH session, not sudo (sudo is not installed):

```
bash /data/stacks/host/install-root.sh
```

That script:

- copies the `.service` and `.timer` into `/etc/systemd/system/`
- runs `daemon-reload`
- enables the timer
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
