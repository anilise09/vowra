# Competitive mobile UI research

Research date: 2026-09-24

## Direct Android walkthrough (2026-09-25–26)

The following observations came from Tinder and Bumble installed on the owner's Samsung phone. These describe the visible UI and interactions, not a claim about every account or region.

| Area | Tinder | Bumble | Vawra decision |
| --- | --- | --- | --- |
| Discovery | A nearly full-screen portrait carries name, age, a few facts, and prominent Pass/Like buttons. An up-arrow opens a separate, vertically scrollable profile; a down-arrow closes it. | The People card is photo-led and scrolls vertically through bio and structured facts. | Keep the person dominant. Swipe up and a visible arrow open details; left passes and right likes. |
| Navigation | Five stable destinations: Swipe, Explore, Likes, Chat, Profile. | Five stable destinations: Profile, Discover, People, Liked You, Chats. | Keep destinations clear and predictable; add destinations only when Vawra has real content for them. |
| Profile detail | Large media first, followed by relationship intent, tags, bio, facts, and per-section response affordances. | Bio and structured facts are part of the vertical People profile. | Put biography and interests in a focused details view and retain visible safety controls. |
| Onboarding | One question at a time with a progress indicator, large choice cards, and Skip on optional school, habits, interests, and bio screens. Photos precede optional bio/prompt. | Asks about gender, who to meet, intent, lifestyle, interests, a prompt, and photos. Optional items can be skipped. | Build progressive onboarding with obvious optional steps, while keeping adult access and consent explicit. |
| Empty and premium states | Likes shows an upgrade invitation; Chat explains that matches appear there. | Chats explains matching; Liked You and Profile offer Spotlight and Premium. | Explain empty states plainly. Keep matching, messaging, block, and report free. |

On Tinder, skipping Face Check allowed UI inspection but left the account hidden and Likes unavailable. Bumble required a live-photo check after its cartoon profile image was moderated. These gates are account-state observations, not UI patterns to copy. No competitor Likes or messages were sent. The temporary Tinder research account was deleted after the walkthrough; Bumble deletion could not be verified behind its live-photo gate.

This review uses current first-party product pages, help material, and official Google Play screenshots. It identifies interaction principles; Vawra must not copy another product's trade dress, exact layout, icons, wording, or brand system.

## Products reviewed

### Tinder

The official store presentation continues to frame discovery as a fast, photo-led decision with very little chrome. Safety tools and profile verification exist, but they do not visually compete with the person being considered.

Source: [Tinder on Google Play](https://play.google.com/store/apps/details?id=com.tinder)

### Bumble

Bumble's official material leads with a large portrait card, a concise relationship-intent statement, and a simple bottom navigation. Profile prompts and interests are used to create clearer conversations, while safety and verification are positioned as confidence-building tools.

Sources: [Bumble on Google Play](https://play.google.com/store/apps/details?id=com.bumble.app), [Bumble photo guidance](https://support.bumble.com/hc/articles/28523708029341-Uploading-profile-photos)

### Hinge

Hinge makes profile content actionable: photos, facts, and prompts are individual conversation surfaces. The product emphasizes learning someone's personality and starting with a specific like or comment instead of treating discovery as a photo-only game.

Sources: [What is Hinge?](https://help.hinge.co/hc/en-us/articles/26845979318803-What-is-Hinge), [Hinge on Google Play](https://play.google.com/store/apps/details?id=co.hinge.app), [Convo Starters](https://hinge.co/newsroom/convo-starters)

### Feeld

Feeld's 2025 redesign is the strongest reference for expressive differentiation. Its team describes dimensional navigation, an expanded palette, chunky shapes, contrasting forms, clearer search settings, and shared desires surfaced in discovery. The member remains the main character and the product gets out of the way.

Sources: [Feeld 8.0 overview](https://support.feeld.co/hc/en-gb/articles/21061472034716-Meet-the-new-Feeld-app-version-8-0), [Feeld design roundtable](https://feeld.co/ask-feeld/how-to/a-roundtable-with-feeld-designers-on-the-app-s-newest-evolution)

### Visual inspiration gallery

The owner also supplied a dating-app presentation reference and the current [Dribbble dating-app UI gallery](https://dribbble.com/tags/dating-app-ui). These are inspiration sources rather than product evidence. Reusable ideas include layered photo cards, circular connection previews, compact conversation headers, soft asymmetric message bubbles, and low-chrome navigation. Vawra does not reproduce a specific shot, layout, illustration, or trade dress.

## Shared strengths

- The current person is the largest visual element.
- Name, age, intent, and useful compatibility cues can be scanned without opening another screen.
- Primary actions are few, large, and reachable with one thumb.
- Filters are available from discovery without becoming the focus.
- Profile prompts and common interests provide a reason to start a conversation.
- Safety is visible and accessible without making every profile feel alarming.
- Navigation uses four or five stable destinations with a strong selected state.

## Problems in the former Vawra prototype

- Engineering and policy explanations appeared before the person and dominated the card.
- The photo occupied too little of the first viewport.
- Material defaults made the product look like a settings form rather than a dating experience.
- The welcome screen was a legal checklist with weak emotional hierarchy.
- Action buttons, filters, and navigation lacked a distinctive Vawra system.
- Relationship intent and privacy information required too much reading.

## Vawra direction

Vawra combines photo-first clarity with intent-first context:

- a large immersive portrait with a restrained gradient for readable information;
- intent and coarse-distance privacy pills directly on the image;
- a prompt-like biography section and visually consistent interest chips;
- one emphasized coral Like action, quieter Pass and Next actions, plus retained swipe gestures;
- compact Vawra/filter/safety discovery chrome;
- a calm coral/plum/blush design system with large rounded shapes and minimal elevation;
- a welcoming adult/consent gate that remains explicit without reading like a settings screen;
- prototype and safety disclosures preserved, but demoted from the primary emotional hierarchy.

The same system now extends through welcome, discovery, connections, chat, and profile editing. Existing safety, consent, report, block, match, messaging, and mutual-call-readiness behavior remains intact.

CP-053 applies the owner's preferred presentation principles more directly: a split illustration/content welcome screen, floating circular people previews, a story-style discovery strip, a dominant portrait card, and a floating high-contrast navigation pill. These are composition principles only; Vawra retains its own logo, palette, copy, safety disclosures, profile fixtures, and interaction rules.
