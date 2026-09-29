import { type Cell, snapToCell } from './location.js';
import type { Sealer } from './crypto.js';
import type { Db } from './db.js';
import { interests as allowedInterests, lifestyleOptions } from './rules.js';

export interface DemoProfile {
  name: string;
  age: number;
  intent_label: string;
  bio: string;
  interests: string[];
  portrait: string;
  /** Reviewed for every portrait (lib/data/demo_genders.dart). */
  gender: 'woman' | 'man' | 'nonbinary';
}

const intentKeys: Record<string, string> = {
  'Long-term relationship': 'long_term',
  'Open to long-term': 'open_to_long_term',
  'Casual dating': 'casual',
  'Figuring it out': 'figuring_it_out',
};

const renamedInterests: Record<string, string> = { 'Live music': 'Music' };

/** Same habits every run, so "Why you might click" is stable while testing. */
function habitsFor(index: number): Record<string, string> {
  const pick = <T>(list: readonly T[], salt: number) => list[(index * 7 + salt) % list.length]!;
  const habits: Record<string, string> = {
    pets: pick(lifestyleOptions.pets, 1),
    smoking: pick(lifestyleOptions.smoking, 2),
  };
  if (index % 2 === 0) habits.exercise = pick(lifestyleOptions.exercise, 3);
  if (index % 3 === 0) habits.drinking = pick(lifestyleOptions.drinking, 4);
  return habits;
}

export const demoEmail = (index: number) => `demo-${String(index).padStart(3, '0')}@vawra.test`;

/**
 * A made-up area for a demo member: spread from 1 to 150 km around [near]
 * in a fixed pattern, so every distance band appears.
 */
export function demoArea(near: Cell, index: number): Cell {
  const km = 1 + ((index * 37) % 150);
  const bearing = ((index * 137.5) % 360) * (Math.PI / 180);
  const lat = near.lat + (km / 111.2) * Math.cos(bearing);
  const lng = near.lng + (km / (111.2 * Math.cos((near.lat * Math.PI) / 180))) * Math.sin(bearing);
  return snapToCell(lat, lng);
}

/**
 * Adds synthetic demo members (age-verified, active) for local testing.
 * Idempotent: members already present are left alone. Returns how many were added.
 */
export async function seedDemo(
  db: Db,
  sealer: Sealer,
  people: DemoProfile[],
  now: Date,
  near?: Cell,
): Promise<number> {
  let added = 0;
  for (const [index, person] of people.entries()) {
    const email = demoEmail(index);
    const lookup = sealer.lookup(email);
    const exists = await db.query('SELECT 1 FROM accounts WHERE email_lookup = $1', [lookup]);
    if (exists.length > 0) continue;
    const intent = intentKeys[person.intent_label];
    if (!intent) throw new Error(`unknown goal "${person.intent_label}" for ${person.name}`);
    const interests = [
      ...new Set(
        person.interests
          .map((i) => renamedInterests[i] ?? i)
          .filter((i): i is (typeof allowedInterests)[number] =>
            (allowedInterests as readonly string[]).includes(i),
          ),
      ),
    ].sort();
    const id = crypto.randomUUID();
    await db.transaction(async (tx) => {
      await tx.query(
        `INSERT INTO accounts (id, email_lookup, email_sealed, age_state, lifecycle, created_at)
         VALUES ($1, $2, $3, 'adult_verified', 'active', $4)`,
        [id, lookup, sealer.seal(email), new Date(now.getTime() + index)],
      );
      await tx.query(
        `INSERT INTO profiles (account_id, display_name, relationship_intent, bio, interests,
                               show_distance_band, call_ready_by_default, updated_at,
                               lifestyle, prompts, public_age, demo_portrait,
                               gender, show_gender)
         VALUES ($1, $2, $3, $4, $5, true, false, $6, $7::jsonb, '[]'::jsonb, $8, $9,
                 $10, true)`,
        [
          id,
          person.name,
          intent,
          person.bio,
          interests,
          now,
          JSON.stringify(habitsFor(index)),
          person.age,
          person.portrait,
          person.gender,
        ],
      );
      if (near) {
        const area = demoArea(near, index);
        await tx.query(
          'UPDATE profiles SET location_sealed = $2, location_updated_at = $3 WHERE account_id = $1',
          [id, sealer.seal(JSON.stringify(area)), now],
        );
      }
    });
    added++;
  }
  return added;
}

/** Removes every seeded demo member and everything tied to them. */
export async function removeDemo(db: Db): Promise<number> {
  const rows = await db.query<{ account_id: string }>(
    'SELECT account_id FROM profiles WHERE demo_portrait IS NOT NULL',
  );
  for (const row of rows) {
    await db.query('DELETE FROM accounts WHERE id = $1', [row.account_id]);
  }
  return rows.length;
}
