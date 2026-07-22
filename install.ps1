# deft installer for native Windows (PowerShell).
#
#   irm https://deft-cli.com/install.ps1 | iex
#
# Downloads the latest release binary, installs it to
# %LOCALAPPDATA%\deft\bin (override with $env:DEFT_BIN_DIR), adds that to your
# user PATH, and runs `deft doctor`.
#
#   $env:DEFT_VERSION = "v0.6.0"   # pin a version instead of the latest

$ErrorActionPreference = "Stop"
$repo = "xntas/deft"

$binDir = if ($env:DEFT_BIN_DIR) { $env:DEFT_BIN_DIR } else { "$env:LOCALAPPDATA\deft\bin" }

# Windows builds are x86_64 for now.
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -ne "AMD64") {
  throw "no Windows build for '$arch' yet — build from source: https://github.com/$repo"
}
$target = "x86_64-pc-windows-msvc"

# Resolve version.
if ($env:DEFT_VERSION) {
  $tag = $env:DEFT_VERSION
} else {
  Write-Host "  resolving latest release..."
  $tag = (Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest").tag_name
  if (-not $tag) { throw "couldn't determine the latest release (set `$env:DEFT_VERSION to pin one)" }
}

$asset = "deft-$target.zip"
$url   = "https://github.com/$repo/releases/download/$tag/$asset"
Write-Host "  installing deft $tag ($target)"

$tmp = Join-Path $env:TEMP ("deft-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
  $zip = Join-Path $tmp $asset
  Write-Host "  downloading $asset"
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $tmp -Force

  $src = Join-Path $tmp "deft-$target\deft.exe"
  if (-not (Test-Path $src)) { throw "archive did not contain deft.exe" }

  New-Item -ItemType Directory -Force -Path $binDir | Out-Null
  Copy-Item $src (Join-Path $binDir "deft.exe") -Force
  Write-Host "  installed to $binDir\deft.exe"
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# Add to the user PATH if it isn't already there.
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
  $env:Path = "$env:Path;$binDir"
  Write-Host "  added $binDir to your user PATH (restart your terminal for it to stick)"
}

Write-Host ""
Write-Host "  running 'deft doctor' to check your environment..."
Write-Host ""
& "$binDir\deft.exe" doctor
