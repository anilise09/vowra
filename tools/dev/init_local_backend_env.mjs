// Creates the git-ignored keys used by the local Vawra backend. Existing keys
// are never replaced, because changing them would make encrypted local test
// records unreadable.
import { chmodSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

const directory = new URL('../../backend/.data/', import.meta.url);
const target = new URL('dev.env', directory);

mkdirSync(directory, { recursive: true });
if (existsSync(target)) {
  console.log('Local backend keys already exist.');
  process.exit(0);
}

const key = () => randomBytes(32).toString('base64');
writeFileSync(
  target,
  [
    'VAWRA_SERVER_ENABLED=1',
    'VAWRA_DEV_OUTBOX=1',
    `VAWRA_DATA_KEY=${key()}`,
    `VAWRA_LOOKUP_KEY=${key()}`,
    '',
  ].join('\n'),
  { flag: 'wx', mode: 0o600 },
);
chmodSync(target, 0o600);
console.log('Created git-ignored local backend keys at backend/.data/dev.env.');
