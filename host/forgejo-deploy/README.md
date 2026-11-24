# Forgejo deploy service

A user service on `sheeta` executes one fixed command per configured application.
Forgejo Actions reaches it through the unexposed `deploy-relay` service in the
Forgejo Compose network. Each application has its own bearer token. Requests can
provide only a 40-character Git commit SHA; they cannot choose commands or
arguments.

## Install

As `irae`:

```bash
bash /data/stacks/host/forgejo-deploy/install-user.sh
```

The service uses `/data/volumes/forgejo-deploy` for its private configuration,
keys, socket, and state. The systemd user unit points at the versioned server in
this checkout.

## Allow an application

Create an executable deployment script, then add it:

```bash
/data/stacks/host/forgejo-deploy/manage-app.sh add job-finder /data/stacks/job-finder/deploy.sh
```

The command prints the new token once. Add it to that repository as the
`DEPLOY_API_KEY` Actions secret. Adding the app again rotates its token.

List or remove applications:

```bash
/data/stacks/host/forgejo-deploy/manage-app.sh list
/data/stacks/host/forgejo-deploy/manage-app.sh remove job-finder
```

## Checks

```bash
systemctl --user status forgejo-deploy.service
curl --unix-socket /data/volumes/forgejo-deploy/run/server.sock http://localhost/healthz
journalctl --user -u forgejo-deploy.service -n 100
```

The relay has no published host port. It mounts only the socket directory, not
the deployment configuration, API keys, Docker socket, or application data.
