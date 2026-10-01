import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { type Harness, member, type Person, signIn, startHarness } from './harness.js';

/**
 * docs/API_REFERENCE.md is checked against the running app: every route is
 * listed, nothing listed is missing, and each route's access column holds.
 */
type Doc = { method: string; path: string; access: 'public' | 'signed-in' | 'adult' | 'moderator' };

const docRows: Doc[] = readFileSync(new URL('../../docs/API_REFERENCE.md', import.meta.url), 'utf8')
  .split(/\r?\n/)
  .map((line) => /^\| (GET|POST|PUT|PATCH|DELETE) \| `([^`]+)` \| (public|signed-in|adult|moderator) \|/.exec(line))
  .filter((m): m is RegExpExecArray => m !== null)
  .map((m) => ({ method: m[1]!, path: m[2]!, access: m[3] as Doc['access'] }));

/** Fastify prints routes as a tree; children carry only their own part of the path. */
function serverRoutes(tree: string): string[] {
  const routes: string[] = [];
  const stack: string[] = [];
  for (const line of tree.split('\n')) {
    const m = /^((?:│   |    )*)(?:├── |└── )(\S+)(?: \(([^)]+)\))?/.exec(line);
    if (!m) continue;
    const depth = m[1]!.length / 4;
    stack.length = depth;
    const path = (stack[depth - 1] ?? '') + m[2]!;
    stack[depth] = path;
    for (const method of (m[3] ?? '').split(',').map((x) => x.trim()).filter(Boolean)) {
      if (method !== 'HEAD') routes.push(`${method} ${path}`);
    }
  }
  return routes.sort();
}

let h: Harness;
let notYetChecked: Person;
let adult: Person;
beforeAll(async () => {
  h = await startHarness();
  notYetChecked = await signIn(h, 'unchecked@example.test');
  adult = await member(h, 'Ana');
});
afterAll(async () => h.close());

const concrete = (path: string) => path.replace(/:\w+/g, '7c1e3d90-0f3a-4b8e-9d2e-5a6b7c8d9e0f');
const hit = (route: Doc, as?: Person) =>
  h.app.inject({ method: route.method as 'GET', url: concrete(route.path), headers: as?.auth ?? {} });

describe('the API reference', () => {
  it('lists every route the server answers, and nothing else', () => {
    expect(docRows.length).toBeGreaterThan(60);
    const documented = docRows.map((r) => `${r.method} ${r.path}`).sort();
    expect(new Set(documented).size).toBe(documented.length);
    expect(serverRoutes(h.app.printRoutes({ commonPrefix: false }))).toEqual(documented);
  });

  it('every route that needs a sign-in refuses one without it', async () => {
    for (const route of docRows.filter((r) => r.access !== 'public')) {
      const res = await hit(route);
      expect(res.statusCode, `${route.method} ${route.path}`).toBe(401);
    }
  });

  it('every adult route refuses an account whose age is not confirmed', async () => {
    for (const route of docRows.filter((r) => r.access === 'adult')) {
      const res = await hit(route, notYetChecked);
      expect(res.statusCode, `${route.method} ${route.path}`).toBe(403);
      expect(res.json().error, `${route.method} ${route.path}`).toBe('age_assurance_required');
    }
  });

  it('every moderation route looks absent to a member who is not a moderator', async () => {
    for (const route of docRows.filter((r) => r.access === 'moderator')) {
      const res = await hit(route, adult);
      expect(res.statusCode, `${route.method} ${route.path}`).toBe(404);
    }
  });
});
