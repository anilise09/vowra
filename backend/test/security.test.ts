import { describe, expect, it } from 'vitest';
import { deliveryFailure } from '../src/email.js';
import { member, startHarness } from './harness.js';

describe('security review fixes (2026-10-02)', () => {
  it('a failed sign-in email is logged without the address', () => {
    const smtp = Object.assign(
      new Error("Can't send mail - all recipients were rejected: 550 5.1.1 <someone@example.test>: Recipient address rejected"),
      { code: 'EENVELOPE', responseCode: 550 },
    );
    const logged = deliveryFailure(smtp);
    expect(logged).toEqual({ name: 'Error', code: 'EENVELOPE', response_code: 550 });
    expect(JSON.stringify(logged)).not.toContain('someone@example.test');
    expect(deliveryFailure(undefined)).toEqual({ name: 'Error' });
  });

  it('a malformed query is the caller’s mistake (400), not a server error', async () => {
    const h = await startHarness();
    try {
      const ana = await member(h, 'Ana');
      for (const url of ['/v1/discovery?limit=abc', '/v1/discovery?limit=999', '/v1/matches/x/messages?limit=0']) {
        const res = await h.app.inject({ method: 'GET', url, headers: ana.auth });
        expect(res.statusCode, url).toBeLessThan(500);
      }
      const res = await h.app.inject({ method: 'GET', url: '/v1/discovery?limit=abc', headers: ana.auth });
      expect(res.statusCode).toBe(400);
      expect(res.json().error).toBe('invalid_request');
    } finally {
      await h.close();
    }
  });
});
