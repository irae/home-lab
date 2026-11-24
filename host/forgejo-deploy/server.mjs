import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
import { timingSafeEqual } from 'node:crypto';

const args = process.argv.slice(2);
const configIndex = args.indexOf('--config');
if (configIndex === -1 || !args[configIndex + 1]) throw new Error('usage: server.mjs --config <path>');

const config = JSON.parse(readFileSync(args[configIndex + 1], 'utf8'));
const listenHost = process.env.FORGEJO_DEPLOY_HOST ?? config.host ?? '0.0.0.0';
const listenPort = Number(process.env.FORGEJO_DEPLOY_PORT ?? config.port ?? 5008);
if (!Number.isInteger(listenPort) || listenPort < 1 || listenPort > 65535) throw new Error('invalid deployment service port');
if (!config.apps || typeof config.apps !== 'object') throw new Error('config.apps must be an object');

const apps = new Map();
for (const [name, value] of Object.entries(config.apps)) {
  if (!/^[a-z0-9][a-z0-9-]*$/.test(name)) throw new Error(`invalid app name: ${name}`);
  if (!Array.isArray(value.command) || value.command.length === 0 || !value.command.every(part => typeof part === 'string')) {
    throw new Error(`apps.${name}.command must be a non-empty string array`);
  }
  const key = readFileSync(value.keyFile, 'utf8').trim();
  if (!key) throw new Error(`apps.${name}.keyFile is empty`);
  apps.set(name, {
    command: value.command,
    key: Buffer.from(key),
    timeoutMs: value.timeoutMs ?? 1_800_000,
  });
}

const active = new Set();
const maxBodyBytes = 8192;
const maxOutputBytes = 4 * 1024 * 1024;

function send(response, status, body) {
  response.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  response.end(`${JSON.stringify(body)}\n`);
}

function authorized(request, expected) {
  const header = request.headers.authorization ?? '';
  if (!header.startsWith('Bearer ')) return false;
  const supplied = Buffer.from(header.slice(7));
  return supplied.length === expected.length && timingSafeEqual(supplied, expected);
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on('data', chunk => {
      size += chunk.length;
      if (size > maxBodyBytes) {
        reject(new Error('request body too large'));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    request.on('error', reject);
  });
}

function run(appName, app, sha) {
  return new Promise(resolve => {
    const child = spawn(app.command[0], app.command.slice(1), {
      env: {
        ...process.env,
        FORGEJO_DEPLOY_APP: appName,
        FORGEJO_DEPLOY_SHA: sha,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const stdout = [];
    const stderr = [];
    let outputBytes = 0;
    let overflow = false;
    let timedOut = false;

    const collect = target => chunk => {
      outputBytes += chunk.length;
      if (outputBytes > maxOutputBytes) {
        overflow = true;
        child.kill('SIGTERM');
        return;
      }
      target.push(chunk);
    };
    child.stdout.on('data', collect(stdout));
    child.stderr.on('data', collect(stderr));

    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGTERM');
      setTimeout(() => child.kill('SIGKILL'), 5000).unref();
    }, app.timeoutMs);

    child.on('error', error => {
      clearTimeout(timer);
      resolve({ code: null, stdout: '', stderr: error.message, timedOut, overflow });
    });
    child.on('close', code => {
      clearTimeout(timer);
      resolve({
        code,
        stdout: Buffer.concat(stdout).toString('utf8'),
        stderr: Buffer.concat(stderr).toString('utf8'),
        timedOut,
        overflow,
      });
    });
  });
}

const server = createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/healthz') {
    send(response, 200, { status: 'ok', apps: apps.size });
    return;
  }

  const match = /^\/v1\/deploy\/([a-z0-9][a-z0-9-]*)$/.exec(request.url ?? '');
  if (request.method !== 'POST' || !match) {
    send(response, 404, { error: 'not found' });
    return;
  }

  const appName = match[1];
  const app = apps.get(appName);
  if (!app) {
    send(response, 404, { error: 'unknown app' });
    return;
  }
  if (!authorized(request, app.key)) {
    send(response, 401, { error: 'unauthorized' });
    return;
  }
  if (active.has(appName)) {
    send(response, 409, { error: 'deployment already running' });
    return;
  }

  let body;
  try {
    body = JSON.parse(await readBody(request));
  } catch (error) {
    send(response, 400, { error: error.message });
    return;
  }
  if (!body || typeof body.sha !== 'string' || !/^[0-9a-f]{40}$/.test(body.sha)) {
    send(response, 400, { error: 'sha must be 40 lowercase hexadecimal characters' });
    return;
  }

  active.add(appName);
  try {
    const result = await run(appName, app, body.sha);
    const status = result.code === 0 && !result.timedOut && !result.overflow ? 200 : 500;
    send(response, status, {
      app: appName,
      sha: body.sha,
      exitCode: result.code,
      timedOut: result.timedOut,
      outputLimitExceeded: result.overflow,
      stdout: result.stdout,
      stderr: result.stderr,
    });
  } finally {
    active.delete(appName);
  }
});

server.listen(listenPort, listenHost, () => {
  console.log(`forgejo-deploy listening on ${listenHost}:${listenPort} with ${apps.size} app(s)`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
