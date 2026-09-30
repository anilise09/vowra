import nodemailer from 'nodemailer';
import type { Delivery } from './context.js';

/**
 * Sign-in codes by email through any SMTP provider (Amazon SES, Postmark,
 * Resend, Mailgun and others all offer SMTP), so no provider is built in.
 *   VAWRA_SMTP_URL    smtps://user:password@smtp.example.com:465 (or smtp://... with STARTTLS)
 *   VAWRA_EMAIL_FROM  "Vawra <no-reply@example.com>"
 */
export interface EmailConfig {
  smtpUrl: string;
  from: string;
}

/** Problems with the email settings; production needs them, development may leave them out. */
export function emailProblems(env: NodeJS.ProcessEnv, production: boolean): string[] {
  const problems: string[] = [];
  const url = env.VAWRA_SMTP_URL;
  const from = env.VAWRA_EMAIL_FROM;
  if (!url && !from) {
    if (production) problems.push('Production needs VAWRA_SMTP_URL and VAWRA_EMAIL_FROM to send sign-in codes.');
    return problems;
  }
  if (!url) problems.push('VAWRA_EMAIL_FROM is set but VAWRA_SMTP_URL is missing.');
  if (!from) problems.push('VAWRA_SMTP_URL is set but VAWRA_EMAIL_FROM is missing.');
  if (url) {
    let parsed: URL | undefined;
    try {
      parsed = new URL(url);
    } catch {
      problems.push('VAWRA_SMTP_URL is not a valid URL (smtps://user:password@host:465).');
    }
    if (parsed && !['smtp:', 'smtps:'].includes(parsed.protocol)) {
      problems.push('VAWRA_SMTP_URL must start with smtps:// or smtp://.');
    }
    // Plain smtp:// is allowed only where STARTTLS is required below; a local
    // relay without TLS is for development only.
    if (parsed && production && parsed.protocol === 'smtp:' && parsed.searchParams.get('insecure') === '1') {
      problems.push('VAWRA_SMTP_URL may not turn TLS off in production.');
    }
  }
  if (from && !/^[^<>\r\n]*<[^<>@\s\r\n]+@[^<>@\s\r\n]+>$|^[^<>@\s\r\n]+@[^<>@\s\r\n]+$/.test(from)) {
    problems.push('VAWRA_EMAIL_FROM must be an address, optionally with a name: "Vawra <no-reply@example.com>".');
  }
  return problems;
}

export function emailConfigFrom(env: NodeJS.ProcessEnv): EmailConfig | null {
  if (!env.VAWRA_SMTP_URL || !env.VAWRA_EMAIL_FROM) return null;
  return { smtpUrl: env.VAWRA_SMTP_URL, from: env.VAWRA_EMAIL_FROM };
}

/** The words of the email: short, no links, nothing that looks like marketing. */
export function signInMessage(code: string, purpose: 'sign_in' | 'recovery', minutes: number) {
  const action = purpose === 'recovery' ? 'recover your Vawra account' : 'sign in to Vawra';
  const subject = purpose === 'recovery' ? 'Your Vawra recovery code' : 'Your Vawra sign-in code';
  const text = [
    `Your code to ${action} is:`,
    '',
    `    ${code}`,
    '',
    `It works once and expires in ${minutes} minutes. Enter it in the app on the phone where you asked for it.`,
    '',
    'If you did not ask for this code, you can ignore this email. Nobody can use it without your phone.',
    'Vawra will never ask you for this code by message, call or chat.',
  ].join('\n');
  const html = `<!doctype html><html><body style="margin:0;padding:32px 16px;background:#fff9f7;font-family:Arial,Helvetica,sans-serif;color:#2c1035">
<div style="max-width:440px;margin:0 auto;background:#ffffff;border:1px solid #eadfe5;border-radius:20px;padding:28px">
<p style="margin:0 0 6px;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:#ed3c89;font-weight:bold">Vawra</p>
<p style="margin:0 0 18px;font-size:16px">Your code to ${action} is:</p>
<p style="margin:0 0 18px;font-size:34px;letter-spacing:.3em;font-weight:bold">${code}</p>
<p style="margin:0 0 12px;font-size:14px;line-height:1.6;color:#736777">It works once and expires in ${minutes} minutes. Enter it in the app on the phone where you asked for it.</p>
<p style="margin:0;font-size:13px;line-height:1.6;color:#736777">If you did not ask for this code, you can ignore this email. Vawra will never ask you for this code by message, call or chat.</p>
</div></body></html>`;
  return { subject, text, html };
}

/**
 * Sends sign-in codes over SMTP. TLS is required: smtps:// connects over TLS,
 * smtp:// must upgrade with STARTTLS, and the server certificate is verified.
 */
export class SmtpDelivery implements Delivery {
  private readonly transport;

  constructor(
    private readonly config: EmailConfig,
    private readonly proofTtlSeconds: number,
    options: { allowInsecureForTests?: boolean } = {},
  ) {
    const url = new URL(config.smtpUrl);
    const insecure = options.allowInsecureForTests === true && url.searchParams.get('insecure') === '1';
    this.transport = nodemailer.createTransport({
      host: url.hostname,
      port: Number(url.port || (url.protocol === 'smtps:' ? 465 : 587)),
      secure: url.protocol === 'smtps:',
      requireTLS: !insecure && url.protocol === 'smtp:',
      ignoreTLS: insecure,
      auth: url.username
        ? { user: decodeURIComponent(url.username), pass: decodeURIComponent(url.password) }
        : undefined,
      tls: { rejectUnauthorized: !insecure, minVersion: 'TLSv1.2' },
      connectionTimeout: 10_000,
      greetingTimeout: 10_000,
      socketTimeout: 20_000,
    });
  }

  async sendProof(email: string, proof: string, purpose: 'sign_in' | 'recovery'): Promise<void> {
    const message = signInMessage(proof, purpose, Math.round(this.proofTtlSeconds / 60));
    await this.transport.sendMail({
      from: this.config.from,
      to: email,
      subject: message.subject,
      text: message.text,
      html: message.html,
      // Not a newsletter: no tracking, and replies go nowhere useful.
      headers: { 'Auto-Submitted': 'auto-generated', 'X-Auto-Response-Suppress': 'All' },
    });
  }
}
