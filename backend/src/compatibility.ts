/**
 * Why two people might click, in plain words. Vawra ranks Discover by these
 * visible, additive signals only (the lesson from interpretable models):
 * shared goals, shared interests and matching habits. It never uses
 * popularity, swipe rates, looks or any hidden desirability score, and every
 * point of the score comes with a reason the person can read.
 */
export interface CompatibilityProfile {
  relationship_intent: string;
  interests: string[];
  lifestyle: Record<string, string>;
}

export interface Reason {
  kind: 'goal' | 'interests' | 'habit';
  text: string;
}

export interface Compatibility {
  score: number;
  reasons: Reason[];
}

const sameIntent: Record<string, string> = {
  long_term: 'Both want something long-term',
  open_to_long_term: 'Both open to long-term',
  casual: 'Both keeping it casual',
  figuring_it_out: 'Both still figuring it out',
};

const petsTogether: Record<string, string> = {
  'Dog person': 'Both dog people',
  'Cat person': 'Both cat people',
  'Other pets': 'Both have pets',
  'No pets': 'Neither has pets',
  'Want one': 'Both want a pet',
};

function sameHabit(topic: string, answer: string): string | null {
  switch (topic) {
    case 'pets':
      return petsTogether[answer] ?? null;
    case 'smoking':
      return answer === 'No' ? 'Neither smokes' : 'Same answer on smoking';
    case 'drinking':
      return answer === 'Never' ? 'Neither drinks' : 'Similar drinking habits';
    case 'exercise':
      return 'Similar exercise routine';
    default:
      return null;
  }
}

function listed(items: string[]): string {
  if (items.length === 1) return items[0]!;
  if (items.length <= 3) return `${items.slice(0, -1).join(', ')} and ${items.at(-1)}`;
  return `${items.slice(0, 3).join(', ')} and ${items.length - 3} more`;
}

export const maxReasons = 3;

export function compatibility(me: CompatibilityProfile, them: CompatibilityProfile): Compatibility {
  let score = 0;
  const reasons: Reason[] = [];

  const a = me.relationship_intent;
  const b = them.relationship_intent;
  if (a === b) {
    score += 3;
    if (sameIntent[a]) reasons.push({ kind: 'goal', text: sameIntent[a]! });
  } else if (new Set([a, b]).size === 2 && [a, b].every((i) => i === 'long_term' || i === 'open_to_long_term')) {
    score += 2;
    reasons.push({ kind: 'goal', text: 'Both open to something long-term' });
  }

  const shared = them.interests.filter((i) => me.interests.includes(i)).sort();
  if (shared.length > 0) {
    score += shared.length;
    reasons.push({ kind: 'interests', text: `You both like ${listed(shared)}` });
  }

  for (const topic of Object.keys(me.lifestyle ?? {}).sort()) {
    const answer = me.lifestyle[topic];
    if (answer && them.lifestyle?.[topic] === answer) {
      score += 0.5;
      const reason = sameHabit(topic, answer);
      if (reason) reasons.push({ kind: 'habit', text: reason });
    }
  }

  return { score, reasons: reasons.slice(0, maxReasons) };
}
