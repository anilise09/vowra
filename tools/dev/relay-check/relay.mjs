// Development only: a local TURN relay that accepts Vawra's time-limited
// credentials. Vawra hands each person "expiry:accountId" and
// base64(HMAC-SHA1(secret, it)); the relay works the password out from the
// name and refuses expired names, as coturn does with use-auth-secret.
import { createHmac } from 'node:crypto';
import { createRequire } from 'node:module';
import { networkInterfaces } from 'node:os';

const require = createRequire(import.meta.url);
const Turn = require('node-turn');
const dgram = require('node:dgram');

/** The computer's network address: browsers and phones send from there, never loopback. */
export const lanAddress = () =>
  process.env.RELAY_IP ??
  Object.values(networkInterfaces())
    .flat()
    .find((a) => a.family === 'IPv4' && !a.internal)?.address;

export function startRelay({ ip = lanAddress(), port = 3479, secret, minPort = 49200, maxPort = 49400 }) {
  if (!ip) throw new Error('No network address for the relay; set RELAY_IP.');
  const stats = { auths: 0, relayedBytes: 0 };
  const credentials = new Proxy(
    {},
    {
      get(_, username) {
        if (typeof username !== 'string') return undefined;
        const expiry = Number(username.split(':')[0]);
        if (!Number.isInteger(expiry) || expiry < Date.now() / 1000) return undefined;
        stats.auths++;
        return createHmac('sha1', secret).update(username).digest('base64');
      },
    },
  );
  // Count what arrives on the relay's own ports: media relayed between the two people.
  const emit = dgram.Socket.prototype.emit;
  dgram.Socket.prototype.emit = function (event, ...rest) {
    if (event === 'message') {
      try {
        const local = this.address().port;
        if (local >= minPort && local <= maxPort) stats.relayedBytes += rest[0]?.length ?? 0;
      } catch {}
    }
    return emit.call(this, event, ...rest);
  };
  const turn = new Turn({
    listeningPort: port,
    listeningIps: [ip],
    relayIps: [ip],
    minPort,
    maxPort,
    authMech: 'long-term',
    realm: 'vawra.local',
    credentials,
    debugLevel: 'OFF',
  });
  turn.start();
  return {
    url: `turn:${ip}:${port}?transport=udp`,
    stats,
    stop() {
      turn.stop();
      dgram.Socket.prototype.emit = emit;
    },
  };
}

// node relay.mjs: runs the relay alone, for a phone test against the dev server
// (start the server with the printed VAWRA_TURN_URLS and the same VAWRA_TURN_SECRET).
if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/\\/g, '/').split('/').pop())) {
  const secret = process.env.VAWRA_TURN_SECRET;
  if (!secret || secret.length < 16) {
    console.error('Set VAWRA_TURN_SECRET (16+ characters), the same as the dev server.');
    process.exit(1);
  }
  const relay = startRelay({ secret });
  console.log(`relay on ${relay.url}; VAWRA_TURN_URLS=${relay.url}`);
  setInterval(() => console.log(`credential checks ${relay.stats.auths}, relayed ${relay.stats.relayedBytes} bytes`), 10_000);
}
