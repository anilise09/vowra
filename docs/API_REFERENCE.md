# Vawra API reference

Every route the server answers, who may call it, and what it does. `backend/test/api_reference.test.ts`
reads this table: it fails when the server has a route this page does not list (or the other way
round), and it checks the access column for every route by calling it without a sign-in, as an
account whose age is not yet confirmed, and as a member who is not a moderator.

Access:

- **public**: anyone; protected some other way where it matters (a single-use grant, a signed and
  expiring link, a webhook signature, PKCE).
- **signed-in**: a valid access token (`Authorization: Bearer ...`); otherwise `401`.
- **adult**: signed in and the age check passed; otherwise `403 age_assurance_required`. Suspended
  or leaving accounts get `409`.
- **moderator**: signed in with the moderator role; anyone else gets `404`, so the console is not
  revealed. Moderation itself also needs the authenticator code (BE-25).

Details of each area are in `BACKEND_API_CONTRACT.md`, `SESSION_CONTRACT.md` and
`MEDIA_UPLOAD_CONTRACT.md`. Errors are always `{error, request_id}`.

## Health

| Method | Path | Access | What it does |
|---|---|---|---|
| GET | `/v1/health` | public | Liveness: the process answers. |
| GET | `/v1/ready` | public | Readiness: database reachable, migrations applied, not shutting down. |

## Sign-in and sessions

| Method | Path | Access | What it does |
|---|---|---|---|
| POST | `/v1/auth/requests` | public | Emails a six-digit code; the same answer, and timing, for every address. |
| POST | `/v1/auth/exchange` | public | Code + PKCE verifier + state for a session (five tries per code; ten wrong codes a day pause the address). |
| POST | `/v1/session/rotate` | public | A single-use refresh token for new tokens; reuse ends the sign-in. |
| DELETE | `/v1/session` | signed-in | Signs out this device (the whole sign-in chain). |
| DELETE | `/v1/sessions` | signed-in | Signs out every device. |

## Profile and account

| Method | Path | Access | What it does |
|---|---|---|---|
| GET | `/v1/me/profile` | signed-in | Account state, profile, suspension. |
| PATCH | `/v1/me/profile` | signed-in | Creates or edits the profile (never the age). |
| GET | `/v1/me/settings` | signed-in | Read receipts and typing. |
| PATCH | `/v1/me/settings` | signed-in | Changes them. |
| POST | `/v1/me/pause` | signed-in | Stops appearing to new people. |
| DELETE | `/v1/me/pause` | signed-in | Appears again. |
| PUT | `/v1/me/location` | signed-in | Sets the approximate area (a 2 km cell). |
| DELETE | `/v1/me/location` | signed-in | Removes it at once. |
| GET | `/v1/me/export` | signed-in | A copy of everything kept about you (recent sign-in, 5 a day). |
| POST | `/v1/me/deletion` | signed-in | Deletes the account after 7 days (recent sign-in). |
| DELETE | `/v1/me/deletion` | signed-in | Keeps the account after all. |
| POST | `/v1/me/age-check` | signed-in | A one-time link to the age-check provider. |
| POST | `/v1/me/appeal` | signed-in | Explains a suspension to a moderator. |

## Photos

| Method | Path | Access | What it does |
|---|---|---|---|
| POST | `/v1/me/photos` | signed-in | Asks to upload a profile photo; returns a single-use upload link. |
| PUT | `/v1/uploads/:id` | public | The photo's bytes, with the single-use grant from the link. |
| GET | `/v1/me/photos` | signed-in | Your photos and their review state. |
| DELETE | `/v1/me/photos/:id` | signed-in | Removes one. |
| PUT | `/v1/me/photos/order` | signed-in | Reorders them. |
| GET | `/v1/media/:id` | public | A photo, through a signed link bound to its viewer, valid 15 minutes. |
| POST | `/v1/matches/:matchId/photos` | signed-in | Asks to send a photo in a chat (the other person must allow photos). |

