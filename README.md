# Home lab stacks

- Host: `sheeta`; checkout: `/data/stacks`; persistent binds: `/data/volumes`.
- Host installation and layout: [INSTALL.md](INSTALL.md).
- Host services and image-update timer: [host/README.md](host/README.md).

## Services and ports

TCP ports below are Docker-published host ports. **Planned** and **Ready for setup**
entries are not running.
Use `http://sheeta:<port>/` on LAN and Tailscale.

Host access: on the LAN, use `<host>.local` (mDNS). Elsewhere, use the bare hostname through Tailscale MagicDNS. Do not use the tailnet suffix, because it differs between tailnets. Do not use fixed IPs. Firewall rules use CIDRs.

| Stack / service | Host port | Container port | Host bind / access | Status |
| --- | --- | --- | --- | --- |
| [Dockge](dockge/README.md) | 5001 | 5001 | All interfaces; `http://sheeta:5001/` | Running |
| [Restricted mail](restricted-mail/README.md) | 5002 | 8080 | All IPv4 interfaces; `http://sheeta:5002/` | Running |
| [SABnzbd](sabnzbd/README.md) | 5003 | 8080 | All interfaces; `http://sheeta:5003/` | Running |
| [Set-brainz](set-brainz/README.md) | 5004 | 8765 | All interfaces; `http://sheeta:5004/` | Running |
| [Hermes dashboard / chat](hermes/README.md) | 5006 | 9119 | All IPv4 interfaces; `http://sheeta:5006/` | Running |
| [Hermes API](hermes/README.md) | 7390 | 8642 | All IPv4 interfaces; `http://sheeta:7390/` | Running |
| [Hermes SSH](hermes/README.md) | 2202 | 22 | All interfaces; `ssh -p 2202 hermes@sheeta` (key-only; no root SSH) | Running |
| [Local LLM sandbox](local-llm-sandboxed/README.md) | 2201 | 22 | All interfaces; `ssh -p 2201 haku@sheeta` (key-only; no root SSH) | Running |
| TSE 2026 DuckDB | None | — | Container/CLI; separate checkout in `tse-2026/` | Running |

- All-interface bindings are **not** Tailscale-only; existing stack bindings are unchanged.
- Hermes binds `0.0.0.0` for LAN and Tailscale access; `sheeta` resolves on both.
  Web/API authentication remains required.
- No router forwarding, public DNS, or public webhook ingress planned for Hermes.
- Docker SSH daemons use container port 22 and the next available host port in the 22xx range. Current assignments: local-llm-sandboxed `2201`, Hermes `2202`.
- Container images copy `/home/irae/.ssh/authorized_keys` at build time. Add keys there and rebuild; never commit private keys.
- Images use `:latest` or no tag by default. Do not pin a major version. When an update breaks a stack, fix the stack.
- Keep this table updated when mappings change; recheck port availability before deployment.
- These entries describe stack mappings, not every host listener. SSH and Samba are
  host services; Samba configuration is in [host/samba/README.md](host/samba/README.md).

## Container users and agent access

- Run agents, coding shells, and application work as the image's existing unprivileged
  application account: `hermes` for Hermes, `haku` for the local LLM sandbox. Do not
  add another account when a suitable one already exists.
- Root may initialize the container and run the SSH listener or supervisor. SSH must
  use key-only authentication, allow only the application account, and disable root
  login. The daemon drops privileges for each session. The shared SSH startup script
  accepts `SSHD_ALLOW_USERS` and `SSHD_PERMIT_ROOT_LOGIN`; set them explicitly per stack.
- Docker has one configured default user, not a separate default exec user. A
  root-started container's plain `docker exec` defaults to root even when its app and
  SSH sessions are unprivileged. Use
  `docker exec -it --user <app-user> --env HOME=<app-home> <container> bash`
  or replace `bash` with the agent command. App homes
  are `/opt/data` for Hermes and `/home/haku` for the sandbox.
- Interactive root Bash shells should warn against agent use and show the exact
  normal-use commands. Root access through Docker exec is for deliberate maintenance;
  do not weaken `no-new-privileges` or add privilege escalation for convenience.
- SSH must use the application's authoritative configuration and environment, not
  separately maintained copies. With s6 images, load the existing container environment
  through `s6-envdir`, preserve SSH session variables, and set the application HOME.
  Bake stable paths into the image rather than probing for them on every login.
- Before changing users or recreating a container, check persistent ownership and
  work outside the volume. Preserve user work and fix its ownership selectively;
  never blindly chown system files or SSH host private keys. Keep host keys persistent.
