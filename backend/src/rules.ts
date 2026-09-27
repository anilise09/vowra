// Validation mirrors the app (lib/domain/user_profile.dart, chat_message.dart).
// The server repeats every check; the client is never trusted.

export const intents = [
  'long_term',
  'open_to_long_term',
  'casual',
  'figuring_it_out',
] as const;

export const interests = [
  'Arts',
  'Books',
  'Cooking',
  'Fitness',
  'Music',
  'Outdoors',
  'Travel',
] as const;

const controlChars = /[\u0000-\u001F\u007F]/;

export function validateName(value: string): string | null {
  const v = value.trim();
  if (v.length < 2) return 'name_too_short';
  if (v.length > 40) return 'name_too_long';
  if (controlChars.test(v)) return 'name_control_characters';
  return null;
}

/** Optional; when present it must say something meaningful. */
export function validateBio(value: string): string | null {
  const v = value.trim();
  if (v.length === 0) return null;
  if (v.length < 20) return 'bio_too_short';
  if (v.length > 300) return 'bio_too_long';
  return null;
}

export const messageRules = { maxCharacters: 1000, maxPerMinute: 5 } as const;

// Same topics and answers as LifestyleTopic in lib/domain/lifestyle.dart.
export const lifestyleOptions = {
  drinking: ['Never', 'Rarely', 'Socially', 'Often'],
  smoking: ['No', 'Sometimes', 'Yes', 'Trying to quit'],
  exercise: ['Daily', 'Most weeks', 'Now and then', 'Rarely'],
  pets: ['Dog person', 'Cat person', 'Other pets', 'No pets', 'Want one'],
} as const;

// Same questions and limits as ProfilePrompt in lib/domain/profile_prompt.dart.
export const promptQuestions = [
  'A perfect Sunday looks like…',
  'I get far too excited about…',
  'The way to win me over is…',
  'A green flag I look for…',
  'My most controversial food opinion…',
  'I am looking for someone who…',
  'Ask me about…',
  'The best trip I have taken…',
] as const;
export const promptRules = { maxPrompts: 2, maxAnswer: 150 } as const;

/** Trims each answer; returns an error code or the cleaned list. */
export function normalizePrompts<Q extends string>(
  prompts: { question: Q; answer: string }[],
): { prompts: { question: Q; answer: string }[] } | { error: string } {
  const cleaned = prompts.map((p) => ({ question: p.question, answer: p.answer.trim() }));
  if (new Set(cleaned.map((p) => p.question)).size !== cleaned.length) {
    return { error: 'prompt_repeated' };
  }
  for (const p of cleaned) {
    if (p.answer.length === 0) return { error: 'prompt_answer_empty' };
    if (p.answer.length > promptRules.maxAnswer) return { error: 'prompt_answer_too_long' };
    if (controlChars.test(p.answer)) return { error: 'prompt_answer_control_characters' };
  }
  return { prompts: cleaned };
}

/** Free Super Likes in any rolling 24 hours; the app shows the same number. */
export const swipeRules = { superLikesPerDay: 3 } as const;

/** Trims, collapses runs of spaces/tabs, and rejects blank or control text. */
export function normalizeMessage(value: string): { text: string } | { error: string } {
  const text = value.trim().replace(/[ \t]+/g, ' ');
  if (text.length === 0) return { error: 'message_empty' };
  if (text.length > messageRules.maxCharacters) return { error: 'message_too_long' };
  if (/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/.test(text)) {
    return { error: 'message_control_characters' };
  }
  return { text };
}

// Same set as ReportReason in lib/domain/safety_report.dart.
export const reportReasons = [
  'harassment',
  'impersonation',
  'scam',
  'sexual_content',
  'underage_concern',
  'other',
] as const;
