# Restricted mail: a mediated interface for agents

This stack puts an application policy boundary between an agent and Fastmail.
Instead of handing the agent a Fastmail token, the server holds it and exposes a
smaller HTTP API. It supports personal automation experiments in the
[local-LLM sandbox](../local-llm-sandboxed/README.md).

The app is a separate private repository (`git@github.com:irae/restricted-mail.git`).
Its local checkout is `/data/stacks/restricted-mail/app`, owned by root and ignored
here. Compose and the deployment `.env` live in this directory; application
behavior, API documentation, and tests live in that separate checkout.

## Policy boundary and limits

The current upstream docs describe unauthenticated clients and group-dependent
permissions: whitelist groups read selected senders and permitted downloads;
classifier groups can also change mailbox membership for messages in configured
folders. **Do not assume this deployment is universally read-only.** The deployed
app revision, sender/group policy, and token scope are not in this checkout.
Inspect them before granting an agent access. The app's `docs/security.md` and
`docs/api.md` explain the policy and API for readers with repository access;
they do not establish which policy is active on this host.

[Compose](compose.yaml) runs UID/GID 10001 with a read-only root filesystem,
all capabilities dropped, `no-new-privileges`, a temporary `/tmp`, and a read-only
sender-policy mount. Logs remain writable. The Fastmail token is supplied as a
file-backed Compose secret, not baked into the image or mounted into the Pi
container. This keeps the credential out of normal agent access; the mail server
itself and host administrators can still read it. A Compose secret is not an
encrypted credential store, and the API's own enforcement remains essential.

The host port comes from `HOST_PORT` in `.env` (documented assignment: `5002`)
and binds all IPv4 interfaces. Containers on the `restricted-mail` network use
`http://restricted-mail:8080`. The shared bridge is not an authentication control
and is not declared internal. This stack defines no destination firewall policy.
The sandbox's separate CIDR rules are broader than this app; they do not establish
exclusive mail access. Because the current upstream API has no client login,
review who can reach the published port and shared network. HTTP alone adds no
transport encryption.

## Configuration and first deployment

Provide `APP_DIR`, `HOST_PORT`, `SENDERS_FILE`, `LOG_DIR`, and `TOKEN_FILE` in the
private `.env`. Review the application version and policy, ensure bind paths
exist, and give UID/GID 10001 the needed read access to policy/token files and
write access to logs. Keep tokens, policy contents, mail, and logs out of Git and
shared diagnostic output. There is no checked-in `.env` template establishing
safe defaults.

The [development Compose file](compose.dev.yaml) substitutes `DEV_DIR`, builds
the development target, and mounts its source read-only. It still receives the
configured token and network access: using it does not make a test environment
safe for real credentials. Use the app's stub-based tests for offline checks.

## Update

This is the stack that must be updated as root. This host has no `sudo`. Open a root shell.

Root pulls with the key at `/home/irae/.ssh/id_ed25519`. The client config is `/root/.ssh/config`, mode `600`. `/root/.ssh` is mode `700`.

```
Host github.com
    User git
    IdentityFile /home/irae/.ssh/id_ed25519
    IdentitiesOnly yes
```

As root:

```bash
git -C /data/stacks/restricted-mail/app pull
cd /data/stacks/restricted-mail
docker compose up -d --build
```

Run Compose in this directory. The app checkout has no `compose.yaml` and no `.env`.

`docker compose build` and `docker compose restart` leave the existing container on its old image. `up -d --build` replaces the container.

```bash
docker inspect restricted-mail-restricted-mail-1 --format '{{.Image}}'
docker image inspect restricted-mail:prod --format '{{.Id}}'
```

The two ids match when the new image is the one that is running. The healthcheck
only checks the local `/health` response; it does not verify policy enforcement,
Fastmail token scope, or isolation from other services.

## Checks after changes

Confirm the running image and effective policy first. Using non-sensitive test
messages, check an allowed operation and a denied sender/folder/download host;
check mutation behavior against the intended group category rather than assuming
read-only access. Confirm which clients can reach the published port. Use the
upstream test/runbook guidance for application-level checks; no live mail-policy
validation is claimed by this repository's Compose configuration.
