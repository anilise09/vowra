// Development only: proves a Vawra call works relay-only, the way production
// runs calls, without any outside service.
//
// It starts a local TURN server that accepts Vawra's time-limited credentials
// (the same shared-secret scheme coturn uses), starts its own Vawra server on a
// throwaway database, creates two synthetic members, confirms their ages
// through the signed age-check webhook, matches them, and has two headless
// Chromium pages (fake camera and microphone) make a video call with
// iceTransportPolicy "relay". It passes only if both sides decode video and
// audio, every candidate offered is a relay candidate, the chosen path is
// relay to relay, and the TURN server carried the media.
//
//   cd tools/dev/relay-check && npm install && npm run build --prefix ../../../backend
//   node relay_check.mjs                         # PGlite, one server
//   node relay_check.mjs --postgres postgres://postgres@127.0.0.1:5433/postgres
//                                                # two servers sharing a new PostgreSQL database
//   node relay_check.mjs --wrong-secret          # must fail: the relay refuses the credentials
import { spawn } from 'node:child_process';
import { createHash, createHmac, randomBytes } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { startRelay } from './relay.mjs';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright-core');

const here = fileURLToPath(new URL('.', import.meta.url));
const backend = join(here, '..', '..', '..', 'backend');
const args = process.argv.slice(2);
const postgres = args.includes('--postgres') ? args[args.indexOf('--postgres') + 1] : undefined;
const wrongSecret = args.includes('--wrong-secret');
const turnPort = 3479;
const turnSecret = randomBytes(24).toString('base64url');
const ageSecret = randomBytes(32).toString('base64url');
const log = (...a) => console.log(new Date().toISOString().slice(11, 19), ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// --- The relay -------------------------------------------------------------
// With --wrong-secret the relay checks against a different secret, so every
// credential Vawra hands out is refused.
const relay = startRelay({ secret: wrongSecret ? 'not-the-secret' : turnSecret, port: turnPort });

// --- Vawra servers ---------------------------------------------------------
const work = mkdtempSync(join(tmpdir(), 'vawra-relay-'));
let dbName;
let adminUrl;
if (postgres) {
  const pg = require(join(backend, 'node_modules', 'pg'));
  adminUrl = postgres;
  dbName = `vawra_relay_${randomBytes(6).toString('hex')}`;
  const c = new pg.Client({ connectionString: adminUrl });
  await c.connect();
  await c.query(`CREATE DATABASE ${dbName}`);
  await c.end();
}
const keys = { VAWRA_DATA_KEY: randomBytes(32).toString('base64'), VAWRA_LOOKUP_KEY: randomBytes(32).toString('base64') };
const servers = [];
function startServer(port) {
  const env = {
    ...process.env,
    ...keys,
    VAWRA_SERVER_ENABLED: '1',
    VAWRA_ENV: 'development',
    VAWRA_PORT: String(port),
    VAWRA_DEV_OUTBOX: '1',
    VAWRA_TURN_URLS: relay.url,
    VAWRA_TURN_SECRET: turnSecret,
    VAWRA_AGE_CHECK_URL: 'https://age.example.test/start?ref={reference}',
    VAWRA_AGE_WEBHOOK_SECRET: ageSecret,
  };
  delete env.VAWRA_CALLS_DEV_P2P;
  if (postgres) {
    const url = new URL(adminUrl);
    url.pathname = `/${dbName}`;
    env.DATABASE_URL = url.toString();
  }
  const child = spawn(process.execPath, [join(backend, 'dist', 'src', 'server.js')], { cwd: work, env, stdio: 'pipe' });
  let output = '';
  child.stdout.on('data', (d) => (output += d));
  child.stderr.on('data', (d) => (output += d));
  servers.push({ child, port, output: () => output });
  return `http://127.0.0.1:${port}`;
}
const bases = postgres ? [startServer(8811), startServer(8812)] : [startServer(8811)];
const baseFor = (i) => bases[i % bases.length];
for (const base of bases) {
  for (let i = 0; ; i++) {
    try {
      if ((await fetch(`${base}/v1/ready`)).ok) break;
    } catch {}
    if (i > 100) throw new Error(`server at ${base} did not start:\n${servers.map((s) => s.output()).join('\n')}`);
    await sleep(200);
  }
}
log(`Vawra ready on ${bases.join(' and ')}${postgres ? ` sharing PostgreSQL database ${dbName}` : ' (PGlite)'}`);

async function api(base, method, path, body, token) {
  const res = await fetch(base + path, {
    method,
    headers: { ...(body ? { 'content-type': 'application/json' } : {}), ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  if (res.status >= 400) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return text ? JSON.parse(text) : {};
}

async function member(i, email, name) {
  const base = baseFor(i);
  const verifier = randomBytes(32).toString('base64url');
  const state = randomBytes(24).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  await api(base, 'POST', '/v1/auth/requests', { identifier: email, purpose: 'sign_in', code_challenge: challenge, state });
  const line = readFileSync(join(work, '.data', 'outbox.log'), 'utf8').trim().split('\n').reverse().find((l) => l.split(' ')[2] === email);
  const session = await api(base, 'POST', '/v1/auth/exchange', { proof: line.split(' ')[3], code_verifier: verifier, state });
  const token = session.access_token;
  await api(base, 'PATCH', '/v1/me/profile', { display_name: name, relationship_intent: 'open_to_long_term', bio: '', interests: ['Books', 'Music'] }, token);
  // The age check, as a provider would finish it: a signed webhook.
  const { url } = await api(base, 'POST', '/v1/me/age-check', undefined, token);
  const body = JSON.stringify({ reference: new URL(url).searchParams.get('ref'), outcome: 'passed', age: 30 });
  const t = Math.floor(Date.now() / 1000);
  const v1 = createHmac('sha256', ageSecret).update(`${t}.${body}`).digest('hex');
  const hook = await fetch(`${base}/v1/webhooks/age-check`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'vawra-signature': `t=${t},v1=${v1}` },
    body,
  });
  if (hook.status !== 200) throw new Error(`age webhook -> ${hook.status}`);
  const me = await api(base, 'GET', '/v1/me/profile', undefined, token);
  if (me.age_state !== 'adult_verified') throw new Error(`${name} not verified: ${me.age_state}`);
  return { base, token, id: session.account_id, name };
}

const failures = [];
const check = (ok, what) => {
  log(`${ok ? 'PASS' : 'FAIL'} ${what}`);
  if (!ok) failures.push(what);
};

let browser;
try {
  const alex = await member(0, 'relay-alex@example.test', 'Alex');
  const maya = await member(1, 'relay-maya@example.test', 'Maya');
  const people = (await api(alex.base, 'GET', '/v1/discovery?limit=50', undefined, alex.token)).people;
  await api(alex.base, 'POST', `/v1/discovery/${people.find((p) => p.display_name === 'Maya').account_id}/swipe`, { kind: 'like' }, alex.token);
  const back = (await api(maya.base, 'GET', '/v1/discovery?limit=50', undefined, maya.token)).people;
  await api(maya.base, 'POST', `/v1/discovery/${back.find((p) => p.display_name === 'Alex').account_id}/swipe`, { kind: 'like' }, maya.token);
  const matchId = (await api(alex.base, 'GET', '/v1/matches', undefined, alex.token)).matches[0].match_id;
  for (const p of [alex, maya]) await api(p.base, 'PUT', `/v1/matches/${matchId}/call-ready`, { ready: true }, p.token);
  log('Alex and Maya: ages confirmed by webhook, matched, both open to calls');

  // --- The call --------------------------------------------------------------
  const chromes = join(process.env.LOCALAPPDATA ?? '', 'ms-playwright');
  const build = existsSync(chromes) ? readdirSync(chromes).filter((d) => /^chromium-\d+$/.test(d)).sort().pop() : undefined;
  const executablePath = process.env.CHROME_PATH ?? (build ? join(chromes, build, 'chrome-win64', 'chrome.exe') : undefined);
  browser = await chromium.launch({
    executablePath,
    args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream'],
  });
  const open = async (p) => {
    const page = await (await browser.newContext({ permissions: ['camera', 'microphone'] })).newPage();
    await page.goto(`${p.base}/v1/health`); // a secure context (localhost) for the camera
    return page;
  };
  const pageA = await open(alex);
  const pageB = await open(maya);

  const call = await api(alex.base, 'POST', `/v1/matches/${matchId}/calls`, { kind: 'video' }, alex.token);
  check(call.ice?.policy === 'relay', 'the server hands out relay-only call settings');
  check(call.ice.servers.every((s) => s.urls.every((u) => u.startsWith('turn:'))), 'and no STUN server, so no address is learned outside the relay');
  const ringing = await api(maya.base, 'GET', `/v1/calls/${call.call_id}`, undefined, maya.token);
  check(ringing.state === 'ringing' && ringing.role === 'callee', `Maya's ${postgres ? 'other ' : ''}server sees the call ringing`);
  const answered = await api(maya.base, 'POST', `/v1/calls/${call.call_id}/answer`, undefined, maya.token);

  const setup = async (page, ice) =>
    page.evaluate(async (ice) => {
      const pc = new RTCPeerConnection({ iceServers: ice.servers, iceTransportPolicy: ice.policy === 'relay' ? 'relay' : 'all' });
      window.pc = pc;
      window.outbox = [];
      window.candidateTypes = [];
      pc.onicecandidate = (e) => {
        if (!e.candidate) return;
        window.candidateTypes.push(e.candidate.type);
        window.outbox.push({ type: 'candidate', data: JSON.stringify(e.candidate) });
      };
      const media = await navigator.mediaDevices.getUserMedia({ audio: true, video: true });
      for (const track of media.getTracks()) pc.addTrack(track, media);
    }, ice);
  await setup(pageA, call.ice);
  await setup(pageB, answered.ice);
  await pageA.evaluate(async () => {
    const offer = await window.pc.createOffer();
    await window.pc.setLocalDescription(offer);
    window.outbox.push({ type: 'offer', data: JSON.stringify(offer) });
  });

  // Signals travel through Vawra, as in the app: post your own, read the other's.
  const sides = [
    { who: alex, page: pageA, after: 0 },
    { who: maya, page: pageB, after: 0 },
  ];
  const deadline = Date.now() + 30_000;
  let connected = false;
  while (Date.now() < deadline && !connected) {
    for (const side of sides) {
      const out = await side.page.evaluate(() => window.outbox.splice(0));
      for (const s of out) await api(side.who.base, 'POST', `/v1/calls/${call.call_id}/signals`, s, side.who.token);
      const got = await api(side.who.base, 'GET', `/v1/calls/${call.call_id}/signals?after=${side.after}`, undefined, side.who.token);
      for (const s of got.signals) {
        side.after = Math.max(side.after, s.seq);
        await side.page.evaluate(async (s) => {
          const pc = window.pc;
          if (s.type === 'candidate') return pc.addIceCandidate(JSON.parse(s.data));
          await pc.setRemoteDescription(JSON.parse(s.data));
          if (s.type === 'offer') {
            const answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            window.outbox.push({ type: 'answer', data: JSON.stringify(answer) });
          }
        }, s);
      }
    }
    connected = (await Promise.all(sides.map((s) => s.page.evaluate(() => window.pc.connectionState)))).every((x) => x === 'connected');
    await sleep(250);
  }
  check(connected, 'both sides connect');
  if (connected) {
    await sleep(8000); // let media flow
    const stats = (page) =>
      page.evaluate(async () => {
        const report = [...(await window.pc.getStats()).values()];
        const byId = Object.fromEntries(report.map((r) => [r.id, r]));
        const pair = report.find((r) => r.type === 'candidate-pair' && r.nominated && r.state === 'succeeded');
        const video = report.find((r) => r.type === 'inbound-rtp' && r.kind === 'video');
        const audio = report.find((r) => r.type === 'inbound-rtp' && r.kind === 'audio');
        const sent = report.find((r) => r.type === 'outbound-rtp' && r.kind === 'video');
        const track = window.pc.getSenders().find((x) => x.track?.kind === 'video')?.track;
        return {
          local: pair && byId[pair.localCandidateId]?.candidateType,
          remote: pair && byId[pair.remoteCandidateId]?.candidateType,
          frames: video?.framesDecoded ?? 0,
          videoBytes: video?.bytesReceived ?? 0,
          audioBytes: audio?.bytesReceived ?? 0,
          offered: [...new Set(window.candidateTypes)],
          sent: sent
            ? `${sent.framesEncoded ?? 0} encoded, ${sent.bytesSent ?? 0} B sent, limited by ${sent.qualityLimitationReason}`
            : 'no video sender stats',
          track: track ? `${track.readyState}${track.muted ? ', muted' : ''}` : 'no video track',
        };
      });
    for (const side of sides) {
      const s = await stats(side.page);
      log(`${side.who.name}: path ${s.local} -> ${s.remote}; ${s.frames} frames, ${s.videoBytes} B video, ${s.audioBytes} B audio; offered ${s.offered}`);
      log(`${side.who.name} sending: ${s.sent}; camera ${s.track}`);
      check(s.local === 'relay' && s.remote === 'relay', `${side.who.name}'s call runs relay to relay`);
      check(s.offered.length === 1 && s.offered[0] === 'relay', `${side.who.name} offered only relay candidates (no device address)`);
      check(s.frames > 50 && s.audioBytes > 5000, `${side.who.name} receives video and audio`);
    }
    check(relay.stats.relayedBytes > 100_000, `the relay carried the media (${relay.stats.relayedBytes} bytes)`);
  }
  await api(alex.base, 'POST', `/v1/calls/${call.call_id}/end`, undefined, alex.token);
  const ended = await api(maya.base, 'GET', `/v1/calls/${call.call_id}`, undefined, maya.token);
  check(ended.state === 'ended' && !('ice' in ended), 'hanging up ends it for both, and the relay details stop');
  check(relay.stats.auths > 0, 'the relay checked Vawra credentials');
} catch (error) {
  failures.push(String(error?.stack ?? error));
  log(error);
} finally {
  await browser?.close();
  // Wait for the servers to exit: Windows keeps their files open until then.
  await Promise.all(
    servers.map(
      (s) =>
        new Promise((resolve) => {
          if (s.child.exitCode !== null) return resolve();
          s.child.once('exit', resolve);
          s.child.kill();
          setTimeout(resolve, 10_000);
        }),
    ),
  );
  relay.stop();
  await sleep(500);
  if (dbName) {
    const pg = require(join(backend, 'node_modules', 'pg'));
    const c = new pg.Client({ connectionString: adminUrl });
    await c.connect();
    await c.query(`DROP DATABASE IF EXISTS ${dbName} WITH (FORCE)`);
    await c.end();
  }
  try {
    rmSync(work, { recursive: true, force: true, maxRetries: 10, retryDelay: 500 });
  } catch (error) {
    log(`could not remove ${work} (${error.code}); it holds only throwaway test data`);
  }
}
if (failures.length) {
  console.log(`\nRELAY CHECK FAILED (${failures.length})`);
  process.exit(1);
}
console.log('\nRELAY CHECK PASSED');
process.exit(0); // the relay's sockets would otherwise keep the process alive
