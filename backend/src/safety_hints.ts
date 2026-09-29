/**
 * Gentle warnings for the person receiving a message, never for the sender
 * and never a block: the person decides. Aimed at requests, not mentions, so
 * "I sent my mum money for her birthday" is not flagged.
 */
export type SafetyHint = 'money' | 'off_platform' | 'link';

const money: RegExp[] = [
  /\b(send|wire|transfer|lend|loan|give)\s+(me|us)\b.{0,40}\b(money|cash|funds|dollars?|rupees?|euros?|pounds?|\$\s?\d+)/i,
  /\b(can|could|would|will)\s+you\s+(send|lend|wire|transfer|help\s+(me\s+)?with)\b.{0,30}\b(money|cash|funds|rent|bills?|dollars?|\$)/i,
  /\bi\s+need\s+(some\s+)?(money|cash|funds)\b/i,
  /\b(gift\s?cards?|itunes\s+cards?|steam\s+cards?|google\s+play\s+cards?|amazon\s+cards?)\b/i,
  /\b(bitcoin|btc|crypto(currency|currencies)?|usdt|ethereum|forex|binary\s+options?)\b/i,
  /\binvest(ment)?\s+(opportunity|platform|with\s+me)\b/i,
  /\b(western\s+union|moneygram|cash\s?app|venmo|zelle|paypal\s+me)\b/i,
  /\b(bank\s+(details|account|login)|routing\s+number|iban)\b/i,
];

const offPlatform: RegExp[] = [
  /\b(whats\s?app|telegram|snap\s?chat|kik|wechat|viber|signal\s+app|line\s+app)\b/i,
  /\b(text|call|message|add|dm|find)\s+me\s+(at|on)\b/i,
  // A phone number: nine or more digits, with the usual separators.
  /(\+?\d[\d\s().-]{7,}\d)/,
  /[\w.+-]+@[\w-]+\.[a-z]{2,}/i,
];

const link: RegExp[] = [
  /\bhttps?:\/\//i,
  /\bwww\.[a-z0-9-]+\./i,
  /\b[a-z0-9-]+\.(com|net|org|io|app|xyz|link|ly|me|site|online|top|click)(\/\S*)?(\s|$)/i,
];

const digits = (s: string) => s.replace(/\D/g, '').length;

export function safetyHints(text: string): SafetyHint[] {
  const hints: SafetyHint[] = [];
  if (money.some((r) => r.test(text))) hints.push('money');
  const phone = offPlatform[2]!.exec(text);
  const otherOff = offPlatform.filter((_, i) => i !== 2).some((r) => r.test(text));
  if (otherOff || (phone && digits(phone[0]) >= 9)) hints.push('off_platform');
  if (link.some((r) => r.test(text))) hints.push('link');
  return hints;
}
