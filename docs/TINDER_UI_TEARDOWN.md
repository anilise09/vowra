# Tinder Android UI teardown

Recorded 2026-09-26 on the owner's Asus (Android 12), Tinder 17.35.0, region Canada. About 160 screens
were captured as screenshots plus Android layout dumps (exact text, ids, positions). Raw captures stay
local in the git-ignored `screenshots/tinder_full/` folder and are not committed: they include other
people's profiles. This document names no real user.

Conduct: the account was a household Google account used with its holder's approval. No likes, Super Likes or
messages were sent. Face Check was skipped, which Tinder says keeps the profile hidden and blocks
sending Likes. Location was granted approximate and one-time only. Tracking consent was refused.
Contacts were not shared. No report or block was submitted. Photos were an abstract Vawra artwork plus
three cartoon images left from an earlier research account. Deletion was requested; see the last section.

Vawra rule reminder: record interaction principles, never copy Tinder's trade dress, icons, wording,
colours or art.

## 1. Visual system (measured)

| Token | Value | Where |
| --- | --- | --- |
| Brand red | `#CD130A` | welcome background, onboarding progress, selected tile outline, Km/Mi selected, toggles |
| Like heart | `#EC180E` | the ♥ glyph on the Like button |
| Page background | `#131110` (warm near-black) | onboarding, profile, settings, paywalls |
| Card/section fill | `#242020` | expanded-profile sections, prompt cards, selected plan tile |
| Chip fill | `#0A0A0A`, 1 px outline | lifestyle and interest chips |
| Round action buttons | `#272729` | Pass/Like circles over the photo |
| Primary button | `#FBFBFB` pill, black text | Next / Continue / Invite friends |
| Disabled button | `#403B3A` pill, grey text | Next before a choice |
| Secondary text | `#C4C0BF` | onboarding helper lines |
| Divider | `#302C2B` | between chip groups |
| Online | `#3AA25C` dot in a white pill | "Active" / "Nearby" label on cards |
| Gold | mustard banner, orange-brown gradient hero | paywalls and upsells |

- The whole signed-in app and onboarding are dark. Only the logged-out welcome is red.
- Type: a geometric sans for UI, very large bold question headlines (about 44 sp) in onboarding, and a
  serif display face only for marketing moments (Double Date carousel, paywall headline).
- Buttons are full-width pills about 62 dp tall with 20–24 dp side margins. Chips are fully rounded.
- Section cards use about 24 dp radius. The swipe card is edge-to-edge with only the bottom corners
  rounded; inside Explore hubs and Preview the card is inset with margins.
- Bottom navigation: black bar, five outline icons with labels (Swipe, Explore, Likes, Chat, Profile);
  the active tab turns white and bold. Red dots mark unseen items.

## 2. Sign-in (logged out)

1. Welcome: full red screen, white wordmark, legal line ("By tapping Continue…" with Terms, Privacy,
   Cookies links), four white pill buttons with left icons: Continue with Passkey / phone number /
   Google / email, then "Trouble signing in?".
2. Google account picker (system sheet) → Google phone-number chooser → "Enter your code" with six
   digit boxes.
3. "Simplify your sign-in": passkey offer with Skip and Continue.
4. Returning within 90 days of deletion shows "Let's dust off your old profile": data is pre-filled.

## 3. Onboarding (one question per screen)

Shared frame: back arrow top-left, a short red progress bar centred at the top, "Skip" top-right only
on optional steps, huge bold white question, grey helper line, one full-width Next pill at the bottom
that stays grey and disabled until the step is valid. Later headlines use the first name
("Let's talk lifestyle habits, [name]").

