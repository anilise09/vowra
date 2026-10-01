// Load test, in process: a fresh in-memory database, many members, and a busy
// mix of Discover, likes, chat and profile reads at once. Measures the
// server's own work (routing, rules, SQL on PGlite), not the network.
//   npm run load                 100 members, 3000 requests, 25 at a time
//   npm run load -- 200 6000 50  members, requests, concurrency
//   npm run load -- --shared     the same, sharing state through the database
import { performance } from 'node:perf_hooks';
import { pkceChallenge } from '../src/crypto.js';
import { makeProfile, markAdult, type Person, startHarness, state, swipe, verifier } from '../test/harness.js';

const [members = 100, total = 3000, concurrency = 25] = process.argv.slice(2).filter((a) => !a.startsWith('--')).map(Number);
// --shared: live updates, presence and call setup through the database, as several servers run.
const shared = process.argv.includes('--shared');
const h = await startHarness({ shared });

let seed = 1;
const random = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 2 ** 32);
const pick = <T>(list: T[]) => list[Math.floor(random() * list.length)]!;

/** Signs a member in from their own address, as real phones would be. */
async function member(i: number): Promise<Person> {
  const email = `member${i}@example.test`;
  const remoteAddress = `10.${Math.floor(i / 250)}.${i % 250}.1`;
  const v = verifier();
  const s = state();
  await h.app.inject({
    method: 'POST',
    url: '/v1/auth/requests',
    remoteAddress,
    payload: { identifier: email, purpose: 'sign_in', code_challenge: pkceChallenge(v), state: s },
  });
  const proof = [...h.outbox].reverse().find((m) => m.email === email)!.proof;
  const body = (
    await h.app.inject({
      method: 'POST',
      url: '/v1/auth/exchange',
      remoteAddress,
      payload: { proof, code_verifier: v, state: s },
    })
  ).json();
  const p: Person = {
    email,
    accountId: body.account_id,
    access: body.access_token,
    refresh: body.refresh_token,
    auth: { authorization: `Bearer ${body.access_token}` },
  };
  await makeProfile(h, p, `Member${i}`);
  await markAdult(h, p);
  return p;
}

console.log(`Setting up ${members} members...`);
const setupStart = performance.now();
const people: Person[] = [];
for (let i = 0; i < members; i++) people.push(await member(i));
const matchIds: { a: Person; b: Person; id: string }[] = [];
for (let i = 0; i < members * 3; i++) {
  const a = pick(people);
  const b = pick(people);
  if (a === b) continue;
  const res = await swipe(h, a, b);
  const back = await swipe(h, b, a);
  const id = back.json().match_id ?? res.json().match_id;
  if (id) matchIds.push({ a, b, id });
}
console.log(`Set up in ${((performance.now() - setupStart) / 1000).toFixed(1)} s, ${matchIds.length} matches.`);

type Op = { name: string; run: () => Promise<{ statusCode: number }> };
const ops: (() => Op)[] = [
  () => {
    const p = pick(people);
    return { name: 'discover', run: () => h.app.inject({ method: 'GET', url: '/v1/discovery', headers: p.auth }) };
  },
  () => {
    const p = pick(people);
    return { name: 'matches', run: () => h.app.inject({ method: 'GET', url: '/v1/matches', headers: p.auth }) };
  },
  () => {
    const a = pick(people);
    const b = pick(people);
    return { name: 'like', run: () => swipe(h, a, b, random() < 0.5 ? 'like' : 'pass') };
  },
  () => {
    const m = pick(matchIds);
    return {
      name: 'send',
      run: () =>
        h.app.inject({
          method: 'POST',
          url: `/v1/matches/${m.id}/messages`,
          headers: m.a.auth,
          payload: { text: 'How is your week going?' },
        }),
    };
  },
  () => {
    const m = pick(matchIds);
    return {
      name: 'thread',
      run: () => h.app.inject({ method: 'GET', url: `/v1/matches/${m.id}/messages`, headers: m.b.auth }),
    };
  },
  () => {
    const p = pick(people);
    return { name: 'profile', run: () => h.app.inject({ method: 'GET', url: '/v1/me/profile', headers: p.auth }) };
  },
];

const timings = new Map<string, number[]>();
const statuses = new Map<number, number>();
let done = 0;
const started = performance.now();
async function worker() {
  while (done < total) {
    done++;
    const op = pick(ops)();
    const t0 = performance.now();
    const res = await op.run();
    const ms = performance.now() - t0;
    (timings.get(op.name) ?? timings.set(op.name, []).get(op.name)!).push(ms);
    statuses.set(res.statusCode, (statuses.get(res.statusCode) ?? 0) + 1);
  }
}
await Promise.all(Array.from({ length: concurrency }, worker));
const seconds = (performance.now() - started) / 1000;

const pct = (sorted: number[], p: number) => sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))]!;
console.log(`\n${total} requests, ${concurrency} at a time, in ${seconds.toFixed(1)} s (${(total / seconds).toFixed(0)}/s)`);
console.log('operation   count    p50 ms   p95 ms   p99 ms');
for (const [name, list] of [...timings].sort()) {
  const s = [...list].sort((x, y) => x - y);
  console.log(
    `${name.padEnd(10)} ${String(s.length).padStart(6)} ${pct(s, 0.5).toFixed(1).padStart(9)} ${pct(s, 0.95)
      .toFixed(1)
      .padStart(8)} ${pct(s, 0.99).toFixed(1).padStart(8)}`,
  );
}
console.log('status codes:', Object.fromEntries([...statuses].sort()));
const errors = [...statuses].filter(([code]) => code >= 500).reduce((n, [, c]) => n + c, 0);
await h.close();
if (errors > 0) {
  console.error(`${errors} server errors`);
  process.exit(1);
}
