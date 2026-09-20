# Security and safety baseline

## Highest risks

- Under-age access; stalking via location/presence; harassment after blocking
- Romance scams, financial solicitation, impersonation, account takeover
- Non-consensual sexual imagery and deepfake impersonation
- User/media enumeration; unauthorized call joining and ringing abuse
- Insider access to conversations and moderation evidence

## Required controls

- Region-appropriate age assurance; coarse distance bands; encrypted coordinates never returned to clients
- Opaque IDs, per-object authorization, rate limits, anomaly detection
- Short-lived call tokens bound to one active match and participant
- Immediate block fan-out across discovery, chat, notifications, and calls
- Signed short-lived media URLs, malware scanning, moderation quarantine
- Default blur/hold for suspected explicit media and recipient consent to reveal
- Step-up account recovery, least privilege, audited privileged access
- Documented deletion and narrowly retained abuse evidence

## Privacy defaults

- Pause/safety invisibility, no precise last-seen, no contact upload, no ad-tech SDKs
- No message-body or call-content analytics
- Calls are not recorded; diagnostics exclude audio/video content

