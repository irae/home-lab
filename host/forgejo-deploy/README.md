# Forgejo deploy service

A Node.js systemd user service on `sheeta` executes one fixed command per
configured application. It listens on host TCP port `5008`; every deployment
request requires the API key assigned to that application.

Runtime configuration is private under `/data/volumes/forgejo-deploy`. The
configuration maps application names to key files and exact executable commands:

```json
{
  "apps": {
    "job-finder": {
      "keyFile": "/data/volumes/forgejo-deploy/keys/job-finder",
      "command": ["/data/stacks/job-finder/deploy.sh"],
      "timeoutMs": 1800000
    }
  }
}
```

Requests can provide only a 40-character Git commit SHA. They cannot choose a
command or add arguments.

## Install

As `irae`:

```bash
bash /data/stacks/host/forgejo-deploy/install-user.sh
```

The systemd user unit points at the versioned server in this checkout.

## Allow or rotate an application

`manage-app.sh set` reads the key from standard input and prints nothing:

```bash
openssl rand -hex 32 | /data/stacks/host/forgejo-deploy/manage-app.sh set \
  job-finder /data/stacks/job-finder/deploy.sh
```

When configuring Forgejo, generate the key once in memory and pipe the same
value into `manage-app.sh set` and the repository's `DEPLOY_API_KEY` Actions
secret. Set the repository's `DEPLOY_API_URL` Actions variable to
`http://sheeta:5008`. Adding the application again rotates its key.

List or remove applications:

```bash
/data/stacks/host/forgejo-deploy/manage-app.sh list
/data/stacks/host/forgejo-deploy/manage-app.sh remove job-finder
```

## API

```bash
curl --fail \
  -H "Authorization: Bearer $DEPLOY_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"sha":"<40-character-commit-sha>"}' \
  http://sheeta:5008/v1/deploy/job-finder
```

## Checks

```bash
systemctl --user status forgejo-deploy.service
curl http://127.0.0.1:5008/healthz
journalctl --user -u forgejo-deploy.service -n 100
```
