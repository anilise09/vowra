import type { AddressInfo } from 'node:net';
import { SMTPServer } from 'smtp-server';
import { afterEach, describe, expect, it } from 'vitest';
import { emailProblems, signInMessage, SmtpDelivery } from '../src/email.js';

describe('email settings', () => {
  it('development may leave email out; production may not', () => {
    expect(emailProblems({}, false)).toEqual([]);
    expect(emailProblems({}, true).join()).toMatch(/Production needs VAWRA_SMTP_URL/);
  });

  it('both settings come together, and must be well formed', () => {
    expect(emailProblems({ VAWRA_SMTP_URL: 'smtps://u:p@mail.example.com:465' }, false).join()).toMatch(
      /VAWRA_EMAIL_FROM is missing|VAWRA_SMTP_URL is set but VAWRA_EMAIL_FROM/,
    );
    expect(emailProblems({ VAWRA_SMTP_URL: 'https://mail.example.com', VAWRA_EMAIL_FROM: 'a@b.c' }, false).join()).toMatch(
      /must start with smtps/,
    );
    expect(emailProblems({ VAWRA_SMTP_URL: 'smtps://mail.example.com', VAWRA_EMAIL_FROM: 'not an address' }, false).join()).toMatch(
      /VAWRA_EMAIL_FROM must be an address/,
    );
    expect(
      emailProblems({ VAWRA_SMTP_URL: 'smtp://mail.example.com:587?insecure=1', VAWRA_EMAIL_FROM: 'a@b.c' }, true).join(),
    ).toMatch(/may not turn TLS off/);
    expect(
      emailProblems({ VAWRA_SMTP_URL: 'smtps://u:p@mail.example.com:465', VAWRA_EMAIL_FROM: 'Vawra <no-reply@example.com>' }, true),
    ).toEqual([]);
  });
});

describe('the sign-in email', () => {
  it('says what the code is for, when it expires, and never contains a link', () => {
    const signIn = signInMessage('042917', 'sign_in', 10);
    expect(signIn.subject).toBe('Your Vawra sign-in code');
    expect(signIn.text).toContain('042917');
    expect(signIn.text).toContain('expires in 10 minutes');
    expect(signIn.html).toContain('042917');
    expect(signIn.text + signIn.html).not.toMatch(/https?:\/\//);
    expect(signInMessage('042917', 'recovery', 10).subject).toBe('Your Vawra recovery code');
  });
});

describe('sending over SMTP', () => {
  let server: SMTPServer | undefined;
  afterEach(async () => {
    await new Promise<void>((resolve) => (server ? server.close(() => resolve()) : resolve()));
    server = undefined;
  });

  /** A local mail server that keeps what it receives. */
  async function mailServer(options: { starttls: boolean }) {
    const received: { from: string; to: string[]; data: string }[] = [];
    server = new SMTPServer({
      authOptional: true,
      disabledCommands: options.starttls ? [] : ['STARTTLS'],
      logger: false,
      onData(stream, session, done) {
        let data = '';
        stream.on('data', (chunk) => (data += chunk.toString()));
        stream.on('end', () => {
          received.push({
            from: session.envelope.mailFrom ? session.envelope.mailFrom.address : '',
            to: session.envelope.rcptTo.map((r) => r.address),
            data,
          });
          done();
        });
      },
    });
    await new Promise<void>((resolve) => server!.listen(0, '127.0.0.1', () => resolve()));
    const port = (server!.server.address() as AddressInfo).port;
    return { port, received };
  }

  it('delivers the code to the right person', async () => {
    const { port, received } = await mailServer({ starttls: false });
    const delivery = new SmtpDelivery(
      { smtpUrl: `smtp://127.0.0.1:${port}?insecure=1`, from: 'Vawra <no-reply@vawra.test>' },
      600,
      { allowInsecureForTests: true },
    );
    await delivery.sendProof('maya@example.test', '042917', 'sign_in');
    expect(received).toHaveLength(1);
    expect(received[0]!.from).toBe('no-reply@vawra.test');
    expect(received[0]!.to).toEqual(['maya@example.test']);
    expect(received[0]!.data).toContain('Subject: Your Vawra sign-in code');
    expect(received[0]!.data).toContain('042917');
    expect(received[0]!.data).toMatch(/Auto-Submitted: auto-generated/i);
  });

  it('refuses to send without TLS unless explicitly allowed for tests', async () => {
    const { port, received } = await mailServer({ starttls: false });
    // Without the test switch, a server that cannot encrypt is refused.
    const strict = new SmtpDelivery({ smtpUrl: `smtp://127.0.0.1:${port}?insecure=1`, from: 'no-reply@vawra.test' }, 600);
    await expect(strict.sendProof('maya@example.test', '042917', 'sign_in')).rejects.toThrow();
    expect(received).toHaveLength(0);
  });
});
