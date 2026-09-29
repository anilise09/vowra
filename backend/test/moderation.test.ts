import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { type Harness, member, type Person, signIn, startHarness, swipe } from './harness.js';

let h: Harness;
beforeEach(async () => (h = await startHarness()));
afterEach(async () => h.close());

const MINUTE = 60_000;

const call = (p: Person, method: 'GET' | 'POST' | 'DELETE', url: string, payload?: object) =>
  h.app.inject({ method, url, headers: p.auth, ...(payload ? { payload } : {}) });

async function moderator(name: string): Promise<Person> {
  const p = await member(h, name);
  await h.db.query("UPDATE accounts SET role = 'moderator' WHERE id = $1", [p.accountId]);
  return p;
}

/** Ana and Ben match; Ben sends two messages; Ana reports the second. */
async function reportedChat() {
  const ana = await member(h, 'Ana');
  const ben = await member(h, 'Ben');
  await swipe(h, ana, ben);
  const matchId = (await swipe(h, ben, ana)).json().match_id;
  await call(ben, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Hi, nice to match' });
  const bad = (
    await call(ben, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Send me money now' })
  ).json();
  await call(ana, 'POST', '/v1/reports', { account_id: ben.accountId, reason: 'scam', message_id: bad.id });
  return { ana, ben, matchId };
}

const queue = async (mod: Person) => (await call(mod, 'GET', '/v1/mod/reports')).json().reports;

describe('moderation', () => {
  it('only moderators see the queue; the evidence is the one reported message', async () => {
    const { ana, ben } = await reportedChat();
    for (const p of [ana, ben]) {
      expect((await call(p, 'GET', '/v1/mod/reports')).statusCode).toBe(404);
      expect((await call(p, 'GET', '/v1/mod/appeals')).statusCode).toBe(404);
    }
    const mod = await moderator('Mo');
    const reports = await queue(mod);
    expect(reports).toHaveLength(1);
    expect(reports[0]).toMatchObject({
      reason: 'scam',
      account_id: ben.accountId,
      display_name: 'Ben',
      status: 'active',
      message: { text: 'Send me money now' },
      reports_against: 1,
      reporter_report_count: 1,
    });
    const raw = JSON.stringify(reports);
    expect(raw).not.toContain('Hi, nice to match');
    expect(raw).not.toContain(ana.accountId);
  });

  it('a moderator never handles reports by or about themselves', async () => {
    const mod = await moderator('Mo');
    const ben = await member(h, 'Ben');
    await call(mod, 'POST', '/v1/reports', { account_id: ben.accountId, reason: 'harassment' });
    await call(ben, 'POST', '/v1/reports', { account_id: mod.accountId, reason: 'other' });
    expect(await queue(mod)).toEqual([]);
    const [row] = await h.db.query<{ id: string }>('SELECT id FROM reports WHERE reporter = $1', [
      mod.accountId,
    ]);
    const res = await call(mod, 'POST', `/v1/mod/reports/${row!.id}/decision`, { outcome: 'dismissed' });
    expect(res.json().error).toBe('conflict_of_interest');
  });

  it('dismissing clears it from the queue and changes nothing for the person', async () => {
    const { ben } = await reportedChat();
    const mod = await moderator('Mo');
    const [report] = await queue(mod);
    const res = await call(mod, 'POST', `/v1/mod/reports/${report.report_id}/decision`, {
      outcome: 'dismissed',
      note: 'Joke between friends',
    });
    expect(res.json()).toEqual({ state: 'dismissed' });
    expect(await queue(mod)).toEqual([]);
    expect((await call(ben, 'GET', '/v1/me/profile')).json().lifecycle).toBe('active');
    const again = await call(mod, 'POST', `/v1/mod/reports/${report.report_id}/decision`, {
      outcome: 'suspended',
    });
    expect(again.json().error).toBe('already_decided');
  });

  it('suspending hides them, signs them out and closes their chats', async () => {
    const { ana, ben, matchId } = await reportedChat();
    const cy = await member(h, 'Cy');
    const mod = await moderator('Mo');
    const [report] = await queue(mod);
    const res = await call(mod, 'POST', `/v1/mod/reports/${report.report_id}/decision`, {
      outcome: 'suspended',
    });
    expect(res.json()).toEqual({ state: 'actioned' });

    expect((await call(ben, 'GET', '/v1/me/profile')).statusCode).toBe(401);
    const seen = (await call(cy, 'GET', '/v1/discovery')).json().people;
    expect(seen.map((p: { account_id: string }) => p.account_id)).not.toContain(ben.accountId);
    expect((await call(ana, 'GET', '/v1/matches')).json().matches).toEqual([]);
    const send = await call(ana, 'POST', `/v1/matches/${matchId}/messages`, { text: 'Hello?' });
    expect(send.json().error).toBe('conversation_closed');

    const back = await signIn(h, ben.email);
    const me = (await call(back, 'GET', '/v1/me/profile')).json();
    expect(me.lifecycle).toBe('suspended');
    expect(me.suspension).toMatchObject({ reason: 'scam', appeal: null });
    expect(JSON.stringify(me)).not.toContain(mod.accountId);
    expect((await call(back, 'GET', '/v1/discovery')).json().error).toBe('account_suspended');
    expect((await call(back, 'POST', '/v1/me/pause')).json().error).toBe('account_suspended');
    expect((await call(back, 'DELETE', '/v1/me/pause')).json().error).toBe('account_suspended');
  });

  it('decisions need a recent sign-in', async () => {
    await reportedChat();
    const mod = await moderator('Mo');
    const [report] = await queue(mod);
    h.clock.advance(11 * MINUTE);
    const rotated = (
      await h.app.inject({ method: 'POST', url: '/v1/session/rotate', payload: { refresh_token: mod.refresh } })
    ).json();
    const stale = { ...mod, auth: { authorization: `Bearer ${rotated.access_token}` } };
    const res = await call(stale, 'POST', `/v1/mod/reports/${report.report_id}/decision`, {
      outcome: 'suspended',
    });
    expect(res.json().error).toBe('reauthentication_required');
  });

  it('one appeal at a time, decided by a different moderator', async () => {
    const { ben } = await reportedChat();
    const mo = await moderator('Mo');
    const [report] = await queue(mo);
    await call(mo, 'POST', `/v1/mod/reports/${report.report_id}/decision`, { outcome: 'suspended' });
    const back = await signIn(h, ben.email);

    const appeal = await call(back, 'POST', '/v1/me/appeal', { message: 'That was my brother on my phone.' });
    expect(appeal.statusCode).toBe(202);
    const twice = await call(back, 'POST', '/v1/me/appeal', { message: 'Please look again.' });
    expect(twice.json().error).toBe('appeal_open');
    expect((await call(back, 'GET', '/v1/me/profile')).json().suspension.appeal.state).toBe('open');

    const [open] = (await call(mo, 'GET', '/v1/mod/appeals')).json().appeals;
    expect(open).toMatchObject({ display_name: 'Ben', suspended_by_you: true, suspension_reason: 'scam' });
    const same = await call(mo, 'POST', `/v1/mod/appeals/${open.appeal_id}/decision`, {
      outcome: 'overturned',
    });
    expect(same.json().error).toBe('second_moderator_required');

    const kim = await moderator('Kim');
    const [forKim] = (await call(kim, 'GET', '/v1/mod/appeals')).json().appeals;
    expect(forKim.suspended_by_you).toBe(false);
    const upheld = await call(kim, 'POST', `/v1/mod/appeals/${forKim.appeal_id}/decision`, {
      outcome: 'upheld',
    });
    expect(upheld.json()).toEqual({ state: 'upheld' });
    expect((await call(back, 'GET', '/v1/me/profile')).json().lifecycle).toBe('suspended');

    // Upheld: they may try once more; this time it is overturned.
    await call(back, 'POST', '/v1/me/appeal', { message: 'I have changed my number since.' });
    const [second] = (await call(kim, 'GET', '/v1/mod/appeals')).json().appeals;
    await call(kim, 'POST', `/v1/mod/appeals/${second.appeal_id}/decision`, { outcome: 'overturned' });
    const restored = (await call(back, 'GET', '/v1/me/profile')).json();
    expect(restored.lifecycle).toBe('active');
    expect(restored.suspension).toBeNull();
    const cy = await member(h, 'Cy');
    const seen = (await call(cy, 'GET', '/v1/discovery')).json().people;
    expect(seen.map((p: { account_id: string }) => p.account_id)).toContain(ben.accountId);
  });

  it('only a suspended person can appeal, with a real message', async () => {
    const ana = await member(h, 'Ana');
    expect((await call(ana, 'POST', '/v1/me/appeal', { message: 'Hi' })).json().error).toBe(
      'not_suspended',
    );
    await h.db.query("UPDATE accounts SET lifecycle = 'suspended', suspended_at = now() WHERE id = $1", [
      ana.accountId,
    ]);
    for (const payload of [{ message: '   ' }, { message: 'x'.repeat(1001) }, {}, { message: 'ok', extra: 1 }]) {
      expect((await call(ana, 'POST', '/v1/me/appeal', payload)).statusCode).toBe(400);
    }
  });

  it('the person’s export has the suspension and their appeal, not the notes', async () => {
    const { ben } = await reportedChat();
    const mo = await moderator('Mo');
    const [report] = await queue(mo);
    await call(mo, 'POST', `/v1/mod/reports/${report.report_id}/decision`, {
      outcome: 'suspended',
      note: 'INTERNAL-NOTE-XYZ',
    });
    const back = await signIn(h, ben.email);
    await call(back, 'POST', '/v1/me/appeal', { message: 'Please review this.' });
    const data = (await call(back, 'GET', '/v1/me/export')).json();
    expect(data.suspension).toMatchObject({ reason: 'scam' });
    expect(data.appeals_you_made).toEqual([
      expect.objectContaining({ message: 'Please review this.', state: 'open' }),
    ]);
    const raw = JSON.stringify(data);
    expect(raw).not.toContain('INTERNAL-NOTE-XYZ');
    expect(raw).not.toContain(mo.accountId);
  });

  it('asking for deletion and cancelling does not lift a suspension', async () => {
    const { ben } = await reportedChat();
    const mo = await moderator('Mo');
    const [report] = await queue(mo);
    await call(mo, 'POST', `/v1/mod/reports/${report.report_id}/decision`, { outcome: 'suspended' });
    const back = await signIn(h, ben.email);
    expect((await call(back, 'POST', '/v1/me/deletion')).statusCode).toBe(202);
    const again = await signIn(h, ben.email);
    expect((await call(again, 'DELETE', '/v1/me/deletion')).statusCode).toBe(204);
    expect((await call(again, 'GET', '/v1/me/profile')).json().lifecycle).toBe('suspended');
  });
});
