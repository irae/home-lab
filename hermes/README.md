# Hermes

**Plan agreed; implementation pending. Unstaged. Nothing deployed or configured.**

## Container and storage

- Official `nousresearch/hermes-agent:latest`; upstream init and `gateway run`.
- No custom image, extra packages, dotfiles, or host credentials/Docker socket.
- `HERMES_UID=1000`, `HERMES_GID=1000`; no Compose `user:` override.
- Normal Docker bridge/NAT; `restart: unless-stopped`; API healthcheck.
- Bind `/data/volumes/hermes:/opt/data`, owned by `irae:irae`, mode `0700`.
- State/credentials stay in `/opt/data`; projects and user files in `/opt/data/home`.
- Leave image-owned `/opt/hermes` untouched. Back up the volume with writers stopped;
  never share it between running instances.

## Access

Use `http://sheeta:[port]/` over LAN or Tailscale:

- **:5005** — web app (primary interface), container :9120.
- **:5006** — dashboard / remote desktop backend, container :9119.
- **:8642** — OpenAI-compatible API / health, container :8642.

Host bindings and container listeners use `0.0.0.0`. Set web `public_url` to
`http://sheeta:5005/`. Configure web/dashboard authentication, a persistent session
secret, and an API key; secrets stay outside Git. No public ingress/router forwarding.
Extra server ports require explicit mappings. Inventory: [root README](../README.md).

## Setup and updates

We prepare Compose, private storage, web settings/authentication, and pull the image.
You run the official Docker setup wizard and provider login, then start the service:

```bash
cd /data/stacks/hermes
docker compose run --rm hermes setup
docker compose up -d
```

- Open `http://sheeta:5005/`.
- Shell: `docker exec -it --user hermes hermes bash`.
- Update: `docker compose pull`, then `docker compose up -d`; no in-container self-update.
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

## Next steps

1. Draft Compose/configuration following the official Docker docs; leave unstaged for review.
2. After review, commit the first version; commit subsequent changes too.
3. Deploy only when authorized; you perform setup yourself.

[Docker setup](https://hermes-agent.nousresearch.com/docs/user-guide/docker) ·
[Terminal backends](https://hermes-agent.nousresearch.com/docs/user-guide/configuration) ·
[Providers](https://hermes-agent.nousresearch.com/docs/integrations/providers) ·
[Fallback](https://hermes-agent.nousresearch.com/docs/user-guide/features/fallback-providers)

Supersedes the inactive `host/drafts/hermes-compose.yaml` proposal.
