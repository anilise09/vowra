# Vawra brand identity

## Core mark

Vawra's mark is built from two meeting ribbons. Together they create a subtle `V` silhouette and a heart-shaped negative space, representing mutual connection, consent, warmth, and equal partnership.

The mark deliberately avoids the category's common standalone flame, swipe card, location pin, and chat-bubble motifs. It must remain recognizable at 24 px.

## Palette

- Vawra Coral: `#F24F78`
- Vawra Plum: `#5A274F`
- Blush Canvas: `#FFF6F9`

## Assets

- `assets/branding/vawra_mark.png` is the transparent master used inside the app.
- Android launcher assets live in `android/app/src/main/res/mipmap-*`.
- iOS launcher assets live in `ios/Runner/Assets.xcassets/AppIcon.appiconset`.

Launcher assets place the mark on the opaque Blush Canvas so it remains legible under platform masks. Do not add text, shadows, or another enclosing heart around the mark.

## Generation record

The master was produced with the built-in image-generation workflow as an original, vector-friendly symbol. The final prompt requested two meeting ribbon forms, a subtle `V`, heart-shaped negative space, coral/plum colors, transparent background, a strong small-size silhouette, and no text, trademarks, mockup, 3D treatment, or competitor-like flame/swipe imagery.

The Android and iOS size variants are deterministic resizes of the selected master, not separately generated artwork.
