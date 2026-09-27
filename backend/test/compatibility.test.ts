import { describe, expect, it } from 'vitest';
import { compatibility } from '../src/compatibility.js';
import { type Harness, member, startHarness, swipe } from './harness.js';

const p = (
  relationship_intent: string,
  interests: string[] = [],
  lifestyle: Record<string, string> = {},
) => ({ relationship_intent, interests, lifestyle });

describe('compatibility', () => {
  it('scores only what the two people share, with a reason for each part', () => {
    const fit = compatibility(
      p('long_term', ['Books', 'Music', 'Travel'], { pets: 'Dog person', smoking: 'No' }),
      p('long_term', ['Music', 'Books', 'Arts'], { pets: 'Dog person', smoking: 'Yes' }),
    );
    expect(fit.score).toBe(3 + 2 + 0.5);
    expect(fit.reasons).toEqual([
      { kind: 'goal', text: 'Both want something long-term' },
      { kind: 'interests', text: 'You both like Books and Music' },
      { kind: 'habit', text: 'Both dog people' },
    ]);
  });

  it('treats long-term and open-to-long-term as close, not the same', () => {
    const fit = compatibility(p('long_term'), p('open_to_long_term'));
    expect(fit).toEqual({
      score: 2,
      reasons: [{ kind: 'goal', text: 'Both open to something long-term' }],
    });
    expect(compatibility(p('casual'), p('long_term'))).toEqual({ score: 0, reasons: [] });
  });

  it('keeps reasons short: at most three, long lists summarised', () => {
    const all = ['Arts', 'Books', 'Cooking', 'Fitness', 'Music'];
    const fit = compatibility(
      p('casual', all, { drinking: 'Never', smoking: 'No', exercise: 'Daily' }),
      p('casual', all, { drinking: 'Never', smoking: 'No', exercise: 'Daily' }),
    );
    expect(fit.reasons.map((r) => r.text)).toEqual([
      'Both keeping it casual',
      'You both like Arts, Books, Cooking and 2 more',
      'Neither drinks',
    ]);
  });
});

describe('Discover order', () => {
  let h: Harness;

  it('follows visible compatibility, and popularity changes nothing', async () => {
    h = await startHarness();
    try {
      const patch = (who: { auth: { authorization: string } }, payload: object) =>
        h.app.inject({ method: 'PATCH', url: '/v1/me/profile', headers: who.auth, payload });
      const me = await member(h, 'Me');
      await patch(me, { relationship_intent: 'casual', interests: ['Books', 'Music'] });
      const popular = await member(h, 'Popular'); // long_term, Books (harness default)
      const close = await member(h, 'Close');
      await patch(close, { relationship_intent: 'casual', interests: ['Books', 'Music'] });
      const some = await member(h, 'Some');
      await patch(some, { relationship_intent: 'casual' });
      // Many people like Popular; it must not move up.
      for (const n of ['Fan1', 'Fan2', 'Fan3']) await swipe(h, await member(h, n), popular);

      const people = (
        await h.app.inject({ method: 'GET', url: '/v1/discovery', headers: me.auth })
      ).json().people as { display_name: string; reasons: { text: string }[] }[];
      const order = people.map((x) => x.display_name).filter((n) => !n.startsWith('Fan'));
      expect(order).toEqual(['Close', 'Some', 'Popular']);
      expect(people[0]!.reasons.map((r) => r.text)).toEqual([
        'Both keeping it casual',
        'You both like Books and Music',
      ]);
    } finally {
      await h.close();
    }
  });
});
