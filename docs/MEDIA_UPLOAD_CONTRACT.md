# Media upload and moderation contract

Status: profile photos (BE-12) and photos in a conversation (BE-16) are implemented with local
stand-ins; video is not. Sexually explicit media is not accepted anywhere: moderators reject it,
in profiles and in chats alike, so the explicit-media opt-in described below is not offered.

Conversation photos (BE-16): the receiver allows photos per match ("Allow photos from ..."), off by
default; `POST /v1/matches/:id/photos` refuses without that (`409 photos_not_allowed`). Each photo
goes through the same grant, checks and moderator review as a profile photo, and becomes a message
only on approval, if the match is still open and photos are still allowed. The receiver sees it
blurred until they tap it and can report it from there; links re-check that the viewer is one of
the two people in an open, unblocked match. Chat photos never appear as profile photos.

What exists: the gallery picker (no camera), `POST /v1/me/photos` for a single-use grant bound to the
exact MIME type, byte length and SHA-256, `PUT /v1/uploads/:id` that checks all three plus the file
signature, then decodes safely (40 MP cap against decompression bombs, animation off) and re-encodes
to WebP at most 1600 px with every piece of metadata removed; the original is never stored. Photos
wait in `pending_review` until a moderator approves or rejects them (with a safe reason category) in
the Moderation page; rejected files are deleted. Reads use `GET /v1/media/:id` with a 15-minute HMAC
link bound to the photo, the viewer and the purpose (`view` or `review`), and the server re-checks
access on every read, so a block, suspension, deletion or rejection ends access even for an old
link. Six photos at most, 30 uploads a day. Account deletion removes the files.

Stand-ins, until reviewed providers are chosen: a local disk store (`backend/.data/media`) instead of
an object store, served by the app server instead of direct-to-storage grants; human review by
Vawra moderators instead of malware scanning, automated classification and perceptual hashing.

## Principles

- Media belongs to the authenticated account; a client-supplied media, profile, match, or conversation
  ID is never authorization.
- Uploads go directly to private quarantine through a short-lived, single-purpose signed grant. The
  client never receives a storage key, bucket credential, permanent object URL, or public origin URL.
- Nothing becomes visible until server-side validation and moderation return `approved`.
- Profile media cannot be sexually explicit. Private matched-conversation media still requires an
  active adult-verified match, sender declaration, recipient opt-in, and provider/policy approval.
- Block, unmatch, account pause, moderation action, or deletion immediately removes access even when a
  cached client still holds an old identifier.

## Upload flow

1. The authenticated client submits bounded facts: an idempotency key, media kind, intended audience,
   MIME type, byte length, SHA-256 hash, explicit-content declaration, and an opaque conversation ID
   only for a matched attachment.
2. The server checks session, age assurance, account/moderation state, quotas, MIME/size policy, and—
   for conversation media—the active match and recipient-consent state.
3. The server creates a private quarantine record and returns a short-lived HTTPS upload grant scoped
   to exactly that object, byte ceiling, content type, and checksum.
4. Completion rechecks the observed object size and hash. A mismatch, replay, expired grant, wrong
   content type, or unexpected object path fails closed and deletes/quarantines the object.
5. The object remains unavailable while the pipeline performs file-signature/type checks, archive and
   malware scanning, safe image/video decoding, metadata stripping, policy classification, and any
   required human review.
6. Only an `approved` server snapshot can be attached or shown. Delivery uses a short-lived,
   audience-authorized read grant rather than a permanent URL.

## Moderation and consent

Profile photos and videos are public-to-discovery product surfaces and reject sexually explicit media.
The client declaration is a warning and routing signal, never trusted classification. Server and
provider policy still apply.

An explicit private attachment is never an unsolicited preview. The recipient must have opted in to
receive that class of media from the matched sender before an upload grant is issued, and can revoke
that preference. Revocation blocks future delivery; block/unmatch removes access immediately. Reporting
remains available without opening the media and preserves only the narrowly authorized evidence needed
for review. No automatic download to the device gallery occurs.

Moderation reason codes returned to the client are safe categories, not model scores, provider internals,
hash databases, reviewer identity, or details that help an attacker evade detection. Photo or ID
verification must never be described as proof that a person is safe.

## Deletion and retention

Deleting media removes it from discovery/conversation delivery immediately and schedules the original,
derived thumbnails/transcodes, read grants, and ordinary backups for deletion under the reviewed data
lifecycle schedule. Re-upload deduplication cannot silently restore deleted media.

Narrow abuse-evidence retention is separately encrypted, access-controlled, audited, purpose-limited,
and expires under a legally reviewed schedule. It is not available to product ranking, advertising,
support browsing, profile recovery, or another user.

## Logging and authorization

Logs and analytics exclude signed URLs, storage keys, object paths, image/video bytes, EXIF, perceptual
hashes, malware results, explicit-content labels tied to a person, and moderation-provider payloads.
Bounded audit events may record opaque media ID, operation, outcome category, policy version, and time.

Every request derives the account from the validated session and reauthorizes the target object and
audience. Completion, status, read, attach, reorder, replace, and delete endpoints all require ownership
or explicit recipient authorization; knowledge of an opaque ID is insufficient.

Before production providers: choose and review storage, malware-scanning, content-moderation,
perceptual-hash and managed explicit-media providers; define regional legality and retention; and
complete their privacy, safety and security review. The local implementation now tests upload replay,
polyglot/signature rejection, decompression bombs, metadata removal, cache authorization, cross-account
IDOR, deletion during processing, simultaneous moderation, consent withdrawal, unmatch and block.
Provider adapters still need equivalent transcoder-escape, callback-replay and failure-mode tests.
