# Competitive mobile UI research

Research date: 2026-09-24

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

This checkpoint improves the welcome and discovery experience. Matches, chats, and profile editing retain their existing behavior and should receive the same component-level redesign in later UI checkpoints.
