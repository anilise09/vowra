# Vawra website preview

Static, responsive product website for the 18+ Vawra app. It uses screens from the app in testing; all profiles shown are synthetic and are labeled in the app.

Screens (`assets/screens/*.webp`, 720px wide):

- `discover`, `explore`, `openers`, `chat`: rendered from the app's own code with real fonts by `flutter test tool/site_screens_test.dart --update-goldens` (output in `build/site_screens/`), then converted to WebP.
- `reasons`, `show-me`, `export`: captured on the owner's Asus during the 2026-09-28 device test, with the phone's status bar and system buttons cropped off. The renderer shows block glyphs for button and chip text whose style names no font, so screens with those come from the phone.
- `call`, `scam`, `distance`: captured on the owner's Asus on 2026-09-30 (a voice call with the test member Priya, a gift-card request with its warning, the Distance sheet), cropped to 1080x2124 below the status bar and resized to 720x1416.

Fonts (Manrope, Playfair Display italic) are served from `assets/fonts/` under the SIL Open Font License; no request leaves the site. The site does not collect contact information, run analytics, imply a public launch, or provide a sign-up form.

Live prototype preview: https://anilise09.github.io/vowra/ (published from `gh-pages`, not an app launch).

Pages: `index.html` (home), `safety.html` (community guidelines and how the safety tools work), `privacy.html` (a plain-language description of the app's data handling, marked as not yet the legal privacy policy). Every statement on them describes behaviour built and tested in the app.

Open `index.html` directly or serve this directory with any static web server. All runtime assets are local to `website/`.

Run `powershell -ExecutionPolicy Bypass -File website/check.ps1` from the repository root to verify links, assets, preview screens, launch disclosures, and responsive/reduced-motion rules.

Before a production launch, clear the Vawra trademark and domain, complete privacy/legal/security review, replace prototype screenshots with approved release images, and update the availability wording. Do not add store badges, a waitlist, or real-member claims until those experiences exist.
