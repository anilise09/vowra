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
