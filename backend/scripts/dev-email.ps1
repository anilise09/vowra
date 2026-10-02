# Development only: lets Vawra's test server on this laptop email sign-in codes
# through your own Gmail. Run it yourself on the laptop:
#   powershell -ExecutionPolicy Bypass -File D:\Projects\dating-app-wt-claude\backend\scripts\dev-email.ps1
# It asks for your Gmail address and an app password (made at
# https://myaccount.google.com/apppasswords; needs 2-Step Verification) and saves them
# only in the server's local settings file, which git never tracks. Nothing is printed or sent
# anywhere else. To stop, run it with -Remove.
param(
  [string]$EnvFile = 'D:\Projects\dating-app\backend\.data\dev.env',
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $EnvFile)) { throw "No settings file at $EnvFile" }
$kept = @(Get-Content -LiteralPath $EnvFile | Where-Object { $_ -notmatch '^VAWRA_(SMTP_URL|EMAIL_FROM)=' })

if (-not $Remove) {
  $address = (Read-Host 'Your Gmail address').Trim()
  if ($address -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw 'That does not look like an email address.' }
  $secure = Read-Host 'Gmail app password (16 letters; spaces are fine)' -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) -replace '\s', '' }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  if ($password -notmatch '^[A-Za-z]{16}$') { throw 'A Gmail app password is 16 letters.' }
  $user = [Uri]::EscapeDataString($address)
  # Quoted: the server reads this file with a shell, where < and > mean something.
  $kept += "VAWRA_SMTP_URL='smtps://${user}:${password}@smtp.gmail.com:465'"
  $kept += "VAWRA_EMAIL_FROM='Vawra <$address>'"
}
# Unix line endings, as the server's shell expects.
[IO.File]::WriteAllText($EnvFile, (($kept -join "`n") + "`n"), [Text.Encoding]::ASCII)
if ($Remove) { 'Removed. Codes go to the local file again after the server restarts.' }
else { 'Saved. Tell Claude "email is set" and the test server will restart with it.' }
