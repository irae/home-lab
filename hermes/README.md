# Hermes: persistent agent experiments

I use this stack to try an agent with persistent state, browser chat, and a
workspace for ongoing personal automation. [Compose](compose.yaml) enables the
dashboard and API, starts `gateway run`, and retains application state outside the container. I also use Telegram connector so my Hermes instance can join whitelisted group chats for my family to access some of the apps and agent skills I want to build in the future.

## Design and limits

This is not the [local-LLM sandbox](../local-llm-sandboxed/README.md). Hermes uses
normal Docker networking with no destination allowlist in this Compose file.
Its local terminal backend can execute tools and modify the persistent workspace;
there is no read-only root filesystem or capability-drop policy declared here.
Treat agent output and proposed deployments as work to review, not changes to
apply automatically. Don't grant it host Docker access.

The SSH extension reuses the existing application account and authoritative
container environment so SSH and Docker-exec sessions don't drift into separate
configurations. Key-only application-user SSH so Hermes can be used as a coding agent remotely on a terminal or agentic IDEs, disabled root SSH, has `no-new-privileges` constrain entry and privilege escalation, not what the
application user can do with its files, credentials, or network access.

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
an API key stay outside Git. These are all-interface IPv4 bindings, not
Tailscale-only listeners; LAN/Tailscale use does not itself enforce who can
connect. No public ingress or router forwarding is defined here, and upstream
network policy must be checked separately. The healthcheck tests only the local
API health route, not authentication, model access, or agent behavior.
There is no separate `webapp` service in this Compose file.
Extra server ports require explicit mappings in [compose.yaml](compose.yaml).

## Setup and updates

Storage and credentials are in `/data/volumes/hermes`. Web username: `irae`.
Read your generated password locally (do not commit or share the output):

```bash
grep '^HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=' /data/volumes/hermes/.env
```

For an existing install, do not run `setup`. Use `cd /data/stacks/hermes && docker compose build --pull && docker compose up -d`. This keeps the live configuration.

For a new install only, build the image, run the setup wizard and provider login, then start the service:

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
- Provider selection is private deployment state, not established by the tracked
  starter config. Confirm provider/model IDs during setup rather than assuming a
  particular service is configured.
- For local-model selection, use the hardware-specific process in
  [choose-a-local-llm](https://github.com/irae/choose-a-local-llm). Evaluation results
  do not by themselves configure Hermes or prove compatibility with its tools.
- A local fallback would use the separate inference machine, not `sheeta`.
  The documented candidate endpoint is `http://arrietty:8080/v1`; verify
  availability, model/tool support, and fallback behavior before configuring it.
  This checkout does not establish that a fallback is active.

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

Use the current Compose file rather than the historical
[`host/drafts/hermes-compose.yaml`](../host/drafts/hermes-compose.yaml) proposal.
