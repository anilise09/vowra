import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { safetyHints } from '../src/safety_hints.js';
import { type Harness, member, startHarness, swipe } from './harness.js';

describe('safety hints', () => {
  const flagged: [string, string][] = [
    ['Can you send me $200 for my rent?', 'money'],
    ['could you lend me some money until Friday', 'money'],
    ['I need money for the hospital bill', 'money'],
    ['Buy me a Google Play card and send the code', 'money'],
    ['I trade bitcoin, I can show you how to double it', 'money'],
    ['great investment opportunity, trust me', 'money'],
    ['just send it on Cash App', 'money'],
    ['Add me on WhatsApp, I rarely check this app', 'off_platform'],
    ['text me at +1 (204) 555-0182', 'off_platform'],
    ['my email is maya.test@example.com', 'off_platform'],
    ['let us talk on telegram', 'off_platform'],
    ['look at my pics www.not-a-scam.example', 'link'],
    ['https://bit.ly/abc', 'link'],
    ['check cute-pics.xyz/me', 'link'],
  ];
  const clean = [
    'I sent my mum money for her birthday',
    'We should split the bill at the concert',
    'My favourite app for recipes is great',
    'I was born in 1994 and moved here in 2019',
    'Coffee on Saturday at 10?',
    'The meetup is at 7 pm near the station',
  ];

  it.each(flagged)('flags "%s" as %s', (text, hint) => {
    expect(safetyHints(text)).toContain(hint);
  });

  it.each(clean)('leaves "%s" alone', (text) => {
    expect(safetyHints(text)).toEqual([]);
  });
});

describe('in a conversation', () => {
  let h: Harness;
  beforeEach(async () => (h = await startHarness()));
  afterEach(async () => h.close());

  it('only the person receiving the message sees the warning', async () => {
    const ana = await member(h, 'Ana');
    const ben = await member(h, 'Ben');
    await swipe(h, ana, ben);
    const matchId = (await swipe(h, ben, ana)).json().match_id;
    await h.app.inject({
      method: 'POST',
      url: `/v1/matches/${matchId}/messages`,
      headers: ben.auth,
      payload: { text: 'Add me on WhatsApp and send me a gift card' },
    });
    const forAna = (
      await h.app.inject({ method: 'GET', url: `/v1/matches/${matchId}/messages`, headers: ana.auth })
    ).json().messages;
    expect(forAna[0].safety_hints).toEqual(['money', 'off_platform']);
    const forBen = (
      await h.app.inject({ method: 'GET', url: `/v1/matches/${matchId}/messages`, headers: ben.auth })
    ).json().messages;
    expect(forBen[0].safety_hints).toBeUndefined();
  });
});