| # | Step | Control | Required |
| --- | --- | --- | --- |
| 1 | House Rules: "Welcome. Please follow these House Rules" – Be yourself / Stay safe (links "Date Safely") / Play it cool / Be proactive | text list + "I agree" | yes |
| 2 | First name | text field, note "Can't change it later" | yes |
| 3 | Confirm dialog "Welcome, [name]!" | Let's go / Edit name | yes |
| 4 | Birthday | eight single-digit boxes DD/MM/YYYY; "Your profile shows your age, not your date of birth" | yes |
| 5 | Gender | multi-select rows (Man, Woman, Beyond Binary); each expands an optional accordion of sub-identities with one-line definitions and "Not listed – tell us what's missing"; "Show gender on profile" checkbox; "Learn how Tinder uses this info" | yes |
| 6 | Sexual orientation | multi-select list with a definition under every option (Straight … Omnisexual, Not listed); "Show on profile" | optional |
| 7 | Who are you interested in seeing? | Men / Women / Beyond binary / Everyone | yes |
| 8 | Distance preference | one slider with the value right-aligned ("80 km"), "You can change preferences later in Settings" | yes |
| 9 | What are you looking for? | 3×2 grid of tall rounded tiles (Long-term partner, Long-term open to short, Short-term open to long, Short-term fun, New friends, Still figuring it out); selected tile gets a red outline | yes |
| 10 | School | text field, Next disabled until typed | optional |
| 11 | Lifestyle habits | grouped chip rows, each with a line icon and question: drink / smoke / workout / pets; thin dividers; button shows "Next 0/4" | optional |
| 12 | What else makes you, you? | same pattern: communication style, love language, education level, zodiac | optional |
| 13 | What are you into? | up to 10 interests in ~13 categories (Creativity, Fan favorites, Food and drink, Gaming, Going out, Music, Outdoors, Social and content, Sports and fitness, Staying in, TV and movies, Values and causes, Wellness); each category shows 8 chips + "Show more"; "Next 0/10" | optional |
| 14 | Add your recent pics | 3×2 grid; "Upload 2 photos to start. Add 4 or more to stand out"; filled slots show ✕, empty show ＋ | 2 photos |
| 14a | Photo add | opens the Android system photo picker directly (multi-select, "Add (n)"); then "Edit photos": zoomable crop, thumbnail strip with Remove, Replace, Done | – |
| 15 | Share more about yourself | two cards: About me (bio) and Select a prompt; nudge "a short intro could lead to 25% more matches" | optional |
| 15a | Bio editor | full-screen sheet, example placeholder, 0/500 counter, "Bio tip: great bios are short…" | – |
| 15b | Prompt picker | one long list in sections (My vibe, Social side, Opinions, Story time, Day-to-day, What I'm into, First meet up); tabs jump to sections | – |
| 16 | Location pre-permission | "So, are you from around here?" + Allow + "How is my location used?" (sheet: exact location never shown) → Android dialog | yes |
| 17 | Face Check | "Let's keep it real": biometric video selfie required in this region; Maybe later → "Skipping? Your profile won't be visible… can't send or receive Likes" | skippable, but hides profile |
| 18 | Privacy consent | "We value your privacy": I accept / Personalise → preference centre with Refuse all | yes |
| 19 | Block contacts | "Want to avoid someone you know?": share contacts to hide them | optional |
| 20 | Feature promo | Double Date carousel, three pages, dark green, pink serif headline | dismissible |
| 21 | Swipe tutorial | overlay on the dimmed first card: "Let's get you ready!" → Slide right to like → Slide left to pass → summary of Rewind, Super Like (slide up), Boost | skippable |

## 4. Swipe (main deck)

- Top bar: filter/settings icon, "For you", Double Date icon, Boost bolt. For a new account a white
  banner replaces it: "Learning your type – send 20 more likes to get started".
- Card: full photo; story-style segment bar at the top for multiple photos; left and right halves tap to
  previous/next photo; bottom gradient holding a white "Active"/"Nearby" pill, name (bold) and age
  (lighter) with a verified badge, icon rows ("Lives in …", "9 km away"), and a small round ↑ button.
- Action row: Rewind, Pass ✕ (large), Super Like ★, Like ♥ (large, red glyph), First Impression
  (message before matching). New accounts see only Pass and Like.
- Expanded profile (↑): sticky name header with a ↓ close button, photo pager with a "Reply" pill and
  ⋯ on each photo, then stacked section cards: Looking for, relationship type, About me, Essentials
  (distance, height, job, city, gender), prompt answer, Lifestyle, Basics ("View all 5"), Interests
  chips. Every card has "Reply" and ⋯. At the end, full-width rows: Share [name]'s profile, Block
  [name], Report [name] (red). Pass/Like float over the bottom.
- ⋯ menu: bottom action sheet Share / Block / Report (red) / Cancel.

## 5. Explore

"Missed Connections" card (needs precise location), "Find people with similar relationship goals" row
(identity hubs), then a two-column grid of ~25 hubs, each a dark tile with a glossy 3D object, a label
and a people count (Short-term fun, Long-term partner, Serious commitment, Free Tonight, New friends,
Get Photo Verified, Wants Kids, Child-Free, Travel, Binge Watchers, Sporty, Coffee Date, Date Night,
Thrill Seekers, Creatives, Foodies, Nature Lovers, Self Care, Gamers, Animal Parents …). A hub opens its
own inset deck with ✕, title, Boost and hub settings; cards show context (interest chips).
Flaw: long labels break mid-word ("commitme/nt").

## 6. Likes and Chat

- Likes: fully paywalled; "See people who liked you with Tinder Gold" + "See all your Likes now".
- Chat, first open: "Date safely" three-page modal – be respectful / respect boundaries; is it a scam /
  get-rich-quick; take your time / unmatch, block or report (confidential). Ends with "Got it".
- Chat list: search field ("Search 0 matches"), Safety Toolkit shield, empty state "Get swiping".
- Safety Toolkit sheet: Report (including unmatched people), Update Safety Settings, Safety Centre.
  Safety Settings: get photo verified; "Photo verified chat" (only verified people can message you).

## 7. Profile

- Hub: stacked-photo avatar, name with a dashed (unverified) badge, "Preview ›"; red "Complete Your
  Profile" pill; horizontally scrolling attribute chips with ＋ (Living in, Height, Job, Education,
  Basics, Lifestyle, Relationship type); photo strip with "Get up to 2x more Likes with 6 pics" + Edit;
  My prompts ("Add 2 prompts" in red); My Interests tiles (Currently into, Listening to, Top Artists via
  Spotify); "More profile controls ›" (Smart Photos; hide age / hide distance are paid). A Gold banner
  and a stats bar (Super Likes, Boosts, Subscriptions) stay pinned above the tab bar.
