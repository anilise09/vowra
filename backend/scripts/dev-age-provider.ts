// Development only: a stand-in for an age-check provider, so the whole age
// check can be tried on a phone before a real provider is chosen. It serves the
// page the app opens and, when you pick an outcome, sends Vawra the same signed
// webhook a provider adapter would. It never checks anyone's age, listens only
// on this machine, and refuses to run with VAWRA_ENV=production.
//
//   Vawra server:  VAWRA_AGE_CHECK_URL=http://127.0.0.1:8798/start?ref={reference}
//                  VAWRA_AGE_WEBHOOK_SECRET=<32+ characters, the same below>
//   This:          VAWRA_AGE_WEBHOOK_SECRET=... VAWRA_URL=http://127.0.0.1:8797 npm run dev:age-provider
// On a phone over USB: adb reverse tcp:8798 tcp:8798.
import { createServer } from 'node:http';
import { signAgeWebhook } from '../src/routes/age.js';

if (process.env.VAWRA_ENV === 'production') {
  console.error('Refusing: the stand-in age check is for development only.');
  process.exit(1);
}
const secret = process.env.VAWRA_AGE_WEBHOOK_SECRET ?? '';
if (secret.length < 32) {
  console.error('Set VAWRA_AGE_WEBHOOK_SECRET (32+ characters), the same as the Vawra server.');
  process.exit(1);
}
const vawra = process.env.VAWRA_URL ?? 'http://127.0.0.1:8797';
const port = Number(process.env.VAWRA_DEV_AGE_PORT ?? 8798);

const escape = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

function page(title: string, body: string) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>${escape(title)}</title>
<style>
body { font: 17px/1.5 system-ui, sans-serif; margin: 0; padding: 24px 20px; background: #fff8f4; color: #2a1d1a; }
main { max-width: 28rem; margin: 0 auto; display: grid; gap: 14px; }
.warn { background: #ffe1d6; border-radius: 12px; padding: 12px 14px; font-weight: 600; }
button { font: inherit; width: 100%; padding: 14px; border-radius: 999px; border: 0; background: #e8553e; color: #fff; }
button.alt { background: #fff; color: #2a1d1a; border: 1px solid #d9c6bf; }
input { font: inherit; width: 5rem; padding: 8px; }
</style></head><body><main>
<p class="warn">Development stand-in. This is not a real age check.</p>
<h1>${escape(title)}</h1>${body}</main></body></html>`;
}

async function send(reference: string, outcome: string, age?: number) {
  const body = JSON.stringify({
    reference,
    outcome,
    ...(age === undefined ? {} : { age }),
  });
  const res = await fetch(`${vawra}/v1/webhooks/age-check`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'vawra-signature': signAgeWebhook(secret, Math.floor(Date.now() / 1000), body),
    },
    body,
  });
  return res.status;
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', `http://${req.headers.host}`);
  const html = (status: number, text: string) => {
    res.writeHead(status, {
      'content-type': 'text/html; charset=utf-8',
      'cache-control': 'no-store',
    });
    res.end(text);
  };
  if (req.method === 'GET' && url.pathname === '/start') {
    const ref = url.searchParams.get('ref') ?? '';
    if (!ref) return html(400, page('No reference', '<p>Open this from the app.</p>'));
    const hidden = `<input type="hidden" name="ref" value="${escape(ref)}">`;
    return html(
      200,
      page(
        'Confirm your age',
        `<form method="post" action="/finish">${hidden}<input type="hidden" name="outcome" value="passed">
<p><label>Age to confirm <input name="age" type="number" min="0" max="130" value="29"></label></p>
<button>Pass with this age</button></form>
<form method="post" action="/finish">${hidden}<input type="hidden" name="outcome" value="review"><button class="alt">Needs a closer look</button></form>
<form method="post" action="/finish">${hidden}<input type="hidden" name="outcome" value="failed"><button class="alt">Fail</button></form>`,
      ),
    );
  }
  if (req.method === 'POST' && url.pathname === '/finish') {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const form = new URLSearchParams(raw);
    const ref = form.get('ref') ?? '';
    const outcome = form.get('outcome') ?? '';
    if (!ref || !['passed', 'review', 'failed'].includes(outcome)) return html(400, page('Not understood', ''));
    const age = outcome === 'passed' && form.get('age') ? Number(form.get('age')) : undefined;
    try {
      const status = await send(ref, outcome, age);
      // The reference lets a developer send a later outcome (review, then pass) with curl.
      console.log(`age check ${outcome}${age === undefined ? '' : ` (${age})`} for ${ref}: Vawra answered ${status}`);
      return html(
        200,
        page(status === 200 ? 'Done' : `Vawra answered ${status}`, '<p>Go back to Vawra; it picks up the outcome.</p>'),
      );
    } catch {
      return html(502, page('Vawra is not reachable', `<p>Is the server running at ${escape(vawra)}?</p>`));
    }
  }
  html(404, page('Not found', ''));
});
server.listen(port, '127.0.0.1', () =>
  console.log(`stand-in age check on http://127.0.0.1:${port}, posting to ${vawra}`),
);
