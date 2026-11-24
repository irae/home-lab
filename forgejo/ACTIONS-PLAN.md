# Forgejo Actions and deployment plan

## Goal

Run one instance-level Forgejo runner that is useful across the home-lab repositories, while keeping workflow container builds inside Docker-in-Docker and routing production deployments through a small host HTTP service with one key and one allowlisted command per application.

## Runner

- Keep the runner registered globally with the Forgejo instance.
- Build a local generic job image inside the runner's Docker-in-Docker daemon whenever the Forgejo stack starts.
- Expose the image through the `generic` runner label.
- Include Node.js 26, npm, Python 3, pip, venv, Git, OpenSSH client, curl, wget, jq, SQLite, rsync, zip/unzip, tar, zstd, build tools, Docker CLI, Playwright CLI, Chromium, and Chromium's system dependencies.
- Keep runner capacity at one initially so Docker-in-Docker jobs and caches cannot overlap.
- Keep Actions and npm caches under `/data/volumes/forgejo-runner`.

## Docker builds in workflows

The generic job image includes the Docker CLI. Workflow containers receive the Docker-in-Docker TLS endpoint and client certificates, so repositories may run commands such as `docker build`, `docker run`, and Compose against the isolated daemon. They do not receive the host Docker socket. This lets future applications test their own Dockerfiles without controlling host containers.

## Deployment service

- Run the Node.js deployment service as the existing `irae` systemd user service.
- Listen on `0.0.0.0:5008` so runner jobs, LAN clients, and tailnet clients can call it directly.
- Require a bearer API key on every deployment request.
- Keep runtime configuration in `/data/volumes/forgejo-deploy/config.json` as an application map. Each entry names one key file and one exact executable command.
- Accept only an application name in the URL and a validated 40-character Git SHA in the JSON body. Do not accept arbitrary commands or arguments.
- Permit one deployment at a time per application.
- Keep deployment scripts directly runnable by existing authorized host users.

Example runtime configuration shape:

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

For each new application:

1. Add its fixed deployment script.
2. Generate a new random key without printing it.
3. Pipe the key into the host key file and the repository's Forgejo Actions secret.
4. Add the application-to-command mapping.
5. Call `POST /v1/deploy/<app>` from the repository workflow.

## Job Finder workflow

- Run on pull requests, pushes to `main`, and manual dispatches.
- Use the generic runner image.
- Restore the npm download cache keyed by `package.json` and `package-lock.json`.
- Run one `npm ci`, then the setup, Forgejo helper, unit, functional, typecheck, and build steps separately in the same job.
- Deploy only after verification succeeds on a push to `main`.
- Read the deployment endpoint from a Forgejo repository variable and the application key from a repository secret.
- Send the tested commit SHA to the deployment service.

## Validation

- Build the generic image and verify every listed command is available.
- Open a Job Finder test pull request and require its verification status.
- Verify the npm cache hits on a repeated run.
- Run a Dockerfile build and container execution inside Docker-in-Docker.
- Launch Chromium with Playwright CLI inside a workflow container.
- Merge the test pull request and verify the exact merged SHA deploys.
- Confirm Job Finder is healthy on Node 26 and the deployment backup was created.
- Confirm the deployment endpoint rejects missing or incorrect keys.