- My photos: 3×3 grid, caption badge per photo, "Stand out with our photo tips" → sheet of example
  thumbnails: photos that get Likes (clear face, full body, smiling, one group pic, pets, interests) vs
  nopes (no face, mirror selfie, blurry, outdated, over-filtered, far away).
- Preview: your own card exactly as others see it.
- Double Date "Friends": up to 3 pairs, invite row, empty state.

## 8. Settings (one long page)

Subscription cards (Platinum, Gold, Plus) → tiles Get Super Likes, Get Boosts, Go Incognito, Passport →
Account (phone, passkeys) → Discovery (location, add location, max distance slider + "show further away
if I run out", interested in, age range dual slider + "slightly out of range if I run out") → Gold
premium preferences (minimum photos, looking for, languages, zodiac, education, family plans,
communication, love style, pets, drinking, smoking, workout, social media) → Control my visibility →
Enable Discovery (hide profile; people you liked may still see you) → Control who messages you
(photo verified chat) → Block contacts → Appearance (system theme) → Data usage (autoplay) → Tinder U →
Web profile → Missed Connections → Modes (Double Date, Music, Astrology) → Active status → Notifications
(email, push, SMS) → Distance units (Km/Mi segmented) → Payment account, restore purchase → Contact us
→ Community (guidelines, safety tips, Safety Centre) → Share → Privacy → Legal → Logout → version →
Delete account.

## 9. Money

| Offer | Week | Month (per week) | 6 months (per week) | Default |
| --- | --- | --- | --- | --- |
| Plus | CA$9.99 | CA$6.62 | CA$3.33 | 1 week "Popular" |
| Gold | CA$14.99 | CA$9.99 | CA$4.99 | 1 week "Popular" |
| Platinum | CA$23.99 | CA$15.99 | CA$7.99 | 1 week "Popular" |

Super Likes: 3 / 15 / 30 at CA$5.99 / 4.66 / 3.69 each. Boosts (tabs Boost, Primetime, Super Boost):
1 / 10 / 20 at CA$6.49 / 3.29 / 2.49 each. Paywalls show an auto-renew disclosure and "Continue for
CA$X total". Seeing who liked you, hiding age/distance, unlimited likes and rewind are paid.

## 10. Deletion

Settings → Delete account → "Want a new start?" (offers a swipe-history Reset) → "Pause my account"
offer → exit survey of six reason tiles (Skip or Other with a text box) → final "Are you sure?" with
Delete my account / Pause my account. Data is restorable by signing in within 90 days; Face Check data
is deleted after 30 days. In this session the final tap repeatedly returned to the survey (the phone
also rotated mid-flow); the owner finished on the device and then uninstalled the app. Do not sign in
with that account for 90 days, or the profile is restored.

## 11. What Vawra takes, changes, and refuses

Take (in Vawra's own words, colours and art):
- One question per screen, disabled-until-valid primary button, Skip only on optional steps, name-aware
  headlines, a rules/promises step, a progress bar.
- Chip groups with an icon and question per group and a running count on the button.
- Card anatomy: status pill, bold name + lighter age, icon rows, a round open-details button; details as
  stacked section cards ending in Block and Report rows.
- A three-page "date safely" guide on first opening Chats, and a safety shield in the Chats header.
- Photo tips shown as example thumbnails; a "Preview my card" view; settings grouped by purpose.

Change:
- Seeing who liked you, hiding distance/age, blocking and reporting stay free (Vawra rule).
- No most-expensive-plan pre-selection; show total, renewal and cancellation before the button.
- Deletion is one honest path: at most one pause offer, no survey loop, and a clear statement of what is
  deleted and when.
- Labels never break mid-word; tiles use wrapping-safe text.

Refuse:
- Fake "Active" status or counts without real data; message-before-match as a paid upsell; paywalled
  safety; forced biometric capture without provider and legal review.
