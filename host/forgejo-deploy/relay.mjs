import { createServer, request as httpRequest } from 'node:http';

const socketPath = process.env.FORGEJO_DEPLOY_SOCKET ?? '/run/forgejo-deploy/server.sock';
const port = Number(process.env.PORT ?? 3000);

const server = createServer((request, response) => {
  const upstream = httpRequest({
    socketPath,
    method: request.method,
    path: request.url,
    headers: request.headers,
  }, upstreamResponse => {
    response.writeHead(upstreamResponse.statusCode ?? 502, upstreamResponse.headers);
    upstreamResponse.pipe(response);
  });

  upstream.setTimeout(1_900_000, () => upstream.destroy(new Error('deployment relay timeout')));
  upstream.on('error', error => {
    if (!response.headersSent) response.writeHead(502, { 'content-type': 'application/json; charset=utf-8' });
    response.end(`${JSON.stringify({ error: error.message })}\n`);
  });
  request.pipe(upstream);
});

server.listen(port, '0.0.0.0', () => console.log(`deploy relay listening on ${port}`));
