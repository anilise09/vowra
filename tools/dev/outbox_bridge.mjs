// Local-only bridge used by device integration tests to read one synthetic
// member's newly issued sign-in code. It binds to loopback, refuses non-.test
// addresses, and never exposes codes that existed before this process started.
//
//   VAWRA_OUTBOX_EMAIL=ios.simulator@vawra.test node tools/dev/outbox_bridge.mjs
//
// The Vawra backend must be running with VAWRA_DEV_OUTBOX=1. Never use this
// helper with a deployed service or a real person's email address.
import { existsSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';

const host = '127.0.0.1';
const port = Number(process.env.VAWRA_OUTBOX_BRIDGE_PORT ?? 8798);
const email = (process.env.VAWRA_OUTBOX_EMAIL ?? '').trim().toLowerCase();
const outbox = new URL('../../backend/.data/outbox.log', import.meta.url);

if (!/^[a-z0-9._+-]+@[a-z0-9.-]+\.test$/.test(email)) {
  console.error('VAWRA_OUTBOX_EMAIL must be a synthetic .test email address.');
  process.exit(1);
}
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  console.error('VAWRA_OUTBOX_BRIDGE_PORT must be a valid TCP port.');
  process.exit(1);
}

const initialSize = existsSync(outbox) ? statSync(outbox).size : 0;

function latestNewCode() {
  if (!existsSync(outbox)) return null;
  const contents = readFileSync(outbox);
  const appended = contents
    .subarray(Math.min(initialSize, contents.length))
    .toString('utf8');
  for (const line of appended.trim().split('\n').reverse()) {
    const [, purpose, recipient, code] = line.split(' ');
    if (purpose === 'sign_in' && recipient === email && /^\d{6}$/.test(code)) {
      return code;
    }
  }
  return null;
}

const server = createServer((request, response) => {
  const url = new URL(request.url ?? '/', `http://${host}:${port}`);
  if (
    request.method !== 'GET' ||
    url.pathname !== '/code' ||
    url.searchParams.get('email')?.toLowerCase() !== email
  ) {
    response.writeHead(404).end();
    return;
  }
  const code = latestNewCode();
  if (code == null) {
    response.writeHead(404, { 'cache-control': 'no-store' }).end();
    return;
  }
  response
    .writeHead(200, {
      'cache-control': 'no-store',
      'content-type': 'application/json',
    })
    .end(JSON.stringify({ code }));
});

server.listen(port, host, () => {
  console.log(`Vawra test-code bridge listening on http://${host}:${port}`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
