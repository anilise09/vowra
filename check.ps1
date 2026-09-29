$ErrorActionPreference = 'Stop'
$site = $PSScriptRoot
$html = Get-Content -LiteralPath (Join-Path $site 'index.html') -Raw
$css = Get-Content -LiteralPath (Join-Path $site 'styles.css') -Raw
$script = Get-Content -LiteralPath (Join-Path $site 'script.js') -Raw

$ids = [regex]::Matches($html, 'id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
foreach ($href in [regex]::Matches($html, 'href="#([^"]+)"')) {
  if ($ids -notcontains $href.Groups[1].Value) { throw "Broken page anchor: #$($href.Groups[1].Value)" }
}
foreach ($asset in [regex]::Matches($html, '(?:src|href)="(assets/[^"#]+)"')) {
  $relative = $asset.Groups[1].Value.Replace('/', [IO.Path]::DirectorySeparatorChar)
  if (-not (Test-Path -LiteralPath (Join-Path $site $relative))) { throw "Missing asset: $relative" }
}
foreach ($screen in @('discover','explore','openers','chat')) {
  if ($script -notmatch "${screen}\.webp") { throw "Preview missing $screen" }
  if (-not (Test-Path -LiteralPath (Join-Path $site "assets/screens/$screen.webp"))) { throw "Screen asset missing: $screen" }
}
# Every image the page loads stays light: WebP screens, nothing over 200 KB.
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $site 'assets') -Recurse -File -Include *.png,*.webp,*.jpg) {
  if ($file.Length -gt 200KB) { throw "Image too heavy for the web: $($file.Name) ($([int]($file.Length / 1KB)) KB)" }
}
if ($html + $script -match 'screens/raw/|\.png"\s+alt="[^"]*screen') { throw 'Page still points at unconverted screens' }
# The fonts the design names are served from this site, with their licences.
foreach ($font in @('manrope-latin.woff2','playfair-display-italic-latin.woff2','OFL-Manrope.txt','OFL-PlayfairDisplay.txt')) {
  if (-not (Test-Path -LiteralPath (Join-Path $site "assets/fonts/$font"))) { throw "Missing font file: $font" }
}
foreach ($face in @('font-family:Manrope', "font-family:'Playfair Display'")) {
  if (-not $css.Contains("@font-face{$face")) { throw "Font not loaded: $face" }
}
# Only claim what exists: calls are not built yet.
if ($html -match 'Calls require') { throw 'Calls are described as if they exist' }
foreach ($required in @('prototype', 'synthetic', 'not a public dating service', 'Block and report are always free')) {
  if ($html -notmatch [regex]::Escape($required)) { throw "Missing disclosure: $required" }
}
foreach ($breakpoint in @('max-width:1050px','max-width:720px','max-width:380px','prefers-reduced-motion:reduce')) {
  if (-not $css.Contains($breakpoint)) { throw "Missing responsive or motion rule: $breakpoint" }
}
if ($html -match '<form\b|https?://') { throw 'Unexpected form or external request in static HTML' }
Write-Output 'Vawra website static checks passed.'
