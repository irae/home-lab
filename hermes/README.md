# Hermes

**Hermes is running with browser chat. No external messaging platform is configured.**

## Container and storage

- Local `hermes-ssh:latest` image based on `nousresearch/hermes-agent:latest`; upstream init and `gateway run` with supervised sshd.
- The build reuses `local-llm-sandboxed/sshd-run.sh` and copies only `/home/irae/.ssh/authorized_keys` from its build context.
- `HERMES_UID=1000`, `HERMES_GID=1000`; no Compose `user:` override.
- Normal Docker bridge/NAT; `restart: unless-stopped`; API healthcheck.
- Bind `/data/volumes/hermes:/opt/data`, owned by `irae:irae`, mode `0700`.
- State/credentials stay in `/opt/data`; projects and user files in `/opt/data/home`.
- Leave image-owned `/opt/hermes` untouched. Back up the volume with writers stopped;
  never share it between running instances.

## Access

Use `http://sheeta:[port]/` over LAN or Tailscale:

- **:5006** — dashboard, including browser chat, container :9119.
- **:7390** — OpenAI-compatible API / health, container :8642.
- **:2202** — Key-only SSH as `hermes` on container port 22: `ssh -p 2202 hermes@sheeta`. Root SSH is disabled. Host keys persist in `/data/volumes/hermes/ssh-hostkeys` across builds and container recreations.

Dashboard/API host bindings use `0.0.0.0`. Dashboard `public_url` is
`http://sheeta:5006/`. Dashboard authentication, a persistent session secret, and
an API key stay outside Git. No public ingress/router forwarding.
The installed image has no separate `webapp` service; port 5005 was removed.
Extra server ports require explicit mappings. Inventory: [root README](../README.md).

## Setup and updates

Storage and credentials are in `/data/volumes/hermes`. Web username: `irae`.
Read your generated password locally (do not commit or share the output):

```bash
grep '^HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=' /data/volumes/hermes/.env
```

Build the local image, run the official Docker setup wizard and provider login, then start the service:

```bash
cd /data/stacks/hermes
docker compose build
docker compose run --rm hermes setup
docker compose up -d
```

- Open `http://sheeta:5006/`.
- Agent: `docker exec -it --user hermes --env HOME=/opt/data hermes hermes`.
- Shell: `docker exec -it --user hermes --env HOME=/opt/data hermes bash` or `ssh -p 2202 hermes@sheeta`.
  SSH shells load the existing s6 container environment with `s6-envdir`, including
  `HERMES_HOME`, while preserving SSH session variables and setting `HOME=/opt/data`.
  Interactive logins and remote commands use the same `/opt/data` configuration as
  Docker exec. The login PATH is taken from the base image at build time.
- Root maintenance only: `docker exec -it --user root hermes bash`. Interactive root
  Bash shells display a warning and the normal-use commands; agents and coding work
  should run as `hermes`. Upstream root initialization and supervision are unchanged.
- Update: `docker compose build --pull`, then `docker compose up -d`; no in-container self-update.
- Verify LAN/Tailscale access, authentication, persistence, and restart recovery.

## Development and models

- Small scripts/temporary servers use the local terminal backend and bundled tools.
  Keep dependencies project-local under the volume; no root apt installs.
- Larger apps: Hermes proposes stacks in its own `home-lab` clone; you review and deploy.
  Grant a dedicated SSH key access to a non-root app sandbox if needed, not host Docker.
- The host updater discovers `*/compose.yaml`; pulling a stack can make it eligible for startup.
- Configure Luna during setup; confirm provider/model ID. ChatGPT/Codex uses `openai-codex` OAuth.
- Add local fallback with `hermes fallback` later, when the GPU box returns.
  Candidate: `http://arrietty:8080/v1`; verify endpoint, quota failover, and model capabilities.

## Files and restore

- `Dockerfile`: local image with OpenSSH, reusing the sandbox SSH startup script.
- `ssh-shell.sh`: SSH login shell loading the authoritative s6 environment before Bash.
- `root-shell-warning.sh`: interactive root Bash maintenance warning and normal-use commands.
- `compose.yaml`: local image build, private state bind, and dashboard/API/SSH port mappings.
- `config.yaml`: starter settings copied to the volume once; edit the volume copy after setup.
- `/data/volumes/hermes/.env`: web password/session secret, API key, and setup-managed secrets.
  Compose reads this file too; changes require container recreation, not just a restart.
- On another host, restore the private volume as UID/GID 1000 with mode `0700`
  (secrets mode `0600`), provide `/home/irae/.ssh/authorized_keys`, build the local image, then `up -d`. Do not overwrite restored config/keys.
- Subsequent stack changes are committed; provider setup remains your responsibility.

[Docker setup](https://hermes-agent.nousresearch.com/docs/user-guide/docker) ·
[Terminal backends](https://hermes-agent.nousresearch.com/docs/user-guide/configuration) ·
[Providers](https://hermes-agent.nousresearch.com/docs/integrations/providers) ·
[Fallback](https://hermes-agent.nousresearch.com/docs/user-guide/features/fallback-providers)

Supersedes the inactive `host/drafts/hermes-compose.yaml` proposal.