## Discover, matches and chat

| Method | Path | Access | What it does |
|---|---|---|---|
| GET | `/v1/discovery` | adult | People to meet, ranked by what you share. |
| POST | `/v1/discovery/:accountId/swipe` | adult | Like, Super Like or pass. |
| GET | `/v1/likes-you` | adult | People who liked you. |
| GET | `/v1/matches` | adult | Your conversations. |
| DELETE | `/v1/matches/:matchId` | signed-in | Unmatches. |
| GET | `/v1/matches/:matchId/messages` | adult | A conversation's messages. |
| POST | `/v1/matches/:matchId/messages` | adult | Sends a message. |
| POST | `/v1/matches/:matchId/read` | adult | Marks it read (shared only if both share receipts). |
| POST | `/v1/matches/:matchId/typing` | adult | "Typing", under the same rule. |
| PUT | `/v1/matches/:matchId/photo-consent` | adult | Allows or stops photos from this person. |
| GET | `/v1/events` | adult | The live-update stream (Server-Sent Events). |

## Calls

| Method | Path | Access | What it does |
|---|---|---|---|
| PUT | `/v1/matches/:matchId/call-ready` | adult | Open to a call in this conversation. |
| POST | `/v1/matches/:matchId/calls` | adult | Rings the other person. |
| GET | `/v1/calls/:callId` | adult | A call's state, and relay details while it lasts. |
| POST | `/v1/calls/:callId/answer` | adult | Answers. |
| POST | `/v1/calls/:callId/decline` | adult | Declines. |
| POST | `/v1/calls/:callId/end` | adult | Hangs up or cancels. |
| POST | `/v1/calls/:callId/signals` | adult | Sends a setup message to the other phone. |
| GET | `/v1/calls/:callId/signals` | adult | Reads the other phone's setup messages. |

## Safety

| Method | Path | Access | What it does |
|---|---|---|---|
| POST | `/v1/blocks` | signed-in | Blocks someone; contact and calls end at once. |
| GET | `/v1/blocks` | signed-in | Who you have blocked. |
| DELETE | `/v1/blocks/:accountId` | signed-in | Unblocks (old chats stay closed). |
| POST | `/v1/reports` | signed-in | Reports someone privately (20 a day). |

## Notifications

| Method | Path | Access | What it does |
|---|---|---|---|
| POST | `/v1/me/devices` | signed-in | Registers this phone for push. |
| DELETE | `/v1/me/devices/:id` | signed-in | Removes it. |
| GET | `/v1/me/notifications` | signed-in | What you are told about while the app is closed. |
| PUT | `/v1/me/notifications` | signed-in | Changes it. |

## Moderation

| Method | Path | Access | What it does |
|---|---|---|---|
| GET | `/v1/mod/second-factor` | moderator | Whether the authenticator is set up, and verified until when. |
| POST | `/v1/mod/second-factor/setup` | moderator | A new authenticator secret, shown once (recent sign-in). |
| POST | `/v1/mod/second-factor/confirm` | moderator | Turns it on with a first code. |
| POST | `/v1/mod/second-factor/verify` | moderator | Opens moderation for 30 minutes. |
| GET | `/v1/mod/reports` | moderator | Reports waiting, with only the reported message as evidence. |
| POST | `/v1/mod/reports/:id/decision` | moderator | Dismisses or suspends (recent sign-in). |
| GET | `/v1/mod/appeals` | moderator | Appeals waiting. |
| POST | `/v1/mod/appeals/:id/decision` | moderator | Upholds or overturns (a different moderator). |
| GET | `/v1/mod/photos` | moderator | Photos waiting for review. |
| POST | `/v1/mod/photos/:id/decision` | moderator | Approves or rejects one. |

## From providers

| Method | Path | Access | What it does |
|---|---|---|---|
| POST | `/v1/webhooks/age-check` | public | The age-check outcome, signed with the shared secret. |
