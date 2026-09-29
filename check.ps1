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
foreach ($screen in @('discover','explore','match','chat')) {
  if ($script -notmatch "${screen}\.png") { throw "Preview missing $screen" }
  if (-not (Test-Path -LiteralPath (Join-Path $site "assets/screens/raw/$screen.png"))) { throw "Screen asset missing: $screen" }
}
foreach ($required in @('prototype', 'synthetic', 'not a public dating service', 'Block and report are always free')) {
  if ($html -notmatch [regex]::Escape($required)) { throw "Missing disclosure: $required" }
}
foreach ($breakpoint in @('max-width:1050px','max-width:720px','max-width:380px','prefers-reduced-motion:reduce')) {
  if (-not $css.Contains($breakpoint)) { throw "Missing responsive or motion rule: $breakpoint" }
}
if ($html -match '<form\b|https?://') { throw 'Unexpected form or external request in static HTML' }
Write-Output 'Vawra website static checks passed.'
