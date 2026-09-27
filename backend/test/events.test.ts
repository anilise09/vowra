import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { maxStreamsPerAccount } from '../src/routes/events.js';
import { type Harness, member, type Person, signIn, startHarness, swipe } from './harness.js';

let h: Harness;
let base: string;
const aborts: AbortController[] = [];

beforeEach(async () => {
  h = await startHarness();
  base = await h.app.listen({ host: '127.0.0.1', port: 0 });
});
afterEach(async () => {
  for (const a of aborts.splice(0)) a.abort();
  await h.close();
});

interface Stream {
  status: number;
  /** Everything received so far. */
  text(): string;
  nudges(): unknown[];
  waitFor(check: (s: Stream) => boolean, ms?: number): Promise<void>;
  ended(): boolean;
}

async function open(p: Person): Promise<Stream> {
  const abort = new AbortController();
  aborts.push(abort);
  const res = await fetch(`${base}/v1/events`, { headers: p.auth, signal: abort.signal });
  let buffer = '';
  let done = false;
  if (res.ok && res.body) {
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    void (async () => {
      try {
        for (;;) {
          const chunk = await reader.read();
          if (chunk.done) break;
          buffer += decoder.decode(chunk.value, { stream: true });
        }
      } catch {
        // aborted at the end of the test
      }
      done = true;
    })();
  } else {
    buffer = await res.text();
    done = true;
  }
  const stream: Stream = {
    status: res.status,
    text: () => buffer,
    ended: () => done,
    nudges: () =>
      buffer
        .split('\n\n')
        .filter((block) => block.startsWith('event: nudge'))
        .map((block) => JSON.parse(block.split('\ndata: ')[1]!)),
    async waitFor(check, ms = 3000) {
      const until = Date.now() + ms;
      while (!check(stream)) {
        if (Date.now() > until) throw new Error(`timed out; received: ${JSON.stringify(buffer)}`);
        await new Promise((r) => setTimeout(r, 20));
      }
    },
  };
  if (res.ok) await stream.waitFor((s) => s.text().includes(': connected'));
  return stream;
}

const post = (p: Person, url: string, payload: object) =>
  h.app.inject({ method: 'POST', url, headers: p.auth, payload });

async function matched(a: Person, b: Person): Promise<string> {
  await swipe(h, a, b);
  return (await swipe(h, b, a)).json().match_id;
}

/** Lets any nudge in flight arrive before checking that none did. */
const settle = () => new Promise((r) => setTimeout(r, 150));

describe('nudge stream', () => {
  it('needs a signed-in adult account', async () => {
    const anonymous = await fetch(`${base}/v1/events`);
    expect(anonymous.status).toBe(401);
    const unverified = await signIn(h, 'new@example.test');
    expect((await open(unverified)).status).toBe(403);
  });

  it('a message nudges the other person with no content, and nobody else', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const cy = await member(h, 'Cy');
    const matchId = await matched(ana, ben);
    const benStream = await open(ben);
    const cyStream = await open(cy);

    await post(ana, `/v1/matches/${matchId}/messages`, { text: 'A very private hello' });
    await benStream.waitFor((s) => s.nudges().length > 0);
    expect(benStream.nudges()).toEqual([{ kind: 'message', match_id: matchId }]);
    expect(benStream.text()).not.toContain('private');
    expect(benStream.text()).not.toContain('Ana');
    await settle();
    expect(cyStream.nudges()).toEqual([]);
  });

  it("the sender's other devices hear about their own message too", async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const anaTablet = await signIn(h, ana.email);
    const matchId = await matched(ana, ben);
    const tablet = await open(anaTablet);
    await post(ana, `/v1/matches/${matchId}/messages`, { text: 'Hi' });
    await tablet.waitFor((s) => s.nudges().length > 0);
    expect(tablet.nudges()).toEqual([{ kind: 'message', match_id: matchId }]);
  });

  it('a like nudges them; the match nudges both; a pass nudges nobody', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    const cy = await member(h, 'Cy');
    const anaStream = await open(ana);
    const benStream = await open(ben);

    await swipe(h, cy, ben, 'pass');
    await settle();
    expect(benStream.nudges()).toEqual([]);

    await swipe(h, ana, ben);
    await benStream.waitFor((s) => s.nudges().length === 1);
    expect(benStream.nudges()).toEqual([{ kind: 'like' }]);
    // Repeating a decision already made is not news.
    await swipe(h, ana, ben);
    await settle();
    expect(benStream.nudges()).toHaveLength(1);

    const matchId = (await swipe(h, ben, ana)).json().match_id;
    await anaStream.waitFor((s) => s.nudges().length === 1);
    await benStream.waitFor((s) => s.nudges().length === 2);
    expect(anaStream.nudges()).toEqual([{ kind: 'match', match_id: matchId }]);
    expect(benStream.nudges()[1]).toEqual({ kind: 'match', match_id: matchId });
  });

  it('blocking is never announced to the blocked person', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await matched(ana, ben);
    const benStream = await open(ben);
    await post(ana, '/v1/blocks', { account_id: ben.accountId });
    await settle();
    expect(benStream.nudges()).toEqual([]);
  });

  it('ends when the access token expires', async () => {
    const ana = await member(h, 'Ana');
    h.clock.advance(899_000); // one second of the 900-second token left
    const stream = await open(ana);
    await stream.waitFor((s) => s.ended(), 5000);
  });

  it(`allows ${maxStreamsPerAccount} open streams per account`, async () => {
    const ana = await member(h, 'Ana');
    for (let i = 0; i < maxStreamsPerAccount; i++) expect((await open(ana)).status).toBe(200);
    const extra = await open(ana);
    expect(extra.status).toBe(429);
    expect(extra.text()).toContain('too_many_streams');
  });
});
