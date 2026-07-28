# Wraps index.html (which is body-content only, the format the Claude artifact
# host expects) into a complete standalone page, and writes docs/ — the folder
# GitHub Pages serves.
#
# The page is entirely self-contained: no fonts, scripts, styles or images are
# fetched from anywhere. That makes a very tight Content-Security-Policy
# possible, so this script hashes the one inline <style> and the one inline
# <script> and signs them, rather than falling back to 'unsafe-inline'.
#
# Run after every edit to index.html.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$body = Get-Content (Join-Path $root 'index.html') -Raw -Encoding UTF8
$site = Join-Path $root 'docs'
New-Item -ItemType Directory -Force $site | Out-Null

$title = 'Yuval Gabay — CV'
$desc  = 'Law student, graphic designer and self-taught builder. Two apps built and running. CV for the Bavaria Israel Partnership Accelerator 2026.'

function Get-CspHash([string]$content) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    return "'sha256-" + [Convert]::ToBase64String($sha.ComputeHash($bytes)) + "'"
  } finally { $sha.Dispose() }
}

# Pull out the exact text the browser will hash — everything between the tags,
# byte for byte, with no reformatting anywhere in this script.
function Get-BlockHashes([string]$html, [string]$tag) {
  $hashes = @()
  $open = "<$tag>"
  $close = "</$tag>"
  $i = 0
  while ($true) {
    $s = $html.IndexOf($open, $i)
    if ($s -lt 0) { break }
    $s += $open.Length
    $e = $html.IndexOf($close, $s)
    if ($e -lt 0) { break }
    $hashes += Get-CspHash $html.Substring($s, $e - $s)
    $i = $e + $close.Length
  }
  return $hashes
}

# Scales of justice, drawn as a data URI so the tab icon needs no extra request.
$icon = 'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 32 32%22%3E%3Crect width=%2232%22 height=%2232%22 rx=%226%22 fill=%22%230A0D15%22/%3E%3Cg stroke=%22%23E4AC48%22 stroke-width=%221.8%22 fill=%22none%22 stroke-linecap=%22round%22%3E%3Cpath d=%22M16 7v18%22/%3E%3Cpath d=%22M8 11h16%22/%3E%3Cpath d=%22M11 25h10%22/%3E%3Cpath d=%22M5 18a3.5 3.5 0 0 0 6 0l-3-7z%22/%3E%3Cpath d=%22M21 18a3.5 3.5 0 0 0 6 0l-3-7z%22/%3E%3C/g%3E%3C/svg%3E'

$head = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<meta name="description" content="$desc">
<meta name="author" content="Yuval Gabay">

<!-- Reachable by anyone holding the link, kept out of search results:
     the page carries a personal phone number. -->
<meta name="robots" content="noindex, nofollow">
<meta name="referrer" content="strict-origin-when-cross-origin">
<meta http-equiv="Content-Security-Policy" content="__CSP__">

<meta property="og:type" content="profile">
<meta property="og:title" content="$title">
<meta property="og:description" content="$desc">
<meta property="og:locale" content="en_GB">
<meta name="twitter:card" content="summary">
<meta name="theme-color" content="#0A0D15" media="(prefers-color-scheme: dark)">
<meta name="theme-color" content="#E9EBEF" media="(prefers-color-scheme: light)">
<link rel="icon" href="$icon">
<style>
  html { -webkit-text-size-adjust: 100%; }
  body { margin: 0; }
</style>
</head>
<body>
"@

# Hash every inline block the browser will actually execute: the page's own
# style and script, plus the small reset in the wrapper above. The __CSP__
# token is not inside any of them, so hashing before substitution is exact.
$styleHashes  = @(Get-BlockHashes $head 'style') + @(Get-BlockHashes $body 'style')
$scriptHashes = @(Get-BlockHashes $body 'script')
if ($styleHashes.Count -lt 2) { throw 'Expected an inline <style> in both the wrapper and the page — refusing to write a policy that would break it.' }
if ($scriptHashes.Count -lt 1) { throw 'No inline <script> found — refusing to write a policy that would break the page.' }

# default-src 'none' denies everything; each directive below re-opens only what
# this page actually uses. img-src covers the data: URI favicon. There is no
# connect-src because the page never talks to a network.
$csp = @(
  "default-src 'none'",
  "style-src $($styleHashes -join ' ')",
  "script-src $($scriptHashes -join ' ')",
  "img-src 'self' data:",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
  "object-src 'none'",
  "upgrade-insecure-requests"
) -join '; '

$out = $head.Replace('__CSP__', $csp) + $body + "`n</body>`n</html>`n"
[System.IO.File]::WriteAllText((Join-Path $site 'index.html'), $out, [System.Text.UTF8Encoding]::new($false))

# Serve the files as-is instead of running Jekyll over them.
[System.IO.File]::WriteAllText((Join-Path $site '.nojekyll'), '', [System.Text.UTF8Encoding]::new($false))

# GitHub Pages cannot send custom response headers. This file is ignored there,
# but if the site is ever moved to Cloudflare Pages or Netlify it applies the
# same policy at the HTTP layer, where frame-ancestors and HSTS actually bite.
$headers = @"
/*
  Content-Security-Policy: $csp
  Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=(), usb=(), interest-cohort=()
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Resource-Policy: same-origin
"@
[System.IO.File]::WriteAllText((Join-Path $site '_headers'), $headers, [System.Text.UTF8Encoding]::new($false))

Copy-Item (Join-Path $root 'Yuval-Gabay-CV.pdf') (Join-Path $site 'Yuval-Gabay-CV.pdf') -Force

$kb = [math]::Round((Get-Item (Join-Path $site 'index.html')).Length / 1kb, 1)
Write-Output "docs/index.html written ($kb KB)"
Write-Output "style hashes : $($styleHashes.Count)"
Write-Output "script hashes: $($scriptHashes.Count)"
