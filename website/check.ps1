$ErrorActionPreference = 'Stop'
$site = $PSScriptRoot
$css = Get-Content -LiteralPath (Join-Path $site 'styles.css') -Raw
$script = Get-Content -LiteralPath (Join-Path $site 'script.js') -Raw

$pages = @('index.html', 'safety.html', 'privacy.html', 'get-the-app.html')
$html = @{}
foreach ($page in $pages) {
  $path = Join-Path $site $page
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing page: $page" }
  $html[$page] = Get-Content -LiteralPath $path -Raw
}
$ids = @{}
foreach ($page in $pages) {
  $ids[$page] = [regex]::Matches($html[$page], 'id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
}

foreach ($page in $pages) {
  $text = $html[$page]
  # Links within the site: other pages exist, and every #anchor exists on its page.
  foreach ($link in [regex]::Matches($text, 'href="([a-z-]+\.html)?(#[^"]+)?"')) {
    $target = if ($link.Groups[1].Value) { $link.Groups[1].Value } else { $page }
    if (-not $html.ContainsKey($target)) { throw "$page links to a missing page: $target" }
    $anchor = $link.Groups[2].Value
    if ($anchor -and ($ids[$target] -notcontains $anchor.Substring(1))) { throw "$page has a broken link: $target$anchor" }
  }
  foreach ($asset in [regex]::Matches($text, '(?:src|href)="(assets/[^"#]+)"')) {
    $relative = $asset.Groups[1].Value.Replace('/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath (Join-Path $site $relative))) { throw "$page is missing an asset: $relative" }
  }
  if ($text -match '<form\b|https?://') { throw "$page has a form or an external request" }
  # Only the site's own files may load, and nothing inline that the policy would block.
  $policy = '<meta http-equiv="Content-Security-Policy" content="default-src ''none''; script-src ''self''; style-src ''self''; img-src ''self''; font-src ''self''; media-src ''self''; base-uri ''none''; form-action ''none''">'
  if (-not $text.Contains($policy)) { throw "$page lacks the content security policy" }
  if ($text -match '\sstyle="|\son[a-z]+="|<script>') { throw "$page has inline code the policy would block" }
  # Every page says plainly that Vawra is not launched.
  if ($text -notmatch 'Not a live dating service') { throw "$page lacks the launch disclosure" }
  # Things the header menu script needs on every page.
  foreach ($needed in @('class="menu-toggle"', 'id="nav-links"', 'id="year"', 'id="main"')) {
    if (-not $text.Contains($needed)) { throw "$page lacks $needed" }
  }
  # Only claim what exists: no store badges, sign-ups or real-member claims.
  if ($text -match '(?i)get it on|download on the|download now|join the waitlist|sign up now|join now|millions of') { throw "$page makes a launch claim" }
}

$index = $html['index.html']
foreach ($screen in @('discover','explore','openers','chat')) {
  if ($script -notmatch "${screen}\.webp") { throw "Preview missing $screen" }
  if (-not (Test-Path -LiteralPath (Join-Path $site "assets/screens/$screen.webp"))) { throw "Screen asset missing: $screen" }
}
# Every image the page loads stays light: WebP screens, nothing over 200 KB.
$assets = Get-ChildItem -LiteralPath (Join-Path $site 'assets') -Recurse -File
foreach ($file in $assets | Where-Object { $_.Extension -in '.png', '.webp', '.jpg' }) {
  if ($file.Length -gt 200KB) { throw "Image too heavy for the web: $($file.Name) ($([int]($file.Length / 1KB)) KB)" }
}
# A video loads only when someone presses play, but stays small enough for a phone connection.
foreach ($file in $assets | Where-Object { $_.Extension -in '.mp4', '.webm' }) {
  if ($file.Length -gt 8MB) { throw "Video too heavy for the web: $($file.Name) ($([int]($file.Length / 1MB)) MB)" }
}
if ($index + $script -match 'screens/raw/|\.png"\s+alt="[^"]*screen') { throw 'Page still points at unconverted screens' }
# The fonts the design names are served from this site, with their licences.
foreach ($font in @('manrope-latin.woff2','playfair-display-italic-latin.woff2','OFL-Manrope.txt','OFL-PlayfairDisplay.txt')) {
  if (-not (Test-Path -LiteralPath (Join-Path $site "assets/fonts/$font"))) { throw "Missing font file: $font" }
}
foreach ($face in @('font-family:Manrope', "font-family:'Playfair Display'")) {
  if (-not $css.Contains("@font-face{$face")) { throw "Font not loaded: $face" }
}
# Calls exist in the app now: wherever they are described, both people opt in and nothing is recorded.
foreach ($page in $pages) {
  $text = $html[$page]
  if ($text -match '(?i)voice (and|or) video call') {
    if ($text -notmatch 'never recorded') { throw "$page describes calls without saying they are never recorded" }
    if ($text -notmatch 'Open to a call') { throw "$page describes calls without the both-opt-in rule" }
  }
  if ($text -match '(?i)calls? (are|is) not built') { throw "$page still says calls are not built" }
}
foreach ($required in @('prototype', 'synthetic', 'not a public dating service', 'Block and report are always free')) {
  if ($index -notmatch [regex]::Escape($required)) { throw "Missing disclosure: $required" }
}
# The owner turned on the Android prototype (2026-10-03); iPhone stays off until TestFlight exists.
# Exactly one app file, the signed prototype served from this site, with its checksum on the page.
$app = $html['get-the-app.html']
if (([regex]::Matches($app, 'aria-disabled="true"')).Count -ne 1) { throw 'get-the-app.html: the iPhone button must stay disabled' }
if (([regex]::Matches($app, '(?i)\.apk\b')).Count -ne 1 -or -not $app.Contains('href="vawra-android.apk"')) { throw 'get-the-app.html must link only to vawra-android.apk' }
if ($app -match '(?i)\.ipa\b|apps\.apple|play\.google|testflight\.apple') { throw 'get-the-app.html links to an iPhone file or a store' }
if ($app -notmatch '[0-9a-f]{64}') { throw 'get-the-app.html lacks the app file checksum' }
# The app file itself lives only on the published site (gh-pages), so main stays small; where it
# is present, the page must show its real checksum.
$apk = Join-Path $site 'vawra-android.apk'
if (Test-Path -LiteralPath $apk) {
  $hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
  if (-not $app.Contains($hash)) { throw "get-the-app.html shows a checksum that is not the app file's ($hash)" }
}
if (-not (Test-Path -LiteralPath (Join-Path $site 'assets/video/setup-android.vtt'))) { throw 'The setup video has no captions' }
# The privacy page is honest about its status until a lawyer has reviewed it.
if ($html['privacy.html'] -notmatch 'not yet its legal privacy policy') { throw 'Privacy page lacks its draft status' }
foreach ($breakpoint in @('max-width:1050px','max-width:720px','max-width:380px','prefers-reduced-motion:reduce')) {
  if (-not $css.Contains($breakpoint)) { throw "Missing responsive or motion rule: $breakpoint" }
}
# Logos keep their shape: a sized logo image must let its height follow the width.
foreach ($rule in @('.brand img{width:174px;height:auto', '.footer-brand img{width:168px;height:auto')) {
  if (-not $css.Contains($rule)) { throw "Logo may be squashed: $rule" }
}
Write-Output 'Vawra website static checks passed.'
