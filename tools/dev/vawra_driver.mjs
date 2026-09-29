// Local-only driver for synthetic Vawra test members against the local dev
// server (never a real one). Sessions are kept in backend/.data/, which git
// ignores. Run from the repository root with node; for URL paths in Git Bash
// set MSYS_NO_PATHCONV=1 first.
// usage (from tools/dev):
//   node vawra_driver.mjs signup <email> <name> <intent> <bio...>
//   node vawra_driver.mjs like-all <email>
//   node vawra_driver.mjs like <email> <peerName>
//   node vawra_driver.mjs say <email> <peerName> <text...>
//   node vawra_driver.mjs patch <email> '<profile JSON>'
//   node vawra_driver.mjs share <email> on|off        (read receipts)
//   node vawra_driver.mjs typing|read <email> <peerName>
//   node vawra_driver.mjs get <email> <path>
//   node vawra_driver.mjs show <email>
//   node vawra_driver.mjs area <email> <lat> <lng> | off   (made-up test areas only)
import { createHash, randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const BASE = 'http://127.0.0.1:8797';
const OUTBOX = new URL('../../backend/.data/outbox.log', import.meta.url);
const STORE = new URL('../../backend/.data/driver_sessions.json', import.meta.url);
const b64u = (buf) => buf.toString('base64url');
const sessions = existsSync(STORE) ? JSON.parse(readFileSync(STORE, 'utf8')) : {};
const save = () => writeFileSync(STORE, JSON.stringify(sessions, null, 2));

async function call(method, path, body, token) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : {};
  if (res.status >= 400) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return json;
}

async function authed(email, method, path, body) {
  const s = sessions[email];
  try {
    return await call(method, path, body, s.access_token);
  } catch (e) {
    if (!String(e.message).includes('401')) throw e;
    Object.assign(s, await call('POST', '/v1/session/rotate', { refresh_token: s.refresh_token }));
    save();
    return call(method, path, body, s.access_token);
  }
}

async function signIn(email) {
  const verifier = b64u(randomBytes(32));
  const state = b64u(randomBytes(24));
  const challenge = b64u(createHash('sha256').update(verifier).digest());
  await call('POST', '/v1/auth/requests', {
    identifier: email, purpose: 'sign_in', code_challenge: challenge, state,
  });
  const line = readFileSync(OUTBOX, 'utf8').trim().split('\n').reverse()
    .find((l) => l.split(' ')[2] === email);
  const proof = line.split(' ')[3];
  sessions[email] = await call('POST', '/v1/auth/exchange', { proof, code_verifier: verifier, state });
  save();
}

const [cmd, email, ...rest] = process.argv.slice(2);
if (cmd === 'signup') {
  const [name, intent, ...bio] = rest;
  await signIn(email);
  await authed(email, 'PATCH', '/v1/me/profile', {
    display_name: name, relationship_intent: intent, bio: bio.join(' '),
    interests: ['Books', 'Music'],
  });
  console.log(`${name}: signed up as ${sessions[email].account_id}`);
} else if (cmd === 'like-all') {
  const { people } = await authed(email, 'GET', '/v1/discovery?limit=50');
  for (const p of people) {
    const r = await authed(email, 'POST', `/v1/discovery/${p.account_id}/swipe`, { kind: 'like' });
    console.log(`liked ${p.display_name}: ${JSON.stringify(r)}`);
  }
} else if (cmd === 'say') {
  const [peer, ...words] = rest;
  const { matches } = await authed(email, 'GET', '/v1/matches');
  const m = matches.find((x) => x.peer_name === peer);
  if (!m) throw new Error(`no match with ${peer}`);
  const r = await authed(email, 'POST', `/v1/matches/${m.match_id}/messages`, { text: words.join(' ') });
  console.log(`sent ${JSON.stringify(r)}`);
} else if (cmd === 'patch') {
  console.log(JSON.stringify(await authed(email, 'PATCH', '/v1/me/profile', JSON.parse(rest.join(' ')))));
} else if (cmd === 'like') {
  const [peer] = rest;
  const { people } = await authed(email, 'GET', '/v1/discovery?limit=50');
  const target = people.find((x) => x.display_name === peer);
  if (!target) throw new Error(`${peer} not in discovery`);
  console.log(JSON.stringify(await authed(email, 'POST', `/v1/discovery/${target.account_id}/swipe`, { kind: 'like' })));
} else if (cmd === 'share') {
  console.log(JSON.stringify(await authed(email, 'PATCH', '/v1/me/settings', { share_read_receipts: rest[0] === 'on' })));
} else if (cmd === 'typing' || cmd === 'read') {
  const [peer] = rest;
  const { matches } = await authed(email, 'GET', '/v1/matches');
  const m = matches.find((x) => x.peer_name === peer);
  if (!m) throw new Error(`no match with ${peer}`);
  await authed(email, 'POST', `/v1/matches/${m.match_id}/${cmd}`);
  console.log(`${cmd} sent`);
} else if (cmd === 'area') {
  if (rest[0] === 'off') {
    await authed(email, 'DELETE', '/v1/me/location');
    console.log('area off');
  } else {
    console.log(JSON.stringify(await authed(email, 'PUT', '/v1/me/location', { lat: Number(rest[0]), lng: Number(rest[1]) })));
  }
} else if (cmd === 'get') {
  console.log(JSON.stringify(await authed(email, 'GET', rest[0])));
} else if (cmd === 'show') {
  const { matches } = await authed(email, 'GET', '/v1/matches');
  for (const m of matches) {
    const { messages } = await authed(email, 'GET', `/v1/matches/${m.match_id}/messages`);
    console.log(m.peer_name, messages.map((x) => `${x.mine ? 'me' : 'them'}: ${x.text}`));
  }
} else {
  console.error('unknown command');
  process.exit(1);
}
