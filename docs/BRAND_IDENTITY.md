# Vawra brand identity

## Core mark

Vawra's approved company mark is a continuous heart-shaped ribbon surrounding two facing profiles. The coral, pink, peach, and plum folds represent attraction, warmth, conversation, and partnership.

The owner-supplied identity sheet dated 2026-09-24 is the visual authority. The app uses a clean transparent extraction of that approved mark rather than reproducing the entire presentation sheet.

## Palette

- Vawra Coral: `#F24F78`
- Vawra Plum: `#5A274F`
- Blush Canvas: `#FFF6F9`

## Assets

- `assets/branding/vawra_company_mark.png` is the transparent approved company mark used inside the app.
- `assets/branding/vawra_mark.png` preserves the earlier exploratory ribbon mark for provenance; it is not the active identity.
- `assets/branding/vawra_welcome_background.png` is the original welcome-screen artwork.
- Android launcher assets live in `android/app/src/main/res/mipmap-*`.
- iOS launcher assets live in `ios/Runner/Assets.xcassets/AppIcon.appiconset`.

Launcher assets place the approved mark on the opaque Blush Canvas so it remains legible under platform masks. Do not add text, shadows, or another enclosing heart around the mark.

## Trademark usage

Use `Vawra` and the approved mark consistently as brand identifiers. Do not use the registered-trademark symbol (`®`) or claim registration unless the owner supplies confirmation of an active registration for the relevant jurisdiction and goods/services. This engineering record is not a trademark clearance opinion.

## Generation record

The active master was extracted with the built-in image-generation workflow from the owner-supplied company identity sheet. The extraction request preserved the approved profiles, ribbon geometry, proportions, gradients, highlights, and silhouette while removing the presentation sheet, wordmark, tagline, and background.

The Android and iOS size variants are deterministic resizes of the selected master, not separately generated artwork.
