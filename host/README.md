# Host operations

The Debian host setup was based on
[sunknudsen's guides](https://github.com/sunknudsen/guides), followed by further
hardening and review through agent-assisted iteration. That is the starting
point and working process, not a claim that every guide recommendation is
implemented or that the running host has passed a security audit. This directory
tracks specific operational changes; [INSTALL.md](../INSTALL.md) records the
host layout and package/update conventions.

## Design and trust boundary

This directory is **not** a stack. There is no `compose.yaml` here on
purpose, so the image timer skips `host`. Host services need explicit root
installation rather than being started by Compose discovery. Checking out these
files does not install them; review the scripts, then inspect the installed units
and configuration to establish what is actually active.

The updater runs as root with Docker access. Its worker executes from the live
checkout, so changes to that checkout can change the next privileged run.
Docker access and write access to this deployment tree are trusted administrative
capabilities, not permissions to give a sandboxed agent.

The LAN IPv6 sysctl disables IPv6 on the two named Ethernet interfaces to reduce
an unintended exposure path for published services. It is not a general firewall
or a restriction on IPv4, Tailscale, or future interfaces. Published Docker ports
may listen beyond Tailscale. Use `<host>.local` on the LAN and the bare hostname
through Tailscale MagicDNS elsewhere; don't hardcode changing addresses or a
particular tailnet's DNS suffix.

## Image-update workflow

A systemd **timer** that, once a day, walks every stack under
`/data/stacks/*/compose.yaml` and runs three separate compose commands:

1. `docker compose build --pull`
2. `docker compose pull --ignore-buildable`
3. `docker compose up -d`

It is a host job, not a container.

`build --pull` refreshes base images and rebuilds local images.
`pull --ignore-buildable` pulls registry images and does not pull those local
images. `up -d` recreates a container only when its image or service
configuration changed. A failed build or registry pull skips `up -d` for that
stack only. The worker continues with other stacks and returns a failure status
if any stack failed. It does not pull application Git checkouts, roll back bad
images, or prove that a service is usable after recreation. Registry images use
`:latest` or no tag by convention; the sandbox has a local build tag. This trades
version stability for trying current releases, so inspect failures and verify
applications after updates rather than treating a successful pull as acceptance.
The timer is not installed by a checkout update; run `install-root.sh` explicitly.

## Files

| File | Role |
| --- | --- |
| `stacks-image-update.sh` | The worker. Verbose bash. This path is what the unit will exec. |
| `stacks-image-update.service` | systemd oneshot that calls the script |
| `stacks-image-update.timer` | Fires the service at 04:30 local time |
| `install-root.sh` | Validates and installs the units; applies the sysctl file; enables, starts, and checks the timer |
| `90-lan-ipv6-off.conf` | Disables IPv6 on `enp1s0` and `enp2s0` to reduce exposure from IPv6-published ports; leaves `tailscale0` unchanged. Actual reachability also depends on routing and firewall policy. |
| `install-user.sh` | Explains why there is no user unit. Does not install anything. |
| `drafts/hermes-compose.yaml` | Historical draft, not a discovered stack; use [Hermes](../hermes/README.md) and its current Compose file instead. |

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

Use an IPv4 or Tailscale SSH session. The installer removes LAN IPv6 addresses, which can close an IPv6 SSH session. From the Mac, open a second session with `ssh -4 -o ProxyCommand=none irae@sheeta.local`. Check `echo "$SSH_CONNECTION"`; the server address must be IPv4. Keep this session open.

Finish all stack setup and rebuilds first. The timer has `Persistent=true`: starting it can run a missed update immediately. That update can pull images and recreate containers. Do not run the installer until that is safe.

Run as root in that session, not sudo (sudo is not installed):

```
bash /data/stacks/host/install-root.sh
```

That script:

- validates both units with `systemd-analyze verify` before copying them
- copies the units into `/etc/systemd/system/` and runs `daemon-reload`
- copies `90-lan-ipv6-off.conf` into `/etc/sysctl.d/` and applies it
- enables and starts the timer, then checks that it is enabled and active
- does **not** touch the reboot cron

Check the schedule and any update that ran:

```
systemctl is-enabled stacks-image-update.timer
systemctl is-active stacks-image-update.timer
systemctl list-timers stacks-image-update.timer
systemctl status stacks-image-update.service
journalctl -u stacks-image-update.service -n 100
```

Expect `enabled` and `active` for the timer. The service is a oneshot: it can be inactive after a successful run. If it ran, check its result and repeat the stack checks before you finish.

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

Samba for VLC on Apple TV lives in `samba/`. The configured NetBIOS name is
`sheeta`. The tracked share selection exposes only the SABnzbd completion
directory; installation and runtime checks are separate from that selection.

Review the [Samba design and guest-access limits](samba/README.md). Install or
reinstall explicitly, as root:

```
bash /data/stacks/host/samba/install-root.sh
```

That script is not the image-timer installer. The image timer stays on `bash /data/stacks/host/install-root.sh`.

## Local validation

The existing tests use command stubs to exercise updater ordering, failure
handling, and installer behavior without changing host services:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s host/tests -v
```

Run from the repository root. These tests do not validate a live Debian host,
firewall reachability, or application recovery. Those require the operational
checks above and each stack's checks after deployment.
