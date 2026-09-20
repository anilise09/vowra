# Project Ember engineering rules

This 18+ dating product handles sensitive identity, location, conversation, image, and video data.

## Non-negotiable boundaries

- Never create fake users, matches, likes, messages, or engagement.
- Never expose exact coordinates or overly precise distances.
- Matching, messaging, blocking, reporting, and safety controls remain free.
- Calls require a match and explicit acceptance; never expose phone numbers or record calls by default.
- Block takes effect immediately across discovery, chat, and calling.
- Do not claim photo or ID verification proves someone is safe.
- Never ship secrets or private signing material in the client.
- Treat client age, entitlement, location, verification, and match claims as untrusted; authorize server-side.
- Under-18 access is prohibited; age assurance is a launch gate.
- Purchases clearly disclose total charge, renewal, cancellation, and restoration. No dark patterns.

Use synthetic fixtures until production privacy/security review. Add tests for authorization and safety invariants before feature polish. Do not enable production calls, payments, or identity checks without provider review and explicit configuration.

